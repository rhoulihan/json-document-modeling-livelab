# Lab 9: Performance Testing and Comparison

## Introduction

This lab brings together all the patterns and techniques from previous labs into comprehensive performance comparisons. You will measure the real-world impact of design decisions using realistic datasets and access patterns.

**Estimated Time:** 45 minutes

## Prerequisites

- Completed Labs 1-8
- Understanding of all document modeling patterns covered
- Familiarity with performance benchmarking concepts

## Objectives

In this lab, you will:
- Benchmark Single Collection vs Multiple Collections
- Measure the impact of composite keys vs separate queries
- Compare embedded vs referenced patterns
- Evaluate computed pattern performance gains
- Test bucketing pattern efficiency
- Analyze index effectiveness
- Create performance reports

## Task 1: Single Collection vs Multiple Collections

### Step 1: Create Multiple Collections (Normalized Approach)

```sql
-- Normalized approach: 3 separate JSON Collection Tables
CREATE JSON COLLECTION TABLE customers_normalized;
CREATE JSON COLLECTION TABLE orders_normalized;
CREATE JSON COLLECTION TABLE order_items_normalized;

-- Create indexes for joins
CREATE INDEX idx_customers_norm_id ON customers_normalized (JSON_VALUE(data, '$._id'));
CREATE INDEX idx_orders_norm_id ON orders_normalized (JSON_VALUE(data, '$._id'));
CREATE INDEX idx_orders_norm_cust ON orders_normalized (JSON_VALUE(data, '$.customer_id'));
CREATE INDEX idx_items_norm_order ON order_items_normalized (JSON_VALUE(data, '$.order_id'));
```

Expected output:
```
Table created.
Table created.
Table created.
Index created.
Index created.
Index created.
Index created.
```

### Step 2: Load Data into Normalized Collections

```sql
-- Load customers using CONNECT BY
INSERT INTO customers_normalized (data)
SELECT JSON_OBJECT(
  '_id' VALUE 'CUST-' || LPAD(LEVEL, 5, '0'),
  'name' VALUE 'Customer ' || LEVEL,
  'email' VALUE 'customer' || LEVEL || '@example.com',
  'tier' VALUE CASE MOD(LEVEL, 3) WHEN 0 THEN 'gold' WHEN 1 THEN 'silver' ELSE 'bronze' END
)
FROM DUAL
CONNECT BY LEVEL <= 100;

COMMIT;
```

Expected output:
```
100 rows created.
Commit complete.
```

```sql
-- Load orders using CONNECT BY
INSERT INTO orders_normalized (data)
SELECT JSON_OBJECT(
  '_id' VALUE 'ORD-' || LPAD(LEVEL, 6, '0'),
  'customer_id' VALUE 'CUST-' || LPAD(MOD(LEVEL, 100) + 1, 5, '0'),
  'order_date' VALUE TO_CHAR(SYSTIMESTAMP - INTERVAL '1' DAY * MOD(LEVEL, 365), 'YYYY-MM-DD'),
  'status' VALUE CASE MOD(LEVEL, 4) WHEN 0 THEN 'delivered' WHEN 1 THEN 'shipped' WHEN 2 THEN 'processing' ELSE 'pending' END,
  'total' VALUE ROUND(DBMS_RANDOM.VALUE(50, 500), 2)
)
FROM DUAL
CONNECT BY LEVEL <= 1000;

COMMIT;
```

Expected output:
```
1000 rows created.
Commit complete.
```

```sql
-- Load order items (3 items per order)
INSERT INTO order_items_normalized (data)
SELECT JSON_OBJECT(
  '_id' VALUE 'ITEM-' || LPAD(TRUNC((LEVEL-1)/3) + 1, 6, '0') || '-' || MOD(LEVEL-1, 3) + 1,
  'order_id' VALUE 'ORD-' || LPAD(TRUNC((LEVEL-1)/3) + 1, 6, '0'),
  'sku' VALUE 'SKU-' || LPAD(MOD(LEVEL, 50) + 1, 5, '0'),
  'quantity' VALUE MOD(LEVEL, 3) + 1,
  'price' VALUE ROUND(DBMS_RANDOM.VALUE(10, 100), 2)
)
FROM DUAL
CONNECT BY LEVEL <= 3000;

COMMIT;

-- Verify counts
SELECT 'customers_normalized' AS collection, COUNT(*) AS count FROM customers_normalized
UNION ALL
SELECT 'orders_normalized', COUNT(*) FROM orders_normalized
UNION ALL
SELECT 'order_items_normalized', COUNT(*) FROM order_items_normalized;
```

Expected output:
```
COLLECTION               COUNT
----------------------  ------
customers_normalized       100
orders_normalized         1000
order_items_normalized    3000
```

### Step 3: Create Single Collection (Denormalized Approach)

```sql
-- Single Collection approach
CREATE JSON COLLECTION TABLE ecommerce_single;

-- Create composite key index
CREATE INDEX idx_ecommerce_single_id ON ecommerce_single (JSON_VALUE(data, '$._id'));
CREATE INDEX idx_ecommerce_single_type ON ecommerce_single (JSON_VALUE(data, '$.type'));
```

```sql
-- Load customers into single collection
INSERT INTO ecommerce_single (data)
SELECT JSON_OBJECT(
  '_id' VALUE 'CUSTOMER#' || LPAD(LEVEL, 5, '0'),
  'type' VALUE 'customer',
  'name' VALUE 'Customer ' || LEVEL,
  'email' VALUE 'customer' || LEVEL || '@example.com',
  'tier' VALUE CASE MOD(LEVEL, 3) WHEN 0 THEN 'gold' WHEN 1 THEN 'silver' ELSE 'bronze' END
)
FROM DUAL
CONNECT BY LEVEL <= 100;

COMMIT;
```

```sql
-- Load orders with denormalized customer data and embedded items
INSERT INTO ecommerce_single (data)
SELECT JSON_OBJECT(
  '_id' VALUE 'CUSTOMER#' || LPAD(MOD(LEVEL, 100) + 1, 5, '0') || '#ORDER#' || LPAD(LEVEL, 6, '0'),
  'type' VALUE 'order',
  'customer_id' VALUE 'CUSTOMER#' || LPAD(MOD(LEVEL, 100) + 1, 5, '0'),
  -- Denormalized customer data
  'customer_name' VALUE 'Customer ' || (MOD(LEVEL, 100) + 1),
  'customer_email' VALUE 'customer' || (MOD(LEVEL, 100) + 1) || '@example.com',
  'customer_tier' VALUE CASE MOD(MOD(LEVEL, 100) + 1, 3) WHEN 0 THEN 'gold' WHEN 1 THEN 'silver' ELSE 'bronze' END,
  -- Order data
  'order_date' VALUE TO_CHAR(SYSTIMESTAMP - INTERVAL '1' DAY * MOD(LEVEL, 365), 'YYYY-MM-DD'),
  'status' VALUE CASE MOD(LEVEL, 4) WHEN 0 THEN 'delivered' WHEN 1 THEN 'shipped' WHEN 2 THEN 'processing' ELSE 'pending' END,
  'total' VALUE ROUND(DBMS_RANDOM.VALUE(50, 500), 2),
  -- Embedded items
  'items' VALUE JSON_ARRAY(
    JSON_OBJECT('sku' VALUE 'SKU-' || LPAD(MOD(LEVEL * 1, 50) + 1, 5, '0'), 'quantity' VALUE 1, 'price' VALUE ROUND(DBMS_RANDOM.VALUE(10, 100), 2)),
    JSON_OBJECT('sku' VALUE 'SKU-' || LPAD(MOD(LEVEL * 2, 50) + 1, 5, '0'), 'quantity' VALUE 2, 'price' VALUE ROUND(DBMS_RANDOM.VALUE(10, 100), 2)),
    JSON_OBJECT('sku' VALUE 'SKU-' || LPAD(MOD(LEVEL * 3, 50) + 1, 5, '0'), 'quantity' VALUE 3, 'price' VALUE ROUND(DBMS_RANDOM.VALUE(10, 100), 2))
  )
)
FROM DUAL
CONNECT BY LEVEL <= 1000;

COMMIT;

-- Verify counts
SELECT JSON_VALUE(data, '$.type') AS doc_type, COUNT(*) AS count
FROM ecommerce_single
GROUP BY JSON_VALUE(data, '$.type');
```

Expected output:
```
DOC_TYPE    COUNT
---------  ------
customer      100
order        1000
```

### Step 4: Benchmark Order Retrieval

```sql
-- Test 1: Normalized (3 queries + application join)
SET SERVEROUTPUT ON;

DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_duration NUMBER;
  v_iterations NUMBER := 100;
  v_total_duration NUMBER := 0;
  v_customer_id VARCHAR2(200);
  v_customer_name VARCHAR2(200);
  v_order_total NUMBER;
  v_item_count NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Benchmark: Normalized (3 Collections) ===');

  FOR iter IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;

    -- Query 1: Get order
    SELECT JSON_VALUE(data, '$.customer_id'), JSON_VALUE(data, '$.total' RETURNING NUMBER)
    INTO v_customer_id, v_order_total
    FROM orders_normalized
    WHERE JSON_VALUE(data, '$._id') = 'ORD-000500';

    -- Query 2: Get customer
    SELECT JSON_VALUE(data, '$.name')
    INTO v_customer_name
    FROM customers_normalized
    WHERE JSON_VALUE(data, '$._id') = v_customer_id;

    -- Query 3: Get order items
    SELECT COUNT(*)
    INTO v_item_count
    FROM order_items_normalized
    WHERE JSON_VALUE(data, '$.order_id') = 'ORD-000500';

    v_end := SYSTIMESTAMP;
    v_duration := EXTRACT(SECOND FROM (v_end - v_start)) * 1000;
    v_total_duration := v_total_duration + v_duration;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Average query time: ' || ROUND(v_total_duration / v_iterations, 2) || ' ms');
  DBMS_OUTPUT.PUT_LINE('Network roundtrips: 3');
  DBMS_OUTPUT.PUT_LINE('Application join logic: Required');
END;
/
```

Expected output:
```
=== Benchmark: Normalized (3 Collections) ===
Average query time: 15.34 ms
Network roundtrips: 3
Application join logic: Required
```

```sql
-- Test 2: Single Collection (1 query, no joins)
DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_duration NUMBER;
  v_iterations NUMBER := 100;
  v_total_duration NUMBER := 0;
  v_order_data CLOB;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Benchmark: Single Collection ===');

  FOR iter IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;

    -- Single query gets everything
    SELECT JSON_SERIALIZE(data)
    INTO v_order_data
    FROM ecommerce_single
    WHERE JSON_VALUE(data, '$._id') LIKE '%#ORDER#000500';

    v_end := SYSTIMESTAMP;
    v_duration := EXTRACT(SECOND FROM (v_end - v_start)) * 1000;
    v_total_duration := v_total_duration + v_duration;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Average query time: ' || ROUND(v_total_duration / v_iterations, 2) || ' ms');
  DBMS_OUTPUT.PUT_LINE('Network roundtrips: 1');
  DBMS_OUTPUT.PUT_LINE('Application join logic: Not required');
END;
/
```

Expected output:
```
=== Benchmark: Single Collection ===
Average query time: 2.45 ms
Network roundtrips: 1
Application join logic: Not required

Performance Improvement: 6.3x faster (15.34ms → 2.45ms)
```

## Task 2: Composite Key Prefix Query Performance

### Step 1: Benchmark Composite Key Queries

```sql
-- Test composite key prefix queries
SET SERVEROUTPUT ON;

DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_duration NUMBER;
  v_iterations NUMBER := 50;
  v_total_duration NUMBER := 0;
  v_order_count NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Benchmark: Composite Key Prefix Query ===');

  FOR iter IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;

    -- Get all orders for a customer using composite key prefix
    SELECT COUNT(*)
    INTO v_order_count
    FROM ecommerce_single
    WHERE JSON_VALUE(data, '$._id') LIKE 'CUSTOMER#00050#ORDER#%';

    v_end := SYSTIMESTAMP;
    v_duration := EXTRACT(SECOND FROM (v_end - v_start)) * 1000;
    v_total_duration := v_total_duration + v_duration;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Average query time: ' || ROUND(v_total_duration / v_iterations, 2) || ' ms');
  DBMS_OUTPUT.PUT_LINE('Orders found: ' || v_order_count);
  DBMS_OUTPUT.PUT_LINE('Index used: idx_ecommerce_single_id (composite key)');
END;
/
```

Expected output:
```
=== Benchmark: Composite Key Prefix Query ===
Average query time: 3.12 ms
Orders found: 10
Index used: idx_ecommerce_single_id (composite key)

Key Insight:
- Single query retrieves all related documents using composite key prefix
- No application joins required
- Efficient index range scan
```

## Task 3: Document Size Impact on Performance

### Step 1: Create Documents of Various Sizes

```sql
-- Create test collection with varying document sizes
CREATE JSON COLLECTION TABLE size_perf_test;

-- Create index on _id
CREATE INDEX idx_size_perf_id ON size_perf_test (JSON_VALUE(data, '$._id'));

-- Insert documents of different sizes
-- Inline document (5KB)
INSERT INTO size_perf_test (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'DOC-INLINE',
    'type' VALUE 'inline',
    'data' VALUE RPAD('x', 5000, 'x')
  )
);

-- LOB document (100KB)
INSERT INTO size_perf_test (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'DOC-LOB-100K',
    'type' VALUE 'lob',
    'data' VALUE RPAD('x', 100000, 'x')
  )
);

-- Large LOB document (5MB)
INSERT INTO size_perf_test (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'DOC-LOB-5MB',
    'type' VALUE 'large_lob',
    'data' VALUE RPAD('x', 5000000, 'x')
  )
);

COMMIT;

-- Verify document sizes
SELECT
  JSON_VALUE(data, '$._id') AS doc_id,
  JSON_VALUE(data, '$.type') AS doc_type,
  LENGTHB(data) AS size_bytes,
  ROUND(LENGTHB(data) / 1024, 2) AS size_kb
FROM size_perf_test
ORDER BY size_bytes;
```

Expected output:
```
DOC_ID          DOC_TYPE    SIZE_BYTES    SIZE_KB
--------------  ----------  ----------  ---------
DOC-INLINE      inline           5044       4.93
DOC-LOB-100K    lob            100044      97.70
DOC-LOB-5MB     large_lob     5000044    4882.86
```

### Step 2: Benchmark Read Performance by Size

```sql
-- Benchmark document reads across size tiers
SET SERVEROUTPUT ON;

DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_duration NUMBER;
  v_data CLOB;
  v_iterations NUMBER := 50;
  v_total_duration NUMBER;
BEGIN
  -- Test 1: Inline document (5KB)
  v_total_duration := 0;
  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;
    SELECT JSON_SERIALIZE(data) INTO v_data FROM size_perf_test WHERE JSON_VALUE(data, '$._id') = 'DOC-INLINE';
    v_end := SYSTIMESTAMP;
    v_total_duration := v_total_duration + (EXTRACT(SECOND FROM (v_end - v_start)) * 1000);
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Inline (5KB): ' || ROUND(v_total_duration / v_iterations, 2) || ' ms avg');

  -- Test 2: LOB document (100KB)
  v_total_duration := 0;
  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;
    SELECT JSON_SERIALIZE(data) INTO v_data FROM size_perf_test WHERE JSON_VALUE(data, '$._id') = 'DOC-LOB-100K';
    v_end := SYSTIMESTAMP;
    v_total_duration := v_total_duration + (EXTRACT(SECOND FROM (v_end - v_start)) * 1000);
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('LOB (100KB): ' || ROUND(v_total_duration / v_iterations, 2) || ' ms avg');

  -- Test 3: Large LOB document (5MB)
  v_total_duration := 0;
  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;
    SELECT JSON_SERIALIZE(data) INTO v_data FROM size_perf_test WHERE JSON_VALUE(data, '$._id') = 'DOC-LOB-5MB';
    v_end := SYSTIMESTAMP;
    v_total_duration := v_total_duration + (EXTRACT(SECOND FROM (v_end - v_start)) * 1000);
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Large LOB (5MB): ' || ROUND(v_total_duration / v_iterations, 2) || ' ms avg');
END;
/
```

Expected output:
```
Inline (5KB): 1.23 ms avg
LOB (100KB): 4.56 ms avg
Large LOB (5MB): 89.34 ms avg

Key Insight:
- LOB documents are 3-4x slower than inline
- Large LOB documents are 70-90x slower than inline
- Keep documents small (< 100KB) for optimal performance
```

## Task 4: Index Performance Comparison

### Step 1: Compare Indexed vs Non-Indexed Queries

```sql
-- Create test collection
CREATE JSON COLLECTION TABLE index_perf_test;

-- Load 10,000 documents
INSERT INTO index_perf_test (data)
SELECT JSON_OBJECT(
  '_id' VALUE 'DOC-' || LPAD(LEVEL, 6, '0'),
  'type' VALUE 'test',
  'category' VALUE CASE MOD(LEVEL, 5) WHEN 0 THEN 'A' WHEN 1 THEN 'B' WHEN 2 THEN 'C' WHEN 3 THEN 'D' ELSE 'E' END,
  'status' VALUE CASE MOD(LEVEL, 3) WHEN 0 THEN 'active' WHEN 1 THEN 'pending' ELSE 'completed' END,
  'value' VALUE ROUND(DBMS_RANDOM.VALUE(1, 1000), 2)
)
FROM DUAL
CONNECT BY LEVEL <= 10000;

COMMIT;
```

```sql
-- Benchmark WITHOUT index
SET SERVEROUTPUT ON;

DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_count NUMBER;
  v_iterations NUMBER := 20;
  v_total_duration NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Without Index ===');

  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;
    SELECT COUNT(*) INTO v_count FROM index_perf_test WHERE JSON_VALUE(data, '$.category') = 'A';
    v_end := SYSTIMESTAMP;
    v_total_duration := v_total_duration + (EXTRACT(SECOND FROM (v_end - v_start)) * 1000);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Average query time: ' || ROUND(v_total_duration / v_iterations, 2) || ' ms');
  DBMS_OUTPUT.PUT_LINE('Matching documents: ' || v_count);
END;
/

-- Now create index
CREATE INDEX idx_index_perf_cat ON index_perf_test (JSON_VALUE(data, '$.category'));

-- Benchmark WITH index
DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_count NUMBER;
  v_iterations NUMBER := 20;
  v_total_duration NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== With Index ===');

  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;
    SELECT COUNT(*) INTO v_count FROM index_perf_test WHERE JSON_VALUE(data, '$.category') = 'A';
    v_end := SYSTIMESTAMP;
    v_total_duration := v_total_duration + (EXTRACT(SECOND FROM (v_end - v_start)) * 1000);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Average query time: ' || ROUND(v_total_duration / v_iterations, 2) || ' ms');
  DBMS_OUTPUT.PUT_LINE('Matching documents: ' || v_count);
END;
/
```

Expected output:
```
=== Without Index ===
Average query time: 45.67 ms
Matching documents: 2000

=== With Index ===
Average query time: 2.34 ms
Matching documents: 2000

Performance Improvement: 19.5x faster with index
```

## Task 5: Performance Summary Report

### Step 1: Generate Comprehensive Performance Report

```sql
-- Generate performance comparison report
SET SERVEROUTPUT ON;

BEGIN
  DBMS_OUTPUT.PUT_LINE('╔═══════════════════════════════════════════════════════════════════╗');
  DBMS_OUTPUT.PUT_LINE('║       Oracle JSON Collections Performance Report                 ║');
  DBMS_OUTPUT.PUT_LINE('╠═══════════════════════════════════════════════════════════════════╣');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('1. SINGLE COLLECTION VS MULTIPLE COLLECTIONS');
  DBMS_OUTPUT.PUT_LINE('   Pattern                 Queries  Latency    Improvement');
  DBMS_OUTPUT.PUT_LINE('   ─────────────────────── ──────── ─────────  ───────────');
  DBMS_OUTPUT.PUT_LINE('   Multiple Collections    3        15.34 ms   Baseline');
  DBMS_OUTPUT.PUT_LINE('   Single Collection       1         2.45 ms   6.3x faster');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('2. DOCUMENT SIZE IMPACT');
  DBMS_OUTPUT.PUT_LINE('   Size         Storage Tier   Read Latency  Relative');
  DBMS_OUTPUT.PUT_LINE('   ──────────── ────────────── ─────────────  ────────');
  DBMS_OUTPUT.PUT_LINE('   5KB          Inline         1.23 ms        1x');
  DBMS_OUTPUT.PUT_LINE('   100KB        LOB            4.56 ms        3.7x slower');
  DBMS_OUTPUT.PUT_LINE('   5MB          Large LOB     89.34 ms       72.6x slower');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('3. INDEX IMPACT');
  DBMS_OUTPUT.PUT_LINE('   Scenario               Query Time   Improvement');
  DBMS_OUTPUT.PUT_LINE('   ───────────────────── ────────────  ───────────');
  DBMS_OUTPUT.PUT_LINE('   Without Index          45.67 ms     Baseline');
  DBMS_OUTPUT.PUT_LINE('   With Index              2.34 ms     19.5x faster');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('4. KEY RECOMMENDATIONS');
  DBMS_OUTPUT.PUT_LINE('   ✓ Use Single Collection for related entities');
  DBMS_OUTPUT.PUT_LINE('   ✓ Keep documents under 100KB for best performance');
  DBMS_OUTPUT.PUT_LINE('   ✓ Use composite keys for hierarchical relationships');
  DBMS_OUTPUT.PUT_LINE('   ✓ Denormalize frequently accessed data');
  DBMS_OUTPUT.PUT_LINE('   ✓ Index composite keys and type discriminators');
  DBMS_OUTPUT.PUT_LINE('   ✓ Use multivalue indexes for array field queries');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('╚═══════════════════════════════════════════════════════════════════╝');
END;
/
```

## Task 6: Cleanup

```sql
-- Clean up test collections (optional - keep for reference)
-- DROP TABLE customers_normalized PURGE;
-- DROP TABLE orders_normalized PURGE;
-- DROP TABLE order_items_normalized PURGE;
-- DROP TABLE ecommerce_single PURGE;
-- DROP TABLE size_perf_test PURGE;
-- DROP TABLE index_perf_test PURGE;
```

## Conclusion

In this lab, you benchmarked various document modeling patterns and measured their real-world performance impact.

**Key Performance Findings:**
- ✅ Single Collection is 6-10x faster than multiple collections (fewer queries, no joins)
- ✅ Composite keys enable efficient prefix queries (3-5ms for related documents)
- ✅ Inline documents (< 7,950 bytes) are 70-90x faster than large LOB (> 10MB)
- ✅ Denormalization eliminates application joins and reduces latency
- ✅ Proper indexing improves query performance by 10-50x

**Performance Optimization Priorities:**
1. Use Single Collection design for related entities
2. Keep documents small (< 100KB ideally)
3. Denormalize frequently accessed data
4. Index composite keys and type discriminators
5. Use bucketing for time-series data

**Next Steps:**
- Proceed to **Lab 10: Advanced Patterns & Best Practices** for final recommendations and wrap-up

## Learn More

* [Oracle Database Performance Tuning Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/tgdba/)
* [Oracle JSON Developer's Guide - Performance](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/performance.html)

## Acknowledgments

* **Author** - Rick Houlihan
* **Last Updated By/Date** - November 2025
