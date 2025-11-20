# Lab 8: Indexing Strategies for Single Collection

## Introduction

Proper indexing is critical for achieving optimal query performance in Single Collection designs. Because a single collection contains multiple entity types with diverse access patterns, your indexing strategy must be carefully designed to support efficient queries across all entity types.

In this lab, you will learn indexing strategies optimized for Single Collection patterns, including composite key indexes, type discriminator indexes, multivalue indexes, and partial indexes.

**Estimated Time:** 45 minutes

## Prerequisites

- Completed Lab 3: Single Collection/Table Design Pattern
- Completed Lab 6: Polymorphic Pattern within Single Collection
- Understanding of composite keys and polymorphic documents

## Objectives

In this lab, you will:
- Create indexes optimized for composite key queries
- Implement type discriminator indexing for polymorphic collections
- Use multivalue indexes for array fields
- Create partial indexes for type-specific queries
- Implement search indexes for full-text search
- Measure index effectiveness and query performance

## Task 1: Composite Key Indexing

### Step 1: Understanding Composite Key Query Patterns

From Lab 3, composite keys enable hierarchical relationships:

```sql
-- Composite keys follow patterns like:
CUSTOMER#456                      -- Get specific customer
CUSTOMER#456#ORDER#001            -- Get specific order
CUSTOMER#456#ORDER#%              -- Get all orders for customer
CUSTOMER#456#%                    -- Get all entities for customer
SENSOR#temp001#BUCKET#2024-11-%   -- Get all buckets for sensor in November
```

### Step 2: Create Composite Key Index

```sql
-- Create test collection
CREATE TABLE ecommerce (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
);
```

**Expected output:**
```
Table created.
```

```sql
-- Create index on _id field (composite key)
CREATE INDEX idx_ecommerce_composite_key ON ecommerce (
  JSON_VALUE(json_document, '$._id')
);
```

**Expected output:**
```
Index created.
```

```sql
-- This index enables efficient:
-- 1. Exact match: WHERE _id = 'CUSTOMER#456'
-- 2. Prefix match: WHERE _id LIKE 'CUSTOMER#456#%'
-- 3. Range queries: WHERE _id >= 'X' AND _id < 'Y'
```

**SQL Approach:**

if type="sql"

```sql
<copy>
-- Load test data
BEGIN
  -- Insert customer
  INSERT INTO ecommerce (json_document) VALUES (
    JSON_OBJECT(
      '_id' VALUE 'CUSTOMER#456',
      'type' VALUE 'customer',
      'name' VALUE 'John Doe',
      'email' VALUE 'john@example.com'
    )
  );

  -- Insert 100 orders
  FOR i IN 1..100 LOOP
    INSERT INTO ecommerce (json_document) VALUES (
      JSON_OBJECT(
        '_id' VALUE 'CUSTOMER#456#ORDER#' || LPAD(i, 5, '0'),
        'type' VALUE 'order',
        'customer_id' VALUE 'CUSTOMER#456',
        'order_date' VALUE SYSTIMESTAMP - INTERVAL '1' DAY * i,
        'total' VALUE ROUND(DBMS_RANDOM.VALUE(50, 500), 2)
      )
    );
  END LOOP;

  COMMIT;
END;
/
</copy>
```

Expected output:
```
PL/SQL procedure successfully completed.
```

/if

**SODA Approach:**

if type="soda"

```sql
<copy>
DECLARE
  collection SODA_COLLECTION_T;
  status NUMBER;
  total_inserted NUMBER := 0;
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('ecommerce');

  -- Insert customer
  status := collection.insert_one(
    SODA_DOCUMENT_T(
      b_content => UTL_RAW.cast_to_raw('{
        "_id": "CUSTOMER#456",
        "type": "customer",
        "name": "John Doe",
        "email": "john@example.com"
      }')
    )
  );
  total_inserted := total_inserted + status;

  -- Insert 100 orders
  FOR i IN 1..100 LOOP
    status := collection.insert_one(
      SODA_DOCUMENT_T(
        b_content => UTL_RAW.cast_to_raw(
          '{' ||
          '"_id": "CUSTOMER#456#ORDER#' || LPAD(i, 5, '0') || '",' ||
          '"type": "order",' ||
          '"customer_id": "CUSTOMER#456",' ||
          '"order_date": "' || TO_CHAR(SYSTIMESTAMP - INTERVAL '1' DAY * i, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || '",' ||
          '"total": ' || ROUND(DBMS_RANDOM.VALUE(50, 500), 2) ||
          '}'
        )
      )
    );
    total_inserted := total_inserted + status;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE(total_inserted || ' documents inserted (1 customer + 100 orders).');
  COMMIT;
END;
/
</copy>
```

Expected output:
```
101 documents inserted (1 customer + 100 orders).

PL/SQL procedure successfully completed.
```

/if

```sql
-- Test composite key index performance
SELECT JSON_QUERY(json_document, '$')
FROM ecommerce
WHERE JSON_VALUE(json_document, '$._id') LIKE 'CUSTOMER#456#ORDER#%'
ORDER BY JSON_VALUE(json_document, '$.order_date' RETURNING TIMESTAMP) DESC
FETCH FIRST 20 ROWS ONLY;
```

**Expected output:** (showing first 3 of 20 rows)
```json
{
  "_id" : "CUSTOMER#456#ORDER#00001",
  "type" : "order",
  "customer_id" : "CUSTOMER#456",
  "order_date" : "2025-11-18T...",
  "total" : 358.81
}

{
  "_id" : "CUSTOMER#456#ORDER#00002",
  "type" : "order",
  "customer_id" : "CUSTOMER#456",
  "order_date" : "2025-11-17T...",
  "total" : 122.65
}

{
  "_id" : "CUSTOMER#456#ORDER#00003",
  "type" : "order",
  "customer_id" : "CUSTOMER#456",
  "order_date" : "2025-11-16T...",
  "total" : 220.64
}
...
```

> **Note:** The index `idx_ecommerce_composite_key` enables efficient prefix matching on the `_id` field.

```sql
-- Check execution plan
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'TYPICAL'));
-- Should show INDEX RANGE SCAN on idx_ecommerce_composite_key
```

## Task 2: Type Discriminator Indexing

### Step 1: Create Type Index

```sql
-- Index on type field (essential for polymorphic collections)
CREATE INDEX idx_ecommerce_type ON ecommerce (
  JSON_VALUE(json_document, '$.type')
);

-- This index enables efficient type filtering:
-- WHERE JSON_VALUE(json_document, '$.type') = 'order'

-- Test type-specific query
SELECT COUNT(*)
FROM ecommerce
WHERE JSON_VALUE(json_document, '$.type') = 'order';
```

**Expected output:**
```
  COUNT(*)
----------
       100
```

> **Note:** The query uses `idx_ecommerce_type` for fast filtering by type.

### Step 2: Composite Index with Type

```sql
-- Create composite index: type + frequently queried field
CREATE INDEX idx_ecommerce_type_date ON ecommerce (
  JSON_VALUE(json_document, '$.type'),
  JSON_VALUE(json_document, '$.order_date' RETURNING TIMESTAMP)
);
```

**Expected output:**
```
Index created.
```

```sql
-- This index optimizes:
-- 1. Type-specific date range queries
-- 2. Type-specific sorting by date

-- Test query optimized by composite index
SELECT
  JSON_VALUE(json_document, '$._id') AS order_id,
  JSON_VALUE(json_document, '$.total' RETURNING NUMBER) AS total,
  JSON_VALUE(json_document, '$.order_date' RETURNING TIMESTAMP) AS order_date
FROM ecommerce
WHERE JSON_VALUE(json_document, '$.type') = 'order'
  AND JSON_VALUE(json_document, '$.order_date' RETURNING TIMESTAMP) >= SYSTIMESTAMP - INTERVAL '30' DAY
ORDER BY JSON_VALUE(json_document, '$.order_date' RETURNING TIMESTAMP) DESC;

-- Expected: Uses idx_ecommerce_type_date efficiently
```

## Task 3: Multivalue Indexes for Arrays

### Step 1: Understanding Multivalue Indexes

Multivalue indexes allow indexing individual elements within JSON arrays:

**SQL Approach:**

if type="sql"

```sql
<copy>
-- Add orders with items array
BEGIN
  FOR i IN 1..10 LOOP
    INSERT INTO ecommerce (json_document) VALUES (
      JSON_OBJECT(
        '_id' VALUE 'CUSTOMER#456#ORDER#' || LPAD(100 + i, 5, '0'),
        'type' VALUE 'order',
        'customer_id' VALUE 'CUSTOMER#456',
        'order_date' VALUE SYSTIMESTAMP,
        'items' VALUE JSON_ARRAY(
          JSON_OBJECT('sku' VALUE 'WIDGET-001', 'quantity' VALUE 2),
          JSON_OBJECT('sku' VALUE 'GADGET-042', 'quantity' VALUE 1),
          JSON_OBJECT('sku' VALUE 'TOOL-' || LPAD(i, 3, '0'), 'quantity' VALUE 3)
        ),
        'total' VALUE 125.50
      )
    );
  END LOOP;
  COMMIT;
END;
/
</copy>
```

/if

**SODA Approach:**

if type="soda"

```sql
<copy>
DECLARE
  collection SODA_COLLECTION_T;
  status NUMBER;
  total_inserted NUMBER := 0;
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('ecommerce');

  -- Add orders with items array
  FOR i IN 1..10 LOOP
    status := collection.insert_one(
      SODA_DOCUMENT_T(
        b_content => UTL_RAW.cast_to_raw(
          '{' ||
          '"_id": "CUSTOMER#456#ORDER#' || LPAD(100 + i, 5, '0') || '",' ||
          '"type": "order",' ||
          '"customer_id": "CUSTOMER#456",' ||
          '"order_date": "' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || '",' ||
          '"items": [' ||
            '{"sku": "WIDGET-001", "quantity": 2},' ||
            '{"sku": "GADGET-042", "quantity": 1},' ||
            '{"sku": "TOOL-' || LPAD(i, 3, '0') || '", "quantity": 3}' ||
          '],' ||
          '"total": 125.50' ||
          '}'
        )
      )
    );
    total_inserted := total_inserted + status;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE(total_inserted || ' orders inserted with items arrays.');
  COMMIT;
END;
/
</copy>
```

/if

### Step 2: Create Multivalue Index

```sql
-- Create multivalue index on items.sku
CREATE MULTIVALUE INDEX idx_order_items_sku ON ecommerce e (
  e.json_document.items.sku.string()
)
WHERE JSON_VALUE(e.json_document, '$.type') = 'order';

-- This index enables efficient queries like:
-- "Find all orders containing product SKU 'WIDGET-001'"

-- Test multivalue index
SELECT
  JSON_VALUE(json_document, '$._id') AS order_id,
  JSON_VALUE(json_document, '$.order_date' RETURNING TIMESTAMP) AS order_date,
  JSON_QUERY(json_document, '$.items' PRETTY) AS items
FROM ecommerce e
WHERE JSON_VALUE(e.json_document, '$.type') = 'order'
  AND JSON_EXISTS(e.json_document, '$.items[*]?(@.sku == "WIDGET-001")');

-- Expected: Uses idx_order_items_sku for fast lookup
```

### Step 3: Multivalue Index on Nested Arrays

```sql
-- Create multivalue index on product tags
CREATE MULTIVALUE INDEX idx_product_tags ON ecommerce e (
  e.json_document.tags.string()
)
WHERE JSON_VALUE(e.json_document, '$.type') = 'product';

-- Query products by tag
SELECT
  JSON_VALUE(json_document, '$._id') AS product_id,
  JSON_VALUE(json_document, '$.name') AS product_name,
  JSON_QUERY(json_document, '$.tags') AS tags
FROM ecommerce e
WHERE JSON_VALUE(e.json_document, '$.type') = 'product'
  AND JSON_EXISTS(e.json_document, '$.tags[*]?(@ == "electronics")');
```

## Task 4: Partial Indexes for Type-Specific Queries

### Step 1: Create Partial Indexes

Partial indexes (also called filtered indexes) only index documents matching a WHERE clause:

```sql
-- Partial index for high-value orders only
CREATE INDEX idx_high_value_orders ON ecommerce (
  JSON_VALUE(json_document, '$.customer_id'),
  JSON_VALUE(json_document, '$.total' RETURNING NUMBER)
)
WHERE JSON_VALUE(json_document, '$.type') = 'order'
  AND JSON_VALUE(json_document, '$.total' RETURNING NUMBER) > 1000;

-- This index:
-- - Only indexes orders over $1,000
-- - Reduces index size by 90%+
-- - Optimizes queries for high-value orders

-- Test partial index
SELECT
  JSON_VALUE(json_document, '$._id') AS order_id,
  JSON_VALUE(json_document, '$.customer_id') AS customer_id,
  JSON_VALUE(json_document, '$.total' RETURNING NUMBER) AS total
FROM ecommerce
WHERE JSON_VALUE(json_document, '$.type') = 'order'
  AND JSON_VALUE(json_document, '$.total' RETURNING NUMBER) > 1000
ORDER BY JSON_VALUE(json_document, '$.total' RETURNING NUMBER) DESC;
```

### Step 2: Type-Specific Partial Indexes

```sql
-- Partial index for customer email lookup
CREATE INDEX idx_customers_email ON ecommerce (
  JSON_VALUE(json_document, '$.email')
)
WHERE JSON_VALUE(json_document, '$.type') = 'customer';

-- Partial index for order status
CREATE INDEX idx_orders_status ON ecommerce (
  JSON_VALUE(json_document, '$.status'),
  JSON_VALUE(json_document, '$.order_date' RETURNING TIMESTAMP)
)
WHERE JSON_VALUE(json_document, '$.type') = 'order';

-- Query by email (uses partial index)
SELECT JSON_QUERY(json_document, '$' PRETTY)
FROM ecommerce
WHERE JSON_VALUE(json_document, '$.type') = 'customer'
  AND JSON_VALUE(json_document, '$.email') = 'john@example.com';
```

## Task 5: Search Indexes for Full-Text Search

### Step 1: Create Search Index

```sql
-- Create search index for full-text search across all documents
CREATE SEARCH INDEX idx_ecommerce_fulltext ON ecommerce (json_document)
FOR JSON;

-- This enables:
-- - Full-text search across all text fields
-- - Fuzzy matching
-- - Phrase search
-- - Boolean operators

-- Wait for index to sync
EXEC CTX_DDL.SYNC_INDEX('idx_ecommerce_fulltext');
```

### Step 2: Use Search Index for Queries

```sql
-- Full-text search for customer names
SELECT
  JSON_VALUE(json_document, '$._id') AS doc_id,
  JSON_VALUE(json_document, '$.type') AS doc_type,
  JSON_VALUE(json_document, '$.name') AS name,
  JSON_VALUE(json_document, '$.email') AS email
FROM ecommerce
WHERE JSON_TEXTCONTAINS(json_document, '$', 'John')
  AND JSON_VALUE(json_document, '$.type') = 'customer';

-- Search for products with specific keywords
SELECT
  JSON_VALUE(json_document, '$._id') AS product_id,
  JSON_VALUE(json_document, '$.name') AS product_name,
  JSON_VALUE(json_document, '$.description') AS description
FROM ecommerce
WHERE JSON_TEXTCONTAINS(json_document, '$', 'wireless AND mouse')
  AND JSON_VALUE(json_document, '$.type') = 'product';
```

## Task 6: Index Performance Analysis

### Step 1: Compare Query Performance With and Without Indexes

```sql
-- Disable indexes temporarily (for comparison)
ALTER INDEX idx_ecommerce_composite_key UNUSABLE;
ALTER INDEX idx_ecommerce_type UNUSABLE;

-- Measure query time WITHOUT indexes
SET TIMING ON;

SELECT COUNT(*)
FROM ecommerce
WHERE JSON_VALUE(json_document, '$.type') = 'order'
  AND JSON_VALUE(json_document, '$._id') LIKE 'CUSTOMER#456#ORDER#%';

-- Record time (expected: ~50-100ms)

SET TIMING OFF;

-- Rebuild indexes
ALTER INDEX idx_ecommerce_composite_key REBUILD;
ALTER INDEX idx_ecommerce_type REBUILD;

-- Measure query time WITH indexes
SET TIMING ON;

SELECT COUNT(*)
FROM ecommerce
WHERE JSON_VALUE(json_document, '$.type') = 'order'
  AND JSON_VALUE(json_document, '$._id') LIKE 'CUSTOMER#456#ORDER#%';

-- Record time (expected: ~2-5ms)

SET TIMING OFF;

/*
Expected Results:
Without indexes: 50-100ms (full table scan)
With indexes: 2-5ms (index range scan)
Improvement: 10-50x faster
*/
```

### Step 2: Analyze Index Usage

```sql
-- Check index statistics
SELECT
  index_name,
  index_type,
  uniqueness,
  status,
  num_rows,
  leaf_blocks,
  distinct_keys
FROM user_indexes
WHERE table_name = 'ECOMMERCE'
ORDER BY index_name;

-- Check which indexes are actually being used
SELECT
  sql_text,
  executions,
  buffer_gets,
  disk_reads,
  cpu_time / 1000000 AS cpu_seconds
FROM v$sql
WHERE sql_text LIKE '%ecommerce%'
  AND sql_text NOT LIKE '%v$sql%'
ORDER BY executions DESC
FETCH FIRST 10 ROWS ONLY;
```

## Task 7: Index Strategy Best Practices

### Step 1: Index Design Checklist

When designing indexes for Single Collection:

**Must-Have Indexes:**
- [ ] Index on `_id` (composite key) for exact and prefix matches
- [ ] Index on `type` (discriminator) for type filtering
- [ ] Composite index on `type` + frequently queried field (e.g., date, status)

**Optional Indexes (based on access patterns):**
- [ ] Multivalue indexes on array fields if querying array elements
- [ ] Partial indexes for subset queries (e.g., high-value orders, active users)
- [ ] Search index if full-text search is required
- [ ] Indexes on denormalized fields (e.g., `customer_id` in orders)

**Avoid:**
- [ ] Over-indexing (indexes have write overhead)
- [ ] Indexing rarely queried fields
- [ ] Duplicate indexes (e.g., don't index both `email` and `email || type`)

### Step 2: Index Maintenance Strategy

```sql
-- Monitor index bloat
SELECT
  index_name,
  blevel AS tree_levels,
  leaf_blocks,
  clustering_factor,
  num_rows,
  ROUND(leaf_blocks / num_rows * 100, 2) AS bloat_pct
FROM user_indexes
WHERE table_name = 'ECOMMERCE'
ORDER BY bloat_pct DESC;

-- Rebuild bloated indexes
-- Run this periodically (monthly or when bloat_pct > 20)
ALTER INDEX idx_ecommerce_composite_key REBUILD ONLINE;
ALTER INDEX idx_ecommerce_type REBUILD ONLINE;
```

### Step 3: Index Sizing Estimates

```sql
-- Estimate index size for planning
SELECT
  index_name,
  ROUND(SUM(bytes) / 1024 / 1024, 2) AS size_mb
FROM user_segments
WHERE segment_type = 'INDEX'
  AND segment_name IN (
    'IDX_ECOMMERCE_COMPOSITE_KEY',
    'IDX_ECOMMERCE_TYPE',
    'IDX_ECOMMERCE_TYPE_DATE',
    'IDX_ORDER_ITEMS_SKU'
  )
GROUP BY index_name
ORDER BY size_mb DESC;

/*
Expected Results (for 1M documents):
INDEX_NAME                      SIZE_MB
-----------------------------   -------
IDX_ECOMMERCE_COMPOSITE_KEY     45.2
IDX_ORDER_ITEMS_SKU             32.8
IDX_ECOMMERCE_TYPE_DATE         28.5
IDX_ECOMMERCE_TYPE              12.3
*/
```

## Task 8: Query Optimization Patterns

### Step 1: Covering Indexes

```sql
-- Create covering index (includes all fields needed by query)
CREATE INDEX idx_orders_covering ON ecommerce (
  JSON_VALUE(json_document, '$.type'),
  JSON_VALUE(json_document, '$.customer_id'),
  JSON_VALUE(json_document, '$.order_date' RETURNING TIMESTAMP),
  JSON_VALUE(json_document, '$.total' RETURNING NUMBER)
)
WHERE JSON_VALUE(json_document, '$.type') = 'order';

-- Query can be satisfied entirely from index (no table access)
SELECT
  JSON_VALUE(json_document, '$.customer_id') AS customer_id,
  JSON_VALUE(json_document, '$.order_date' RETURNING TIMESTAMP) AS order_date,
  JSON_VALUE(json_document, '$.total' RETURNING NUMBER) AS total
FROM ecommerce
WHERE JSON_VALUE(json_document, '$.type') = 'order'
  AND JSON_VALUE(json_document, '$.customer_id') = 'CUSTOMER#456'
ORDER BY JSON_VALUE(json_document, '$.order_date' RETURNING TIMESTAMP) DESC;

-- Check plan: Should show "INDEX FAST FULL SCAN" or "INDEX RANGE SCAN" with no table access
```

### Step 2: Hint-Based Optimization

```sql
-- Force index usage with hint
SELECT /*+ INDEX(ecommerce idx_ecommerce_composite_key) */
  JSON_QUERY(json_document, '$')
FROM ecommerce
WHERE JSON_VALUE(json_document, '$._id') LIKE 'CUSTOMER#456#%';

-- Parallel index scan for large queries
SELECT /*+ PARALLEL(ecommerce, 4) INDEX(ecommerce idx_ecommerce_type) */
  JSON_VALUE(json_document, '$.type') AS doc_type,
  COUNT(*) AS doc_count
FROM ecommerce
GROUP BY JSON_VALUE(json_document, '$.type');
```

## Conclusion

In this lab, you learned comprehensive indexing strategies for Single Collection designs in Oracle JSON Collections.

**Key Takeaways:**
- ✅ Always index `_id` (composite key) for prefix and exact match queries
- ✅ Always index `type` (discriminator) for polymorphic collection filtering
- ✅ Use composite indexes combining `type` + frequently queried field
- ✅ Use multivalue indexes for array element queries
- ✅ Use partial indexes to reduce index size and improve performance
- ✅ Use search indexes for full-text search capabilities
- ✅ Monitor index usage and rebuild bloated indexes periodically

**Index Strategy Summary:**
1. Start with composite key and type discriminator indexes
2. Add indexes based on actual query patterns (not speculation)
3. Use partial indexes to reduce overhead
4. Monitor and maintain indexes regularly

**Next Steps:**
- Proceed to **Lab 9: Performance Testing & Comparison** to measure the impact of your design decisions

## Learn More

* [Oracle JSON Developer's Guide - Indexes](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/indexes-for-json-data.html)
* [Oracle Database Performance Tuning Guide - Indexing](https://docs.oracle.com/en/database/oracle/oracle-database/23/tgdba/managing-and-monitoring-database-indexes.html)

## Acknowledgments

* **Author** - Rick Houlihan
* **Last Updated By/Date** - November 2024
