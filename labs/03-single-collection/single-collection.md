# Single Collection/Table Design Pattern

## Introduction

The **Single Collection/Table Design pattern** is an important NoSQL modeling approach that differs from traditional relational database design. This pattern can help improve query performance while avoiding LOB performance cliffs in Oracle JSON Collections.

This pattern draws from DynamoDB Single Table Design and MongoDB's Single Collection pattern, adapted for Oracle JSON Collections with OSON binary format. The access pattern-first methodology was developed at Amazon to model DynamoDB workloads and has been broadly adopted across the NoSQL industry.

By the end of this lab, you will understand how to design document models that store multiple entity types in a single collection, use composite keys for efficient queries, apply strategic denormalization, and achieve predictable query latency at scale.

Estimated Time: 60 minutes

### Objectives

In this lab, you will:

* Understand the paradigm shift from entity-first (RDBMS) to access pattern-first (NoSQL) design
* Learn the core principle: "What is accessed together should be stored together"
* Implement composite key strategies (delimiter-based, hierarchical, date-based)
* Apply strategic denormalization to eliminate application-level joins
* Store multiple entity types in a single collection using polymorphic documents
* Implement many-to-many relationships using arrays with multivalue indexes
* Use hierarchical path queries to aggregate related documents
* Avoid the 32MB OSON limit and LOB performance cliffs
* Measure query performance improvements over multi-collection approach
* Design for common access patterns in e-commerce and enterprise scenarios

### Prerequisites

This lab assumes you have:

* Completed Lab 0: Setup
* Completed Lab 1: JSON Collections Fundamentals
* Completed Lab 2: Embedded vs Referenced Patterns
* Understanding of JSON_VALUE, JSON_QUERY, and performance measurement
* Access to Oracle AI Database 26ai as JSONUSER

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
> **"In cloud computing, storage is cheap but compute (query time) is expensive. Optimize for query performance, not storage minimization."**

## Task 2: Composite Key Strategies

Composite keys enable you to store multiple entity types in one collection while maintaining efficient queries. However, their use differs between DynamoDB and Oracle JSON Collections.

### Step 1: Understanding Composite Keys - DynamoDB vs Oracle

**What is a composite key?**

A composite key combines multiple identifiers into a single `_id` field to represent hierarchical relationships.

**DynamoDB Context:**

In DynamoDB, composite keys are **essential** because:
- ❌ DynamoDB does NOT support compound indexes
- ❌ You can only query on the partition key + sort key
- ✅ Composite keys enable hierarchical queries (`CUSTOMER#456#ORDER#001`)
- ✅ Prefix queries work on sort keys (`begins_with`)

**Oracle JSON Collections Context (Important Difference!):**

In Oracle, composite keys are **optional** because:
- ✅ Oracle DOES support compound/multi-column indexes
- ✅ You can create indexes on multiple JSON fields: `orderId`, `customerId`, etc.
- ✅ You can query efficiently using standard indexed fields

**When to Use Composite Keys in Oracle:**

Use composite keys in Oracle when you want **write efficiency without indexing overhead**:

1. ✅ **Write-heavy workloads** where indexing overhead is expensive
2. ✅ **Grouping related documents** for efficient range queries without indexes
3. ✅ **Temporal data** where date-based keys enable efficient time-range queries
4. ✅ **Hierarchical relationships** where parent-child grouping is natural

**When NOT to Use Composite Keys in Oracle:**

Use indexed attributes instead when:
- ❌ Read performance is more critical than write performance
- ❌ You need to query by multiple different fields
- ❌ Your access patterns require complex filtering
- ❌ Documents are updated frequently (indexes maintain themselves)

**Key Insight:**
> **In Oracle, choose composite keys for write efficiency and grouping without indexes. Use indexed attributes (like `orderId`) when read performance and query flexibility are more important.**

**Why use composite keys in Oracle?**

1. ✅ **Avoid indexing overhead on writes** - No index maintenance
2. ✅ Enable efficient prefix queries for grouping
3. ✅ Natural sorting and grouping
4. ✅ Express hierarchical relationships
5. ✅ Support write-heavy append operations (critical for growing orders!)

### Step 2: Delimiter-Based Composite Keys

**Pattern: Use delimiters to separate key components**

1. Create test collection:

   ```sql
   CREATE JSON COLLECTION TABLE ecommerce_single;
   ```

2. Create index on composite key:

   ```sql
   CREATE INDEX idx_ecommerce_id
   ON ecommerce_single (JSON_VALUE(data, '$._id'));
   ```

3. Insert customer entity:

   ```sql
   INSERT INTO ecommerce_single (data) VALUES (
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

   // Insert customer with composite key
   db.ecommerce_single.insertOne({
     _id: "CUSTOMER#CUST-456",
     type: "customer",
     name: "Alice Johnson",
     email: "alice@email.com",
     phone: "+1-555-0123",
     created: "2024-01-15T10:00:00Z",
     loyalty_tier: "gold",
     total_orders: 127,
     lifetime_value: 12450.00
   })
   ```

   > **MongoDB API**: Composite keys work identically in MongoDB. The delimiter pattern (`#`) is a standard NoSQL practice.

4. Insert order entity (same collection):

   ```sql
   INSERT INTO ecommerce_single (data) VALUES (
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

   COMMIT;
   ```

5. Query by exact key:

   ```sql
   -- Get specific order (single query, ~1-2ms)
   SELECT JSON_SERIALIZE(data PRETTY)
   FROM ecommerce_single
   WHERE JSON_VALUE(data, '$._id') = 'CUSTOMER#CUST-456#ORDER#ORD-001';
   ```

   **Notice:** This single query returns:
   - Order details
   - Customer information (denormalized)
   - All order items
   - No joins required!

6. Query by key prefix (get all orders for customer):

   ```sql
   -- Get all orders for a customer using prefix match
   SELECT
     JSON_VALUE(data, '$._id') AS order_id,
     JSON_VALUE(data, '$.order_date') AS order_date,
     JSON_VALUE(data, '$.total' RETURNING NUMBER) AS total,
     JSON_VALUE(data, '$.status') AS status
   FROM ecommerce_single
   WHERE JSON_VALUE(data, '$._id') LIKE 'CUSTOMER#CUST-456#ORDER#%';
   ```

   Expected output:
   ```
   ORDER_ID                              ORDER_DATE             TOTAL  STATUS
   ------------------------------------- ---------------------- ------ --------
   CUSTOMER#CUST-456#ORDER#ORD-001       2024-11-15T10:30:00Z  114.45 shipped
   ```

   **Key Benefit:** A single index on `_id` enables efficient queries for:
   - Exact matches (`_id = "CUSTOMER#CUST-456"`)
   - Prefix matches (`_id LIKE "CUSTOMER#CUST-456#ORDER#%"`)
   - Range queries (all orders between dates)

7. Get customer and all their orders (2 queries):

   ```sql
   -- Query 1: Get customer
   SELECT JSON_SERIALIZE(data PRETTY)
   FROM ecommerce_single
   WHERE JSON_VALUE(data, '$._id') = 'CUSTOMER#CUST-456'
     AND JSON_VALUE(data, '$.type') = 'customer';

   -- Query 2: Get all customer's orders
   SELECT JSON_SERIALIZE(data PRETTY)
   FROM ecommerce_single
   WHERE JSON_VALUE(data, '$._id') LIKE 'CUSTOMER#CUST-456#ORDER#%'
   ORDER BY JSON_VALUE(data, '$.order_date') DESC;
   ```

### Step 3: Hierarchical Composite Keys (JSON Object)

Alternative approach using JSON object as _id:

1. Insert with hierarchical key:

   ```sql
   INSERT INTO ecommerce_single (data) VALUES (
     '{"_id": {"customer_id": "CUST-789", "order_id": "ORD-002"}, "type": "order", "customer_name": "Bob Martinez", "order_date": "2024-11-16T14:00:00Z", "total": 299.99}'
   );

   COMMIT;
   ```

2. Query with hierarchical key:

   ```sql
   SELECT JSON_SERIALIZE(data PRETTY)
   FROM ecommerce_single
   WHERE JSON_VALUE(data, '$._id.customer_id') = 'CUST-789'
     AND JSON_VALUE(data, '$._id.order_id') = 'ORD-002';
   ```

**Recommendation:** Use **delimiter-based keys** for Oracle JSON Collections because:
- ✅ Better index performance (string comparison vs nested JSON)
- ✅ Simpler LIKE queries for prefix matching
- ✅ Better compatibility with Oracle's optimizer

### Step 4: Date-Based Composite Keys (Time-Series Data)

For time-series data, include date in the key:

1. Insert sensor reading:

   ```sql
   INSERT INTO ecommerce_single (data) VALUES (
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

   COMMIT;
   ```

2. Query by date range:

   ```sql
   SELECT
     JSON_VALUE(data, '$.timestamp') AS timestamp,
     JSON_VALUE(data, '$.temperature') AS temp,
     JSON_VALUE(data, '$.humidity') AS humidity
   FROM ecommerce_single
   WHERE JSON_VALUE(data, '$._id') LIKE 'SENSOR#temp001#2024-11-18#%'
   ORDER BY JSON_VALUE(data, '$.timestamp');
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

**Industry Guidance:**

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
   INSERT INTO ecommerce_single (data) VALUES (
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
     JSON_VALUE(data, '$._id') AS order_id,
     JSON_VALUE(data, '$.customer.name') AS customer_name,
     JSON_VALUE(data, '$.customer.email') AS customer_email,
     JSON_VALUE(data, '$.customer.loyalty_tier') AS tier,
     JSON_VALUE(data, '$.shipping_address.city') AS ship_city,
     JSON_VALUE(data, '$.total' RETURNING NUMBER) AS total
   FROM ecommerce_single
   WHERE JSON_VALUE(data, '$._id') = 'CUSTOMER#CUST-456#ORDER#ORD-003';
   ```

   **Result:** Complete order details in **one query**, ~1-2ms latency!

### Step 3: Extended Reference Pattern (Hybrid Approach)

For large, frequently changing data, use **extended reference pattern**: denormalize only essential fields, reference full entity.

1. Product catalog (separate collection for full details):

   ```sql
   CREATE JSON COLLECTION TABLE products_catalog;

   INSERT INTO products_catalog (data) VALUES (
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
       'price_history' VALUE JSON_ARRAY()
     )
   );

   COMMIT;
   ```

2. Order with extended reference (denormalize small, frequently accessed fields):

   ```json
   // In order document, include only essential product fields:
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
   WHERE JSON_VALUE(data, '$._id') = 'CUSTOMER#CUST-456#ORDER#ORD-003';
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
     JSON_VALUE(data, '$._id') AS id,
     JSON_VALUE(data, '$.type') AS type,
     LENGTHB(data) AS bytes,
     CASE
       WHEN LENGTHB(data) < 7950 THEN 'TIER 1: Inline (Optimal)'
       WHEN LENGTHB(data) < 102400 THEN 'TIER 2: LOB (OK)'
       WHEN LENGTHB(data) < 10485760 THEN 'TIER 3: Large LOB (Slow)'
       ELSE 'TIER 4: Very Large (Avoid)'
     END AS storage_tier
   FROM ecommerce_single
   ORDER BY bytes DESC;
   ```

2. Calculate collection statistics:

   ```sql
   SELECT
     JSON_VALUE(data, '$.type') AS entity_type,
     COUNT(*) AS document_count,
     ROUND(AVG(LENGTHB(data)), 0) AS avg_bytes,
     MIN(LENGTHB(data)) AS min_bytes,
     MAX(LENGTHB(data)) AS max_bytes,
     SUM(CASE WHEN LENGTHB(data) < 7950 THEN 1 ELSE 0 END) AS inline_count,
     ROUND(SUM(CASE WHEN LENGTHB(data) < 7950 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS inline_pct
   FROM ecommerce_single
   GROUP BY JSON_VALUE(data, '$.type');
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

## Task 5: Write-Heavy Orders - Indexed Attributes Approach

In real-world e-commerce, orders don't arrive complete - they grow over time with multiple append operations: shipments, invoices, payments, stock updates, and annotations. This causes documents to bloat and cross into LOB storage, making writes inefficient.

**The Problem:**

A single order document that grows from 2KB → 50KB → 200KB as updates are appended will:
- ❌ Start in inline storage (fast writes)
- ❌ Cross into LOB storage at 7,950 bytes (slower writes)
- ❌ Continue growing with each shipment, payment, invoice
- ❌ Eventually approach 32MB limit with hundreds of updates
- ❌ Every write becomes slower as document grows

**The Solution: Indexed Attribute Pattern**

Instead of composite keys, use **indexed `orderId` attributes** to group small documents:

```
Single Growing Document (Anti-Pattern):        Multiple Small Documents (Pattern):
Order#ORD-001 (2KB → 50KB → 200KB)           Order#ORD-001 (2KB, stays small)
├─ items[]                                    Shipment#SH-001 {orderId: ORD-001} (1KB)
├─ shipments[] (appends)                      Shipment#SH-002 {orderId: ORD-001} (1KB)
├─ invoices[] (appends)                       Invoice#INV-001 {orderId: ORD-001} (3KB)
├─ payments[] (appends)                       Payment#PAY-001 {orderId: ORD-001} (500B)
├─ stock_updates[] (appends)                  Payment#PAY-002 {orderId: ORD-001} (500B)
└─ annotations[] (appends)                    StockUpdate#ST-001 {orderId: ORD-001} (300B)
                                              Annotation#ANN-001 {orderId: ORD-001} (200B)

All documents stay < 7,950 bytes (inline storage)
Single index on orderId collects them all
```

### Step 1: Create Write-Heavy Order Collection

1. Create collection for append-heavy orders:

   ```sql
   CREATE JSON COLLECTION TABLE orders_append_heavy;
   ```

2. Create indexes on orderId and type:

   ```sql
   -- Index on orderId to collect all related documents
   CREATE INDEX idx_orders_orderid
   ON orders_append_heavy (JSON_VALUE(data, '$.orderId'));

   -- Index on document type for filtering
   CREATE INDEX idx_orders_type
   ON orders_append_heavy (JSON_VALUE(data, '$.type'));
   ```

### Step 2: Insert Order with Separate Event Documents

1. Insert initial order (small, stays inline):

   ```sql
   INSERT INTO orders_append_heavy (data) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ORD-2024-001',
       'orderId' VALUE 'ORD-2024-001',  -- Indexed for collection
       'type' VALUE 'order',
       'customerId' VALUE 'CUST-456',
       'customerName' VALUE 'Alice Johnson',
       'orderDate' VALUE '2024-11-18T10:00:00Z',
       'items' VALUE JSON_ARRAY(
         JSON_OBJECT(
           'productId' VALUE 'PROD-789',
           'name' VALUE 'Wireless Headphones',
           'price' VALUE 79.99,
           'quantity' VALUE 2
         )
       ),
       'subtotal' VALUE 159.98,
       'status' VALUE 'pending'
     )
   );

   COMMIT;
   ```

2. Append shipment information (separate document):

   ```sql
   INSERT INTO orders_append_heavy (data) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'SHIPMENT-SH-001',
       'orderId' VALUE 'ORD-2024-001',  -- Links to order
       'type' VALUE 'shipment',
       'shipmentId' VALUE 'SH-001',
       'carrier' VALUE 'FedEx',
       'trackingNumber' VALUE '1Z999AA10123456784',
       'shippedDate' VALUE '2024-11-18T14:30:00Z',
       'estimatedDelivery' VALUE '2024-11-20',
       'items' VALUE JSON_ARRAY(
         JSON_OBJECT('productId' VALUE 'PROD-789', 'quantity' VALUE 2)
       )
     )
   );

   COMMIT;
   ```

3. Append invoice (separate document):

   ```sql
   INSERT INTO orders_append_heavy (data) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'INVOICE-INV-001',
       'orderId' VALUE 'ORD-2024-001',  -- Links to order
       'type' VALUE 'invoice',
       'invoiceId' VALUE 'INV-001',
       'invoiceDate' VALUE '2024-11-18T14:35:00Z',
       'dueDate' VALUE '2024-12-18',
       'lineItems' VALUE JSON_ARRAY(
         JSON_OBJECT('description' VALUE 'Wireless Headphones x2', 'amount' VALUE 159.98),
         JSON_OBJECT('description' VALUE 'Shipping', 'amount' VALUE 12.99),
         JSON_OBJECT('description' VALUE 'Tax', 'amount' VALUE 13.84)
       ),
       'subtotal' VALUE 159.98,
       'shipping' VALUE 12.99,
       'tax' VALUE 13.84,
       'total' VALUE 186.81
     )
   );

   COMMIT;
   ```

4. Append payment information (separate document):

   ```sql
   INSERT INTO orders_append_heavy (data) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'PAYMENT-PAY-001',
       'orderId' VALUE 'ORD-2024-001',  -- Links to order
       'type' VALUE 'payment',
       'paymentId' VALUE 'PAY-001',
       'paymentDate' VALUE '2024-11-18T14:40:00Z',
       'method' VALUE 'credit_card',
       'last4' VALUE '4242',
       'amount' VALUE 186.81,
       'status' VALUE 'completed',
       'transactionId' VALUE 'ch_3MtwBwLkdIwHu7ix0jnF2RBW'
     )
   );

   COMMIT;
   ```

5. Append stock update (separate document):

   ```sql
   INSERT INTO orders_append_heavy (data) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'STOCK-ST-001',
       'orderId' VALUE 'ORD-2024-001',  -- Links to order
       'type' VALUE 'stock_update',
       'updateId' VALUE 'ST-001',
       'updateDate' VALUE '2024-11-18T14:45:00Z',
       'productId' VALUE 'PROD-789',
       'previousStock' VALUE 45,
       'newStock' VALUE 43,
       'quantityReserved' VALUE 2,
       'warehouse' VALUE 'WAREHOUSE-WEST'
     )
   );

   COMMIT;
   ```

6. Append order annotation (separate document):

   ```sql
   INSERT INTO orders_append_heavy (data) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ANNOTATION-ANN-001',
       'orderId' VALUE 'ORD-2024-001',  -- Links to order
       'type' VALUE 'annotation',
       'annotationId' VALUE 'ANN-001',
       'createdDate' VALUE '2024-11-18T15:00:00Z',
       'createdBy' VALUE 'support@company.com',
       'category' VALUE 'customer_request',
       'note' VALUE 'Customer requested gift wrapping - added to shipment notes',
       'visibility' VALUE 'internal'
     )
   );

   COMMIT;
   ```

### Step 3: Query Complete Order History

1. Collect all documents for an order using indexed orderId:

   ```sql
   -- Get complete order history (single query, uses index)
   SELECT
     JSON_VALUE(data, '$.type') AS document_type,
     JSON_VALUE(data, '$._id') AS document_id,
     LENGTHB(data) AS bytes,
     JSON_SERIALIZE(data PRETTY) AS document
   FROM orders_append_heavy
   WHERE JSON_VALUE(data, '$.orderId') = 'ORD-2024-001'
   ORDER BY JSON_VALUE(data, '$.type');
   ```

   **Result:** 6 documents returned, each under 2KB (all inline storage!)

2. Query just the order summary:

   ```sql
   SELECT JSON_SERIALIZE(data PRETTY)
   FROM orders_append_heavy
   WHERE JSON_VALUE(data, '$.orderId') = 'ORD-2024-001'
     AND JSON_VALUE(data, '$.type') = 'order';
   ```

3. Query just shipments:

   ```sql
   SELECT JSON_SERIALIZE(data PRETTY)
   FROM orders_append_heavy
   WHERE JSON_VALUE(data, '$.orderId') = 'ORD-2024-001'
     AND JSON_VALUE(data, '$.type') = 'shipment';
   ```

4. Get aggregated order status:

   ```sql
   SELECT
     MAX(CASE WHEN JSON_VALUE(data, '$.type') = 'order'
              THEN JSON_VALUE(data, '$.status') END) AS order_status,
     MAX(CASE WHEN JSON_VALUE(data, '$.type') = 'shipment'
              THEN JSON_VALUE(data, '$.trackingNumber') END) AS tracking,
     MAX(CASE WHEN JSON_VALUE(data, '$.type') = 'payment'
              THEN JSON_VALUE(data, '$.status') END) AS payment_status,
     COUNT(CASE WHEN JSON_VALUE(data, '$.type') = 'annotation' THEN 1 END) AS annotation_count
   FROM orders_append_heavy
   WHERE JSON_VALUE(data, '$.orderId') = 'ORD-2024-001';
   ```

### Step 4: Measure Document Sizes

1. Verify all documents stay in inline storage:

   ```sql
   SELECT
     JSON_VALUE(data, '$.type') AS type,
     JSON_VALUE(data, '$._id') AS id,
     LENGTHB(data) AS bytes,
     CASE
       WHEN LENGTHB(data) < 7950 THEN 'INLINE (Fast writes)'
       ELSE 'LOB (Slow writes)'
     END AS storage_tier
   FROM orders_append_heavy
   WHERE JSON_VALUE(data, '$.orderId') = 'ORD-2024-001'
   ORDER BY bytes DESC;
   ```

   **Expected Result:**
   ```
   TYPE            ID                  BYTES   STORAGE_TIER
   -------------   -----------------   -----   ------------------
   invoice         INVOICE-INV-001       550   INLINE (Fast writes)
   order           ORD-2024-001          500   INLINE (Fast writes)
   shipment        SHIPMENT-SH-001       450   INLINE (Fast writes)
   payment         PAYMENT-PAY-001       400   INLINE (Fast writes)
   stock_update    STOCK-ST-001          380   INLINE (Fast writes)
   annotation      ANNOTATION-ANN-001    350   INLINE (Fast writes)
   ```

   **All documents in inline storage!** ✅

### Step 5: Benefits of Indexed Attribute Approach

**Advantages:**

1. ✅ **Efficient writes** - All documents stay in inline storage (< 7,950 bytes)
2. ✅ **No LOB cliffs** - Documents never grow unbounded
3. ✅ **Flexible queries** - Can query by type, date, status independently
4. ✅ **Indexed collection** - Single index on `orderId` groups related documents
5. ✅ **Append-friendly** - New events are inserts, not updates to large documents
6. ✅ **Query flexibility** - Oracle's compound indexes enable complex filtering

**When to Use:**

- ✅ Write-heavy workloads (many appends over time)
- ✅ Order processing (shipments, invoices, payments added asynchronously)
- ✅ Event sourcing (append-only event logs)
- ✅ Audit trails (continuous appends)
- ✅ IoT sensor data (continuous readings)

**Comparison: Composite Keys vs Indexed Attributes**

| Factor | Composite Keys | Indexed Attributes |
|--------|---------------|-------------------|
| **Write Performance** | ✅ No index overhead | ⚠️ Index maintenance overhead |
| **Read Performance** | ✅ Prefix queries (no index) | ✅ Index seek (very fast) |
| **Query Flexibility** | ❌ Limited to prefix patterns | ✅ Full SQL capabilities |
| **Best For** | Time-series, logs, sequential access | Complex filtering, multi-field queries |
| **DynamoDB Equivalent** | Required (no compound indexes) | Not available |

**Key Insight:**
> **Use indexed attributes in Oracle when you need write efficiency AND query flexibility. Use composite keys when you want write efficiency WITHOUT indexing overhead (pure sequential/temporal access).**

## Task 6: Performance Comparison - Single vs Multiple Collections

Now let's measure the actual performance improvement of single collection vs traditional multi-collection approach.

### Step 1: Create Multi-Collection Approach (Baseline)

1. Create traditional normalized collections:

   ```sql
   CREATE JSON COLLECTION TABLE customers_multi;
   CREATE JSON COLLECTION TABLE orders_multi;
   CREATE JSON COLLECTION TABLE order_items_multi;

   CREATE INDEX idx_orders_multi_customer
     ON orders_multi (JSON_VALUE(data, '$.customer_id'));
   CREATE INDEX idx_items_multi_order
     ON order_items_multi (JSON_VALUE(data, '$.order_id'));
   ```

2. Insert sample data:

   ```sql
   -- Customer
   INSERT INTO customers_multi (data) VALUES (
     '{"_id": "CUST-456", "name": "Alice Johnson", "email": "alice@email.com"}'
   );

   -- Order
   INSERT INTO orders_multi (data) VALUES (
     '{"_id": "ORD-MULTI-001", "customer_id": "CUST-456", "order_date": "2024-11-18", "total": 114.45}'
   );

   -- Order items (one at a time)
   INSERT INTO order_items_multi (data) VALUES (
     '{"_id": "ITEM-M-001", "order_id": "ORD-MULTI-001", "product_id": "PROD-789", "name": "Headphones", "price": 79.99, "quantity": 1}'
   );

   INSERT INTO order_items_multi (data) VALUES (
     '{"_id": "ITEM-M-002", "order_id": "ORD-MULTI-001", "product_id": "PROD-234", "name": "USB Cable", "price": 12.99, "quantity": 2}'
   );

   COMMIT;
   ```

3. Query (requires 3 queries or expensive join):

   ```sql
   -- Approach 1: Multiple queries (client-side join)
   SELECT * FROM orders_multi WHERE JSON_VALUE(data, '$._id') = 'ORD-MULTI-001';
   SELECT * FROM customers_multi WHERE JSON_VALUE(data, '$._id') = 'CUST-456';
   SELECT * FROM order_items_multi WHERE JSON_VALUE(data, '$.order_id') = 'ORD-MULTI-001';

   -- Approach 2: SQL join (database-side, slower)
   SELECT
     o.data AS order_data,
     c.data AS customer_data,
     i.data AS item_data
   FROM orders_multi o
   JOIN customers_multi c ON JSON_VALUE(o.data, '$.customer_id') = JSON_VALUE(c.data, '$._id')
   JOIN order_items_multi i ON JSON_VALUE(o.data, '$._id') = JSON_VALUE(i.data, '$.order_id')
   WHERE JSON_VALUE(o.data, '$._id') = 'ORD-MULTI-001';
   ```

### Step 2: Compare Query Approaches

1. Single collection query (all data in one query):

   ```sql
   -- Single Collection: One query returns everything
   SELECT JSON_SERIALIZE(data PRETTY)
   FROM ecommerce_single
   WHERE JSON_VALUE(data, '$._id') = 'CUSTOMER#CUST-456#ORDER#ORD-001';
   ```

   **Performance:** ~1-2ms

2. Multi-collection join query:

   ```sql
   -- Multi Collection: Requires join across 3 tables
   SELECT
     JSON_VALUE(o.data, '$._id') AS order_id,
     JSON_VALUE(c.data, '$.name') AS customer_name,
     JSON_VALUE(i.data, '$.name') AS product
   FROM orders_multi o
   JOIN customers_multi c ON JSON_VALUE(o.data, '$.customer_id') = JSON_VALUE(c.data, '$._id')
   JOIN order_items_multi i ON JSON_VALUE(o.data, '$._id') = JSON_VALUE(i.data, '$.order_id')
   WHERE JSON_VALUE(o.data, '$._id') = 'ORD-MULTI-001';
   ```

   **Performance:** ~15-30ms (with small dataset, worse at scale)

### Step 3: Performance Analysis

**Key Performance Results:**

| Approach | Query Time | Complexity | Scalability |
|----------|-----------|------------|-------------|
| Single Collection | 1-2ms | 1 query | Excellent |
| Multi Collection (Joins) | 15-30ms | 3-way join | Poor |
| Multi Collection (3 queries) | 3-6ms | 3 round trips | Moderate |

**Why Single Collection Wins:**

1. ✅ **No joins** - Data is pre-joined in the document
2. ✅ **Single I/O operation** - One table access
3. ✅ **Index efficiency** - Single index lookup
4. ✅ **Predictable latency** - No join explosion
5. ✅ **Scale independence** - Same performance with 1M or 100M docs

## Task 7: Many-to-Many with Multivalue Indexes

Oracle's multivalue indexes enable efficient queries on array elements, supporting many-to-many relationships without junction tables.

### Step 1: Create Collection with Array Paths

1. Insert artifact with project paths (many-to-many):

   ```sql
   INSERT INTO ecommerce_single (data) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ARTIFACT#template-001',
       'type' VALUE 'artifact',
       'name' VALUE 'Marketing Email Template',
       'contentType' VALUE 'email_template',
       'content' VALUE '<html>...</html>',
       'projectPaths' VALUE JSON_ARRAY(
         '/acme/marketing/campaigns/2024',
         '/acme/sales/outreach',
         '/bigcorp/marketing/templates'
       ),
       'createdBy' VALUE 'alice@company.com',
       'lastModified' VALUE '2024-11-18T10:00:00Z'
     )
   );

   COMMIT;
   ```

2. Create multivalue index on array:

   ```sql
   CREATE MULTIVALUE INDEX idx_artifact_paths
   ON ecommerce_single e (e.data.projectPaths.string());
   ```

3. Query all artifacts for a project:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS artifact_name,
     JSON_VALUE(data, '$.contentType') AS type
   FROM ecommerce_single
   WHERE JSON_EXISTS(data, '$.projectPaths[*]?(@ == "/acme/marketing/campaigns/2024")');
   ```

4. Query with hierarchical path (all marketing artifacts):

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS artifact_name,
     JSON_VALUE(data, '$.contentType') AS type
   FROM ecommerce_single
   WHERE JSON_EXISTS(data, '$.projectPaths[*]?(@ like_regex "^/acme/marketing.*")');
   ```

### Step 2: Benefits of Array-Based Many-to-Many

**✅ Single Source of Truth**
- Artifact content stored once
- Updates propagate instantly to all projects
- No stale data, no synchronization issues

**✅ Eliminates Write Amplification**
- Update 1 document instead of 20
- Embedded approach: 20 writes for template update
- Array approach: 1 write affects all references

**✅ Efficient Storage**
- 50KB template stored once, not duplicated 20 times
- Saves 950KB in this example alone
- Scales to thousands of shared assets

**✅ Fast Hierarchical Queries**
- Multivalue index on projectPaths array
- Find all assets at `/acme/website` and below
- Sub-5ms query performance with proper indexing

## Task 8: Anti-Patterns to Avoid

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

**Why bad:** No shared access patterns, violates single collection principles

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

An older DynamoDB pattern (now deprecated):

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

Congratulations! You have learned the **Single Collection/Table Design pattern** - an important NoSQL modeling approach for Oracle JSON Collections.

### What You Learned

* ✅ The paradigm shift from entity-first to access pattern-first design
* ✅ Core principle: "What is accessed together should be stored together"
* ✅ Composite key strategies (delimiter-based, hierarchical, date-based)
* ✅ Strategic denormalization framework (when to denormalize, when not to)
* ✅ Storing multiple entity types in single collection (polymorphic documents)
* ✅ Many-to-many relationships using arrays with multivalue indexes
* ✅ Hierarchical path queries with prefix matching
* ✅ Eliminating write amplification with single source of truth pattern
* ✅ Avoiding the 32MB OSON limit and LOB performance cliffs
* ✅ Measuring query performance improvements
* ✅ Real-world e-commerce and enterprise implementations
* ✅ Anti-patterns to avoid

### Key Performance Results

- **Single Collection: 1-2ms** average query time
- **Multi Collection: 20-30ms** average query time (with joins)
- **Improvement: Up to 15x faster in this scenario**
- **P99 latency: 3ms vs 38ms** (more predictable)

### Design Checklist

Before implementing, ask yourself:

- [ ] What are my access patterns? (start here, not entities)
- [ ] What data is accessed together? (denormalize it)
- [ ] What data changes frequently? (don't denormalize it)
- [ ] Do I have shared resources that belong to many entities? (use arrays + multivalue indexes)
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

You can now apply this pattern to your own workloads!

## Learn More

* [Oracle AI Database 26ai JSON Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/)
* [AWS DynamoDB Single Table Design Patterns](https://aws.amazon.com/blogs/database/single-table-vs-multi-table-design-in-amazon-dynamodb/)
* [MongoDB Data Modeling](https://www.mongodb.com/docs/manual/data-modeling/)
* [OSON Binary Format](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/oson-format.html)

## Acknowledgements

* **Author** - Rick Houlihan
* **Contributors** - Oracle JSON Development Team, Oracle LiveLabs Team
* **Last Updated By/Date** - Rick Houlihan, November 2025
