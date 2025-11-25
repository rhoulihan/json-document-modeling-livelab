# Lab 8: Indexing Strategies for Single Collection

## Introduction

Proper indexing is critical for achieving optimal query performance in Single Collection designs. Because a single collection contains multiple entity types with diverse access patterns, your indexing strategy must be carefully designed to support efficient queries across all entity types.

In this lab, you will learn indexing strategies optimized for Single Collection patterns, including composite key indexes, type discriminator indexes, multivalue indexes, and search indexes.

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

### Step 2: Create Collection and Composite Key Index

```sql
-- Create JSON Collection Table for e-commerce
CREATE JSON COLLECTION TABLE ecommerce;

-- Create index on _id field (composite key)
CREATE INDEX idx_ecommerce_id ON ecommerce (JSON_VALUE(data, '$._id'));

-- This index enables efficient:
-- 1. Exact match: WHERE _id = 'CUSTOMER#456'
-- 2. Prefix match: WHERE _id LIKE 'CUSTOMER#456#%'
-- 3. Range queries: WHERE _id >= 'X' AND _id < 'Y'
```

### Step 3: Load Test Data

```sql
-- Insert customer
INSERT INTO ecommerce (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'CUSTOMER#456',
    'type' VALUE 'customer',
    'name' VALUE 'John Doe',
    'email' VALUE 'john@example.com'
  )
);

-- Insert orders using CONNECT BY for bulk insert
INSERT INTO ecommerce (data)
SELECT JSON_OBJECT(
  '_id' VALUE 'CUSTOMER#456#ORDER#' || LPAD(LEVEL, 5, '0'),
  'type' VALUE 'order',
  'customer_id' VALUE 'CUSTOMER#456',
  'order_date' VALUE TO_CHAR(SYSTIMESTAMP - INTERVAL '1' DAY * LEVEL, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  'total' VALUE ROUND(DBMS_RANDOM.VALUE(50, 500), 2)
)
FROM DUAL
CONNECT BY LEVEL <= 100;

COMMIT;

-- Verify data
SELECT JSON_VALUE(data, '$.type') AS doc_type, COUNT(*) AS count
FROM ecommerce
GROUP BY JSON_VALUE(data, '$.type');
```

Expected output:
```
DOC_TYPE    COUNT
---------   -----
customer        1
order         100
```

### Step 4: Test Composite Key Index Performance

```sql
-- Query using composite key prefix
SELECT
  JSON_VALUE(data, '$._id') AS order_id,
  JSON_VALUE(data, '$.total' RETURNING NUMBER) AS total
FROM ecommerce
WHERE JSON_VALUE(data, '$._id') LIKE 'CUSTOMER#456#ORDER#%'
ORDER BY JSON_VALUE(data, '$._id') DESC
FETCH FIRST 10 ROWS ONLY;
```

Expected output shows orders using the composite key index for fast prefix matching.

## Task 2: Type Discriminator Indexing

### Step 1: Create Type Index

```sql
-- Index on type field (essential for polymorphic collections)
CREATE INDEX idx_ecommerce_type ON ecommerce (JSON_VALUE(data, '$.type'));

-- Test type-specific query
SELECT COUNT(*)
FROM ecommerce
WHERE JSON_VALUE(data, '$.type') = 'order';
```

Expected output:
```
  COUNT(*)
----------
       100
```

### Step 2: Composite Index with Type + Date

```sql
-- Create composite index: type + frequently queried field
CREATE INDEX idx_ecommerce_type_date ON ecommerce (
  JSON_VALUE(data, '$.type'),
  JSON_VALUE(data, '$.order_date')
);

-- Test query optimized by composite index
SELECT
  JSON_VALUE(data, '$._id') AS order_id,
  JSON_VALUE(data, '$.total' RETURNING NUMBER) AS total,
  JSON_VALUE(data, '$.order_date') AS order_date
FROM ecommerce
WHERE JSON_VALUE(data, '$.type') = 'order'
  AND JSON_VALUE(data, '$.order_date') >= '2024-11-01'
ORDER BY JSON_VALUE(data, '$.order_date') DESC
FETCH FIRST 10 ROWS ONLY;
```

## Task 3: Multivalue Indexes for Arrays

### Step 1: Add Orders with Items Array

```sql
-- Add orders with items array
INSERT INTO ecommerce (data)
SELECT JSON_OBJECT(
  '_id' VALUE 'CUSTOMER#456#ORDER#' || LPAD(100 + LEVEL, 5, '0'),
  'type' VALUE 'order',
  'customer_id' VALUE 'CUSTOMER#456',
  'order_date' VALUE TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  'items' VALUE JSON_ARRAY(
    JSON_OBJECT('sku' VALUE 'WIDGET-001', 'quantity' VALUE 2),
    JSON_OBJECT('sku' VALUE 'GADGET-042', 'quantity' VALUE 1),
    JSON_OBJECT('sku' VALUE 'TOOL-' || LPAD(LEVEL, 3, '0'), 'quantity' VALUE 3)
  ),
  'total' VALUE 125.50
)
FROM DUAL
CONNECT BY LEVEL <= 10;

COMMIT;
```

### Step 2: Create Multivalue Index

```sql
-- Create multivalue index on items.sku
CREATE MULTIVALUE INDEX idx_order_items_sku ON ecommerce e (
  e.data.items.sku.string()
);

-- Test multivalue index - Find orders containing 'WIDGET-001'
SELECT
  JSON_VALUE(data, '$._id') AS order_id,
  JSON_VALUE(data, '$.order_date') AS order_date
FROM ecommerce e
WHERE JSON_VALUE(e.data, '$.type') = 'order'
  AND JSON_EXISTS(e.data, '$.items[*]?(@.sku == "WIDGET-001")');
```

Expected output shows all 10 orders containing WIDGET-001.

### Step 3: Add Products with Tags Array

```sql
-- Add products with tags
INSERT INTO ecommerce (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'PRODUCT#WIDGET-001',
    'type' VALUE 'product',
    'name' VALUE 'Super Widget',
    'price' VALUE 29.99,
    'tags' VALUE JSON_ARRAY('electronics', 'gadget', 'bestseller')
  )
);

INSERT INTO ecommerce (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'PRODUCT#GADGET-042',
    'type' VALUE 'product',
    'name' VALUE 'Mega Gadget',
    'price' VALUE 49.99,
    'tags' VALUE JSON_ARRAY('electronics', 'premium')
  )
);

COMMIT;

-- Create multivalue index on product tags
CREATE MULTIVALUE INDEX idx_product_tags ON ecommerce e (
  e.data.tags.string()
);

-- Query products by tag
SELECT
  JSON_VALUE(data, '$._id') AS product_id,
  JSON_VALUE(data, '$.name') AS product_name,
  JSON_VALUE(data, '$.price' RETURNING NUMBER) AS price
FROM ecommerce e
WHERE JSON_VALUE(e.data, '$.type') = 'product'
  AND JSON_EXISTS(e.data, '$.tags[*]?(@ == "electronics")');
```

## Task 4: Search Indexes for Full-Text Search

### Step 1: Create Search Index

```sql
-- Create search index for full-text search
CREATE SEARCH INDEX idx_ecommerce_search ON ecommerce (data) FOR JSON;

-- Note: Search index enables:
-- - Full-text search across all text fields
-- - Fuzzy matching
-- - Phrase search
-- - Boolean operators
```

### Step 2: Use Search Index

```sql
-- Full-text search for customer names
SELECT
  JSON_VALUE(data, '$._id') AS doc_id,
  JSON_VALUE(data, '$.type') AS doc_type,
  JSON_VALUE(data, '$.name') AS name
FROM ecommerce
WHERE JSON_TEXTCONTAINS(data, '$', 'John')
  AND JSON_VALUE(data, '$.type') = 'customer';

-- Search for products with keywords
SELECT
  JSON_VALUE(data, '$._id') AS product_id,
  JSON_VALUE(data, '$.name') AS product_name
FROM ecommerce
WHERE JSON_TEXTCONTAINS(data, '$.name', 'Widget')
  AND JSON_VALUE(data, '$.type') = 'product';
```

## Task 5: Index Performance Analysis

### Step 1: View All Indexes on Collection

```sql
-- Check all indexes on the ecommerce table
SELECT index_name, index_type, status
FROM user_indexes
WHERE table_name = 'ECOMMERCE'
ORDER BY index_name;
```

Expected output:
```
INDEX_NAME                  INDEX_TYPE          STATUS
--------------------------  ------------------  ------
IDX_ECOMMERCE_ID            FUNCTION-BASED      VALID
IDX_ECOMMERCE_TYPE          FUNCTION-BASED      VALID
IDX_ECOMMERCE_TYPE_DATE     FUNCTION-BASED      VALID
IDX_ORDER_ITEMS_SKU         MULTIVALUE          VALID
IDX_PRODUCT_TAGS            MULTIVALUE          VALID
IDX_ECOMMERCE_SEARCH        DOMAIN              VALID
SYS_...                     NORMAL              VALID (auto-generated)
```

### Step 2: Check Index Usage Statistics

```sql
-- Index segment sizes
SELECT
  segment_name AS index_name,
  ROUND(bytes / 1024, 2) AS size_kb
FROM user_segments
WHERE segment_type = 'INDEX'
  AND segment_name LIKE 'IDX_ECOMMERCE%' OR segment_name LIKE 'IDX_ORDER%' OR segment_name LIKE 'IDX_PRODUCT%'
ORDER BY bytes DESC;
```

### Step 3: Explain Plan Analysis

```sql
-- Check execution plan for composite key query
EXPLAIN PLAN FOR
SELECT JSON_VALUE(data, '$._id') AS id
FROM ecommerce
WHERE JSON_VALUE(data, '$._id') LIKE 'CUSTOMER#456#ORDER#%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

The plan should show `INDEX RANGE SCAN` on `IDX_ECOMMERCE_ID`.

## Task 6: Index Strategy Best Practices

### Index Design Checklist

**Must-Have Indexes:**
- [x] Index on `_id` (composite key) for exact and prefix matches
- [x] Index on `type` (discriminator) for type filtering
- [x] Composite index on `type` + frequently queried field (e.g., date, status)

**Optional Indexes (based on access patterns):**
- [ ] Multivalue indexes on array fields if querying array elements
- [ ] Search index if full-text search is required
- [ ] Indexes on denormalized fields (e.g., `customer_id` in orders)

**Avoid:**
- Over-indexing (indexes have write overhead)
- Indexing rarely queried fields
- Duplicate indexes

### Index Maintenance

```sql
-- Rebuild indexes periodically for optimal performance
ALTER INDEX idx_ecommerce_id REBUILD ONLINE;
ALTER INDEX idx_ecommerce_type REBUILD ONLINE;

-- Gather statistics for optimizer
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ECOMMERCE');
```

## Task 7: Cleanup

```sql
-- Clean up (optional - keep for Lab 9)
-- DROP TABLE ecommerce PURGE;
```

## Conclusion

In this lab, you learned comprehensive indexing strategies for Single Collection designs in Oracle JSON Collection Tables.

**Key Takeaways:**
- ✅ Always index `_id` (composite key) for prefix and exact match queries
- ✅ Always index `type` (discriminator) for polymorphic collection filtering
- ✅ Use composite indexes combining `type` + frequently queried field
- ✅ Use multivalue indexes for array element queries
- ✅ Use search indexes for full-text search capabilities
- ✅ Monitor index usage and rebuild indexes periodically

**Index Strategy Summary:**
1. Start with composite key and type discriminator indexes
2. Add indexes based on actual query patterns (not speculation)
3. Monitor and maintain indexes regularly
4. Balance read performance gains against write overhead

**Next Steps:**
- Proceed to **Lab 9: Performance Testing & Comparison** to measure the impact of your design decisions

## Learn More

* [Oracle JSON Developer's Guide - Indexes](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/indexes-for-json-data.html)
* [Oracle Database Performance Tuning Guide - Indexing](https://docs.oracle.com/en/database/oracle/oracle-database/26/tgdba/managing-and-monitoring-database-indexes.html)

## Acknowledgments

* **Author** - Rick Houlihan
* **Last Updated By/Date** - November 2025
