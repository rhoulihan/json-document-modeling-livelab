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

**Performance Characteristics:**

```sql
-- Create test collection
CREATE JSON COLLECTION TABLE perf_test;

-- Test 1: Inline document (< 7,950 bytes)
-- Insert time: ~0.5-1ms
-- Read time: ~1-2ms
INSERT INTO perf_test (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'DOC-INLINE',
    'type' VALUE 'small',
    'data' VALUE RPAD('x', 5000, 'x')  -- 5KB document
  )
);

-- Test 2: LOB document (100KB)
-- Insert time: ~2-5ms
-- Read time: ~5-10ms
INSERT INTO perf_test (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'DOC-LOB',
    'type' VALUE 'medium',
    'data' VALUE RPAD('x', 100000, 'x')  -- 100KB document
  )
);

-- Test 3: Large LOB document (15MB)
-- Insert time: ~50-100ms
-- Read time: ~100-200ms
INSERT INTO perf_test (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'DOC-LARGE-LOB',
    'type' VALUE 'large',
    'data' VALUE RPAD('x', 15000000, 'x')  -- 15MB document
  )
);

-- Measure document sizes and storage tier
SELECT
  JSON_VALUE(json_document, '$._id') AS doc_id,
  JSON_VALUE(json_document, '$.type') AS doc_type,
  LENGTHB(json_document) AS size_bytes,
  ROUND(LENGTHB(json_document) / 1024, 2) AS size_kb,
  CASE
    WHEN LENGTHB(json_document) < 7950 THEN '✅ INLINE (Optimal)'
    WHEN LENGTHB(json_document) < 10485760 THEN '⚠️ LOB (Good)'
    WHEN LENGTHB(json_document) < 33554432 THEN '❌ LARGE LOB (Slow)'
    ELSE '🚫 ERROR (Too Large)'
  END AS storage_tier
FROM perf_test
ORDER BY LENGTHB(json_document);

/*
Expected Result:
DOC_ID          DOC_TYPE  SIZE_BYTES  SIZE_KB   STORAGE_TIER
--------------  --------  ----------  --------  -------------------
DOC-INLINE      small     5243        5.12      ✅ INLINE (Optimal)
DOC-LOB         medium    100343      98.00     ⚠️ LOB (Good)
DOC-LARGE-LOB   large     15000343    14648.77  ❌ LARGE LOB (Slow)
*/
```

### Step 2: Performance Impact of LOB Storage

```sql
-- Benchmark read performance across tiers
SET SERVEROUTPUT ON;

DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_duration NUMBER;
  v_data CLOB;
  v_iterations NUMBER := 100;
  v_total_duration NUMBER;
BEGIN
  -- Test inline document reads
  v_total_duration := 0;
  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;
    SELECT JSON_SERIALIZE(json_document)
    INTO v_data
    FROM perf_test
    WHERE JSON_VALUE(json_document, '$._id') = 'DOC-INLINE';
    v_end := SYSTIMESTAMP;
    v_duration := EXTRACT(SECOND FROM (v_end - v_start)) * 1000;
    v_total_duration := v_total_duration + v_duration;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('INLINE (5KB): ' || ROUND(v_total_duration / v_iterations, 2) || ' ms avg');

  -- Test LOB document reads
  v_total_duration := 0;
  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;
    SELECT JSON_SERIALIZE(json_document)
    INTO v_data
    FROM perf_test
    WHERE JSON_VALUE(json_document, '$._id') = 'DOC-LOB';
    v_end := SYSTIMESTAMP;
    v_duration := EXTRACT(SECOND FROM (v_end - v_start)) * 1000;
    v_total_duration := v_total_duration + v_duration;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('LOB (100KB): ' || ROUND(v_total_duration / v_iterations, 2) || ' ms avg');

  -- Test large LOB document reads
  v_total_duration := 0;
  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;
    SELECT JSON_SERIALIZE(json_document)
    INTO v_data
    FROM perf_test
    WHERE JSON_VALUE(json_document, '$._id') = 'DOC-LARGE-LOB';
    v_end := SYSTIMESTAMP;
    v_duration := EXTRACT(SECOND FROM (v_end - v_start)) * 1000;
    v_total_duration := v_total_duration + v_duration;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('LARGE LOB (15MB): ' || ROUND(v_total_duration / v_iterations, 2) || ' ms avg');
END;
/

/*
Expected Output:
INLINE (5KB): 1.45 ms avg
LOB (100KB): 6.23 ms avg
LARGE LOB (15MB): 142.78 ms avg

Key Insight:
- LOB documents are 4-5x slower than inline
- Large LOB documents are 100x slower than inline
- The "cliff" at 10MB is dramatic
*/
```

## Task 2: Identifying LOB Cliff Candidates

### Step 1: Monitoring Current Document Sizes

```sql
-- Create comprehensive monitoring query
SELECT
  JSON_VALUE(json_document, '$.type') AS document_type,
  COUNT(*) AS document_count,
  ROUND(AVG(LENGTHB(json_document)), 0) AS avg_size_bytes,
  ROUND(MIN(LENGTHB(json_document)), 0) AS min_size_bytes,
  ROUND(MAX(LENGTHB(json_document)), 0) AS max_size_bytes,
  ROUND(STDDEV(LENGTHB(json_document)), 0) AS stddev_size,
  SUM(CASE WHEN LENGTHB(json_document) < 7950 THEN 1 ELSE 0 END) AS inline_count,
  SUM(CASE WHEN LENGTHB(json_document) >= 7950 AND LENGTHB(json_document) < 10485760 THEN 1 ELSE 0 END) AS lob_count,
  SUM(CASE WHEN LENGTHB(json_document) >= 10485760 THEN 1 ELSE 0 END) AS large_lob_count
FROM perf_test
GROUP BY JSON_VALUE(json_document, '$.type')
ORDER BY MAX(LENGTHB(json_document)) DESC;

/*
Expected Result:
DOCUMENT_TYPE  DOCUMENT_COUNT  AVG_SIZE_BYTES  MIN_SIZE_BYTES  MAX_SIZE_BYTES  STDDEV_SIZE  INLINE_COUNT  LOB_COUNT  LARGE_LOB_COUNT
-------------  --------------  --------------  --------------  --------------  -----------  ------------  ---------  ---------------
large          1               15000343        15000343        15000343        0            0             0          1
medium         1               100343          100343          100343          0            0             1          0
small          1               5243            5243            5243            0            1             0          0

Insights:
- 33% of documents in optimal inline storage
- 33% crossed into LOB tier
- 33% crossed into LARGE LOB tier (performance cliff!)
*/
```

### Step 2: Find Documents Approaching Limits

```sql
-- Identify documents at risk of crossing thresholds
SELECT
  JSON_VALUE(json_document, '$._id') AS doc_id,
  JSON_VALUE(json_document, '$.type') AS doc_type,
  LENGTHB(json_document) AS size_bytes,
  ROUND(LENGTHB(json_document) / 1024, 2) AS size_kb,
  CASE
    WHEN LENGTHB(json_document) >= 7000 AND LENGTHB(json_document) < 7950 THEN '⚠️ Near inline limit'
    WHEN LENGTHB(json_document) >= 9437184 AND LENGTHB(json_document) < 10485760 THEN '⚠️ Near LOB cliff (9MB)'
    WHEN LENGTHB(json_document) >= 30408704 THEN '🚨 Near hard limit (29MB)'
    WHEN LENGTHB(json_document) >= 7950 THEN '❌ Already in LOB'
    ELSE '✅ Optimal size'
  END AS status
FROM perf_test
WHERE LENGTHB(json_document) >= 7000
   OR LENGTHB(json_document) >= 7950
ORDER BY LENGTHB(json_document) DESC;

/*
This query identifies:
- Documents near 7,950 byte inline limit
- Documents near 10MB LOB cliff
- Documents near 32MB hard limit
*/
```

## Task 3: Document Splitting Strategies

### Step 1: Vertical Splitting (Frequently vs Rarely Accessed Fields)

```sql
-- ❌ Anti-Pattern: Single large document with all fields
-- This customer document is 250KB because it includes full order history

CREATE JSON COLLECTION TABLE customers_bad;

INSERT INTO customers_bad (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'CUSTOMER#456',
    'type' VALUE 'customer',
    'name' VALUE 'John Doe',
    'email' VALUE 'john@example.com',
    -- Frequently accessed fields above

    -- Rarely accessed fields below (making document huge)
    'full_order_history' VALUE JSON_ARRAY(
      /* 5,000 orders = 250KB */
    ),
    'full_payment_history' VALUE JSON_ARRAY(
      /* 5,000 payments = 200KB */
    )
  )
);

-- ✅ Solution: Vertical Split - Separate hot and cold data

CREATE JSON COLLECTION TABLE customers_good;

-- Hot data: Frequently accessed (stays small)
INSERT INTO customers_good (json_document) VALUES (
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
    -- Recent orders only (for dashboard)
    'recent_orders' VALUE JSON_ARRAY(
      /* Last 10 orders only = 3KB */
    )
  )
);
-- Document size: 5KB ✅ INLINE

-- Cold data: Full order history (separate document)
INSERT INTO customers_good (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'CUSTOMER#456#ORDERS#ARCHIVE',
    'type' VALUE 'order_archive',
    'customer_id' VALUE 'CUSTOMER#456',
    'orders' VALUE JSON_ARRAY(
      /* 5,000 orders */
    )
  )
);
-- Document size: 250KB ⚠️ LOB (but rarely accessed)

-- Result:
-- - Hot path query: 2ms (inline document)
-- - Cold path query (rare): 50ms (LOB document, but acceptable for rare access)
```

### Step 2: Horizontal Splitting (Array Pagination)

```sql
-- ❌ Anti-Pattern: Unbounded array grows forever

CREATE JSON COLLECTION TABLE social_bad;

INSERT INTO social_bad (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'USER#123',
    'type' VALUE 'user',
    'name' VALUE 'Jane Smith',
    'all_posts' VALUE JSON_ARRAY(
      /* 10,000 posts = 50MB - EXCEEDS 32MB LIMIT! */
    )
  )
);

-- ✅ Solution: Horizontal Split with Composite Keys (from Lab 3)

CREATE JSON COLLECTION TABLE social_good;

-- User document (small, frequently accessed)
INSERT INTO social_good (json_document) VALUES (
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
-- Document size: 1KB ✅ INLINE

-- Each post is a separate document
INSERT INTO social_good (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'USER#123#POST#001',
    'type' VALUE 'post',
    'user_id' VALUE 'USER#123',
    'user_name' VALUE 'Jane Smith',  -- Denormalized
    'content' VALUE 'My first post!',
    'created_at' VALUE SYSTIMESTAMP
  )
);
-- Document size: 500 bytes ✅ INLINE

-- Query user's recent posts using composite key prefix
SELECT JSON_QUERY(json_document, '$')
FROM social_good
WHERE JSON_VALUE(json_document, '$._id') LIKE 'USER#123#POST#%'
ORDER BY JSON_VALUE(json_document, '$.created_at' RETURNING TIMESTAMP) DESC
FETCH FIRST 20 ROWS ONLY;

-- Result:
-- - Each post: 500 bytes ✅ INLINE
-- - Can scale to millions of posts
-- - Query performance: 5-10ms for paginated results
```

### Step 3: Time-Based Archiving

```sql
-- ✅ Solution: Archive old data to separate documents

CREATE JSON COLLECTION TABLE logs_with_archive;

-- Active logs (current month)
INSERT INTO logs_with_archive (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'LOGS#app-server-01#2024-11',
    'type' VALUE 'active_logs',
    'server_id' VALUE 'app-server-01',
    'month' VALUE '2024-11',
    'log_entries' VALUE JSON_ARRAY(
      /* Current month logs = 150KB */
    )
  )
);
-- Document size: 150KB ⚠️ LOB (but acceptable)

-- Archived logs (previous months)
INSERT INTO logs_with_archive (json_document) VALUES (
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
    -- Full logs moved to cold storage or compressed
  )
);
-- Document size: 2KB ✅ INLINE (summary only)
```

## Task 4: Real-Time Monitoring and Alerting

### Step 1: Create Monitoring View

```sql
-- Create view for document size monitoring
CREATE OR REPLACE VIEW v_document_size_monitor AS
SELECT
  JSON_VALUE(json_document, '$._id') AS doc_id,
  JSON_VALUE(json_document, '$.type') AS doc_type,
  LENGTHB(json_document) AS size_bytes,
  ROUND(LENGTHB(json_document) / 1024, 2) AS size_kb,
  ROUND(LENGTHB(json_document) / 1048576, 2) AS size_mb,
  CASE
    WHEN LENGTHB(json_document) < 7950 THEN 'INLINE'
    WHEN LENGTHB(json_document) < 10485760 THEN 'LOB'
    WHEN LENGTHB(json_document) < 33554432 THEN 'LARGE_LOB'
    ELSE 'TOO_LARGE'
  END AS storage_tier,
  CASE
    WHEN LENGTHB(json_document) >= 30408704 THEN 'CRITICAL'  -- > 29MB
    WHEN LENGTHB(json_document) >= 9437184 THEN 'WARNING'     -- > 9MB
    WHEN LENGTHB(json_document) >= 7000 THEN 'INFO'           -- > 7KB
    ELSE 'OK'
  END AS alert_level
FROM perf_test;

-- Query documents requiring attention
SELECT *
FROM v_document_size_monitor
WHERE alert_level IN ('WARNING', 'CRITICAL')
ORDER BY size_bytes DESC;
```

### Step 2: Create Alert Trigger

```sql
-- Trigger to prevent insertion of documents exceeding size thresholds
CREATE OR REPLACE TRIGGER trg_prevent_large_documents
BEFORE INSERT OR UPDATE ON perf_test
FOR EACH ROW
DECLARE
  v_size NUMBER;
  v_doc_id VARCHAR2(200);
BEGIN
  v_size := LENGTHB(:NEW.json_document);
  v_doc_id := JSON_VALUE(:NEW.json_document, '$._id');

  -- Block documents over 29MB (leave buffer before 32MB hard limit)
  IF v_size > 30408704 THEN
    RAISE_APPLICATION_ERROR(
      -20001,
      'Document ' || v_doc_id || ' exceeds 29MB limit: ' || ROUND(v_size / 1048576, 2) || 'MB. ' ||
      'Please split this document into smaller documents.'
    );
  END IF;

  -- Warn on documents over 10MB (crossed LOB cliff)
  IF v_size > 10485760 THEN
    DBMS_OUTPUT.PUT_LINE('WARNING: Document ' || v_doc_id || ' is ' ||
                         ROUND(v_size / 1048576, 2) || 'MB (crossed LOB cliff). Consider splitting.');
  END IF;
END;
/

-- Test the trigger
BEGIN
  -- This should fail
  INSERT INTO perf_test (json_document) VALUES (
    JSON_OBJECT(
      '_id' VALUE 'DOC-TOO-LARGE',
      'data' VALUE RPAD('x', 31000000, 'x')  -- 31MB
    )
  );
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Trigger blocked large document: ' || SQLERRM);
END;
/
```

## Task 5: Architectural Patterns to Prevent Unbounded Growth

### Step 1: Design Checklist

Use this checklist when designing your data model:

**Document Size Prevention:**
- [ ] No unbounded arrays in documents (use composite keys instead)
- [ ] Limit embedded arrays to fixed maximum size (e.g., "recent 10 items")
- [ ] Split hot data (frequently accessed) from cold data (rarely accessed)
- [ ] Archive old data to separate documents periodically
- [ ] Use bucketing pattern for time-series data (Lab 5)
- [ ] Store computed aggregates instead of raw detail (Lab 4)

**Monitoring:**
- [ ] Create view or query to monitor document sizes weekly
- [ ] Set up alerts for documents exceeding 9MB (approaching cliff)
- [ ] Implement trigger to block documents over 29MB
- [ ] Track document growth trends over time

**Testing:**
- [ ] Load test with realistic data volumes
- [ ] Simulate document growth over time (1 year, 5 years)
- [ ] Verify documents stay under 500KB (ideally under 100KB)

### Step 2: Common Unbounded Growth Patterns to Avoid

```sql
-- ❌ AVOID: Unbounded activity log
{
  "_id": "USER#123",
  "activity_log": [/* grows forever */]
}

-- ✅ SOLUTION: Use composite keys with time-based buckets (Lab 5)
{
  "_id": "USER#123#ACTIVITY#2024-11-18",
  "type": "daily_activity",
  "activities": [/* max 1 day */]
}

-- ❌ AVOID: All order history in customer document
{
  "_id": "CUSTOMER#456",
  "orders": [/* 10,000 orders = 50MB */]
}

-- ✅ SOLUTION: Separate documents with composite keys (Lab 3)
{
  "_id": "CUSTOMER#456",
  "recent_orders": [/* last 10 only */]
}
{
  "_id": "CUSTOMER#456#ORDER#001",
  "type": "order"
}

-- ❌ AVOID: Growing comments array
{
  "_id": "POST#12345",
  "comments": [/* grows forever */]
}

-- ✅ SOLUTION: Separate comment documents
{
  "_id": "POST#12345",
  "comment_count": 5420
}
{
  "_id": "POST#12345#COMMENT#001",
  "type": "comment"
}
```

## Conclusion

In this lab, you learned how to identify and avoid the LOB performance cliff in Oracle JSON Collections.

**Key Takeaways:**
- ✅ Inline storage (< 7,950 bytes) is 100x faster than large LOB (> 10MB)
- ✅ The 10MB threshold is a dramatic performance cliff
- ✅ Use vertical splitting (hot vs cold data) to keep hot path fast
- ✅ Use horizontal splitting (composite keys) to prevent unbounded arrays
- ✅ Implement monitoring and alerting for document sizes
- ✅ Design with fixed-size limits from the start (no unbounded growth)

**OSON Performance Tiers:**
- Inline (under 7,950 bytes): 1-2ms reads ✅ Optimal
- LOB (7,950 bytes - 10MB): 5-10ms reads ⚠️ Good
- Large LOB (over 10MB): 100-200ms reads ❌ Slow

**Next Steps:**
- Proceed to **Lab 8: Indexing Strategies for Single Collection** to optimize query performance

## Learn More

* [Oracle JSON Developer's Guide - OSON Format](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/oson-format.html)
* [Oracle Database Performance Tuning Guide](https://docs.oracle.com/en/database/oracle/oracle-database/23/tgdba/)

## Acknowledgments

* **Author** - Rick Houlihan, Principal Solutions Architect, Oracle Database
* **Last Updated By/Date** - November 2024
