# Single Collection/Table Design Pattern

## Introduction

Welcome to the most critical lab in this workshop! The **Single Collection/Table Design pattern** represents a fundamental paradigm shift from relational database design and is the key to achieving 10-20x query performance improvements while avoiding LOB performance cliffs in Oracle JSON Collections.

This pattern is based on Rick Houlihan's DynamoDB Single Table Design methodology and MongoDB's Single Collection pattern, adapted for Oracle JSON Collections with OSON binary format.

By the end of this lab, you will understand how to design document models that store multiple entity types in a single collection, use composite keys for efficient queries, apply strategic denormalization, and achieve predictable sub-5ms query latency at scale.

Estimated Time: 60 minutes

### Objectives

In this lab, you will:

* Understand the paradigm shift from entity-first (RDBMS) to access pattern-first (NoSQL) design
* Learn Rick Houlihan's core principle: "What is accessed together should be stored together"
* Implement composite key strategies (delimiter-based, hierarchical, date-based)
* Apply strategic denormalization to eliminate application-level joins
* Store multiple entity types in a single collection using polymorphic documents
* Avoid the 32MB OSON limit and LOB performance cliffs
* Measure 10-20x query performance improvements over multi-collection approach
* Design for common access patterns in e-commerce scenarios

### Prerequisites

This lab assumes you have:

* Completed Lab 0: Setup
* Completed Lab 1: JSON Collections Fundamentals
* Completed Lab 2: Embedded vs Referenced Patterns
* Understanding of JSON_VALUE, JSON_QUERY, and performance measurement
* Access to Oracle Database as JSONUSER

## Task 1: The Paradigm Shift - RDBMS vs NoSQL

Before implementing the pattern, you must understand the fundamental difference in design philosophy.

### Step 1: Traditional RDBMS Approach (Entity-First)

**RDBMS Design Process:**

```
1. Identify entities (Customer, Order, OrderItem, Product)
2. Normalize to 3NF (eliminate redundancy)
3. Create tables with foreign keys
4. Write queries with JOINs to reconstruct data
```

**Goal:** Eliminate redundancy, enforce referential integrity, optimize for storage

**Example RDBMS Schema:**

```sql
-- 4 separate tables
CREATE TABLE customers (...);
CREATE TABLE orders (...);     -- FK to customers
CREATE TABLE order_items (...); -- FK to orders
CREATE TABLE products (...);
```

**Query to get order with customer info:**

```sql
-- Requires 3 JOINs
SELECT o.*, c.name, c.email, oi.*, p.name
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_id = 'ORD-001';
```

**Problems in NoSQL context:**
- ❌ Multiple queries or expensive aggregations
- ❌ Application-side joins add latency
- ❌ Unpredictable performance with large datasets
- ❌ Documents can grow unbounded (exceed 32MB OSON limit)

### Step 2: NoSQL Approach (Access Pattern-First)

**NoSQL Design Process:**

```
1. Identify access patterns (how will data be queried?)
2. Design for the most common queries (optimize for reads)
3. Denormalize strategically (duplicate data accessed together)
4. Create single collection with polymorphic documents
```

**Goal:** Optimize read performance, minimize query latency, avoid application joins

**Access Pattern Analysis:**

```
Access Pattern 1: Get order with customer info and all items
  Frequency: 90% of queries
  → Store order, customer info, and items together

Access Pattern 2: Get customer's order history
  Frequency: 8% of queries
  → Use composite key for efficient prefix queries

Access Pattern 3: Search products
  Frequency: 2% of queries
  → Separate query, can be in same collection or separate
```

**Key Insight:**
> **"In cloud computing, storage is cheap but compute (query time) is expensive. Optimize for query performance, not storage minimization."** - Rick Houlihan

## Task 2: Composite Key Strategies

Composite keys are the foundation of Single Collection design. They enable you to store multiple entity types in one collection while maintaining efficient queries.

### Step 1: Understanding Composite Keys

**What is a composite key?**

A composite key combines multiple identifiers into a single `_id` field to represent hierarchical relationships.

**Why use composite keys?**

1. ✅ Support multiple entity types in one collection
2. ✅ Enable efficient prefix queries
3. ✅ Natural sorting and grouping
4. ✅ Express hierarchical relationships
5. ✅ Reduce number of queries

### Step 2: Delimiter-Based Composite Keys

**Pattern: Use delimiters to separate key components**

1. Create test collection:

   ```sql
   CREATE TABLE ecommerce_single (
     id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
     json_document JSON,
     created_on TIMESTAMP DEFAULT SYSTIMESTAMP
   );
   ```

2. Create index on composite key:

   ```sql
   CREATE INDEX idx_ecommerce_id
   ON ecommerce_single (JSON_VALUE(json_document, '$._id'));
   ```

3. Insert customer entity:

   ```sql
   INSERT INTO ecommerce_single (json_document) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'CUSTOMER#CUST-456',
       'type' VALUE 'customer',
       'name' VALUE 'Alice Johnson',
       'email' VALUE 'alice@email.com',
       'phone' VALUE '+1-555-0123',
       'created' VALUE '2024-01-15T10:00:00Z',
       'loyalty_tier' VALUE 'gold',
       'total_orders' VALUE 127,
       'lifetime_value' VALUE 12450.00
     )
   );
   ```

4. Insert order entity (same collection):

   ```sql
   INSERT INTO ecommerce_single (json_document) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'CUSTOMER#CUST-456#ORDER#ORD-001',
       'type' VALUE 'order',
       'customer_id' VALUE 'CUST-456',
       'customer_name' VALUE 'Alice Johnson',      -- Denormalized
       'customer_email' VALUE 'alice@email.com',   -- Denormalized
       'order_date' VALUE '2024-11-15T10:30:00Z',
       'status' VALUE 'shipped',
       'items' VALUE JSON_ARRAY(
         JSON_OBJECT(
           'product_id' VALUE 'PROD-789',
           'name' VALUE 'Wireless Headphones',
           'price' VALUE 79.99,
           'quantity' VALUE 1,
           'subtotal' VALUE 79.99
         ),
         JSON_OBJECT(
           'product_id' VALUE 'PROD-234',
           'name' VALUE 'USB-C Cable',
           'price' VALUE 12.99,
           'quantity' VALUE 2,
           'subtotal' VALUE 25.98
         )
       ),
       'subtotal' VALUE 105.97,
       'tax' VALUE 8.48,
       'shipping' VALUE 0.00,
       'total' VALUE 114.45
     )
   );
   ```

5. Query by exact key:

   ```sql
   -- Get specific order (single query, ~1-2ms)
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM ecommerce_single
   WHERE JSON_VALUE(json_document, '$._id') = 'CUSTOMER#CUST-456#ORDER#ORD-001';
   ```

   **Notice:** This single query returns:
   - Order details
   - Customer information (denormalized)
   - All order items
   - No joins required!

6. Query by key prefix (get all orders for customer):

   ```sql
   -- Get all orders for a customer
   SELECT
     JSON_VALUE(json_document, '$._id') AS order_id,
     JSON_VALUE(json_document, '$.order_date') AS order_date,
     JSON_VALUE(json_document, '$.total' RETURNING NUMBER) AS total,
     JSON_VALUE(json_document, '$.status') AS status
   FROM ecommerce_single
   WHERE JSON_VALUE(json_document, '$._id') LIKE 'CUSTOMER#CUST-456#ORDER#%';
   ```

7. Get customer and all their orders (2 queries):

   ```sql
   -- Query 1: Get customer
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM ecommerce_single
   WHERE JSON_VALUE(json_document, '$._id') = 'CUSTOMER#CUST-456'
     AND JSON_VALUE(json_document, '$.type') = 'customer';

   -- Query 2: Get all customer's orders
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM ecommerce_single
   WHERE JSON_VALUE(json_document, '$._id') LIKE 'CUSTOMER#CUST-456#ORDER#%'
   ORDER BY JSON_VALUE(json_document, '$.order_date') DESC;
   ```

### Step 3: Hierarchical Composite Keys (JSON Object)

Alternative approach using JSON object as _id:

1. Insert with hierarchical key:

   ```sql
   INSERT INTO ecommerce_single (json_document) VALUES (
     '{"_id": {"customer_id": "CUST-789", "order_id": "ORD-002"}, "type": "order", "customer_name": "Bob Martinez", "order_date": "2024-11-16T14:00:00Z", "total": 299.99}'
   );
   ```

2. Query with hierarchical key:

   ```sql
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM ecommerce_single
   WHERE JSON_VALUE(json_document, '$._id.customer_id') = 'CUST-789'
     AND JSON_VALUE(json_document, '$._id.order_id') = 'ORD-002';
   ```

**Recommendation:** Use **delimiter-based keys** for Oracle JSON Collections because:
- ✅ Better index performance (string comparison vs nested JSON)
- ✅ Simpler LIKE queries for prefix matching
- ✅ Better compatibility with Oracle's optimizer

### Step 4: Date-Based Composite Keys (Time-Series Data)

For time-series data, include date in the key:

1. Insert sensor reading:

   ```sql
   INSERT INTO ecommerce_single (json_document) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'SENSOR#temp001#2024-11-18#14:00',
       'type' VALUE 'sensor_reading',
       'sensor_id' VALUE 'temp001',
       'timestamp' VALUE '2024-11-18T14:00:00Z',
       'temperature' VALUE 72.5,
       'humidity' VALUE 45.2,
       'location' VALUE 'warehouse_A'
     )
   );
   ```

2. Query by date range:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.timestamp') AS timestamp,
     JSON_VALUE(json_document, '$.temperature') AS temp,
     JSON_VALUE(json_document, '$.humidity') AS humidity
   FROM ecommerce_single
   WHERE JSON_VALUE(json_document, '$._id') LIKE 'SENSOR#temp001#2024-11-18#%'
   ORDER BY JSON_VALUE(json_document, '$.timestamp');
   ```

## Task 3: Strategic Denormalization

Strategic denormalization is the practice of intentionally duplicating data that is accessed together.

### Step 1: Denormalization Decision Framework

**When to Denormalize:**

| Criteria | Denormalize? | Example |
|----------|--------------|---------|
| Data accessed together? | ✅ Yes | Customer name in order |
| Data changes infrequently? | ✅ Yes | Product name (frozen at order time) |
| Data is small (< 1KB)? | ✅ Yes | Customer email, shipping address |
| Read-heavy workload? | ✅ Yes | Order history queries |
| Data changes frequently? | ❌ No | Inventory levels |
| Data is large (over 10KB)? | ❌ No | Product images, full descriptions |
| Strong consistency required? | ❌ No | Financial balances |

**Rick Houlihan's Guidance (2024):**

> **DO denormalize:**
> - Data accessed together by a single access pattern
> - Data that changes infrequently
> - Data within the same service boundary
>
> **DO NOT denormalize:**
> - Unrelated data just to reduce collections
> - Data across service boundaries
> - Frequently changing data that would cause write amplification

### Step 2: Implement Strategic Denormalization

1. Insert order with denormalized customer and product data:

   ```sql
   INSERT INTO ecommerce_single (json_document) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'CUSTOMER#CUST-456#ORDER#ORD-003',
       'type' VALUE 'order',

       -- Customer data (denormalized snapshot)
       'customer' VALUE JSON_OBJECT(
         'id' VALUE 'CUST-456',
         'name' VALUE 'Alice Johnson',
         'email' VALUE 'alice@email.com',
         'phone' VALUE '+1-555-0123',
         'loyalty_tier' VALUE 'gold',
         'snapshot_date' VALUE '2024-11-18'  -- Important: indicates it's a snapshot
       ),

       -- Shipping address (denormalized)
       'shipping_address' VALUE JSON_OBJECT(
         'street' VALUE '123 Main Street',
         'city' VALUE 'San Francisco',
         'state' VALUE 'CA',
         'zip' VALUE '94105',
         'country' VALUE 'USA'
       ),

       -- Order items (denormalized product info)
       'items' VALUE JSON_ARRAY(
         JSON_OBJECT(
           'product_id' VALUE 'PROD-789',
           'name' VALUE 'Wireless Headphones',
           'sku' VALUE 'WH-BT-789',
           'price' VALUE 79.99,        -- Price frozen at order time
           'quantity' VALUE 1,
           'subtotal' VALUE 79.99,
           'category' VALUE 'Electronics',
           'brand' VALUE 'AudioTech'
         )
       ),

       'order_date' VALUE '2024-11-18T10:30:00Z',
       'status' VALUE 'processing',
       'total' VALUE 87.99
     )
   );

   COMMIT;
   ```

2. Query order (single query, all data):

   ```sql
   SELECT
     JSON_VALUE(json_document, '$._id') AS order_id,
     JSON_VALUE(json_document, '$.customer.name') AS customer_name,
     JSON_VALUE(json_document, '$.customer.email') AS customer_email,
     JSON_VALUE(json_document, '$.customer.loyalty_tier') AS tier,
     JSON_VALUE(json_document, '$.shipping_address.city') AS ship_city,
     JSON_VALUE(json_document, '$.total' RETURNING NUMBER) AS total,
     JSON_QUERY(json_document, '$.items' PRETTY) AS items
   FROM ecommerce_single
   WHERE JSON_VALUE(json_document, '$._id') = 'CUSTOMER#CUST-456#ORDER#ORD-003';
   ```

   **Result:** Complete order details in **one query**, ~1-2ms latency!

### Step 3: Extended Reference Pattern (Hybrid Approach)

For large, frequently changing data, use **extended reference pattern**: denormalize only essential fields, reference full entity.

1. Product catalog (separate collection for full details):

   ```sql
   CREATE TABLE products_catalog (
     id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
     json_document JSON
   );

   INSERT INTO products_catalog (json_document) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'PROD-789',
       'name' VALUE 'Wireless Headphones',
       'full_description' VALUE 'Premium wireless Bluetooth headphones with 30-hour battery life...',
       'specifications' VALUE JSON_OBJECT(
         'weight' VALUE '8.5 oz',
         'bluetooth' VALUE '5.0',
         'battery_hours' VALUE 30,
         'noise_cancellation' VALUE true
       ),
       'images' VALUE JSON_ARRAY('image1.jpg', 'image2.jpg', 'image3.jpg'),
       'reviews' VALUE JSON_ARRAY(/* hundreds of reviews */),
       'price_history' VALUE JSON_ARRAY(/* price changes over time */)
     )
   );
   ```

2. Order with extended reference (denormalize small, frequently accessed fields):

   ```sql
   -- In order document, include only essential product fields:
   {
     "items": [
       {
         "product_id": "PROD-789",     // Reference to full product
         "name": "Wireless Headphones", // Denormalized (small, accessed often)
         "price": 79.99,                // Denormalized (frozen at order time)
         "sku": "WH-BT-789",            // Denormalized (small, useful)
         "image": "image1.jpg"          // Denormalized (primary image only)
         // Full details NOT denormalized (large, infrequently needed)
       }
     ]
   }
   ```

3. Query pattern:

   ```sql
   -- Most common: Get order (no product details needed)
   SELECT * FROM ecommerce_single
   WHERE JSON_VALUE(json_document, '$._id') = 'CUSTOMER#CUST-456#ORDER#ORD-003';
   -- Returns in ~1-2ms

   -- Rare: Get order + full product details (2 queries)
   -- Query 1: Get order (extract product IDs)
   -- Query 2: Get full product details from products_catalog
   ```

**Benefits:**
- ✅ Common queries are fast (single query, no large data)
- ✅ Documents stay small (avoid LOB cliff)
- ✅ Product catalog can be updated independently
- ✅ Order still has essential product info

## Task 4: Avoiding LOB Performance Cliffs

Oracle's OSON format has performance tiers based on document size. Understanding these is critical.

### Step 1: OSON Performance Tiers

```
TIER 1: Inline Storage (< 7,950 bytes)
  - Stored directly in table row
  - Fastest query performance (~1-2ms)
  - TARGET: Keep 80%+ of documents here

TIER 2: LOB Storage (7,950 bytes - 100KB)
  - Stored in LOB segment
  - Slower performance (~5-10ms)
  - ACCEPTABLE: Use for infrequent queries

TIER 3: Large LOB (100KB - 10MB)
  - Significantly slower (~20-50ms)
  - AVOID: Redesign to split data

TIER 4: Very Large (10MB - 32MB)
  - Very slow, unpredictable performance
  - STRONGLY AVOID: Major redesign needed

LIMIT: 32MB maximum
  - Documents exceeding 32MB FAIL to insert
```

### Step 2: Measure Document Sizes

1. Check current document sizes:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$._id') AS id,
     JSON_VALUE(json_document, '$.type') AS type,
     LENGTHB(json_document) AS bytes,
     CASE
       WHEN LENGTHB(json_document) < 7950 THEN 'TIER 1: Inline (Optimal)'
       WHEN LENGTHB(json_document) < 102400 THEN 'TIER 2: LOB (OK)'
       WHEN LENGTHB(json_document) < 10485760 THEN 'TIER 3: Large LOB (Slow)'
       ELSE 'TIER 4: Very Large (Avoid)'
     END AS storage_tier
   FROM ecommerce_single
   ORDER BY bytes DESC;
   ```

2. Calculate collection statistics:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.type') AS entity_type,
     COUNT(*) AS document_count,
     ROUND(AVG(LENGTHB(json_document)), 0) AS avg_bytes,
     MIN(LENGTHB(json_document)) AS min_bytes,
     MAX(LENGTHB(json_document)) AS max_bytes,
     SUM(CASE WHEN LENGTHB(json_document) < 7950 THEN 1 ELSE 0 END) AS inline_count,
     ROUND(SUM(CASE WHEN LENGTHB(json_document) < 7950 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS inline_pct
   FROM ecommerce_single
   GROUP BY JSON_VALUE(json_document, '$.type');
   ```

   **Target:** 80%+ of documents in "inline" tier (< 7,950 bytes)

### Step 3: Strategies to Avoid LOB Cliffs

**Problem:** Order with 500 items exceeds 100KB

**Solution 1: Bounded Arrays**
```sql
-- Instead of embedding all 500 items:
-- Embed only first 10-20 items (most commonly accessed)
{
  "_id": "CUSTOMER#CUST-456#ORDER#ORD-LARGE",
  "items_preview": [/* first 10 items */],
  "total_items": 500,
  "items_paginated": true
}

-- Store remaining items separately:
{
  "_id": "CUSTOMER#CUST-456#ORDER#ORD-LARGE#ITEMS#PAGE-2",
  "type": "order_items_page",
  "page": 2,
  "items": [/* items 11-20 */]
}
```

**Solution 2: Subset Pattern**
```sql
-- Frequently accessed fields in main document:
{
  "_id": "CUSTOMER#CUST-456#ORDER#ORD-LARGE",
  "summary": {
    "item_count": 500,
    "total": 12450.00,
    "top_items": [/* 5 most expensive items */]
  }
}

-- Full details in separate document (rarely accessed):
{
  "_id": "CUSTOMER#CUST-456#ORDER#ORD-LARGE#DETAILS",
  "type": "order_details",
  "all_items": [/* all 500 items */],
  "detailed_breakdown": {...}
}
```

**Solution 3: Bucketing Pattern (Time-Series)**
```sql
-- Instead of single document with all sensor readings:
-- Bucket by hour:
{
  "_id": "SENSOR#temp001#2024-11-18#14",
  "type": "sensor_bucket",
  "readings": [
    {"time": "14:00", "temp": 72.5},
    {"time": "14:05", "temp": 72.7},
    /* ... 12 readings per hour */
  ]
}
```

## Task 5: Performance Comparison - Single vs Multiple Collections

Now let's measure the actual performance improvement.

### Step 1: Create Multi-Collection Approach (Baseline)

1. Create traditional normalized collections:

   ```sql
   CREATE TABLE customers_multi (id RAW(16) PRIMARY KEY, json_document JSON);
   CREATE TABLE orders_multi (id RAW(16) PRIMARY KEY, json_document JSON);
   CREATE TABLE order_items_multi (id RAW(16) PRIMARY KEY, json_document JSON);

   CREATE INDEX idx_orders_multi_customer
     ON orders_multi (JSON_VALUE(json_document, '$.customer_id'));
   CREATE INDEX idx_items_multi_order
     ON order_items_multi (JSON_VALUE(json_document, '$.order_id'));
   ```

2. Insert sample data:

   ```sql
   -- Customer
   INSERT INTO customers_multi (json_document) VALUES (
     '{"_id": "CUST-456", "name": "Alice Johnson", "email": "alice@email.com"}'
   );

   -- Order
   INSERT INTO orders_multi (json_document) VALUES (
     '{"_id": "ORD-MULTI-001", "customer_id": "CUST-456", "order_date": "2024-11-18", "total": 114.45}'
   );

   -- Order items
   INSERT INTO order_items_multi (json_document) VALUES
     ('{"_id": "ITEM-M-001", "order_id": "ORD-MULTI-001", "product_id": "PROD-789", "name": "Headphones", "price": 79.99, "quantity": 1}'),
     ('{"_id": "ITEM-M-002", "order_id": "ORD-MULTI-001", "product_id": "PROD-234", "name": "USB Cable", "price": 12.99, "quantity": 2}');

   COMMIT;
   ```

3. Query (requires 3 queries or expensive join):

   ```sql
   -- Approach 1: Multiple queries (client-side join)
   SELECT * FROM orders_multi WHERE JSON_VALUE(json_document, '$._id') = 'ORD-MULTI-001';
   SELECT * FROM customers_multi WHERE JSON_VALUE(json_document, '$._id') = 'CUST-456';
   SELECT * FROM order_items_multi WHERE JSON_VALUE(json_document, '$.order_id') = 'ORD-MULTI-001';

   -- Approach 2: SQL join (database-side, slower)
   SELECT
     o.json_document,
     c.json_document,
     i.json_document
   FROM orders_multi o
   JOIN customers_multi c ON JSON_VALUE(o.json_document, '$.customer_id') = JSON_VALUE(c.json_document, '$._id')
   JOIN order_items_multi i ON JSON_VALUE(o.json_document, '$._id') = JSON_VALUE(i.json_document, '$.order_id')
   WHERE JSON_VALUE(o.json_document, '$._id') = 'ORD-MULTI-001';
   ```

### Step 2: Create Performance Benchmark

1. Generate test data for both approaches:

   ```sql
   -- Generate 1000 orders in single collection
   INSERT INTO ecommerce_single (json_document)
   SELECT
     JSON_OBJECT(
       '_id' VALUE 'CUSTOMER#CUST-' || LPAD(MOD(level, 100), 3, '0') || '#ORDER#ORD-' || LPAD(level, 4, '0'),
       'type' VALUE 'order',
       'customer' VALUE JSON_OBJECT(
         'id' VALUE 'CUST-' || LPAD(MOD(level, 100), 3, '0'),
         'name' VALUE 'Customer ' || MOD(level, 100),
         'email' VALUE 'customer' || MOD(level, 100) || '@email.com'
       ),
       'items' VALUE JSON_ARRAY(
         JSON_OBJECT(
           'product_id' VALUE 'PROD-' || LPAD(MOD(level * 3, 50), 3, '0'),
           'name' VALUE 'Product ' || MOD(level * 3, 50),
           'price' VALUE 29.99 + MOD(level, 20) * 5,
           'quantity' VALUE MOD(level, 5) + 1
         )
       ),
       'order_date' VALUE TO_CHAR(SYSDATE - level, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       'total' VALUE (29.99 + MOD(level, 20) * 5) * (MOD(level, 5) + 1)
     )
   FROM dual
   CONNECT BY level <= 1000;

   COMMIT;
   ```

2. Run benchmark:

   ```sql
   -- Clear previous metrics
   DELETE FROM performance_metrics WHERE test_id = 'SINGLE_VS_MULTI';
   COMMIT;

   -- Benchmark SINGLE COLLECTION
   DECLARE
     v_start TIMESTAMP;
     v_end TIMESTAMP;
     v_iterations CONSTANT NUMBER := 1000;
     v_result CLOB;
   BEGIN
     FOR i IN 1..v_iterations LOOP
       v_start := SYSTIMESTAMP;

       -- Single query gets everything
       SELECT JSON_SERIALIZE(json_document)
       INTO v_result
       FROM ecommerce_single
       WHERE JSON_VALUE(json_document, '$._id') = 'CUSTOMER#CUST-' || LPAD(MOD(i, 100), 3, '0') || '#ORDER#ORD-' || LPAD(i, 4, '0');

       v_end := SYSTIMESTAMP;

       INSERT INTO performance_metrics VALUES (
         'SINGLE_VS_MULTI', 'SINGLE_COLLECTION', 'GET_ORDER', i,
         EXTRACT(SECOND FROM (v_end - v_start)) * 1000,
         NULL, NULL, NULL, SYSTIMESTAMP,
         'Single query retrieves order with customer and items'
       );
     END LOOP;
     COMMIT;
   END;
   /

   -- Benchmark MULTI COLLECTION (3 queries)
   DECLARE
     v_start TIMESTAMP;
     v_end TIMESTAMP;
     v_iterations CONSTANT NUMBER := 100;  -- Fewer iterations (it's slower)
     v_customer_id VARCHAR2(20);
     v_result1 CLOB;
     v_result2 CLOB;
     v_count NUMBER;
   BEGIN
     FOR i IN 1..v_iterations LOOP
       v_start := SYSTIMESTAMP;

       -- Query 1: Get order
       SELECT
         JSON_SERIALIZE(json_document),
         JSON_VALUE(json_document, '$.customer_id')
       INTO v_result1, v_customer_id
       FROM orders_multi
       WHERE JSON_VALUE(json_document, '$._id') = 'ORD-MULTI-001';

       -- Query 2: Get customer
       SELECT JSON_SERIALIZE(json_document)
       INTO v_result2
       FROM customers_multi
       WHERE JSON_VALUE(json_document, '$._id') = v_customer_id;

       -- Query 3: Get order items
       SELECT COUNT(*) INTO v_count
       FROM order_items_multi
       WHERE JSON_VALUE(json_document, '$.order_id') = 'ORD-MULTI-001';

       v_end := SYSTIMESTAMP;

       INSERT INTO performance_metrics VALUES (
         'SINGLE_VS_MULTI', 'MULTI_COLLECTION', 'GET_ORDER', i,
         EXTRACT(SECOND FROM (v_end - v_start)) * 1000,
         NULL, NULL, NULL, SYSTIMESTAMP,
         'Three queries: order + customer + items'
       );
     END LOOP;
     COMMIT;
   END;
   /
   ```

3. Analyze results:

   ```sql
   SELECT
     pattern_name,
     COUNT(*) AS iterations,
     ROUND(AVG(execution_time_ms), 2) AS avg_ms,
     ROUND(MIN(execution_time_ms), 2) AS min_ms,
     ROUND(MAX(execution_time_ms), 2) AS max_ms,
     ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_time_ms), 2) AS p95_ms,
     ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY execution_time_ms), 2) AS p99_ms,
     ROUND(STDDEV(execution_time_ms), 2) AS stddev_ms
   FROM performance_metrics
   WHERE test_id = 'SINGLE_VS_MULTI'
   GROUP BY pattern_name
   ORDER BY avg_ms;
   ```

   **Expected Results:**
   ```
   PATTERN_NAME       ITERATIONS  AVG_MS  MIN_MS  MAX_MS  P95_MS  P99_MS  STDDEV_MS
   ----------------   ----------  ------  ------  ------  ------  ------  ---------
   SINGLE_COLLECTION        1000    1.85    0.92    4.20    2.50    3.10       0.45
   MULTI_COLLECTION          100   24.50   18.30   42.00   32.00   38.50       4.20
   ```

   **Analysis:**
   - **Single Collection: ~2ms average** (predictable, fast)
   - **Multi Collection: ~25ms average** (10-15x slower)
   - **Performance improvement: 10-13x faster with Single Collection**
   - **P99 latency: 3ms vs 38ms** (more predictable performance)

4. Calculate speedup:

   ```sql
   SELECT
     ROUND(
       (SELECT AVG(execution_time_ms) FROM performance_metrics WHERE test_id = 'SINGLE_VS_MULTI' AND pattern_name = 'MULTI_COLLECTION') /
       (SELECT AVG(execution_time_ms) FROM performance_metrics WHERE test_id = 'SINGLE_VS_MULTI' AND pattern_name = 'SINGLE_COLLECTION'),
       1
     ) AS speedup_factor
   FROM dual;
   ```

   **Result:** 10-20x speedup! 🚀

## Task 6: Real-World E-commerce Implementation

Let's implement a complete e-commerce system using Single Collection pattern.

### Step 1: Design Access Patterns

**Primary Access Patterns:**

1. **Get order with all details** (90% of queries)
   - Order info + customer info + items
   - Target: < 5ms

2. **Get customer's order history** (8% of queries)
   - List of orders for a customer
   - Target: < 10ms

3. **Get customer profile** (2% of queries)
   - Customer details + summary stats
   - Target: < 5ms

### Step 2: Implement Complete E-commerce Collection

1. Drop and recreate collection:

   ```sql
   DROP TABLE ecommerce_single;

   CREATE TABLE ecommerce_single (
     id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
     json_document JSON,
     created_on TIMESTAMP DEFAULT SYSTIMESTAMP
   );

   CREATE INDEX idx_ecommerce_id ON ecommerce_single (JSON_VALUE(json_document, '$._id'));
   CREATE INDEX idx_ecommerce_type ON ecommerce_single (JSON_VALUE(json_document, '$.type'));
   ```

2. Insert customers:

   ```sql
   INSERT INTO ecommerce_single (json_document)
   SELECT
     JSON_OBJECT(
       '_id' VALUE 'CUSTOMER#CUST-' || LPAD(level, 3, '0'),
       'type' VALUE 'customer',
       'name' VALUE 'Customer ' || level,
       'email' VALUE 'customer' || level || '@email.com',
       'phone' VALUE '+1-555-' || LPAD(level, 4, '0'),
       'created' VALUE TO_CHAR(SYSDATE - (level * 10), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       'loyalty_tier' VALUE CASE
         WHEN MOD(level, 3) = 0 THEN 'platinum'
         WHEN MOD(level, 3) = 1 THEN 'gold'
         ELSE 'silver'
       END,
       'total_orders' VALUE MOD(level, 50) + 10,
       'lifetime_value' VALUE (MOD(level, 50) + 10) * 85.00,
       'addresses' VALUE JSON_ARRAY(
         JSON_OBJECT(
           'type' VALUE 'shipping',
           'street' VALUE level || ' Main Street',
           'city' VALUE 'San Francisco',
           'state' VALUE 'CA',
           'zip' VALUE '9410' || MOD(level, 10),
           'default' VALUE true
         )
       )
     )
   FROM dual
   CONNECT BY level <= 100;
   ```

3. Insert orders with full denormalization:

   ```sql
   INSERT INTO ecommerce_single (json_document)
   SELECT
     JSON_OBJECT(
       '_id' VALUE 'CUSTOMER#CUST-' || LPAD(MOD(level, 100) + 1, 3, '0') || '#ORDER#ORD-' || LPAD(level, 5, '0'),
       'type' VALUE 'order',

       -- Denormalized customer info
       'customer' VALUE JSON_OBJECT(
         'id' VALUE 'CUST-' || LPAD(MOD(level, 100) + 1, 3, '0'),
         'name' VALUE 'Customer ' || (MOD(level, 100) + 1),
         'email' VALUE 'customer' || (MOD(level, 100) + 1) || '@email.com',
         'loyalty_tier' VALUE CASE
           WHEN MOD(level, 3) = 0 THEN 'platinum'
           WHEN MOD(level, 3) = 1 THEN 'gold'
           ELSE 'silver'
         END
       ),

       -- Denormalized shipping address
       'shipping_address' VALUE JSON_OBJECT(
         'street' VALUE (MOD(level, 100) + 1) || ' Main Street',
         'city' VALUE 'San Francisco',
         'state' VALUE 'CA',
         'zip' VALUE '9410' || MOD(level, 10)
       ),

       -- Embedded order items with denormalized product info
       'items' VALUE JSON_ARRAY(
         JSON_OBJECT(
           'product_id' VALUE 'PROD-' || LPAD(MOD(level * 3, 50) + 1, 3, '0'),
           'name' VALUE 'Product ' || (MOD(level * 3, 50) + 1),
           'sku' VALUE 'SKU-' || (MOD(level * 3, 50) + 1),
           'price' VALUE 19.99 + MOD(level, 30) * 3,
           'quantity' VALUE MOD(level, 4) + 1,
           'category' VALUE CASE MOD(level, 4)
             WHEN 0 THEN 'Electronics'
             WHEN 1 THEN 'Books'
             WHEN 2 THEN 'Clothing'
             ELSE 'Home & Garden'
           END
         )
       ),

       'order_date' VALUE TO_CHAR(SYSDATE - level * 0.5, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       'status' VALUE CASE MOD(level, 4)
         WHEN 0 THEN 'delivered'
         WHEN 1 THEN 'shipped'
         WHEN 2 THEN 'processing'
         ELSE 'pending'
       END,
       'subtotal' VALUE (19.99 + MOD(level, 30) * 3) * (MOD(level, 4) + 1),
       'tax' VALUE (19.99 + MOD(level, 30) * 3) * (MOD(level, 4) + 1) * 0.08,
       'shipping' VALUE CASE WHEN MOD(level, 5) = 0 THEN 0 ELSE 7.99 END,
       'total' VALUE (19.99 + MOD(level, 30) * 3) * (MOD(level, 4) + 1) * 1.08 + CASE WHEN MOD(level, 5) = 0 THEN 0 ELSE 7.99 END
     )
   FROM dual
   CONNECT BY level <= 10000;

   COMMIT;
   ```

### Step 3: Query Access Patterns

1. **Access Pattern 1: Get order with all details**

   ```sql
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM ecommerce_single
   WHERE JSON_VALUE(json_document, '$._id') = 'CUSTOMER#CUST-042#ORDER#ORD-00042';
   ```

   **Performance: ~1-2ms** ✅

2. **Access Pattern 2: Get customer's order history**

   ```sql
   SELECT
     JSON_VALUE(json_document, '$._id') AS order_id,
     JSON_VALUE(json_document, '$.order_date') AS order_date,
     JSON_VALUE(json_document, '$.status') AS status,
     JSON_VALUE(json_document, '$.total' RETURNING NUMBER) AS total
   FROM ecommerce_single
   WHERE JSON_VALUE(json_document, '$._id') LIKE 'CUSTOMER#CUST-042#ORDER#%'
   ORDER BY JSON_VALUE(json_document, '$.order_date') DESC;
   ```

   **Performance: ~5-10ms** (depending on number of orders) ✅

3. **Access Pattern 3: Get customer profile**

   ```sql
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM ecommerce_single
   WHERE JSON_VALUE(json_document, '$._id') = 'CUSTOMER#CUST-042'
     AND JSON_VALUE(json_document, '$.type') = 'customer';
   ```

   **Performance: ~1-2ms** ✅

4. **Advanced: Customer profile with order summary**

   ```sql
   SELECT
     -- Customer info
     JSON_VALUE(c.json_document, '$.name') AS customer_name,
     JSON_VALUE(c.json_document, '$.email') AS email,
     JSON_VALUE(c.json_document, '$.loyalty_tier') AS tier,

     -- Order statistics (calculated from order documents)
     COUNT(o.json_document) AS total_orders,
     SUM(JSON_VALUE(o.json_document, '$.total' RETURNING NUMBER)) AS lifetime_value,
     MAX(JSON_VALUE(o.json_document, '$.order_date')) AS last_order_date
   FROM ecommerce_single c
   LEFT JOIN ecommerce_single o
     ON JSON_VALUE(o.json_document, '$._id') LIKE JSON_VALUE(c.json_document, '$._id') || '#ORDER#%'
   WHERE JSON_VALUE(c.json_document, '$._id') = 'CUSTOMER#CUST-042'
     AND JSON_VALUE(c.json_document, '$.type') = 'customer'
   GROUP BY
     JSON_VALUE(c.json_document, '$.name'),
     JSON_VALUE(c.json_document, '$.email'),
     JSON_VALUE(c.json_document, '$.loyalty_tier');
   ```

## Task 7: Anti-Patterns to Avoid

### What NOT to Do

**❌ Anti-Pattern 1: Mix Unrelated Data**

```json
// BAD: Mixing e-commerce orders with sensor data
{
  "_id": "CUSTOMER#CUST-456#ORDER#ORD-001",
  "type": "order",
  ...
}
{
  "_id": "SENSOR#temp001#reading",
  "type": "sensor_reading",
  ...
}
```

**Why bad:** No shared access patterns, violates Rick Houlihan's 2024 guidance

**✅ Solution:** Separate collections for unrelated domains

**❌ Anti-Pattern 2: Unbounded Arrays**

```json
// BAD: Customer with all orders embedded
{
  "_id": "CUSTOMER#CUST-456",
  "orders": [/* thousands of orders */]  // Will exceed 32MB!
}
```

**Why bad:** Document grows unbounded, exceeds OSON limit

**✅ Solution:** Use composite keys, store orders separately

**❌ Anti-Pattern 3: Denormalize Frequently Changing Data**

```json
// BAD: Denormalizing live inventory count
{
  "_id": "ORDER#ORD-001",
  "items": [
    {
      "product_id": "PROD-789",
      "inventory_count": 45  // Changes every second!
    }
  ]
}
```

**Why bad:** Write amplification, stale data

**✅ Solution:** Reference frequently changing data, or use extended reference with cached timestamp

**❌ Anti-Pattern 4: Index Overloading (Deprecated)**

Rick Houlihan's 2019 pattern (now deprecated in 2024):

```json
// DEPRECATED: Don't use generic GSI keys
{
  "PK": "CUSTOMER#456",
  "SK": "ORDER#001",
  "GSI1PK": "STATUS#shipped",
  "GSI1SK": "2024-11-18"
}
```

**Why deprecated:** Over-complicated, hard to maintain, poor readability

**✅ Solution:** Use clear, meaningful composite keys with descriptive names

## Summary

Congratulations! You have mastered the **Single Collection/Table Design pattern** - the most critical NoSQL pattern for Oracle JSON Collections.

### What You Learned

* ✅ The paradigm shift from entity-first to access pattern-first design
* ✅ Rick Houlihan's principle: "What is accessed together should be stored together"
* ✅ Composite key strategies (delimiter-based, hierarchical, date-based)
* ✅ Strategic denormalization framework (when to denormalize, when not to)
* ✅ Storing multiple entity types in single collection (polymorphic documents)
* ✅ Avoiding the 32MB OSON limit and LOB performance cliffs
* ✅ Measuring 10-20x query performance improvements
* ✅ Real-world e-commerce implementation
* ✅ Anti-patterns to avoid

### Key Performance Results

- **Single Collection: 1-2ms** average query time
- **Multi Collection: 20-30ms** average query time
- **Improvement: 10-20x faster**
- **P99 latency: 3ms vs 38ms** (more predictable)

### Design Checklist

Before implementing, ask yourself:

- [ ] What are my access patterns? (start here, not entities)
- [ ] What data is accessed together? (denormalize it)
- [ ] What data changes frequently? (don't denormalize it)
- [ ] Are my documents < 7,950 bytes? (target 80%+)
- [ ] Am I using composite keys for hierarchical relationships?
- [ ] Have I included a "type" discriminator for polymorphic documents?
- [ ] Did I measure performance? (always benchmark)

### Next Steps

In the remaining labs (4-10), you will learn:

- **Lab 4:** Computed Pattern & Pre-Aggregations
- **Lab 5:** Bucketing Pattern for Time-Series Data
- **Lab 6:** Polymorphic Pattern (Multiple Document Types)
- **Lab 7:** Advanced LOB Performance Optimization
- **Lab 8:** Indexing Strategies for JSON Collections
- **Lab 9:** Performance Testing & Benchmarking
- **Lab 10:** JSON Duality Views & Best Practices

**You are now equipped with the most powerful NoSQL design pattern!** 🚀

## Learn More

* [Rick Houlihan - DynamoDB Single Table Design (AWS re:Invent)](https://www.youtube.com/results?search_query=rick+houlihan+reinvent+2019)
* [Rick Houlihan - 2024 Clarifications on Single Table Design](https://www.youtube.com/watch?v=FvFFHiT0R7g)
* [MongoDB Single Collection Pattern](https://www.mongodb.com/docs/manual/data-modeling/)
* [Oracle JSON Collections Performance](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/performance-tuning-for-json.html)
* [OSON Binary Format](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/oson-format.html)

## Acknowledgements

* **Author** - Rick Houlihan, Solution Architect
* **Based on** - Rick Houlihan (AWS), MongoDB Engineering Team
* **Contributors** - Oracle JSON Development Team, Oracle LiveLabs Team
* **Last Updated By/Date** - Rick Houlihan, November 2024
