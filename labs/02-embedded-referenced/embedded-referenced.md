# Embedded vs Referenced Patterns

## Introduction

This lab teaches you the two fundamental patterns for modeling relationships in document databases: **Embedded** and **Referenced**. Understanding these patterns is critical because they form the foundation for all document modeling decisions.

You will learn when to embed related data directly in documents (denormalization) versus storing them separately with references (normalization), and how this choice dramatically impacts query performance, data consistency, and storage efficiency.

Estimated Time: 45 minutes

### Objectives

In this lab, you will:

* Understand the Embedded pattern (denormalized data)
* Understand the Referenced pattern (normalized data with foreign keys)
* Implement both patterns with e-commerce order data
* Compare query performance between embedded and referenced approaches
* Learn the decision criteria for choosing between patterns
* Understand the trade-offs (performance vs consistency vs storage)
* Prepare for the Single Collection pattern (Lab 3)

### Prerequisites

This lab assumes you have:

* Completed Lab 0: Setup
* Completed Lab 1: JSON Collections Fundamentals
* Access to Oracle Database as JSONUSER
* Understanding of JSON_VALUE, JSON_QUERY, and JSON_TABLE

## Task 1: Understand the Patterns

### The Fundamental Question

When modeling relationships in document databases, you must answer:

> **Should related data be stored together (embedded) or separately (referenced)?**

This is the **most important decision** in document modeling, and your answer should be based on **how the data is accessed**, not how it's logically organized.

### Embedded Pattern (Denormalized)

**Definition:** Related data is stored directly within the same document.

**Example: Order with Embedded Items**
```json
{
  "_id": "ORD-001",
  "order_date": "2024-11-15",
  "customer_id": "CUST-456",
  "customer_name": "Alice Johnson",
  "total": 189.97,
  "items": [
    {
      "product_id": "PROD-123",
      "product_name": "Wireless Mouse",
      "price": 34.99,
      "quantity": 2
    },
    {
      "product_id": "PROD-456",
      "product_name": "Keyboard",
      "price": 119.99,
      "quantity": 1
    }
  ]
}
```

**Characteristics:**
- ✅ All related data in one document
- ✅ Single query retrieves everything
- ✅ Extremely fast reads (no joins)
- ❌ Data duplication (uses more storage)
- ❌ Updates must propagate to all copies

### Referenced Pattern (Normalized)

**Definition:** Related data is stored in separate documents, linked by identifiers.

**Example: Order with Referenced Items**

**Order Document:**
```json
{
  "_id": "ORD-001",
  "order_date": "2024-11-15",
  "customer_id": "CUST-456",
  "total": 189.97,
  "item_ids": ["ITEM-001", "ITEM-002"]
}
```

**Order Item Documents:**
```json
{
  "_id": "ITEM-001",
  "order_id": "ORD-001",
  "product_id": "PROD-123",
  "price": 34.99,
  "quantity": 2
}
```
```json
{
  "_id": "ITEM-002",
  "order_id": "ORD-001",
  "product_id": "PROD-456",
  "price": 119.99,
  "quantity": 1
}
```

**Characteristics:**
- ✅ No data duplication
- ✅ Easy to update individual items
- ✅ Maintains referential integrity
- ❌ Requires multiple queries or joins
- ❌ Slower reads (application-level assembly)

### The Decision Matrix

| Factor | Use Embedded | Use Referenced |
|--------|-------------|----------------|
| **Access Pattern** | Data always accessed together | Data accessed independently |
| **Update Frequency** | Read-heavy, infrequent updates | Write-heavy, frequent updates |
| **Data Size** | Small, bounded arrays (< 100 items) | Large, unbounded arrays |
| **Consistency** | Eventual consistency acceptable | Strong consistency required |
| **Relationships** | 1-to-few (under 100 related items) | 1-to-many (over 100 related items) |

**Key Principle:**
> **"What is accessed together should be stored together."** - Rick Houlihan

## Task 2: Implement Embedded Pattern

Let's implement an e-commerce order system using the embedded pattern.

### Step 1: Create Orders Collection (Embedded)

1. Create the collection:

   ```sql
   CREATE TABLE orders_embedded (
     id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
     json_document JSON,
     created_on TIMESTAMP DEFAULT SYSTIMESTAMP,
     last_modified TIMESTAMP DEFAULT SYSTIMESTAMP
   );
   ```

2. Create index on order ID:

   ```sql
   CREATE INDEX idx_orders_emb_id
   ON orders_embedded (JSON_VALUE(json_document, '$._id'));
   ```

3. Create index on customer ID:

   ```sql
   CREATE INDEX idx_orders_emb_customer
   ON orders_embedded (JSON_VALUE(json_document, '$.customer_id'));
   ```

### Step 2: Insert Embedded Orders

1. Insert an order with embedded items and customer info:

   ```sql
   INSERT INTO orders_embedded (json_document) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ORD-EMB-001',
       'order_date' VALUE '2024-11-15T10:30:00',
       'status' VALUE 'shipped',
       'customer_id' VALUE 'CUST-456',
       'customer' VALUE JSON_OBJECT(
         'name' VALUE 'Alice Johnson',
         'email' VALUE 'alice@email.com',
         'phone' VALUE '+1-555-0123'
       ),
       'shipping_address' VALUE JSON_OBJECT(
         'street' VALUE '123 Main Street',
         'city' VALUE 'San Francisco',
         'state' VALUE 'CA',
         'zip' VALUE '94105'
       ),
       'items' VALUE JSON_ARRAY(
         JSON_OBJECT(
           'product_id' VALUE 'PROD-001',
           'product_name' VALUE 'Wireless Bluetooth Headphones',
           'price' VALUE 79.99,
           'quantity' VALUE 1,
           'subtotal' VALUE 79.99
         ),
         JSON_OBJECT(
           'product_id' VALUE 'PROD-002',
           'product_name' VALUE 'Ergonomic Wireless Mouse',
           'price' VALUE 34.99,
           'quantity' VALUE 2,
           'subtotal' VALUE 69.98
         )
       ),
       'subtotal' VALUE 149.97,
       'tax' VALUE 12.00,
       'shipping' VALUE 7.99,
       'total' VALUE 169.96
     )
   );
   ```

2. Insert more embedded orders:

   ```sql
   INSERT INTO orders_embedded (json_document)
   SELECT
     JSON_OBJECT(
       '_id' VALUE 'ORD-EMB-' || LPAD(level, 3, '0'),
       'order_date' VALUE SYSTIMESTAMP - level,
       'status' VALUE CASE MOD(level, 3)
         WHEN 0 THEN 'delivered'
         WHEN 1 THEN 'shipped'
         ELSE 'processing'
       END,
       'customer_id' VALUE 'CUST-' || LPAD(MOD(level, 10) + 1, 3, '0'),
       'customer' VALUE JSON_OBJECT(
         'name' VALUE 'Customer ' || MOD(level, 10),
         'email' VALUE 'customer' || MOD(level, 10) || '@email.com'
       ),
       'items' VALUE JSON_ARRAY(
         JSON_OBJECT(
           'product_id' VALUE 'PROD-' || LPAD(MOD(level * 3, 20) + 1, 3, '0'),
           'product_name' VALUE 'Product ' || MOD(level * 3, 20),
           'price' VALUE 29.99 + (level * 5),
           'quantity' VALUE MOD(level, 3) + 1,
           'subtotal' VALUE (29.99 + (level * 5)) * (MOD(level, 3) + 1)
         )
       ),
       'total' VALUE (29.99 + (level * 5)) * (MOD(level, 3) + 1) * 1.08
     )
   FROM dual
   CONNECT BY level <= 100;

   COMMIT;
   ```

3. Verify the data:

   ```sql
   SELECT COUNT(*) FROM orders_embedded;
   ```

   Expected: 101 orders

### Step 3: Query Embedded Orders

1. Retrieve complete order with one query:

   ```sql
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM orders_embedded
   WHERE JSON_VALUE(json_document, '$._id') = 'ORD-EMB-001';
   ```

   **Notice:** All order data (customer, items, totals) returned in a **single query**!

2. Find customer's orders with all details:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$._id') AS order_id,
     JSON_VALUE(json_document, '$.order_date') AS order_date,
     JSON_VALUE(json_document, '$.customer.name') AS customer_name,
     JSON_VALUE(json_document, '$.total' RETURNING NUMBER) AS total
   FROM orders_embedded
   WHERE JSON_VALUE(json_document, '$.customer_id') = 'CUST-456';
   ```

3. Expand order items using JSON_TABLE:

   ```sql
   SELECT
     JSON_VALUE(o.json_document, '$._id') AS order_id,
     JSON_VALUE(o.json_document, '$.customer.name') AS customer_name,
     items.product_name,
     items.quantity,
     items.price,
     items.subtotal
   FROM orders_embedded o,
     JSON_TABLE(o.json_document, '$.items[*]'
       COLUMNS (
         product_name VARCHAR2(100) PATH '$.product_name',
         quantity NUMBER PATH '$.quantity',
         price NUMBER PATH '$.price',
         subtotal NUMBER PATH '$.subtotal'
       )
     ) items
   WHERE JSON_VALUE(o.json_document, '$._id') = 'ORD-EMB-001';
   ```

4. Calculate total revenue by product (embedded):

   ```sql
   SELECT
     items.product_id,
     items.product_name,
     SUM(items.quantity) AS total_quantity,
     SUM(items.subtotal) AS total_revenue
   FROM orders_embedded o,
     JSON_TABLE(o.json_document, '$.items[*]'
       COLUMNS (
         product_id VARCHAR2(20) PATH '$.product_id',
         product_name VARCHAR2(100) PATH '$.product_name',
         quantity NUMBER PATH '$.quantity',
         subtotal NUMBER PATH '$.subtotal'
       )
     ) items
   GROUP BY items.product_id, items.product_name
   ORDER BY total_revenue DESC;
   ```

## Task 3: Implement Referenced Pattern

Now let's implement the same scenario using the referenced pattern (normalized).

### Step 1: Create Referenced Collections

1. Create orders collection (referenced):

   ```sql
   CREATE TABLE orders_referenced (
     id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
     json_document JSON,
     created_on TIMESTAMP DEFAULT SYSTIMESTAMP
   );
   ```

2. Create order items collection:

   ```sql
   CREATE TABLE order_items_referenced (
     id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
     json_document JSON,
     created_on TIMESTAMP DEFAULT SYSTIMESTAMP
   );
   ```

3. Create customers collection:

   ```sql
   CREATE TABLE customers_referenced (
     id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
     json_document JSON,
     created_on TIMESTAMP DEFAULT SYSTIMESTAMP
   );
   ```

4. Create indexes:

   ```sql
   CREATE INDEX idx_orders_ref_id
   ON orders_referenced (JSON_VALUE(json_document, '$._id'));

   CREATE INDEX idx_orders_ref_customer
   ON orders_referenced (JSON_VALUE(json_document, '$.customer_id'));

   CREATE INDEX idx_items_ref_order
   ON order_items_referenced (JSON_VALUE(json_document, '$.order_id'));

   CREATE INDEX idx_customers_ref_id
   ON customers_referenced (JSON_VALUE(json_document, '$._id'));
   ```

### Step 2: Insert Referenced Data

1. Insert customers:

   ```sql
   INSERT INTO customers_referenced (json_document) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'CUST-456',
       'name' VALUE 'Alice Johnson',
       'email' VALUE 'alice@email.com',
       'phone' VALUE '+1-555-0123',
       'addresses' VALUE JSON_ARRAY(
         JSON_OBJECT(
           'type' VALUE 'shipping',
           'street' VALUE '123 Main Street',
           'city' VALUE 'San Francisco',
           'state' VALUE 'CA',
           'zip' VALUE '94105'
         )
       )
     )
   );

   COMMIT;
   ```

2. Insert orders (without embedded items or customer details):

   ```sql
   INSERT INTO orders_referenced (json_document) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ORD-REF-001',
       'order_date' VALUE '2024-11-15T10:30:00',
       'status' VALUE 'shipped',
       'customer_id' VALUE 'CUST-456',
       'subtotal' VALUE 149.97,
       'tax' VALUE 12.00,
       'shipping' VALUE 7.99,
       'total' VALUE 169.96
     )
   );
   ```

3. Insert order items (separate documents):

   ```sql
   INSERT INTO order_items_referenced (json_document)
   VALUES
   (JSON_OBJECT(
     '_id' VALUE 'ITEM-001',
     'order_id' VALUE 'ORD-REF-001',
     'product_id' VALUE 'PROD-001',
     'product_name' VALUE 'Wireless Bluetooth Headphones',
     'price' VALUE 79.99,
     'quantity' VALUE 1,
     'subtotal' VALUE 79.99
   )),
   (JSON_OBJECT(
     '_id' VALUE 'ITEM-002',
     'order_id' VALUE 'ORD-REF-001',
     'product_id' VALUE 'PROD-002',
     'product_name' VALUE 'Ergonomic Wireless Mouse',
     'price' VALUE 34.99,
     'quantity' VALUE 2,
     'subtotal' VALUE 69.98
   ));

   COMMIT;
   ```

4. Insert more referenced data:

   ```sql
   -- Insert more customers
   INSERT INTO customers_referenced (json_document)
   SELECT
     JSON_OBJECT(
       '_id' VALUE 'CUST-' || LPAD(level, 3, '0'),
       'name' VALUE 'Customer ' || level,
       'email' VALUE 'customer' || level || '@email.com'
     )
   FROM dual
   CONNECT BY level <= 10;

   -- Insert more orders
   INSERT INTO orders_referenced (json_document)
   SELECT
     JSON_OBJECT(
       '_id' VALUE 'ORD-REF-' || LPAD(level, 3, '0'),
       'order_date' VALUE SYSTIMESTAMP - level,
       'status' VALUE 'shipped',
       'customer_id' VALUE 'CUST-' || LPAD(MOD(level, 10) + 1, 3, '0'),
       'total' VALUE (29.99 + (level * 5)) * 1.08
     )
   FROM dual
   CONNECT BY level <= 100;

   -- Insert more order items
   INSERT INTO order_items_referenced (json_document)
   SELECT
     JSON_OBJECT(
       '_id' VALUE 'ITEM-' || LPAD(level, 4, '0'),
       'order_id' VALUE 'ORD-REF-' || LPAD(level, 3, '0'),
       'product_id' VALUE 'PROD-' || LPAD(MOD(level, 20) + 1, 3, '0'),
       'product_name' VALUE 'Product ' || MOD(level, 20),
       'price' VALUE 29.99 + (level * 5),
       'quantity' VALUE MOD(level, 3) + 1,
       'subtotal' VALUE (29.99 + (level * 5)) * (MOD(level, 3) + 1)
     )
   FROM dual
   CONNECT BY level <= 100;

   COMMIT;
   ```

### Step 3: Query Referenced Orders (Requires Multiple Queries or Joins)

1. Retrieve order (first query):

   ```sql
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM orders_referenced
   WHERE JSON_VALUE(json_document, '$._id') = 'ORD-REF-001';
   ```

   **Notice:** This returns only the order header - no customer details, no items!

2. Retrieve order items (second query):

   ```sql
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM order_items_referenced
   WHERE JSON_VALUE(json_document, '$.order_id') = 'ORD-REF-001';
   ```

3. Retrieve customer (third query):

   ```sql
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM customers_referenced
   WHERE JSON_VALUE(json_document, '$._id') = 'CUST-456';
   ```

   **Notice:** It took **3 separate queries** to get the same data that embedded pattern returned in **1 query**!

4. Alternatively, use SQL joins (slower):

   ```sql
   SELECT
     JSON_VALUE(o.json_document, '$._id') AS order_id,
     JSON_VALUE(o.json_document, '$.order_date') AS order_date,
     JSON_VALUE(c.json_document, '$.name') AS customer_name,
     JSON_VALUE(i.json_document, '$.product_name') AS product,
     JSON_VALUE(i.json_document, '$.quantity' RETURNING NUMBER) AS quantity,
     JSON_VALUE(i.json_document, '$.subtotal' RETURNING NUMBER) AS subtotal
   FROM orders_referenced o
   JOIN customers_referenced c
     ON JSON_VALUE(o.json_document, '$.customer_id') = JSON_VALUE(c.json_document, '$._id')
   JOIN order_items_referenced i
     ON JSON_VALUE(o.json_document, '$._id') = JSON_VALUE(i.json_document, '$.order_id')
   WHERE JSON_VALUE(o.json_document, '$._id') = 'ORD-REF-001';
   ```

## Task 4: Performance Comparison

Now let's measure the performance difference between embedded and referenced patterns.

### Step 1: Create Benchmark Script

1. Create a test to measure query latency:

   ```sql
   -- Clear metrics
   TRUNCATE TABLE performance_metrics;

   -- Benchmark EMBEDDED pattern (single query)
   DECLARE
     v_start TIMESTAMP;
     v_end TIMESTAMP;
     v_iterations CONSTANT NUMBER := 1000;
     v_order_id VARCHAR2(20);
   BEGIN
     FOR i IN 1..v_iterations LOOP
       v_start := SYSTIMESTAMP;
       v_order_id := 'ORD-EMB-' || LPAD(MOD(i, 100) + 1, 3, '0');

       -- Single query retrieves everything
       SELECT
         JSON_VALUE(json_document, '$._id'),
         JSON_VALUE(json_document, '$.customer.name'),
         JSON_QUERY(json_document, '$.items')
       INTO v_order_id, v_order_id, v_order_id
       FROM orders_embedded
       WHERE JSON_VALUE(json_document, '$._id') = v_order_id;

       v_end := SYSTIMESTAMP;

       INSERT INTO performance_metrics
       VALUES (
         'ORDER_RETRIEVAL',
         'EMBEDDED',
         'SINGLE_QUERY',
         i,
         EXTRACT(SECOND FROM (v_end - v_start)) * 1000,
         NULL, NULL, NULL,
         SYSTIMESTAMP,
         'Complete order with customer and items'
       );
     END LOOP;
     COMMIT;
   END;
   /

   -- Benchmark REFERENCED pattern (multiple queries)
   DECLARE
     v_start TIMESTAMP;
     v_end TIMESTAMP;
     v_iterations CONSTANT NUMBER := 1000;
     v_order_id VARCHAR2(20);
     v_customer_id VARCHAR2(20);
   BEGIN
     FOR i IN 1..v_iterations LOOP
       v_start := SYSTIMESTAMP;
       v_order_id := 'ORD-REF-' || LPAD(MOD(i, 100) + 1, 3, '0');

       -- Query 1: Get order
       SELECT JSON_VALUE(json_document, '$.customer_id')
       INTO v_customer_id
       FROM orders_referenced
       WHERE JSON_VALUE(json_document, '$._id') = v_order_id;

       -- Query 2: Get customer (simulated with another select)
       SELECT JSON_VALUE(json_document, '$.name')
       INTO v_customer_id
       FROM customers_referenced
       WHERE JSON_VALUE(json_document, '$._id') = v_customer_id;

       -- Query 3: Get items (simulated with count)
       SELECT COUNT(*)
       INTO i
       FROM order_items_referenced
       WHERE JSON_VALUE(json_document, '$.order_id') = v_order_id;

       v_end := SYSTIMESTAMP;

       INSERT INTO performance_metrics
       VALUES (
         'ORDER_RETRIEVAL',
         'REFERENCED',
         'MULTIPLE_QUERIES',
         i,
         EXTRACT(SECOND FROM (v_end - v_start)) * 1000,
         NULL, NULL, NULL,
         SYSTIMESTAMP,
         '3 queries: order + customer + items'
       );
     END LOOP;
     COMMIT;
   END;
   /
   ```

2. Analyze results:

   ```sql
   SELECT
     pattern_name,
     COUNT(*) AS iterations,
     ROUND(AVG(execution_time_ms), 2) AS avg_ms,
     ROUND(MIN(execution_time_ms), 2) AS min_ms,
     ROUND(MAX(execution_time_ms), 2) AS max_ms,
     ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_time_ms), 2) AS p95_ms,
     ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY execution_time_ms), 2) AS p99_ms
   FROM performance_metrics
   WHERE test_id = 'ORDER_RETRIEVAL'
   GROUP BY pattern_name
   ORDER BY avg_ms;
   ```

   **Expected Results:**
   ```
   PATTERN_NAME   ITERATIONS   AVG_MS   MIN_MS   MAX_MS   P95_MS   P99_MS
   ------------   ----------   ------   ------   ------   ------   ------
   EMBEDDED             1000     1.20     0.80     3.50     1.80     2.20
   REFERENCED           1000     4.50     3.20    12.00     6.50     8.90
   ```

   **Analysis:**
   - Embedded pattern is **3-4x faster** for retrieving complete orders
   - Referenced pattern requires 3 queries, resulting in higher latency
   - P95/P99 latencies are more predictable with embedded pattern

### Step 2: Measure Storage Efficiency

1. Compare storage usage:

   ```sql
   SELECT
     'EMBEDDED' AS pattern,
     COUNT(*) AS document_count,
     SUM(LENGTHB(json_document)) AS total_bytes,
     ROUND(AVG(LENGTHB(json_document)), 0) AS avg_bytes,
     MAX(LENGTHB(json_document)) AS max_bytes
   FROM orders_embedded
   UNION ALL
   SELECT
     'REFERENCED (orders)',
     COUNT(*),
     SUM(LENGTHB(json_document)),
     ROUND(AVG(LENGTHB(json_document)), 0),
     MAX(LENGTHB(json_document))
   FROM orders_referenced
   UNION ALL
   SELECT
     'REFERENCED (items)',
     COUNT(*),
     SUM(LENGTHB(json_document)),
     ROUND(AVG(LENGTHB(json_document)), 0),
     MAX(LENGTHB(json_document))
   FROM order_items_referenced
   UNION ALL
   SELECT
     'REFERENCED (customers)',
     COUNT(*),
     SUM(LENGTHB(json_document)),
     ROUND(AVG(LENGTHB(json_document)), 0),
     MAX(LENGTHB(json_document))
   FROM customers_referenced;
   ```

2. Calculate total storage comparison:

   ```sql
   SELECT
     'EMBEDDED' AS pattern,
     SUM(LENGTHB(json_document)) AS total_bytes
   FROM orders_embedded
   UNION ALL
   SELECT
     'REFERENCED (total)',
     (SELECT SUM(LENGTHB(json_document)) FROM orders_referenced) +
     (SELECT SUM(LENGTHB(json_document)) FROM order_items_referenced) +
     (SELECT SUM(LENGTHB(json_document)) FROM customers_referenced)
   FROM dual;
   ```

   **Insight:** Embedded pattern uses more storage due to data duplication, but storage is cheap compared to query performance.

## Task 5: Decision Criteria

### When to Use Embedded Pattern

**Use embedded when:**

1. ✅ **Data is always accessed together**
   - Example: Order with items, customer info, shipping address

2. ✅ **Bounded, small arrays** (< 100 items)
   - Example: Order items (typically < 50 items per order)

3. ✅ **Read-heavy workload**
   - Example: E-commerce order history, invoices

4. ✅ **Performance is critical**
   - Example: Real-time dashboards, customer-facing APIs

5. ✅ **Data changes infrequently**
   - Example: Historical orders (immutable after shipping)

**Real-world examples:**
- E-commerce orders with items
- Blog posts with comments (< 100 comments)
- User profiles with preferences
- Events with attendee lists (< 100 attendees)

### When to Use Referenced Pattern

**Use referenced when:**

1. ✅ **Data is accessed independently**
   - Example: Product catalog (products queried separately from orders)

2. ✅ **Unbounded, large arrays** (over 100 items)
   - Example: Social media followers (millions of followers)

3. ✅ **Write-heavy workload**
   - Example: Real-time analytics, frequently updated data

4. ✅ **Strong consistency required**
   - Example: Financial transactions, inventory management

5. ✅ **Many-to-many relationships**
   - Example: Users and groups, products and categories

**Real-world examples:**
- Product catalog (products referenced by many orders)
- Social media followers (millions of users)
- Inventory management (frequent updates)
- Many-to-many relationships (users ↔ groups)

### The Hybrid Approach (Best Practice)

In practice, most applications use **both patterns**:

**Example: E-commerce System**

**Embedded:**
- Order → Items (bounded, always accessed together)
- Order → Shipping address (small, accessed together)
- Order → Billing info (small, accessed together)

**Referenced:**
- Order → Customer (customer accessed independently)
- Order Items → Product (product info changes frequently)
- Customer → Orders (unbounded list of orders)

**Next Lab Preview:**

In **Lab 3 (Single Collection/Table Design)**, you will learn how to take the embedded pattern to the next level by storing **multiple entity types** in a single collection using **composite keys** and **strategic denormalization**. This is the key to avoiding LOB performance cliffs and achieving 10-20x query performance improvements!

## Task 6: Update Patterns

Understanding update behavior is critical for pattern selection.

### Embedded Pattern Updates

1. Update embedded customer name (must update all orders):

   ```sql
   -- Update customer name in all orders
   UPDATE orders_embedded
   SET json_document = JSON_MERGEPATCH(
     json_document,
     '{"customer": {"name": "Alice Smith-Johnson"}}'
   )
   WHERE JSON_VALUE(json_document, '$.customer_id') = 'CUST-456';

   COMMIT;
   ```

   **Impact:** If customer has 100 orders, you must update 100 documents!

### Referenced Pattern Updates

1. Update customer name (single update):

   ```sql
   -- Update customer name in one place
   UPDATE customers_referenced
   SET json_document = JSON_MERGEPATCH(
     json_document,
     '{"name": "Alice Smith-Johnson"}'
   )
   WHERE JSON_VALUE(json_document, '$._id') = 'CUST-456';

   COMMIT;
   ```

   **Impact:** Only 1 document updated, all orders automatically reflect new name on next query.

### The Trade-Off

**Embedded Pattern:**
- ❌ Updates affect multiple documents (write amplification)
- ✅ Reads are fast (no joins)
- ✅ Historical accuracy (order shows name at time of order)

**Referenced Pattern:**
- ✅ Updates affect single document
- ❌ Reads require joins (slower)
- ❌ No historical accuracy (order always shows current name)

**Best Practice for Embedded:**

When embedding customer data in orders, include a **snapshot timestamp**:

```json
{
  "customer": {
    "name": "Alice Johnson",
    "email": "alice@email.com",
    "snapshot_date": "2024-11-15"
  }
}
```

This indicates the data is a historical snapshot, not a live reference.

## Summary

In this lab, you learned:

* ✅ The two fundamental patterns: Embedded and Referenced
* ✅ Embedded pattern stores related data together (denormalized)
* ✅ Referenced pattern stores data separately with foreign keys (normalized)
* ✅ Embedded pattern is 3-4x faster for reads but uses more storage
* ✅ Decision criteria based on access patterns, array size, and update frequency
* ✅ Most applications use hybrid approach (both patterns)
* ✅ Understanding trade-offs: performance vs consistency vs storage

**Key Takeaways:**

1. **"What is accessed together should be stored together"** - Design for queries, not entities
2. **Embedded is faster** - Single query vs multiple queries
3. **Referenced is more flexible** - Better for writes and unbounded relationships
4. **Storage is cheap, compute is expensive** - Denormalize for performance
5. **Use hybrid approach** - Apply both patterns where appropriate

You are now ready for **Lab 3: Single Collection/Table Design**, where you will learn how to combine multiple entity types in a single collection using composite keys and strategic denormalization - the most powerful NoSQL design pattern!

## Learn More

* [MongoDB Embedded vs Referenced Patterns](https://www.mongodb.com/docs/manual/data-modeling/)
* [DynamoDB One-to-Many Relationships](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-modeling-nosql.html)
* [Oracle JSON Collections Performance](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/performance-tuning-for-json.html)
* [Rick Houlihan - Data Modeling with DynamoDB](https://www.youtube.com/results?search_query=rick+houlihan+data+modeling)

## Acknowledgements

* **Author** - Rick Houlihan, Solution Architect
* **Contributors** - Oracle JSON Development Team, Oracle LiveLabs Team
* **Last Updated By/Date** - Rick Houlihan, November 2024
