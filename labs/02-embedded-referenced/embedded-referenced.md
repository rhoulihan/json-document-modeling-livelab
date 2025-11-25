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
* Access to Oracle AI Database 26ai as JSONUSER
* Understanding of JSON_VALUE, JSON_QUERY, and JSON_TABLE

## Task 1: Understand the Patterns

### The Fundamental Question

When modeling relationships in document databases, you must answer:

> **Should related data be stored together (embedded) or separately (referenced)?**

This is a **key decision** in document modeling, and your answer should be based on **how the data is accessed**, not how it's logically organized.

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
- All related data in one document
- Single query retrieves everything
- Extremely fast reads (no joins)
- Data duplication (uses more storage)
- Updates must propagate to all copies

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
- No data duplication
- Easy to update individual items
- Maintains referential integrity
- Requires multiple queries or joins
- Slower reads (application-level assembly)

### The Decision Matrix

| Factor | Use Embedded | Use Referenced |
|--------|-------------|----------------|
| **Access Pattern** | Data always accessed together | Data accessed independently |
| **Update Frequency** | Read-heavy, infrequent updates | Write-heavy, frequent updates |
| **Data Size** | Small, bounded arrays (< 100 items) | Large, unbounded arrays |
| **Consistency** | Eventual consistency acceptable | Strong consistency required |
| **Relationships** | 1-to-few (under 100 related items) | 1-to-many (over 100 related items) |

**Key Principle:**
> **"What is accessed together should be stored together."**

## Task 2: Implement Embedded Pattern

Let's implement an e-commerce order system using the embedded pattern.

### Step 1: Create Orders Collection (Embedded)

1. Create the collection:

   ```sql
   CREATE JSON COLLECTION TABLE orders_embedded;
   ```

2. Create index on order ID:

   ```sql
   CREATE INDEX idx_orders_emb_id
   ON orders_embedded (JSON_VALUE(data, '$._id'));
   ```

3. Create index on customer ID:

   ```sql
   CREATE INDEX idx_orders_emb_customer
   ON orders_embedded (JSON_VALUE(data, '$.customer_id'));
   ```

### Step 2: Insert Embedded Orders

1. Insert an order with embedded items and customer info:

   ```sql
   INSERT INTO orders_embedded (data) VALUES (
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

   COMMIT;
   ```

   Expected output:
   ```
   1 row created.

   Commit complete.
   ```

   **MongoDB API Approach:**

   ```javascript
   // Connect to Oracle using MongoDB API
   // mongosh "mongodb://jsonuser:WelcomeJson%23123@localhost:27017/jsonuser?authMechanism=PLAIN&authSource=$external&tls=false"

   use jsonuser

   // Insert embedded order document
   db.orders_embedded.insertOne({
     _id: "ORD-EMB-001",
     order_date: "2024-11-15T10:30:00",
     status: "shipped",
     customer_id: "CUST-456",
     customer: {
       name: "Alice Johnson",
       email: "alice@email.com",
       phone: "+1-555-0123"
     },
     shipping_address: {
       street: "123 Main Street",
       city: "San Francisco",
       state: "CA",
       zip: "94105"
     },
     items: [
       {
         product_id: "PROD-001",
         product_name: "Wireless Bluetooth Headphones",
         price: 79.99,
         quantity: 1,
         subtotal: 79.99
       },
       {
         product_id: "PROD-002",
         product_name: "Ergonomic Wireless Mouse",
         price: 34.99,
         quantity: 2,
         subtotal: 69.98
       }
     ],
     subtotal: 149.97,
     tax: 12.00,
     shipping: 7.99,
     total: 169.96
   })
   ```

   > **MongoDB API**: Embedded pattern is natural in MongoDB - nested documents and arrays are first-class citizens.

   **REST API Approach:**

   ```bash
   # Insert embedded order via ORDS SODA REST API
   # Prerequisite: Schema must be REST-enabled (EXEC ORDS.ENABLE_SCHEMA;)
   curl -X POST \
     "http://localhost:8080/ords/jsonuser/soda/latest/orders_embedded" \
     -H "Content-Type: application/json" \
     -d '{
       "_id": "ORD-EMB-001",
       "order_date": "2024-11-15T10:30:00",
       "status": "shipped",
       "customer_id": "CUST-456",
       "customer": {
         "name": "Alice Johnson",
         "email": "alice@email.com",
         "phone": "+1-555-0123"
       },
       "items": [
         {
           "product_id": "PROD-001",
           "product_name": "Wireless Bluetooth Headphones",
           "price": 79.99,
           "quantity": 1,
           "subtotal": 79.99
         }
       ],
       "total": 169.96
     }'
   ```

   **Python Approach:**

   ```python
   import oracledb
   import json

   connection = oracledb.connect(
       user="jsonuser",
       password="WelcomeJson#123",
       dsn="localhost:1522/myatp_low"
   )

   cursor = connection.cursor()

   # Embedded order with nested customer and items
   embedded_order = {
       "_id": "ORD-EMB-001",
       "order_date": "2024-11-15T10:30:00",
       "status": "shipped",
       "customer_id": "CUST-456",
       "customer": {
           "name": "Alice Johnson",
           "email": "alice@email.com"
       },
       "items": [
           {"product_id": "PROD-001", "product_name": "Headphones", "price": 79.99, "quantity": 1}
       ],
       "total": 169.96
   }

   cursor.execute(
       "INSERT INTO orders_embedded (data) VALUES (:1)",
       [json.dumps(embedded_order)]
   )
   connection.commit()
   print("1 row created.")
   connection.close()
   ```

2. Insert more embedded orders:

   ```sql
   -- Insert additional orders one at a time
   INSERT INTO orders_embedded (data) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ORD-EMB-002',
       'order_date' VALUE SYSTIMESTAMP - 1,
       'status' VALUE 'delivered',
       'customer_id' VALUE 'CUST-001',
       'customer' VALUE JSON_OBJECT('name' VALUE 'Customer 1', 'email' VALUE 'customer1@email.com'),
       'items' VALUE JSON_ARRAY(
         JSON_OBJECT('product_id' VALUE 'PROD-003', 'product_name' VALUE 'Product 3', 'price' VALUE 34.99, 'quantity' VALUE 2, 'subtotal' VALUE 69.98)
       ),
       'total' VALUE 75.58
     )
   );

   INSERT INTO orders_embedded (data) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ORD-EMB-003',
       'order_date' VALUE SYSTIMESTAMP - 2,
       'status' VALUE 'shipped',
       'customer_id' VALUE 'CUST-002',
       'customer' VALUE JSON_OBJECT('name' VALUE 'Customer 2', 'email' VALUE 'customer2@email.com'),
       'items' VALUE JSON_ARRAY(
         JSON_OBJECT('product_id' VALUE 'PROD-004', 'product_name' VALUE 'Product 4', 'price' VALUE 44.99, 'quantity' VALUE 1, 'subtotal' VALUE 44.99)
       ),
       'total' VALUE 48.59
     )
   );

   INSERT INTO orders_embedded (data) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ORD-EMB-004',
       'order_date' VALUE SYSTIMESTAMP - 3,
       'status' VALUE 'processing',
       'customer_id' VALUE 'CUST-003',
       'customer' VALUE JSON_OBJECT('name' VALUE 'Customer 3', 'email' VALUE 'customer3@email.com'),
       'items' VALUE JSON_ARRAY(
         JSON_OBJECT('product_id' VALUE 'PROD-005', 'product_name' VALUE 'Product 5', 'price' VALUE 54.99, 'quantity' VALUE 3, 'subtotal' VALUE 164.97)
       ),
       'total' VALUE 178.17
     )
   );

   COMMIT;
   ```

3. Verify the data:

   ```sql
   SELECT COUNT(*) FROM orders_embedded;
   ```

   Expected: 4 orders

### Step 3: Query Embedded Orders

1. Retrieve complete order with one query:

   ```sql
   SELECT JSON_SERIALIZE(data PRETTY)
   FROM orders_embedded
   WHERE JSON_VALUE(data, '$._id') = 'ORD-EMB-001';
   ```

   **Notice:** All order data (customer, items, totals) returned in a **single query**!

2. Find customer's orders with all details:

   ```sql
   SELECT
     JSON_VALUE(data, '$._id') AS order_id,
     JSON_VALUE(data, '$.order_date') AS order_date,
     JSON_VALUE(data, '$.customer.name') AS customer_name,
     JSON_VALUE(data, '$.total' RETURNING NUMBER) AS total
   FROM orders_embedded
   WHERE JSON_VALUE(data, '$.customer_id') = 'CUST-456';
   ```

   **Expected output:**
   ```
   ORDER_ID       ORDER_DATE             CUSTOMER_NAME     TOTAL
   -------------- ---------------------- ---------------- -------
   ORD-EMB-001    2024-11-15T10:30:00    Alice Johnson    169.96
   ```

   **Performance:** Single query returns complete order in **~2ms** (no joins!)

3. Expand order items using JSON_TABLE:

   ```sql
   SELECT
     JSON_VALUE(o.data, '$._id') AS order_id,
     JSON_VALUE(o.data, '$.customer.name') AS customer_name,
     items.product_name,
     items.quantity,
     items.price,
     items.subtotal
   FROM orders_embedded o,
     JSON_TABLE(o.data, '$.items[*]'
       COLUMNS (
         product_name VARCHAR2(100) PATH '$.product_name',
         quantity NUMBER PATH '$.quantity',
         price NUMBER PATH '$.price',
         subtotal NUMBER PATH '$.subtotal'
       )
     ) items
   WHERE JSON_VALUE(o.data, '$._id') = 'ORD-EMB-001';
   ```

4. Calculate total revenue by product (embedded):

   ```sql
   SELECT
     items.product_id,
     items.product_name,
     SUM(items.quantity) AS total_quantity,
     SUM(items.subtotal) AS total_revenue
   FROM orders_embedded o,
     JSON_TABLE(o.data, '$.items[*]'
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
   CREATE JSON COLLECTION TABLE orders_referenced;
   ```

2. Create order items collection:

   ```sql
   CREATE JSON COLLECTION TABLE order_items_referenced;
   ```

3. Create customers collection:

   ```sql
   CREATE JSON COLLECTION TABLE customers_referenced;
   ```

4. Create indexes:

   ```sql
   CREATE INDEX idx_orders_ref_id
   ON orders_referenced (JSON_VALUE(data, '$._id'));

   CREATE INDEX idx_orders_ref_customer
   ON orders_referenced (JSON_VALUE(data, '$.customer_id'));

   CREATE INDEX idx_items_ref_order
   ON order_items_referenced (JSON_VALUE(data, '$.order_id'));

   CREATE INDEX idx_customers_ref_id
   ON customers_referenced (JSON_VALUE(data, '$._id'));
   ```

### Step 2: Insert Referenced Data

1. Insert customers:

   ```sql
   INSERT INTO customers_referenced (data) VALUES (
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
   INSERT INTO orders_referenced (data) VALUES (
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

   COMMIT;
   ```

3. Insert order items (separate documents):

   ```sql
   -- Insert item 1
   INSERT INTO order_items_referenced (data) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ITEM-001',
       'order_id' VALUE 'ORD-REF-001',
       'product_id' VALUE 'PROD-001',
       'product_name' VALUE 'Wireless Bluetooth Headphones',
       'price' VALUE 79.99,
       'quantity' VALUE 1,
       'subtotal' VALUE 79.99
     )
   );

   -- Insert item 2
   INSERT INTO order_items_referenced (data) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ITEM-002',
       'order_id' VALUE 'ORD-REF-001',
       'product_id' VALUE 'PROD-002',
       'product_name' VALUE 'Ergonomic Wireless Mouse',
       'price' VALUE 34.99,
       'quantity' VALUE 2,
       'subtotal' VALUE 69.98
     )
   );

   COMMIT;
   ```

4. Insert more referenced data:

   ```sql
   -- Insert more customers
   INSERT INTO customers_referenced (data) VALUES (
     JSON_OBJECT('_id' VALUE 'CUST-001', 'name' VALUE 'Customer 1', 'email' VALUE 'customer1@email.com')
   );
   INSERT INTO customers_referenced (data) VALUES (
     JSON_OBJECT('_id' VALUE 'CUST-002', 'name' VALUE 'Customer 2', 'email' VALUE 'customer2@email.com')
   );
   INSERT INTO customers_referenced (data) VALUES (
     JSON_OBJECT('_id' VALUE 'CUST-003', 'name' VALUE 'Customer 3', 'email' VALUE 'customer3@email.com')
   );

   -- Insert more orders
   INSERT INTO orders_referenced (data) VALUES (
     JSON_OBJECT('_id' VALUE 'ORD-REF-002', 'order_date' VALUE SYSTIMESTAMP - 1, 'status' VALUE 'shipped', 'customer_id' VALUE 'CUST-001', 'total' VALUE 75.58)
   );
   INSERT INTO orders_referenced (data) VALUES (
     JSON_OBJECT('_id' VALUE 'ORD-REF-003', 'order_date' VALUE SYSTIMESTAMP - 2, 'status' VALUE 'delivered', 'customer_id' VALUE 'CUST-002', 'total' VALUE 125.99)
   );

   -- Insert more order items
   INSERT INTO order_items_referenced (data) VALUES (
     JSON_OBJECT('_id' VALUE 'ITEM-003', 'order_id' VALUE 'ORD-REF-002', 'product_id' VALUE 'PROD-003', 'product_name' VALUE 'Product 3', 'price' VALUE 34.99, 'quantity' VALUE 2, 'subtotal' VALUE 69.98)
   );
   INSERT INTO order_items_referenced (data) VALUES (
     JSON_OBJECT('_id' VALUE 'ITEM-004', 'order_id' VALUE 'ORD-REF-003', 'product_id' VALUE 'PROD-004', 'product_name' VALUE 'Product 4', 'price' VALUE 125.99, 'quantity' VALUE 1, 'subtotal' VALUE 125.99)
   );

   COMMIT;
   ```

### Step 3: Query Referenced Orders (Requires Multiple Queries or Joins)

1. Retrieve order (first query):

   ```sql
   SELECT JSON_SERIALIZE(data PRETTY)
   FROM orders_referenced
   WHERE JSON_VALUE(data, '$._id') = 'ORD-REF-001';
   ```

   **Notice:** This returns only the order header - no customer details, no items!

2. Retrieve order items (second query):

   ```sql
   SELECT JSON_SERIALIZE(data PRETTY)
   FROM order_items_referenced
   WHERE JSON_VALUE(data, '$.order_id') = 'ORD-REF-001';
   ```

3. Retrieve customer (third query):

   ```sql
   SELECT JSON_SERIALIZE(data PRETTY)
   FROM customers_referenced
   WHERE JSON_VALUE(data, '$._id') = 'CUST-456';
   ```

   **Notice:** It took **3 separate queries** to get the same data that embedded pattern returned in **1 query**!

4. Alternatively, use SQL joins (slower):

   ```sql
   SELECT
     JSON_VALUE(o.data, '$._id') AS order_id,
     JSON_VALUE(o.data, '$.order_date') AS order_date,
     JSON_VALUE(c.data, '$.name') AS customer_name,
     JSON_VALUE(i.data, '$.product_name') AS product,
     JSON_VALUE(i.data, '$.quantity' RETURNING NUMBER) AS quantity,
     JSON_VALUE(i.data, '$.subtotal' RETURNING NUMBER) AS subtotal
   FROM orders_referenced o
   JOIN customers_referenced c
     ON JSON_VALUE(o.data, '$.customer_id') = JSON_VALUE(c.data, '$._id')
   JOIN order_items_referenced i
     ON JSON_VALUE(o.data, '$._id') = JSON_VALUE(i.data, '$.order_id')
   WHERE JSON_VALUE(o.data, '$._id') = 'ORD-REF-001';
   ```

   **Key Insight:**

   > The referenced pattern requires **3 queries** (or complex joins) to retrieve what embedded pattern returns in **1 query**. This is the fundamental trade-off between normalization and denormalization.

## Task 4: Performance Comparison

Now let's measure the performance difference between embedded and referenced patterns.

### Step 1: Simple Performance Test

1. Time embedded pattern query:

   ```sql
   SET TIMING ON

   -- Embedded: Single query gets everything
   SELECT
     JSON_VALUE(data, '$._id') AS order_id,
     JSON_VALUE(data, '$.customer.name') AS customer_name,
     JSON_QUERY(data, '$.items') AS items,
     JSON_VALUE(data, '$.total') AS total
   FROM orders_embedded
   WHERE JSON_VALUE(data, '$._id') = 'ORD-EMB-001';

   SET TIMING OFF
   ```

2. Time referenced pattern query (with joins):

   ```sql
   SET TIMING ON

   -- Referenced: Requires join across 3 tables
   SELECT
     JSON_VALUE(o.data, '$._id') AS order_id,
     JSON_VALUE(c.data, '$.name') AS customer_name,
     JSON_VALUE(i.data, '$.product_name') AS product,
     JSON_VALUE(o.data, '$.total') AS total
   FROM orders_referenced o
   JOIN customers_referenced c
     ON JSON_VALUE(o.data, '$.customer_id') = JSON_VALUE(c.data, '$._id')
   JOIN order_items_referenced i
     ON JSON_VALUE(o.data, '$._id') = JSON_VALUE(i.data, '$.order_id')
   WHERE JSON_VALUE(o.data, '$._id') = 'ORD-REF-001';

   SET TIMING OFF
   ```

### Step 2: Measure Storage Efficiency

1. Compare storage usage:

   ```sql
   SELECT
     'EMBEDDED' AS pattern,
     COUNT(*) AS document_count,
     SUM(LENGTHB(data)) AS total_bytes,
     ROUND(AVG(LENGTHB(data)), 0) AS avg_bytes
   FROM orders_embedded
   UNION ALL
   SELECT
     'REFERENCED (orders)',
     COUNT(*),
     SUM(LENGTHB(data)),
     ROUND(AVG(LENGTHB(data)), 0)
   FROM orders_referenced
   UNION ALL
   SELECT
     'REFERENCED (items)',
     COUNT(*),
     SUM(LENGTHB(data)),
     ROUND(AVG(LENGTHB(data)), 0)
   FROM order_items_referenced
   UNION ALL
   SELECT
     'REFERENCED (customers)',
     COUNT(*),
     SUM(LENGTHB(data)),
     ROUND(AVG(LENGTHB(data)), 0)
   FROM customers_referenced;
   ```

   **Insight:** Embedded pattern uses more storage due to data duplication, but storage is cheap compared to query performance.

## Task 5: Decision Criteria

### When to Use Embedded Pattern

**Use embedded when:**

1. **Data is always accessed together**
   - Example: Order with items, customer info, shipping address

2. **Bounded, small arrays** (< 100 items)
   - Example: Order items (typically < 50 items per order)

3. **Read-heavy workload**
   - Example: E-commerce order history, invoices

4. **Performance is critical**
   - Example: Real-time dashboards, customer-facing APIs

5. **Data changes infrequently**
   - Example: Historical orders (immutable after shipping)

**Real-world examples:**
- E-commerce orders with items
- Blog posts with comments (< 100 comments)
- User profiles with preferences
- Events with attendee lists (< 100 attendees)

### When to Use Referenced Pattern

**Use referenced when:**

1. **Data is accessed independently**
   - Example: Product catalog (products queried separately from orders)

2. **Unbounded, large arrays** (over 100 items)
   - Example: Social media followers (millions of followers)

3. **Write-heavy workload**
   - Example: Real-time analytics, frequently updated data

4. **Strong consistency required**
   - Example: Financial transactions, inventory management

5. **Many-to-many relationships**
   - Example: Users and groups, products and categories

**Real-world examples:**
- Product catalog (products referenced by many orders)
- Social media followers (millions of users)
- Inventory management (frequent updates)
- Many-to-many relationships (users <-> groups)

### The Hybrid Approach (Best Practice)

In practice, most applications use **both patterns**:

**Example: E-commerce System**

**Embedded:**
- Order -> Items (bounded, always accessed together)
- Order -> Shipping address (small, accessed together)
- Order -> Billing info (small, accessed together)

**Referenced:**
- Order -> Customer (customer accessed independently)
- Order Items -> Product (product info changes frequently)
- Customer -> Orders (unbounded list of orders)

**Next Lab Preview:**

In **Lab 3 (Single Collection/Table Design)**, you will learn how to take the embedded pattern to the next level by storing **multiple entity types** in a single collection using **composite keys** and **strategic denormalization**. This is the key to avoiding LOB performance cliffs and achieving 10-20x query performance improvements!

## Task 6: Update Patterns

Understanding update behavior is critical for pattern selection.

### Embedded Pattern Updates

1. Update embedded customer name (must update all orders):

   ```sql
   -- Update customer name in all orders
   UPDATE orders_embedded
   SET data = JSON_MERGEPATCH(
     data,
     '{"customer": {"name": "Alice Smith-Johnson"}}'
   )
   WHERE JSON_VALUE(data, '$.customer_id') = 'CUST-456';

   COMMIT;
   ```

   **Impact:** If customer has 100 orders, you must update 100 documents!

2. Update using JSON_TRANSFORM (recommended):

   ```sql
   -- More precise update with JSON_TRANSFORM
   UPDATE orders_embedded
   SET data = JSON_TRANSFORM(data, SET '$.customer.name' = 'Alice Smith-Johnson')
   WHERE JSON_VALUE(data, '$.customer_id') = 'CUST-456';

   COMMIT;
   ```

### Referenced Pattern Updates

1. Update customer name (single update):

   ```sql
   -- Update customer name in one place
   UPDATE customers_referenced
   SET data = JSON_MERGEPATCH(
     data,
     '{"name": "Alice Smith-Johnson"}'
   )
   WHERE JSON_VALUE(data, '$._id') = 'CUST-456';

   COMMIT;
   ```

   **Impact:** Only 1 document updated, all orders automatically reflect new name on next query.

### The Trade-Off

**Embedded Pattern:**
- Updates affect multiple documents (write amplification)
- Reads are fast (no joins)
- Historical accuracy (order shows name at time of order)

**Referenced Pattern:**
- Updates affect single document
- Reads require joins (slower)
- No historical accuracy (order always shows current name)

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

* The two fundamental patterns: Embedded and Referenced
* Embedded pattern stores related data together (denormalized)
* Referenced pattern stores data separately with foreign keys (normalized)
* Embedded pattern is 3-4x faster for reads but uses more storage
* Decision criteria based on access patterns, array size, and update frequency
* Most applications use hybrid approach (both patterns)
* Understanding trade-offs: performance vs consistency vs storage

**Key Takeaways:**

1. **"What is accessed together should be stored together"** - Design for queries, not entities
2. **Embedded is faster** - Single query vs multiple queries
3. **Referenced is more flexible** - Better for writes and unbounded relationships
4. **Storage is cheap, compute is expensive** - Denormalize for performance
5. **Use hybrid approach** - Apply both patterns where appropriate

You are now ready for **Lab 3: Single Collection/Table Design**, where you will learn how to combine multiple entity types in a single collection using composite keys and strategic denormalization - the most powerful NoSQL design pattern!

## Learn More

* [Oracle AI Database 26ai JSON Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/)
* [MongoDB Embedded vs Referenced Patterns](https://www.mongodb.com/docs/manual/data-modeling/)
* [DynamoDB One-to-Many Relationships](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-modeling-nosql.html)
* [AWS DynamoDB Data Modeling](https://aws.amazon.com/dynamodb/resources/)

## Acknowledgements

* **Author** - Rick Houlihan
* **Contributors** - Oracle JSON Development Team, Oracle LiveLabs Team
* **Last Updated By/Date** - Rick Houlihan, November 2025
