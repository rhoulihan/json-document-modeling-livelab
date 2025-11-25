# Lab 7: Avoiding LOB Performance Cliffs

## Introduction

Oracle's OSON (Optimized Binary JSON) format has distinct performance tiers based on document size. Understanding these tiers and designing your data model to stay within optimal size ranges is critical for achieving maximum performance.

In this lab, you will learn the OSON performance tiers, document splitting strategies, real-time monitoring techniques, and how to architect your Single Collection design to avoid crossing into the LOB cliff.

**Estimated Time:** 45 minutes

## Prerequisites

- Completed Lab 1: JSON Collections Fundamentals (OSON basics)
- Completed Lab 3: Single Collection/Table Design Pattern
- Understanding of document sizing and storage considerations

## Objectives

In this lab, you will:
- Understand OSON performance tiers (inline, LOB, large LOB)
- Measure document sizes and identify LOB cliff candidates
- Implement document splitting strategies
- Create real-time monitoring and alerting for document sizes
- Apply architectural patterns to prevent unbounded growth

## Task 1: Understanding OSON Performance Tiers

### Step 1: The Three Performance Tiers

Oracle stores JSON documents in OSON (Optimized Binary JSON) format with three distinct performance tiers:

```
Performance Tier         Size Range              Performance    Storage Location
-------------------      -------------------     -----------    ----------------
✅ INLINE (Optimal)      < 7,950 bytes           Fastest        Inline with row data
⚠️  LOB (Good)           7,950 bytes - 10MB      Good           LOB segment
❌ LARGE LOB (Slow)      10MB - 32MB             Slower         LOB segment
🚫 ERROR                 > 32MB                  Not allowed    N/A (hard limit)
```

### Step 2: Create Test Collection

```sql
-- Create JSON Collection Table for performance testing
CREATE JSON COLLECTION TABLE perf_test;

-- Create index on _id
CREATE INDEX idx_perf_id ON perf_test (JSON_VALUE(data, '$._id'));
```

### Step 3: Insert Test Documents

```sql
-- Test 1: Small inline document (< 7,950 bytes)
INSERT INTO perf_test (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'DOC-INLINE-SMALL',
    'type' VALUE 'small',
    'data' VALUE RPAD('x', 3000, 'x')
  )
);

-- Test 2: Medium inline document (approaching threshold)
INSERT INTO perf_test (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'DOC-INLINE-MEDIUM',
    'type' VALUE 'medium',
    'data' VALUE RPAD('x', 3900, 'x')
  )
);

COMMIT;
```

### Step 4: Measure Document Sizes and Storage Tier

```sql
-- Measure document sizes and determine storage tier
SELECT
  JSON_VALUE(data, '$._id') AS doc_id,
  JSON_VALUE(data, '$.type') AS doc_type,
  LENGTHB(data) AS size_bytes,
  ROUND(LENGTHB(data) / 1024, 2) AS size_kb,
  CASE
    WHEN LENGTHB(data) < 7950 THEN 'INLINE (Optimal)'
    WHEN LENGTHB(data) < 10485760 THEN 'LOB (Good)'
    WHEN LENGTHB(data) < 33554432 THEN 'LARGE LOB (Slow)'
    ELSE 'ERROR (Too Large)'
  END AS storage_tier
FROM perf_test
ORDER BY LENGTHB(data);
```

Expected output:
```
DOC_ID              DOC_TYPE  SIZE_BYTES  SIZE_KB   STORAGE_TIER
------------------  --------  ----------  --------  -------------------
DOC-INLINE-SMALL    small         3067      3.00    INLINE (Optimal)
DOC-INLINE-MEDIUM   medium        3967      3.87    INLINE (Optimal)
```

### Step 5: Benchmark Read Performance

```sql
SET SERVEROUTPUT ON;

DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_duration NUMBER;
  v_data CLOB;
  v_iterations NUMBER := 100;
  v_total_duration NUMBER;
BEGIN
  -- Test small inline document reads
  v_total_duration := 0;
  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;
    SELECT JSON_SERIALIZE(data)
    INTO v_data
    FROM perf_test
    WHERE JSON_VALUE(data, '$._id') = 'DOC-INLINE-SMALL';
    v_end := SYSTIMESTAMP;
    v_duration := EXTRACT(SECOND FROM (v_end - v_start)) * 1000;
    v_total_duration := v_total_duration + v_duration;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('INLINE (3KB): ' || ROUND(v_total_duration / v_iterations, 2) || ' ms avg');

  -- Test medium inline document reads
  v_total_duration := 0;
  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;
    SELECT JSON_SERIALIZE(data)
    INTO v_data
    FROM perf_test
    WHERE JSON_VALUE(data, '$._id') = 'DOC-INLINE-MEDIUM';
    v_end := SYSTIMESTAMP;
    v_duration := EXTRACT(SECOND FROM (v_end - v_start)) * 1000;
    v_total_duration := v_total_duration + v_duration;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('INLINE (3.9KB): ' || ROUND(v_total_duration / v_iterations, 2) || ' ms avg');
END;
/
```

Expected output:
```
INLINE (3KB): ~1-2 ms avg
INLINE (3.9KB): ~1-2 ms avg

Key Insight:
- Inline documents typically read in 1-2ms
- Once documents exceed 7,950 bytes, they move to LOB storage (~5-10ms)
- Large LOB documents over 10MB can take 100-200ms to read
```

## Task 2: Identifying LOB Cliff Candidates

### Step 1: Monitoring Current Document Sizes

```sql
-- Create comprehensive monitoring query
SELECT
  JSON_VALUE(data, '$.type') AS document_type,
  COUNT(*) AS document_count,
  ROUND(AVG(LENGTHB(data)), 0) AS avg_size_bytes,
  ROUND(MIN(LENGTHB(data)), 0) AS min_size_bytes,
  ROUND(MAX(LENGTHB(data)), 0) AS max_size_bytes,
  SUM(CASE WHEN LENGTHB(data) < 7950 THEN 1 ELSE 0 END) AS inline_count,
  SUM(CASE WHEN LENGTHB(data) >= 7950 AND LENGTHB(data) < 10485760 THEN 1 ELSE 0 END) AS lob_count,
  SUM(CASE WHEN LENGTHB(data) >= 10485760 THEN 1 ELSE 0 END) AS large_lob_count
FROM perf_test
GROUP BY JSON_VALUE(data, '$.type')
ORDER BY MAX(LENGTHB(data)) DESC;
```

### Step 2: Find Documents Approaching Limits

```sql
-- Identify documents at risk of crossing thresholds
SELECT
  JSON_VALUE(data, '$._id') AS doc_id,
  JSON_VALUE(data, '$.type') AS doc_type,
  LENGTHB(data) AS size_bytes,
  ROUND(LENGTHB(data) / 1024, 2) AS size_kb,
  CASE
    WHEN LENGTHB(data) >= 7000 AND LENGTHB(data) < 7950 THEN 'Near inline limit (7KB)'
    WHEN LENGTHB(data) >= 9437184 AND LENGTHB(data) < 10485760 THEN 'Near LOB cliff (9MB)'
    WHEN LENGTHB(data) >= 30408704 THEN 'Near hard limit (29MB)'
    WHEN LENGTHB(data) >= 7950 THEN 'Already in LOB'
    ELSE 'Optimal size'
  END AS status
FROM perf_test
WHERE LENGTHB(data) >= 3000
ORDER BY LENGTHB(data) DESC;
```

## Task 3: Document Splitting Strategies

### Step 1: Vertical Splitting (Hot vs Cold Data)

The anti-pattern is a single large document with all fields:

```sql
-- Create collection for split example
CREATE JSON COLLECTION TABLE customer_split;
CREATE INDEX idx_customer_split_id ON customer_split (JSON_VALUE(data, '$._id'));
```

**Anti-Pattern: All data in one document (would be 450KB)**:
```json
{
  "_id": "CUSTOMER#456",
  "name": "John Doe",
  "email": "john@example.com",
  "full_order_history": [/* 5,000 orders = 250KB */],
  "full_payment_history": [/* 5,000 payments = 200KB */]
}
```

**Solution: Vertical Split - Separate hot and cold data**:

```sql
-- Hot data: Frequently accessed (stays small, INLINE)
INSERT INTO customer_split (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'CUSTOMER#456',
    'type' VALUE 'customer',
    'name' VALUE 'John Doe',
    'email' VALUE 'john@example.com',
    'tier' VALUE 'gold',
    'stats' VALUE JSON_OBJECT(
      'total_orders' VALUE 5000,
      'lifetime_value' VALUE 125000,
      'last_order_date' VALUE '2024-11-18'
    ),
    'recent_orders' VALUE JSON_ARRAY(
      JSON_OBJECT('order_id' VALUE 'ORD-4999', 'total' VALUE 89.99),
      JSON_OBJECT('order_id' VALUE 'ORD-5000', 'total' VALUE 125.50)
    )
  )
);
-- Document size: ~1KB - INLINE (Optimal)

-- Cold data: Full order archive (separate document, accessed rarely)
INSERT INTO customer_split (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'CUSTOMER#456#ARCHIVE',
    'type' VALUE 'order_archive',
    'customer_id' VALUE 'CUSTOMER#456',
    'summary' VALUE JSON_OBJECT(
      'total_archived_orders' VALUE 4998,
      'archive_date' VALUE SYSTIMESTAMP
    )
  )
);
-- Archive document with summary only: ~500 bytes - INLINE

COMMIT;

-- Verify sizes
SELECT
  JSON_VALUE(data, '$._id') AS doc_id,
  JSON_VALUE(data, '$.type') AS doc_type,
  LENGTHB(data) AS size_bytes,
  CASE WHEN LENGTHB(data) < 7950 THEN 'INLINE' ELSE 'LOB' END AS storage
FROM customer_split;
```

**Result:**
- Hot path query (customer profile): ~2ms (inline document)
- Cold path query (full archive): Only when needed

### Step 2: Horizontal Splitting (Using Composite Keys)

**Anti-Pattern: Unbounded array grows forever**:
```json
{
  "_id": "USER#123",
  "all_posts": [/* grows forever, eventually exceeds 32MB */]
}
```

**Solution: Separate documents with composite keys (from Lab 3)**:

```sql
-- Create collection for social example
CREATE JSON COLLECTION TABLE social_split;
CREATE INDEX idx_social_id ON social_split (JSON_VALUE(data, '$._id'));

-- User document (small, frequently accessed)
INSERT INTO social_split (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'USER#123',
    'type' VALUE 'user',
    'name' VALUE 'Jane Smith',
    'stats' VALUE JSON_OBJECT(
      'post_count' VALUE 10000,
      'follower_count' VALUE 5420
    )
  )
);
-- Document size: ~200 bytes - INLINE

-- Each post is a separate document
INSERT INTO social_split (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'USER#123#POST#001',
    'type' VALUE 'post',
    'user_id' VALUE 'USER#123',
    'user_name' VALUE 'Jane Smith',
    'content' VALUE 'My first post!',
    'created_at' VALUE SYSTIMESTAMP
  )
);

INSERT INTO social_split (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'USER#123#POST#002',
    'type' VALUE 'post',
    'user_id' VALUE 'USER#123',
    'user_name' VALUE 'Jane Smith',
    'content' VALUE 'Another post!',
    'created_at' VALUE SYSTIMESTAMP
  )
);
-- Each post: ~300 bytes - INLINE

COMMIT;

-- Query user's recent posts using composite key prefix
SELECT JSON_SERIALIZE(data PRETTY)
FROM social_split
WHERE JSON_VALUE(data, '$._id') LIKE 'USER#123#POST#%'
ORDER BY JSON_VALUE(data, '$.created_at') DESC
FETCH FIRST 20 ROWS ONLY;
```

**Benefits:**
- Each post: ~300 bytes (INLINE)
- Can scale to millions of posts
- Query performance: 5-10ms for paginated results

### Step 3: Time-Based Archiving

```sql
-- Create collection for logs example
CREATE JSON COLLECTION TABLE logs_archive;
CREATE INDEX idx_logs_id ON logs_archive (JSON_VALUE(data, '$._id'));

-- Active logs (current month)
INSERT INTO logs_archive (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'LOGS#app-server-01#2024-11',
    'type' VALUE 'active_logs',
    'server_id' VALUE 'app-server-01',
    'month' VALUE '2024-11',
    'log_count' VALUE 1500,
    'last_entry' VALUE SYSTIMESTAMP
  )
);

-- Archived logs (previous months - summary only)
INSERT INTO logs_archive (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'LOGS#app-server-01#2024-10#ARCHIVE',
    'type' VALUE 'archived_logs',
    'server_id' VALUE 'app-server-01',
    'month' VALUE '2024-10',
    'archived_date' VALUE SYSTIMESTAMP,
    'log_summary' VALUE JSON_OBJECT(
      'total_entries' VALUE 45230,
      'error_count' VALUE 42,
      'warning_count' VALUE 256
    )
  )
);
-- Archive document: ~500 bytes - INLINE (summary only)

COMMIT;
```

## Task 4: Real-Time Monitoring and Alerting

### Step 1: Create Monitoring View

```sql
-- Create view for document size monitoring
CREATE OR REPLACE VIEW v_document_size_monitor AS
SELECT
  JSON_VALUE(data, '$._id') AS doc_id,
  JSON_VALUE(data, '$.type') AS doc_type,
  LENGTHB(data) AS size_bytes,
  ROUND(LENGTHB(data) / 1024, 2) AS size_kb,
  ROUND(LENGTHB(data) / 1048576, 4) AS size_mb,
  CASE
    WHEN LENGTHB(data) < 7950 THEN 'INLINE'
    WHEN LENGTHB(data) < 10485760 THEN 'LOB'
    WHEN LENGTHB(data) < 33554432 THEN 'LARGE_LOB'
    ELSE 'TOO_LARGE'
  END AS storage_tier,
  CASE
    WHEN LENGTHB(data) >= 30408704 THEN 'CRITICAL'
    WHEN LENGTHB(data) >= 9437184 THEN 'WARNING'
    WHEN LENGTHB(data) >= 7000 THEN 'INFO'
    ELSE 'OK'
  END AS alert_level
FROM perf_test;

-- Query documents requiring attention
SELECT * FROM v_document_size_monitor
WHERE alert_level IN ('WARNING', 'CRITICAL', 'INFO')
ORDER BY size_bytes DESC;
```

### Step 2: Create Size Check Function

```sql
-- Function to check document size before insert
CREATE OR REPLACE FUNCTION check_document_size(
  p_doc JSON,
  p_max_kb NUMBER DEFAULT 500
) RETURN VARCHAR2 IS
  v_size NUMBER;
  v_max_bytes NUMBER;
BEGIN
  v_size := LENGTHB(p_doc);
  v_max_bytes := p_max_kb * 1024;

  IF v_size > 30408704 THEN
    RETURN 'ERROR: Document exceeds 29MB safety limit (' || ROUND(v_size/1048576, 2) || 'MB)';
  ELSIF v_size > 10485760 THEN
    RETURN 'WARNING: Document crossed LOB cliff (' || ROUND(v_size/1048576, 2) || 'MB)';
  ELSIF v_size > v_max_bytes THEN
    RETURN 'INFO: Document exceeds recommended ' || p_max_kb || 'KB limit (' || ROUND(v_size/1024, 2) || 'KB)';
  ELSE
    RETURN 'OK: ' || ROUND(v_size/1024, 2) || 'KB';
  END IF;
END;
/

-- Test the function
SELECT check_document_size(data) AS size_check
FROM perf_test;
```

### Step 3: Monitor All Collections

```sql
-- Query to monitor all JSON collections in the schema
SELECT
  table_name,
  COUNT(*) AS doc_count,
  ROUND(AVG(LENGTHB(data)), 0) AS avg_size_bytes,
  ROUND(MAX(LENGTHB(data)), 0) AS max_size_bytes,
  SUM(CASE WHEN LENGTHB(data) < 7950 THEN 1 ELSE 0 END) AS inline_count,
  SUM(CASE WHEN LENGTHB(data) >= 7950 THEN 1 ELSE 0 END) AS lob_count
FROM (
  SELECT 'PERF_TEST' AS table_name, data FROM perf_test
  UNION ALL
  SELECT 'CUSTOMER_SPLIT', data FROM customer_split
  UNION ALL
  SELECT 'SOCIAL_SPLIT', data FROM social_split
  UNION ALL
  SELECT 'LOGS_ARCHIVE', data FROM logs_archive
)
GROUP BY table_name
ORDER BY max_size_bytes DESC;
```

## Task 5: Design Checklist for LOB Prevention

### Document Size Prevention Checklist

Use this checklist when designing your data model:

**Design Principles:**
- [ ] No unbounded arrays in documents (use composite keys instead)
- [ ] Limit embedded arrays to fixed maximum size (e.g., "recent 10 items")
- [ ] Split hot data (frequently accessed) from cold data (rarely accessed)
- [ ] Archive old data to separate documents periodically
- [ ] Use bucketing pattern for time-series data (Lab 5)
- [ ] Store computed aggregates instead of raw detail (Lab 4)

**Size Guidelines:**
- [ ] Keep hot-path documents under 5KB for optimal performance
- [ ] Keep most documents under 100KB
- [ ] Never design for documents that could exceed 10MB
- [ ] Use composite keys for one-to-many relationships

**Monitoring:**
- [ ] Create view or query to monitor document sizes weekly
- [ ] Set up alerts for documents exceeding 9MB (approaching cliff)
- [ ] Track document growth trends over time

### Common Anti-Patterns to Avoid

```
❌ AVOID: Unbounded activity log
{
  "_id": "USER#123",
  "activity_log": [/* grows forever */]
}

✅ SOLUTION: Time-based buckets (Lab 5)
{
  "_id": "USER#123#ACTIVITY#2024-11-18",
  "type": "daily_activity",
  "activities": [/* max 1 day */]
}

❌ AVOID: All order history in customer document
{
  "_id": "CUSTOMER#456",
  "orders": [/* 10,000 orders = 50MB */]
}

✅ SOLUTION: Separate documents with composite keys (Lab 3)
{
  "_id": "CUSTOMER#456",
  "recent_orders": [/* last 10 only */]
}
{
  "_id": "CUSTOMER#456#ORDER#001",
  "type": "order"
}

❌ AVOID: Growing comments array
{
  "_id": "POST#12345",
  "comments": [/* grows forever */]
}

✅ SOLUTION: Separate comment documents
{
  "_id": "POST#12345",
  "comment_count": 5420
}
{
  "_id": "POST#12345#COMMENT#001",
  "type": "comment"
}
```

## Task 6: Cleanup

```sql
-- Clean up test tables (optional)
-- DROP TABLE perf_test PURGE;
-- DROP TABLE customer_split PURGE;
-- DROP TABLE social_split PURGE;
-- DROP TABLE logs_archive PURGE;
-- DROP VIEW v_document_size_monitor;
```

## Conclusion

In this lab, you learned how to identify and avoid the LOB performance cliff in Oracle JSON Collection Tables.

**Key Takeaways:**
- ✅ Inline storage (< 7,950 bytes) is significantly faster than LOB storage
- ✅ The 10MB threshold is a dramatic performance cliff
- ✅ Use vertical splitting (hot vs cold data) to keep hot path fast
- ✅ Use horizontal splitting (composite keys) to prevent unbounded arrays
- ✅ Implement monitoring and alerting for document sizes
- ✅ Design with fixed-size limits from the start (no unbounded growth)

**OSON Performance Tiers:**
- Inline (< 7,950 bytes): 1-2ms reads - Optimal
- LOB (7,950 bytes - 10MB): 5-10ms reads - Good
- Large LOB (> 10MB): 100-200ms reads - Slow

**Next Steps:**
- Proceed to **Lab 8: Indexing Strategies** to optimize query performance

## Learn More

* [Oracle JSON Developer's Guide - OSON Format](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/oson-format.html)
* [Oracle Database Performance Tuning Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/tgdba/)

## Acknowledgments

* **Author** - Rick Houlihan
* **Last Updated By/Date** - November 2025
