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

   **SQL Approach:**

if type="sql"

   ```sql
   <copy>
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
   </copy>
   ```

   Expected output:
   ```
   1 row created.
   ```

/if

   **SODA Approach:**

if type="soda"

   ```sql
   <copy>
   DECLARE
     collection SODA_COLLECTION_T;
     status NUMBER;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('ecommerce_single');

     status := collection.insert_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw('{
           "_id": "CUSTOMER#CUST-456",
           "type": "customer",
           "name": "Alice Johnson",
           "email": "alice@email.com",
           "phone": "+1-555-0123",
           "created": "2024-01-15T10:00:00Z",
           "loyalty_tier": "gold",
           "total_orders": 127,
           "lifetime_value": 12450.00
         }')
       )
     );

     IF status = 1 THEN
       DBMS_OUTPUT.PUT_LINE('1 row created.');
     END IF;
   END;
   /
   </copy>
   ```

   Expected output:
   ```
   1 row created.

   PL/SQL procedure successfully completed.
   ```

/if

   **MongoDB API Approach:**

if type="mongodb"

   ```javascript
   <copy>
   // Connect to Oracle using MongoDB API
   // mongosh "mongodb://jsonuser:WelcomeJson%23123@localhost:27017/mydb?authMechanism=PLAIN&authSource=$external&tls=false"

   use mydb

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
   </copy>
   ```

   Expected output:
   ```javascript
   {
     acknowledged: true,
     insertedId: 'CUSTOMER#CUST-456'
   }
   ```

   > **MongoDB API**: Composite keys work identically in MongoDB. The delimiter pattern (`#`) is a standard NoSQL practice.

/if

   **REST API Approach:**

if type="rest"

   ```bash
   <copy>
   # Insert customer with composite key via REST
   curl -X POST \
     "http://localhost:8080/ords/jsonuser/soda/latest/ecommerce_single" \
     -H "Content-Type: application/json" \
     -d '{
       "_id": "CUSTOMER#CUST-456",
       "type": "customer",
       "name": "Alice Johnson",
       "email": "alice@email.com",
       "phone": "+1-555-0123",
       "created": "2024-01-15T10:00:00Z",
       "loyalty_tier": "gold",
       "total_orders": 127,
       "lifetime_value": 12450.00
     }'
   </copy>
   ```

   Expected output:
   ```json
   {
     "id": "...",
     "etag": "...",
     "lastModified": "2024-01-15T10:00:00.000Z"
   }
   ```

   > **REST API**: Composite keys in the `_id` field are just strings - works seamlessly with REST.

/if

   **Python Approach:**

if type="python"

   ```python
   <copy>
   import oracledb

   connection = oracledb.connect(
       user="jsonuser",
       password="WelcomeJson#123",
       dsn="localhost/FREEPDB1"
   )

   soda = connection.getSodaDatabase()
   collection = soda.openCollection("ecommerce_single")

   # Insert customer with composite key
   customer = {
       "_id": "CUSTOMER#CUST-456",
       "type": "customer",
       "name": "Alice Johnson",
       "email": "alice@email.com",
       "phone": "+1-555-0123",
       "created": "2024-01-15T10:00:00Z",
       "loyalty_tier": "gold",
       "total_orders": 127,
       "lifetime_value": 12450.00
   }

   doc = collection.insertOne(customer)
   print("1 row created.")
   connection.commit()

   connection.close()
   </copy>
   ```

   Expected output:
   ```
   1 row created.
   ```

   > **Python**: Composite keys are just string values in Python dictionaries - natural and simple.

/if

4. Insert order entity (same collection):

   **SQL Approach:**

if type="sql"

   ```sql
   <copy>
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
   </copy>
   ```

   Expected output:
   ```
   1 row created.
   ```

/if

   **SODA Approach:**

if type="soda"

   ```sql
   <copy>
   DECLARE
     collection SODA_COLLECTION_T;
     status NUMBER;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('ecommerce_single');

     status := collection.insert_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw('{
           "_id": "CUSTOMER#CUST-456#ORDER#ORD-001",
           "type": "order",
           "customer_id": "CUST-456",
           "customer_name": "Alice Johnson",
           "customer_email": "alice@email.com",
           "order_date": "2024-11-15T10:30:00Z",
           "status": "shipped",
           "items": [
             {
               "product_id": "PROD-789",
               "name": "Wireless Headphones",
               "price": 79.99,
               "quantity": 1,
               "subtotal": 79.99
             },
             {
               "product_id": "PROD-234",
               "name": "USB-C Cable",
               "price": 12.99,
               "quantity": 2,
               "subtotal": 25.98
             }
           ],
           "subtotal": 105.97,
           "tax": 8.48,
           "shipping": 0.00,
           "total": 114.45
         }')
       )
     );

     IF status = 1 THEN
       DBMS_OUTPUT.PUT_LINE('1 row created.');
     END IF;
   END;
   /
   </copy>
   ```

   Expected output:
   ```
   1 row created.

   PL/SQL procedure successfully completed.
   ```

/if

   **MongoDB API Approach:**

if type="mongodb"

   ```javascript
   <copy>
   // Insert order with hierarchical composite key
   db.ecommerce_single.insertOne({
     _id: "CUSTOMER#CUST-456#ORDER#ORD-001",
     type: "order",
     customer_id: "CUST-456",
     customer_name: "Alice Johnson",      // Denormalized
     customer_email: "alice@email.com",   // Denormalized
     order_date: "2024-11-15T10:30:00Z",
     status: "shipped",
     items: [
       {
         product_id: "PROD-789",
         name: "Wireless Headphones",
         price: 79.99,
         quantity: 1,
         subtotal: 79.99
       },
       {
         product_id: "PROD-234",
         name: "USB-C Cable",
         price: 12.99,
         quantity: 2,
         subtotal: 25.98
       }
     ],
     subtotal: 105.97,
     tax: 8.48,
     shipping: 0.00,
     total: 114.45
   })
   </copy>
   ```

   Expected output:
   ```javascript
   {
     acknowledged: true,
     insertedId: 'CUSTOMER#CUST-456#ORDER#ORD-001'
   }
   ```

   > **MongoDB API**: Hierarchical composite key (`CUSTOMER#...#ORDER#...`) enables efficient prefix queries to find all orders for a customer.

/if

   **REST API Approach:**

if type="rest"

   ```bash
   <copy>
   # Insert order with composite key
   curl -X POST \
     "http://localhost:8080/ords/jsonuser/soda/latest/ecommerce_single" \
     -H "Content-Type: application/json" \
     -d '{
       "_id": "CUSTOMER#CUST-456#ORDER#ORD-001",
       "type": "order",
       "customer_id": "CUST-456",
       "customer_name": "Alice Johnson",
       "customer_email": "alice@email.com",
       "order_date": "2024-11-15T10:30:00Z",
       "status": "shipped",
       "items": [
         {
           "product_id": "PROD-789",
           "name": "Wireless Headphones",
           "price": 79.99,
           "quantity": 1,
           "subtotal": 79.99
         },
         {
           "product_id": "PROD-234",
           "name": "USB-C Cable",
           "price": 12.99,
           "quantity": 2,
           "subtotal": 25.98
         }
       ],
       "subtotal": 105.97,
       "tax": 8.48,
       "shipping": 0.00,
       "total": 114.45
     }'
   </copy>
   ```

   Expected output:
   ```json
   {
     "id": "...",
     "etag": "...",
     "lastModified": "2024-11-15T10:30:00.000Z"
   }
   ```

   > **REST API**: Notice how we store both customer and order in the same collection - this is the single collection pattern.

/if

   **Python Approach:**

if type="python"

   ```python
   <copy>
   import oracledb

   connection = oracledb.connect(
       user="jsonuser",
       password="WelcomeJson#123",
       dsn="localhost/FREEPDB1"
   )

   soda = connection.getSodaDatabase()
   collection = soda.openCollection("ecommerce_single")

   # Insert order with hierarchical composite key and denormalized customer data
   order = {
       "_id": "CUSTOMER#CUST-456#ORDER#ORD-001",
       "type": "order",
       "customer_id": "CUST-456",
       "customer_name": "Alice Johnson",      # Denormalized
       "customer_email": "alice@email.com",   # Denormalized
       "order_date": "2024-11-15T10:30:00Z",
       "status": "shipped",
       "items": [
           {
               "product_id": "PROD-789",
               "name": "Wireless Headphones",
               "price": 79.99,
               "quantity": 1,
               "subtotal": 79.99
           },
           {
               "product_id": "PROD-234",
               "name": "USB-C Cable",
               "price": 12.99,
               "quantity": 2,
               "subtotal": 25.98
           }
       ],
       "subtotal": 105.97,
       "tax": 8.48,
       "shipping": 0.00,
       "total": 114.45
   }

   doc = collection.insertOne(order)
   print("1 row created.")
   connection.commit()

   connection.close()
   </copy>
   ```

   Expected output:
   ```
   1 row created.
   ```

   > **Python**: Composite keys and denormalization work naturally in Python. Both customer and order entities live in one collection.

/if

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

   if type="sql"

   ```sql
   <copy>
   -- Get all orders for a customer using prefix match
   SELECT
     JSON_VALUE(json_document, '$._id') AS order_id,
     JSON_VALUE(json_document, '$.order_date') AS order_date,
     JSON_VALUE(json_document, '$.total' RETURNING NUMBER) AS total,
     JSON_VALUE(json_document, '$.status') AS status
   FROM ecommerce_single
   WHERE JSON_VALUE(json_document, '$._id') LIKE 'CUSTOMER#CUST-456#ORDER#%';
   </copy>
   ```

   Expected output:
   ```
   ORDER_ID                              ORDER_DATE             TOTAL  STATUS
   ------------------------------------- ---------------------- ------ --------
   CUSTOMER#CUST-456#ORDER#ORD-001       2024-11-15T10:30:00Z  114.45 shipped
   ```

   /if

   if type="soda"

   ```sql
   <copy>
   DECLARE
     collection SODA_COLLECTION_T;
     cursor SODA_CURSOR_T;
     doc SODA_DOCUMENT_T;
     doc_content CLOB;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('ecommerce_single');

     -- Query by prefix using regex filter
     cursor := collection.find()
       .filter('{"_id": {"$regex": "^CUSTOMER#CUST-456#ORDER#"}}')
       .getCursor();

     DBMS_OUTPUT.PUT_LINE('Orders for customer CUST-456:');
     DBMS_OUTPUT.PUT_LINE('--------------------------------------');

     LOOP
       IF cursor.has_next() THEN
         doc := cursor.next();
         doc_content := doc.get_clob();

         DBMS_OUTPUT.PUT_LINE('Order: ' ||
           JSON_VALUE(doc_content, '$._id') || ', Total: $' ||
           JSON_VALUE(doc_content, '$.total'));
       ELSE
         EXIT;
       END IF;
     END LOOP;

     cursor.close();
   END;
   /
   </copy>
   ```

   Expected output:
   ```
   Orders for customer CUST-456:
   --------------------------------------
   Order: CUSTOMER#CUST-456#ORDER#ORD-001, Total: $114.45
   ```

   /if

   if type="mongodb"

   ```javascript
   <copy>
   // Query by key prefix using regex
   db.ecommerce_single.find(
     { _id: { $regex: /^CUSTOMER#CUST-456#ORDER#/ } },
     { _id: 1, order_date: 1, total: 1, status: 1 }
   )
   </copy>
   ```

   Expected output:
   ```javascript
   [
     {
       _id: 'CUSTOMER#CUST-456#ORDER#ORD-001',
       order_date: '2024-11-15T10:30:00Z',
       total: 114.45,
       status: 'shipped'
     }
   ]
   ```

   > **MongoDB API**: Use regex with `^` anchor for prefix matching. This is equivalent to SQL LIKE with trailing `%`.

   /if

   if type="rest"

   ```bash
   <copy>
   # Query by prefix using regex pattern
   curl -X POST \
     "http://localhost:8080/ords/jsonuser/soda/latest/ecommerce_single?action=query" \
     -H "Content-Type: application/json" \
     -d '{
       "$query": {
         "_id": { "$regex": "^CUSTOMER#CUST-456#ORDER#" }
       },
       "$fields": {
         "_id": 1,
         "order_date": 1,
         "total": 1,
         "status": 1
       }
     }'
   </copy>
   ```

   Expected output:
   ```json
   {
     "items": [
       {
         "_id": "CUSTOMER#CUST-456#ORDER#ORD-001",
         "order_date": "2024-11-15T10:30:00Z",
         "total": 114.45,
         "status": "shipped"
       }
     ],
     "hasMore": false,
     "count": 1
   }
   ```

   > **REST API**: Use `$regex` operator in QBE queries for pattern matching. Efficient for finding all related entities.

   /if

   if type="python"

   ```python
   <copy>
   import oracledb
   import re

   connection = oracledb.connect(
       user="jsonuser",
       password="WelcomeJson#123",
       dsn="localhost/FREEPDB1"
   )

   soda = connection.getSodaDatabase()
   collection = soda.openCollection("ecommerce_single")

   # Query by prefix using regex filter
   filter_spec = {
       "_id": {"$regex": "^CUSTOMER#CUST-456#ORDER#"}
   }

   documents = collection.find().filter(filter_spec).getDocuments()

   print("Orders for customer CUST-456:")
   print("-" * 60)

   for doc in documents:
       content = doc.getContent()
       print(f"Order: {content['_id']}, Total: ${content['total']}, Status: {content['status']}")

   connection.close()
   </copy>
   ```

   Expected output:
   ```
   Orders for customer CUST-456:
   ------------------------------------------------------------
   Order: CUSTOMER#CUST-456#ORDER#ORD-001, Total: $114.45, Status: shipped
   ```

   > **Python**: Regex filters work seamlessly. The `^` anchor matches the start of the string, enabling efficient prefix queries.

   /if

   **Key Benefit:** A single index on `_id` enables efficient queries for:
   - Exact matches (`_id = "CUSTOMER#CUST-456"`)
   - Prefix matches (`_id LIKE "CUSTOMER#CUST-456#ORDER#%"`)
   - Range queries (all orders between dates)

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

   **SQL Approach:**

if type="sql"

   ```sql
   <copy>
   INSERT INTO ecommerce_single (json_document) VALUES (
     '{"_id": {"customer_id": "CUST-789", "order_id": "ORD-002"}, "type": "order", "customer_name": "Bob Martinez", "order_date": "2024-11-16T14:00:00Z", "total": 299.99}'
   );
   </copy>
   ```

   Expected output:
   ```
   1 row created.
   ```

/if

   **SODA Approach:**

if type="soda"

   ```sql
   <copy>
   DECLARE
     collection SODA_COLLECTION_T;
     status NUMBER;
     json_string VARCHAR2(4000);
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('ecommerce_single');

     json_string := '{"_id": {"customer_id": "CUST-789", "order_id": "ORD-002"}, "type": "order", "customer_name": "Bob Martinez", "order_date": "2024-11-16T14:00:00Z", "total": 299.99}';

     status := collection.insert_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw(json_string)
       )
     );

     IF status = 1 THEN
       DBMS_OUTPUT.PUT_LINE('1 row created.');
     END IF;
   END;
   /
   </copy>
   ```

   Expected output:
   ```
   1 row created.

   PL/SQL procedure successfully completed.
   ```

/if

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

   **SQL Approach:**

if type="sql"

   ```sql
   <copy>
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
   </copy>
   ```

   Expected output:
   ```
   1 row created.
   ```

/if

   **SODA Approach:**

if type="soda"

   ```sql
   <copy>
   DECLARE
     collection SODA_COLLECTION_T;
     status NUMBER;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('ecommerce_single');

     status := collection.insert_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw('{
           "_id": "SENSOR#temp001#2024-11-18#14:00",
           "type": "sensor_reading",
           "sensor_id": "temp001",
           "timestamp": "2024-11-18T14:00:00Z",
           "temperature": 72.5,
           "humidity": 45.2,
           "location": "warehouse_A"
         }')
       )
     );

     IF status = 1 THEN
       DBMS_OUTPUT.PUT_LINE('1 row created.');
     END IF;
   END;
   /
   </copy>
   ```

   Expected output:
   ```
   1 row created.

   PL/SQL procedure successfully completed.
   ```

/if

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

   **SQL Approach:**

if type="sql"

   ```sql
   <copy>
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
   </copy>
   ```

   Expected output:
   ```
   1 row created.

   Commit complete.
   ```

/if

   **SODA Approach:**

if type="soda"

   ```sql
   <copy>
   DECLARE
     collection SODA_COLLECTION_T;
     status NUMBER;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('ecommerce_single');

     status := collection.insert_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw('{
           "_id": "CUSTOMER#CUST-456#ORDER#ORD-003",
           "type": "order",
           "customer": {
             "id": "CUST-456",
             "name": "Alice Johnson",
             "email": "alice@email.com",
             "phone": "+1-555-0123",
             "loyalty_tier": "gold",
             "snapshot_date": "2024-11-18"
           },
           "shipping_address": {
             "street": "123 Main Street",
             "city": "San Francisco",
             "state": "CA",
             "zip": "94105",
             "country": "USA"
           },
           "items": [
             {
               "product_id": "PROD-789",
               "name": "Wireless Headphones",
               "sku": "WH-BT-789",
               "price": 79.99,
               "quantity": 1,
               "subtotal": 79.99,
               "category": "Electronics",
               "brand": "AudioTech"
             }
           ],
           "order_date": "2024-11-18T10:30:00Z",
           "status": "processing",
           "total": 87.99
         }')
       )
     );

     IF status = 1 THEN
       DBMS_OUTPUT.PUT_LINE('1 row created.');
       DBMS_OUTPUT.PUT_LINE('');
       DBMS_OUTPUT.PUT_LINE('Commit complete.');
     END IF;

     COMMIT;
   END;
   /
   </copy>
   ```

   Expected output:
   ```
   1 row created.

   Commit complete.

   PL/SQL procedure successfully completed.
   ```

/if

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
   CREATE TABLE orders_append_heavy (
     id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
     json_document JSON,
     created_on TIMESTAMP DEFAULT SYSTIMESTAMP
   );
   ```

2. Create index on orderId (critical for collection):

   ```sql
   -- Index on orderId to collect all related documents
   CREATE INDEX idx_orders_orderid
   ON orders_append_heavy (JSON_VALUE(json_document, '$.orderId'));

   -- Index on document type for filtering
   CREATE INDEX idx_orders_type
   ON orders_append_heavy (JSON_VALUE(json_document, '$.type'));
   ```

### Step 2: Insert Order with Separate Event Documents

1. Insert initial order (small, stays inline):

   ```sql
   INSERT INTO orders_append_heavy (json_document) VALUES (
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
   ```

2. Append shipment information (separate document):

   ```sql
   INSERT INTO orders_append_heavy (json_document) VALUES (
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
   ```

3. Append invoice (separate document):

   ```sql
   INSERT INTO orders_append_heavy (json_document) VALUES (
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
   ```

4. Append payment information (separate document):

   ```sql
   INSERT INTO orders_append_heavy (json_document) VALUES (
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
   ```

5. Append stock update (separate document):

   ```sql
   INSERT INTO orders_append_heavy (json_document) VALUES (
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
   ```

6. Append order annotation (separate document):

   ```sql
   INSERT INTO orders_append_heavy (json_document) VALUES (
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
     JSON_VALUE(json_document, '$.type') AS document_type,
     JSON_VALUE(json_document, '$._id') AS document_id,
     LENGTHB(json_document) AS bytes,
     JSON_SERIALIZE(json_document PRETTY) AS document
   FROM orders_append_heavy
   WHERE JSON_VALUE(json_document, '$.orderId') = 'ORD-2024-001'
   ORDER BY created_on;
   ```

   **Result:** 7 documents returned, each under 2KB (all inline storage!)

2. Query just the order summary:

   ```sql
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM orders_append_heavy
   WHERE JSON_VALUE(json_document, '$.orderId') = 'ORD-2024-001'
     AND JSON_VALUE(json_document, '$.type') = 'order';
   ```

3. Query just shipments:

   ```sql
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM orders_append_heavy
   WHERE JSON_VALUE(json_document, '$.orderId') = 'ORD-2024-001'
     AND JSON_VALUE(json_document, '$.type') = 'shipment';
   ```

4. Get aggregated order status:

   ```sql
   SELECT
     MAX(CASE WHEN JSON_VALUE(json_document, '$.type') = 'order'
              THEN JSON_VALUE(json_document, '$.status') END) AS order_status,
     MAX(CASE WHEN JSON_VALUE(json_document, '$.type') = 'shipment'
              THEN JSON_VALUE(json_document, '$.trackingNumber') END) AS tracking,
     MAX(CASE WHEN JSON_VALUE(json_document, '$.type') = 'payment'
              THEN JSON_VALUE(json_document, '$.status') END) AS payment_status,
     COUNT(CASE WHEN JSON_VALUE(json_document, '$.type') = 'annotation' THEN 1 END) AS annotation_count
   FROM orders_append_heavy
   WHERE JSON_VALUE(json_document, '$.orderId') = 'ORD-2024-001';
   ```

### Step 4: Measure Document Sizes

1. Verify all documents stay in inline storage:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.type') AS type,
     JSON_VALUE(json_document, '$._id') AS id,
     LENGTHB(json_document) AS bytes,
     CASE
       WHEN LENGTHB(json_document) < 7950 THEN 'INLINE (Fast writes)'
       ELSE 'LOB (Slow writes)'
     END AS storage_tier
   FROM orders_append_heavy
   WHERE JSON_VALUE(json_document, '$.orderId') = 'ORD-2024-001'
   ORDER BY bytes DESC;
   ```

   **Expected Result:**
   ```
   TYPE            ID                  BYTES   STORAGE_TIER
   -------------   -----------------   -----   ------------------
   invoice         INVOICE-INV-001      1850   INLINE (Fast writes)
   order           ORD-2024-001         1620   INLINE (Fast writes)
   shipment        SHIPMENT-SH-001      1340   INLINE (Fast writes)
   payment         PAYMENT-PAY-001       680   INLINE (Fast writes)
   stock_update    STOCK-ST-001          590   INLINE (Fast writes)
   annotation      ANNOTATION-ANN-001    420   INLINE (Fast writes)
   ```

   **All documents in inline storage!** ✅

### Step 5: Compare Write Performance

1. Simulate appending to a growing document vs small documents:

   ```sql
   -- Create metrics table
   TRUNCATE TABLE performance_metrics;

   -- Test 1: Growing document (LOB cliff simulation)
   DECLARE
     v_start TIMESTAMP;
     v_end TIMESTAMP;
     v_doc CLOB;
   BEGIN
     -- Simulate large document (10KB)
     v_doc := RPAD('{"_id":"ORD-BIG","orderId":"ORD-BIG","items":[', 10000, '{"x":"data"},');
     v_doc := v_doc || ']}';

     FOR i IN 1..100 LOOP
       v_start := SYSTIMESTAMP;

       -- Simulate appending to large document (update)
       UPDATE orders_append_heavy
       SET json_document = JSON_MERGEPATCH(json_document,
         '{"lastUpdate":"' || TO_CHAR(SYSDATE, 'YYYY-MM-DD') || '"}')
       WHERE JSON_VALUE(json_document, '$.orderId') = 'ORD-BIG';

       v_end := SYSTIMESTAMP;

       INSERT INTO performance_metrics VALUES (
         'WRITE_APPEND', 'LARGE_DOCUMENT_UPDATE', 'UPDATE', i,
         EXTRACT(SECOND FROM (v_end - v_start)) * 1000,
         NULL, NULL, NULL, SYSTIMESTAMP,
         'Updating 10KB+ document (LOB storage)'
       );
     END LOOP;
     COMMIT;
   END;
   /

   -- Test 2: Small document inserts (inline storage)
   DECLARE
     v_start TIMESTAMP;
     v_end TIMESTAMP;
   BEGIN
     FOR i IN 1..100 LOOP
       v_start := SYSTIMESTAMP;

       -- Insert small annotation document (< 1KB, inline)
       INSERT INTO orders_append_heavy (json_document) VALUES (
         JSON_OBJECT(
           '_id' VALUE 'ANN-' || LPAD(i, 4, '0'),
           'orderId' VALUE 'ORD-2024-001',
           'type' VALUE 'annotation',
           'note' VALUE 'Test annotation ' || i,
           'createdDate' VALUE SYSTIMESTAMP
         )
       );

       v_end := SYSTIMESTAMP;

       INSERT INTO performance_metrics VALUES (
         'WRITE_APPEND', 'SMALL_DOCUMENT_INSERT', 'INSERT', i,
         EXTRACT(SECOND FROM (v_end - v_start)) * 1000,
         NULL, NULL, NULL, SYSTIMESTAMP,
         'Inserting small document (inline storage)'
       );
     END LOOP;
     COMMIT;
   END;
   /
   ```

2. Compare write performance:

   ```sql
   SELECT
     pattern_name,
     COUNT(*) AS iterations,
     ROUND(AVG(execution_time_ms), 2) AS avg_ms,
     ROUND(MIN(execution_time_ms), 2) AS min_ms,
     ROUND(MAX(execution_time_ms), 2) AS max_ms,
     ROUND(STDDEV(execution_time_ms), 2) AS stddev_ms
   FROM performance_metrics
   WHERE test_id = 'WRITE_APPEND'
   GROUP BY pattern_name
   ORDER BY avg_ms;
   ```

   **Expected Results:**
   ```
   PATTERN_NAME               ITERATIONS   AVG_MS   MIN_MS   MAX_MS   STDDEV_MS
   -----------------------   ----------   ------   ------   ------   ---------
   SMALL_DOCUMENT_INSERT           100     0.85     0.60     2.10        0.25
   LARGE_DOCUMENT_UPDATE           100     3.40     2.20     8.50        1.10
   ```

   **Analysis:**
   - Small document inserts: ~0.85ms (inline storage, fast!)
   - Large document updates: ~3.40ms (LOB storage, 4x slower)
   - **4x write performance improvement with small documents**

### Step 6: Benefits of Indexed Attribute Approach

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

## Task 8: Many-to-Many Relationships with Multivalue Indexes - Enterprise Content Management

In enterprise environments, shared assets like documents, images, templates, and specifications often belong to multiple projects simultaneously. When these artifacts have high rates of change (version updates, metadata changes, approvals), embedding them creates write amplification and stale data problems. This task demonstrates how to use **arrays of references with multivalue indexes** to implement many-to-many relationships that scale.

### The Problem: Embedded References for Shared Assets

**Scenario:** A company has design templates, legal documents, and brand assets shared across 20+ active projects. When a template is updated, all projects using it must reflect the change immediately.

**❌ Anti-Pattern: Embedding Document Content**

```json
// Project document with embedded template
{
  "_id": "PROJECT#acme-website",
  "type": "project",
  "name": "ACME Website Redesign",
  "templates": [
    {
      "id": "TMPL-header-001",
      "name": "Header Template v2.1",
      "content": "<!DOCTYPE html>...",  // 50KB embedded
      "lastModified": "2024-11-18",
      "approvedBy": "design-team"
    },
    {
      "id": "TMPL-footer-001",
      "content": "...",  // Another 30KB
      ...
    }
  ]
}
```

**Problems:**
- ❌ Template updated → Must update 20 project documents (write amplification)
- ❌ Documents bloat (project doc grows from 5KB to 200KB)
- ❌ Risk of stale data if updates miss some projects
- ❌ Duplicate storage of same template in 20 locations

### ✅ Solution: Array of Project Paths with Multivalue Index

**Pattern:** Store artifacts once, track all project locations in an array

```json
// Artifact document (single source of truth)
{
  "_id": "ARTIFACT#TMPL-header-001",
  "type": "artifact",
  "artifactType": "template",
  "name": "Corporate Header Template",
  "version": "2.1",
  "content": "<!DOCTYPE html>...",  // 50KB stored once
  "lastModified": "2024-11-18T14:30:00Z",
  "approvedBy": "design-team",
  "projectPaths": [
    "/acme/website/frontend/templates",
    "/acme/mobile-app/ui/headers",
    "/acme/partner-portal/layouts",
    "/internal/design-system/components",
    "/marketing/email-templates/headers"
  ]
}
```

**Benefits:**
- ✅ Update artifact once → Immediately reflected in all 20 projects
- ✅ No duplication → 50KB stored once, not 20 times
- ✅ No stale data → Single source of truth
- ✅ Multivalue index on `projectPaths` array → Fast hierarchical queries

### Step 1: Create Artifact Collection with Multivalue Index

1. Create collection for shared artifacts:

   ```sql
   CREATE TABLE enterprise_artifacts (
     id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
     json_document JSON,
     created_on TIMESTAMP DEFAULT SYSTIMESTAMP
   );
   ```

2. Create multivalue index on the projectPaths array:

   ```sql
   -- Multivalue index on array elements
   CREATE INDEX idx_artifact_project_paths
   ON enterprise_artifacts (
     JSON_VALUE(json_document, '$.projectPaths[*]' RETURNING VARCHAR2(500))
   );

   -- Index on artifact type for filtering
   CREATE INDEX idx_artifact_type
   ON enterprise_artifacts (JSON_VALUE(json_document, '$.artifactType'));
   ```

   **Expected Output:**
   ```
   Table created.
   Index created.
   Index created.
   ```

### Step 2: Insert Shared Artifacts

1. Insert a template used across multiple projects:

   **SQL Approach:**

if type="sql"

   ```sql
   <copy>
   INSERT INTO enterprise_artifacts (json_document) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ARTIFACT#TMPL-header-001',
       'type' VALUE 'artifact',
       'artifactType' VALUE 'template',
       'name' VALUE 'Corporate Header Template',
       'version' VALUE '2.1',
       'fileName' VALUE 'header_v2.1.html',
       'sizeBytes' VALUE 51200,
       'lastModified' VALUE '2024-11-18T14:30:00Z',
       'modifiedBy' VALUE 'USER#jane-designer',
       'approvedBy' VALUE 'design-team',
       'projectPaths' VALUE JSON_ARRAY(
         '/acme/website/frontend/templates',
         '/acme/mobile-app/ui/headers',
         '/acme/partner-portal/layouts',
         '/internal/design-system/components',
         '/marketing/email-templates/headers'
       ),
       'metadata' VALUE JSON_OBJECT(
         'license' VALUE 'internal-use-only',
         'category' VALUE 'ui-component',
         'tags' VALUE JSON_ARRAY('header', 'responsive', 'branded')
       )
     )
   );
   </copy>
   ```

   Expected output:
   ```
   1 row created.
   ```

/if

   **SODA Approach:**

if type="soda"

   ```sql
   <copy>
   DECLARE
     collection SODA_COLLECTION_T;
     status NUMBER;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('enterprise_artifacts');

     status := collection.insert_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw('{
           "_id": "ARTIFACT#TMPL-header-001",
           "type": "artifact",
           "artifactType": "template",
           "name": "Corporate Header Template",
           "version": "2.1",
           "fileName": "header_v2.1.html",
           "sizeBytes": 51200,
           "lastModified": "2024-11-18T14:30:00Z",
           "modifiedBy": "USER#jane-designer",
           "approvedBy": "design-team",
           "projectPaths": [
             "/acme/website/frontend/templates",
             "/acme/mobile-app/ui/headers",
             "/acme/partner-portal/layouts",
             "/internal/design-system/components",
             "/marketing/email-templates/headers"
           ],
           "metadata": {
             "license": "internal-use-only",
             "category": "ui-component",
             "tags": ["header", "responsive", "branded"]
           }
         }')
       )
     );

     IF status = 1 THEN
       DBMS_OUTPUT.PUT_LINE('1 row created.');
     END IF;
   END;
   /
   </copy>
   ```

   Expected output:
   ```
   1 row created.

   PL/SQL procedure successfully completed.
   ```

/if

2. Insert a legal document shared across business units:

   ```sql
   INSERT INTO enterprise_artifacts (json_document) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ARTIFACT#DOC-privacy-policy',
       'type' VALUE 'artifact',
       'artifactType' VALUE 'legal-document',
       'name' VALUE 'Privacy Policy - GDPR Compliant',
       'version' VALUE '3.0',
       'fileName' VALUE 'privacy_policy_v3.pdf',
       'sizeBytes' VALUE 245000,
       'lastModified' VALUE '2024-11-15T09:00:00Z',
       'modifiedBy' VALUE 'USER#legal-team',
       'approvedBy' VALUE 'legal,compliance',
       'projectPaths' VALUE JSON_ARRAY(
         '/acme/website/legal/policies',
         '/acme/mobile-app/settings/legal',
         '/acme/partner-portal/footer/legal',
         '/acme/customer-portal/help/legal'
       ),
       'metadata' VALUE JSON_OBJECT(
         'requiresAcknowledgment' VALUE true,
         'effectiveDate' VALUE '2024-12-01',
         'jurisdiction' VALUE 'EU,US,UK'
       )
     )
   );
   ```

3. Insert a brand asset used everywhere:

   ```sql
   INSERT INTO enterprise_artifacts (json_document) VALUES (
     JSON_OBJECT(
       '_id' VALUE 'ARTIFACT#IMG-logo-primary',
       'type' VALUE 'artifact',
       'artifactType' VALUE 'image',
       'name' VALUE 'ACME Primary Logo',
       'version' VALUE '1.5',
       'fileName' VALUE 'acme_logo_primary.svg',
       'sizeBytes' VALUE 12800,
       'lastModified' VALUE '2024-10-01T10:00:00Z',
       'modifiedBy' VALUE 'USER#brand-team',
       'approvedBy' VALUE 'marketing,legal',
       'projectPaths' VALUE JSON_ARRAY(
         '/acme/website/assets/images',
         '/acme/mobile-app/assets/logos',
         '/acme/partner-portal/branding',
         '/marketing/campaigns/2024-q4',
         '/marketing/social-media/assets',
         '/internal/presentations/templates',
         '/sales/proposals/assets'
       ),
       'metadata' VALUE JSON_OBJECT(
         'format' VALUE 'SVG',
         'colorProfile' VALUE 'RGB',
         'usageRights' VALUE 'all-channels'
       )
     )
   );
   ```

   **Expected Output:**
   ```
   1 row created.

   1 row created.

   1 row created.


   Commit complete.
   ```

### Step 3: Query Artifacts by Project Path (Exact Match)

1. Find all artifacts used in the website project:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS artifact_name,
     JSON_VALUE(json_document, '$.artifactType') AS type,
     JSON_VALUE(json_document, '$.version') AS version,
     JSON_VALUE(json_document, '$.lastModified') AS last_modified
   FROM enterprise_artifacts
   WHERE JSON_EXISTS(json_document, '$.projectPaths[*]?(@ == "/acme/website/frontend/templates")');
   ```

   **Expected Output:**
   ```
   ARTIFACT_NAME                       TYPE            VERSION  LAST_MODIFIED
   ----------------------------------- --------------- -------- -------------------------
   Corporate Header Template           template        2.1      2024-11-18T14:30:00Z
   ```

### Step 4: Hierarchical Queries - Find All Artifacts at or Below a Path

**Key Feature:** Use LIKE queries to find all artifacts associated with a project and all its sub-projects.

1. Find all artifacts used in the ACME website project (any subpath):

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS artifact_name,
     JSON_VALUE(json_document, '$.artifactType') AS type
   FROM enterprise_artifacts
   WHERE JSON_EXISTS(json_document, '$.projectPaths[*]?(@ starts with "/acme/website")');
   ```

   **Expected Output:**
   ```
   ARTIFACT_NAME                       TYPE
   ----------------------------------- ---------------
   Corporate Header Template           template
   Privacy Policy - GDPR Compliant     legal-document
   ACME Primary Logo                   image
   ```

2. Find all artifacts used in ALL marketing projects:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS artifact_name,
     JSON_VALUE(json_document, '$.artifactType') AS type,
     JSON_VALUE(json_document, '$.version') AS version
   FROM enterprise_artifacts
   WHERE JSON_EXISTS(json_document, '$.projectPaths[*]?(@ starts with "/marketing")')
   ORDER BY artifact_name;
   ```

   **Expected Output:**
   ```
   ARTIFACT_NAME                       TYPE            VERSION
   ----------------------------------- --------------- --------
   ACME Primary Logo                   image           1.5
   Corporate Header Template           template        2.1
   ```

### Step 5: Update Artifact - Immediate Reflection Everywhere

**Key Benefit:** Update the artifact once, and it's immediately visible to all projects referencing it.

1. Update the header template version:

   **SQL Approach:**

if type="sql"

   ```sql
   <copy>
   UPDATE enterprise_artifacts
   SET json_document = JSON_TRANSFORM(
     json_document,
     SET '$.version' = '2.2',
     SET '$.lastModified' = '2024-11-19T10:00:00Z',
     SET '$.modifiedBy' = 'USER#bob-developer'
   )
   WHERE JSON_VALUE(json_document, '$._id') = 'ARTIFACT#TMPL-header-001';

   COMMIT;
   </copy>
   ```

   Expected output:
   ```
   1 row updated.

   Commit complete.
   ```

/if

   **SODA Approach:**

if type="soda"

   ```sql
   <copy>
   DECLARE
     collection SODA_COLLECTION_T;
     doc SODA_DOCUMENT_T;
     doc_content CLOB;
     merged_content CLOB;
     status NUMBER;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('enterprise_artifacts');

     -- Get the existing document
     doc := collection.find().key('ARTIFACT#TMPL-header-001').get_one();

     IF doc IS NOT NULL THEN
       doc_content := doc.get_clob();

       -- Merge the updates using JSON_MERGEPATCH
       SELECT JSON_MERGEPATCH(doc_content, '{
         "version": "2.2",
         "lastModified": "2024-11-19T10:00:00Z",
         "modifiedBy": "USER#bob-developer"
       }')
       INTO merged_content
       FROM DUAL;

       -- Replace with merged document
       status := collection.find().key('ARTIFACT#TMPL-header-001').replace_one(
         SODA_DOCUMENT_T(b_content => UTL_RAW.cast_to_raw(merged_content))
       );

       IF status = 1 THEN
         DBMS_OUTPUT.PUT_LINE('1 row updated.');
         DBMS_OUTPUT.PUT_LINE('');
         DBMS_OUTPUT.PUT_LINE('Commit complete.');
       END IF;

       COMMIT;
     END IF;
   END;
   /
   </copy>
   ```

   Expected output:
   ```
   1 row updated.

   Commit complete.

   PL/SQL procedure successfully completed.
   ```

/if

   **Expected Output:**
   ```
   1 row updated.


   Commit complete.
   ```

2. Verify update is reflected across ALL project paths:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS artifact_name,
     JSON_VALUE(json_document, '$.version') AS version,
     JSON_VALUE(json_document, '$.lastModified') AS last_modified,
     JSON_VALUE(json_document, '$.modifiedBy') AS modified_by
   FROM enterprise_artifacts
   WHERE JSON_VALUE(json_document, '$._id') = 'ARTIFACT#TMPL-header-001';
   ```

   **Expected Output:**
   ```
   ARTIFACT_NAME                       VERSION  LAST_MODIFIED             MODIFIED_BY
   ----------------------------------- -------- ------------------------- --------------------
   Corporate Header Template           2.2      2024-11-19T10:00:00Z      USER#bob-developer
   ```

   **Result:** ✅ One update, instantly visible in all 5 projects. No write amplification, no stale data!

### Step 6: Add New Project Location to Existing Artifact

1. A new project starts using the logo - just append to the array:

   **SQL Approach:**

if type="sql"

   ```sql
   <copy>
   UPDATE enterprise_artifacts
   SET json_document = JSON_TRANSFORM(
     json_document,
     APPEND '$.projectPaths' = '/acme/investor-relations/assets'
   )
   WHERE JSON_VALUE(json_document, '$._id') = 'ARTIFACT#IMG-logo-primary';

   COMMIT;
   </copy>
   ```

   Expected output:
   ```
   1 row updated.

   Commit complete.
   ```

/if

   **SODA Approach:**

if type="soda"

   > **Note:** SODA doesn't have a direct APPEND operation. Use fetch-transform-replace pattern:

   ```sql
   <copy>
   DECLARE
     collection SODA_COLLECTION_T;
     doc SODA_DOCUMENT_T;
     doc_content CLOB;
     transformed_content CLOB;
     status NUMBER;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('enterprise_artifacts');

     -- Get the existing document
     doc := collection.find().key('ARTIFACT#IMG-logo-primary').get_one();

     IF doc IS NOT NULL THEN
       doc_content := doc.get_clob();

       -- Use JSON_TRANSFORM APPEND in SQL to add to array
       SELECT JSON_TRANSFORM(
         doc_content,
         APPEND '$.projectPaths' = '/acme/investor-relations/assets'
       )
       INTO transformed_content
       FROM DUAL;

       -- Replace with transformed document
       status := collection.find().key('ARTIFACT#IMG-logo-primary').replace_one(
         SODA_DOCUMENT_T(b_content => UTL_RAW.cast_to_raw(transformed_content))
       );

       IF status = 1 THEN
         DBMS_OUTPUT.PUT_LINE('1 row updated.');
         DBMS_OUTPUT.PUT_LINE('');
         DBMS_OUTPUT.PUT_LINE('Commit complete.');
       END IF;

       COMMIT;
     END IF;
   END;
   /
   </copy>
   ```

   Expected output:
   ```
   1 row updated.

   Commit complete.

   PL/SQL procedure successfully completed.
   ```

/if

2. Verify the new path is added:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS artifact_name,
     JSON_QUERY(json_document, '$.projectPaths' RETURNING VARCHAR2(2000) PRETTY) AS project_paths
   FROM enterprise_artifacts
   WHERE JSON_VALUE(json_document, '$._id') = 'ARTIFACT#IMG-logo-primary';
   ```

   **Expected Output:**
   ```
   1 row updated.


   Commit complete.
   ```

   Verify the path was added:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS artifact_name,
     (SELECT COUNT(*)
      FROM JSON_TABLE(json_document, '$.projectPaths[*]' COLUMNS (path VARCHAR2(500) PATH '$'))
     ) AS project_count
   FROM enterprise_artifacts
   WHERE JSON_VALUE(json_document, '$._id') = 'ARTIFACT#IMG-logo-primary';
   ```

   **Expected Output:**
   ```
   ARTIFACT_NAME          PROJECT_COUNT
   ---------------------- -------------
   ACME Primary Logo      8
   ```

### Step 7: Aggregate Queries - Project Asset Reports

1. Count artifacts by type used in website project:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.artifactType') AS artifact_type,
     COUNT(*) AS artifact_count,
     SUM(JSON_VALUE(json_document, '$.sizeBytes' RETURNING NUMBER)) AS total_bytes
   FROM enterprise_artifacts
   WHERE JSON_EXISTS(json_document, '$.projectPaths[*]?(@ starts with "/acme/website")')
   GROUP BY JSON_VALUE(json_document, '$.artifactType')
   ORDER BY artifact_count DESC;
   ```

   **Expected Output:**
   ```
   ARTIFACT_TYPE      ARTIFACT_COUNT  TOTAL_BYTES
   ------------------ -------------- ------------
   template           1              51200
   legal-document     1              245000
   image              1              12800
   ```

2. Find artifacts used in the most projects (most-used assets):

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS artifact_name,
     JSON_VALUE(json_document, '$.artifactType') AS type,
     (SELECT COUNT(*)
      FROM JSON_TABLE(json_document, '$.projectPaths[*]' COLUMNS (path VARCHAR2(500) PATH '$'))
     ) AS project_count
   FROM enterprise_artifacts
   ORDER BY project_count DESC;
   ```

   **Expected Output:**
   ```
   ARTIFACT_NAME                       TYPE            PROJECT_COUNT
   ----------------------------------- --------------- -------------
   ACME Primary Logo                   image                       8
   Corporate Header Template           template                    5
   Privacy Policy - GDPR Compliant     legal-document              4
   ```

### Key Benefits of This Pattern

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

**✅ Flexible Many-to-Many Relationships**
- Artifact can belong to unlimited projects
- Project can reference unlimited artifacts
- No junction table needed
- Bidirectional queries supported

### When to Use Array-Based Many-to-Many

**✓ Use this pattern when:**
- Shared resources belong to multiple entities
- High rate of change requires single source of truth
- Need hierarchical or path-based queries
- Array size is bounded (< 1000 references per document)
- Need to avoid write amplification

**✗ Don't use when:**
- Array could grow unbounded (> 10,000 items)
- Need complex filtering on array elements (better as separate docs)
- Relationships change more frequently than content

### Comparison with Alternatives

| Approach | Storage | Update Cost | Query Speed | Stale Data Risk |
|----------|---------|-------------|-------------|-----------------|
| **Array of Paths** (This pattern) | 1x | 1 write | Fast (indexed) | None |
| Embedded Content | 20x | 20 writes | Fast | High |
| Separate Junction Collection | 1x | 1-2 writes | Slow (join) | None |

**Winner:** Array-based pattern combines best of both worlds!

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
* ✅ Hierarchical path queries with startsWith for aggregation
* ✅ Eliminating write amplification with single source of truth pattern
* ✅ Avoiding the 32MB OSON limit and LOB performance cliffs
* ✅ Measuring query performance improvements
* ✅ Real-world e-commerce and enterprise content management implementations
* ✅ Anti-patterns to avoid

### Key Performance Results

- **Single Collection: 1-2ms** average query time
- **Multi Collection: 20-30ms** average query time
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

* [AWS DynamoDB Single Table Design Patterns](https://aws.amazon.com/blogs/database/single-table-vs-multi-table-design-in-amazon-dynamodb/)
* [MongoDB Data Modeling](https://www.mongodb.com/docs/manual/data-modeling/)
* [Oracle JSON Collections Performance](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/performance-tuning-for-json.html)
* [OSON Binary Format](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/oson-format.html)

## Acknowledgements

* **Author** - Rick Houlihan
* **Contributors** - Oracle JSON Development Team, Oracle LiveLabs Team
* **Last Updated By/Date** - Rick Houlihan, November 2024
