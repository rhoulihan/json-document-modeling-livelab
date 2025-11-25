# JSON Collections Fundamentals

## Introduction

This lab introduces you to Oracle JSON Collection Tables, teaching you how to create collections, insert documents, query data, and understand Oracle's OSON (Oracle Optimized Binary JSON) format. You will work with both SQL/JSON functions and the MongoDB-compatible API.

By the end of this lab, you will understand how Oracle JSON Collection Tables provide the flexibility of NoSQL with the power and reliability of Oracle Database.

Estimated Time: 30 minutes

### Objectives

In this lab, you will:

* Create JSON Collection Tables using the `CREATE JSON COLLECTION TABLE` syntax
* Insert JSON documents with various data types (strings, numbers, arrays, nested objects)
* Query documents using JSON_VALUE, JSON_QUERY, and JSON_TABLE
* Update and delete documents using JSON_MERGEPATCH and JSON_TRANSFORM
* Understand OSON binary format and its performance implications
* Create indexes on JSON data for query optimization
* Compare SQL and MongoDB API syntax
* Measure document sizes and query performance

### Prerequisites

This lab assumes you have:

* Completed Lab 0: Setup
* Access to Oracle AI Database 26ai as JSONUSER
* Basic understanding of JSON format

## Task 1: Create JSON Collection Tables

Oracle AI Database 26ai introduces JSON Collection Tables - single-column tables optimized for JSON document storage.

### Step 1: Create a Products Collection

1. Create the products collection:

   ```sql
   CREATE JSON COLLECTION TABLE products;
   ```

   **Expected output:**
   ```
   Table created.
   ```

2. Verify the collection was created:

   ```sql
   SELECT collection_name, collection_type
   FROM user_json_collections;
   ```

   Expected output:
   ```
   COLLECTION_NAME    COLLECTION_TYPE
   ----------------   ---------------
   PRODUCTS           TABLE
   TEST_COLLECTION    TABLE
   ```

3. Examine the table structure:

   ```sql
   DESC products
   ```

   Output:
   ```
   Name   Null?    Type
   ----   -----    ----
   DATA            JSON
   ```

   > **Key Point:** JSON Collection Tables have a single `DATA` column of type JSON. The database automatically injects an `_id` field into each document for identification.

### Step 2: Create a Customers Collection

1. Create another collection for customers:

   ```sql
   CREATE JSON COLLECTION TABLE customers;
   ```

### Step 3: Understanding JSON Collection Tables

**JSON Collection Tables in 26ai:**
- Single `DATA` column of type JSON
- Automatic `_id` generation (RAW type internally)
- Support for partitioning (lifecycle management, RAC performance)
- Full SQL/JSON query capabilities
- MongoDB API compatible

**Querying collection metadata:**
```sql
-- View all JSON collections in your schema
SELECT * FROM user_json_collections;

-- View only JSON Collection Tables
SELECT * FROM user_json_collection_tables;
```

## Task 2: Insert JSON Documents

Let's populate our collections with sample data representing an e-commerce product catalog.

### Step 1: Insert Documents

1. Insert a product document:

   ```sql
   INSERT INTO products (data)
   VALUES (
     JSON_OBJECT(
       '_id' VALUE 'PROD-001',
       'name' VALUE 'Wireless Bluetooth Headphones',
       'category' VALUE 'Electronics',
       'brand' VALUE 'AudioTech',
       'price' VALUE 79.99,
       'currency' VALUE 'USD',
       'in_stock' VALUE true,
       'quantity' VALUE 45,
       'tags' VALUE JSON_ARRAY('wireless', 'bluetooth', 'audio', 'headphones'),
       'specifications' VALUE JSON_OBJECT(
         'color' VALUE 'Black',
         'weight_oz' VALUE 8.5,
         'battery_hours' VALUE 30,
         'bluetooth_version' VALUE '5.0'
       ),
       'rating' VALUE JSON_OBJECT(
         'average' VALUE 4.5,
         'count' VALUE 127
       )
     )
   );

   COMMIT;
   ```

   **MongoDB API Approach:**

   ```javascript
   // Connect to Oracle using MongoDB API (via ORDS)
   // Note: MongoDB API requires ACL configuration on Autonomous Database
   // mongosh "mongodb://jsonuser:WelcomeJson%23123@localhost:27017/jsonuser?authMechanism=PLAIN&authSource=$external&tls=false"

   use jsonuser

   // Insert document using MongoDB syntax
   db.products.insertOne({
     _id: "PROD-001",
     name: "Wireless Bluetooth Headphones",
     category: "Electronics",
     brand: "AudioTech",
     price: 79.99,
     currency: "USD",
     in_stock: true,
     quantity: 45,
     tags: ["wireless", "bluetooth", "audio", "headphones"],
     specifications: {
       color: "Black",
       weight_oz: 8.5,
       battery_hours: 30,
       bluetooth_version: "5.0"
     },
     rating: {
       average: 4.5,
       count: 127
     }
   })
   ```

   Expected output:
   ```json
   {
     "acknowledged": true,
     "insertedId": "PROD-001"
   }
   ```

   > **Note:** MongoDB API allows you to use familiar MongoDB syntax and tools (mongosh, MongoDB Compass) to work with Oracle Database.

   **REST API Approach:**

   ```bash
   # Insert document via ORDS SODA REST API
   # Prerequisite: Schema must be REST-enabled (EXEC ORDS.ENABLE_SCHEMA;)
   curl -X POST \
     http://localhost:8080/ords/jsonuser/soda/latest/products \
     -H 'Content-Type: application/json' \
     -d '{
       "_id": "PROD-001",
       "name": "Wireless Bluetooth Headphones",
       "category": "Electronics",
       "brand": "AudioTech",
       "price": 79.99,
       "currency": "USD",
       "in_stock": true,
       "quantity": 45,
       "tags": ["wireless", "bluetooth", "audio", "headphones"],
       "specifications": {
         "color": "Black",
         "weight_oz": 8.5,
         "battery_hours": 30,
         "bluetooth_version": "5.0"
       },
       "rating": {
         "average": 4.5,
         "count": 127
       }
     }'
   ```

   Expected output:
   ```json
   {
     "id": "PROD-001",
     "etag": "...",
     "lastModified": "2025-11-20T12:30:45.123Z"
   }
   ```

   > **Note:** REST API enables web and mobile applications to interact with JSON Collections over HTTP.

   **Python Approach:**

   ```python
   import oracledb
   import json

   # Connect to Oracle Database
   connection = oracledb.connect(
       user="jsonuser",
       password="WelcomeJson#123",
       dsn="localhost:1522/myatp_low"
   )

   cursor = connection.cursor()

   # Insert document using SQL
   doc = {
       "_id": "PROD-001",
       "name": "Wireless Bluetooth Headphones",
       "category": "Electronics",
       "brand": "AudioTech",
       "price": 79.99,
       "currency": "USD",
       "in_stock": True,
       "quantity": 45,
       "tags": ["wireless", "bluetooth", "audio", "headphones"],
       "specifications": {
           "color": "Black",
           "weight_oz": 8.5,
           "battery_hours": 30,
           "bluetooth_version": "5.0"
       },
       "rating": {
           "average": 4.5,
           "count": 127
       }
   }

   cursor.execute(
       "INSERT INTO products (data) VALUES (:1)",
       [json.dumps(doc)]
   )

   connection.commit()
   print("1 row created.")
   connection.close()
   ```

   Expected output:
   ```
   1 row created.
   ```

   > **Note:** Python's python-oracledb driver provides native JSON support for data science and Python applications.

2. Insert additional products (individual INSERT statements):

   > **Note on `_id` values:**
   > - Custom `_id` values (strings like 'PROD-001') are fully supported
   > - Essential for composite key patterns (e.g., 'CUSTOMER#123#ORDER#456')
   > - If omitted, database auto-generates a RAW-based `_id`
   > - Once set, `_id` cannot be changed (immutable)

   ```sql
   -- Insert PROD-002
   INSERT INTO products (data)
   VALUES (JSON_OBJECT(
     '_id' VALUE 'PROD-002',
     'name' VALUE 'Ergonomic Wireless Mouse',
     'category' VALUE 'Electronics',
     'brand' VALUE 'TechComfort',
     'price' VALUE 34.99,
     'currency' VALUE 'USD',
     'in_stock' VALUE true,
     'quantity' VALUE 120,
     'tags' VALUE JSON_ARRAY('wireless', 'ergonomic', 'mouse', 'computer'),
     'specifications' VALUE JSON_OBJECT(
       'color' VALUE 'Silver',
       'dpi' VALUE 1600,
       'buttons' VALUE 6,
       'battery_months' VALUE 18
     ),
     'rating' VALUE JSON_OBJECT(
       'average' VALUE 4.7,
       'count' VALUE 342
     )
   ));

   -- Insert PROD-003
   INSERT INTO products (data)
   VALUES (JSON_OBJECT(
     '_id' VALUE 'PROD-003',
     'name' VALUE 'Mechanical Gaming Keyboard',
     'category' VALUE 'Electronics',
     'brand' VALUE 'GamePro',
     'price' VALUE 129.99,
     'currency' VALUE 'USD',
     'in_stock' VALUE true,
     'quantity' VALUE 67,
     'tags' VALUE JSON_ARRAY('mechanical', 'gaming', 'keyboard', 'rgb'),
     'specifications' VALUE JSON_OBJECT(
       'switch_type' VALUE 'Cherry MX Red',
       'rgb_lighting' VALUE true,
       'keys' VALUE 104,
       'wired' VALUE true
     ),
     'rating' VALUE JSON_OBJECT(
       'average' VALUE 4.8,
       'count' VALUE 891
     )
   ));

   -- Insert PROD-004
   INSERT INTO products (data)
   VALUES (JSON_OBJECT(
     '_id' VALUE 'PROD-004',
     'name' VALUE '27-inch 4K Monitor',
     'category' VALUE 'Electronics',
     'brand' VALUE 'ViewPerfect',
     'price' VALUE 449.99,
     'currency' VALUE 'USD',
     'in_stock' VALUE false,
     'quantity' VALUE 0,
     'tags' VALUE JSON_ARRAY('monitor', '4k', 'display', 'gaming'),
     'specifications' VALUE JSON_OBJECT(
       'screen_size' VALUE '27 inch',
       'resolution' VALUE '3840x2160',
       'refresh_rate' VALUE 144,
       'panel_type' VALUE 'IPS'
     ),
     'rating' VALUE JSON_OBJECT(
       'average' VALUE 4.6,
       'count' VALUE 234
     )
   ));

   COMMIT;
   ```

3. Verify the products were inserted:

   ```sql
   SELECT COUNT(*) FROM products;
   ```

   Expected output: `4` (including the first product)

### Step 2: Insert Documents with Raw JSON

You can also insert JSON documents as raw JSON strings:

1. Insert a customer document:

   ```sql
   INSERT INTO customers (data)
   VALUES ('{
     "_id": "CUST-001",
     "name": "Alice Johnson",
     "email": "alice.johnson@email.com",
     "phone": "+1-555-0123",
     "address": {
       "street": "123 Main Street",
       "city": "San Francisco",
       "state": "CA",
       "zip": "94105",
       "country": "USA"
     },
     "preferences": {
       "newsletter": true,
       "notifications": "email"
     },
     "loyalty_points": 1250,
     "member_since": "2023-03-15"
   }');

   COMMIT;
   ```

2. Insert another customer:

   ```sql
   INSERT INTO customers (data) VALUES (
     '{"_id": "CUST-002", "name": "Bob Martinez", "email": "bob.m@email.com", "phone": "+1-555-0124", "address": {"street": "456 Oak Avenue", "city": "Austin", "state": "TX", "zip": "78701", "country": "USA"}, "preferences": {"newsletter": false, "notifications": "sms"}, "loyalty_points": 890, "member_since": "2023-06-22"}'
   );

   COMMIT;
   ```

## Task 3: Query JSON Documents

Oracle provides powerful SQL/JSON functions to query JSON data. Let's explore the main functions.

### Step 1: Query with JSON_VALUE (Extract Scalar Values)

`JSON_VALUE` extracts a single scalar value (string, number, boolean) from a JSON document.

1. Extract product names and prices:

   ```sql
   SELECT
     JSON_VALUE(data, '$._id') AS product_id,
     JSON_VALUE(data, '$.name') AS product_name,
     JSON_VALUE(data, '$.price' RETURNING NUMBER) AS price
   FROM products
   ORDER BY price;
   ```

   Expected output:
   ```
   PRODUCT_ID   PRODUCT_NAME                      PRICE
   ----------   ------------------------------   -------
   PROD-002     Ergonomic Wireless Mouse           34.99
   PROD-001     Wireless Bluetooth Headphones      79.99
   PROD-003     Mechanical Gaming Keyboard        129.99
   PROD-004     27-inch 4K Monitor                449.99
   ```

2. Filter products by category and availability:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS product_name,
     JSON_VALUE(data, '$.price' RETURNING NUMBER) AS price,
     JSON_VALUE(data, '$.quantity' RETURNING NUMBER) AS quantity
   FROM products
   WHERE JSON_VALUE(data, '$.category') = 'Electronics'
     AND JSON_VALUE(data, '$.in_stock' RETURNING VARCHAR2) = 'true'
   ORDER BY price;
   ```

   Expected output:
   ```
   PRODUCT_NAME                      PRICE   QUANTITY
   ------------------------------   ------   --------
   Ergonomic Wireless Mouse          34.99       120
   Wireless Bluetooth Headphones     79.99        45
   Mechanical Gaming Keyboard       129.99        67
   ```

   **MongoDB API Approach:**

   ```javascript
   // Connect to Oracle using MongoDB API
   // mongosh "mongodb://jsonuser:WelcomeJson%23123@localhost:27017/jsonuser?authMechanism=PLAIN&authSource=$external&tls=false"

   use jsonuser

   // Find products by category and in_stock status
   db.products.find(
     {
       category: "Electronics",
       in_stock: true
     },
     {
       _id: 1,
       name: 1,
       price: 1,
       quantity: 1
     }
   ).sort({ price: 1 })
   ```

   Expected output:
   ```javascript
   [
     {
       _id: 'PROD-002',
       name: 'Ergonomic Wireless Mouse',
       price: 34.99,
       quantity: 120
     },
     {
       _id: 'PROD-001',
       name: 'Wireless Bluetooth Headphones',
       price: 79.99,
       quantity: 45
     },
     {
       _id: 'PROD-003',
       name: 'Mechanical Gaming Keyboard',
       price: 129.99,
       quantity: 67
     }
   ]
   ```

   > **MongoDB API**: Use familiar MongoDB query syntax with Oracle Database. The `find()` method accepts filter criteria and projection fields.

   **REST API Approach:**

   ```bash
   # Query products using ORDS SODA REST API with QBE (Query By Example)
   curl -X POST \
     "http://localhost:8080/ords/jsonuser/soda/latest/products?action=query" \
     -H "Content-Type: application/json" \
     -d '{
       "$query": {
         "category": "Electronics",
         "in_stock": true
       },
       "$orderby": {
         "price": 1
       },
       "$fields": {
         "_id": 1,
         "name": 1,
         "price": 1,
         "quantity": 1
       }
     }'
   ```

   Expected output:
   ```json
   {
     "items": [
       {
         "_id": "PROD-002",
         "name": "Ergonomic Wireless Mouse",
         "price": 34.99,
         "quantity": 120
       },
       {
         "_id": "PROD-001",
         "name": "Wireless Bluetooth Headphones",
         "price": 79.99,
         "quantity": 45
       },
       {
         "_id": "PROD-003",
         "name": "Mechanical Gaming Keyboard",
         "price": 129.99,
         "quantity": 67
       }
     ],
     "hasMore": false,
     "count": 3
   }
   ```

   > **REST API**: Use QBE (Query By Example) syntax with `$query`, `$orderby`, and `$fields` operators via HTTP POST.

   **Python Approach:**

   ```python
   import oracledb

   connection = oracledb.connect(
       user="jsonuser",
       password="WelcomeJson#123",
       dsn="localhost:1522/myatp_low"
   )

   cursor = connection.cursor()

   # Find products by category and in_stock status
   cursor.execute("""
       SELECT
         JSON_VALUE(data, '$.name') AS product_name,
         JSON_VALUE(data, '$.price' RETURNING NUMBER) AS price,
         JSON_VALUE(data, '$.quantity' RETURNING NUMBER) AS quantity
       FROM products
       WHERE JSON_VALUE(data, '$.category') = 'Electronics'
         AND JSON_VALUE(data, '$.in_stock' RETURNING VARCHAR2) = 'true'
       ORDER BY price
   """)

   print("Filtered Products (category=Electronics, in_stock=true):")
   print("-" * 60)

   for row in cursor:
       print(f"Product: {row[0]}, Price: ${row[1]}, Qty: {row[2]}")

   connection.close()
   ```

   Expected output:
   ```
   Filtered Products (category=Electronics, in_stock=true):
   ------------------------------------------------------------
   Product: Ergonomic Wireless Mouse, Price: $34.99, Qty: 120
   Product: Wireless Bluetooth Headphones, Price: $79.99, Qty: 45
   Product: Mechanical Gaming Keyboard, Price: $129.99, Qty: 67
   ```

   > **Python**: Use standard SQL/JSON syntax with parameterized queries for Python applications.

3. Extract nested values:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS product_name,
     JSON_VALUE(data, '$.specifications.color') AS color,
     JSON_VALUE(data, '$.rating.average' RETURNING NUMBER) AS rating
   FROM products
   WHERE JSON_VALUE(data, '$.rating.average' RETURNING NUMBER) >= 4.5
   ORDER BY rating DESC;
   ```

### Step 2: Query with JSON_QUERY (Extract Objects and Arrays)

`JSON_QUERY` extracts JSON objects or arrays (non-scalar values).

1. Extract the specifications object:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS product_name,
     JSON_QUERY(data, '$.specifications') AS specifications
   FROM products;
   ```

2. Extract the tags array:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS product_name,
     JSON_QUERY(data, '$.tags') AS tags
   FROM products;
   ```

3. Pretty-print entire documents:

   ```sql
   SELECT
     JSON_VALUE(data, '$._id') AS id,
     JSON_SERIALIZE(data PRETTY) AS document
   FROM products
   WHERE JSON_VALUE(data, '$._id') = 'PROD-001';
   ```

### Step 3: Query with JSON_TABLE (Convert JSON to Relational Rows)

`JSON_TABLE` converts JSON data into relational rows and columns - extremely useful for analytics.

1. Expand product tags into rows:

   ```sql
   SELECT
     JSON_VALUE(p.data, '$.name') AS product_name,
     jt.tag
   FROM products p,
     JSON_TABLE(p.data, '$.tags[*]'
       COLUMNS (
         tag VARCHAR2(50) PATH '$'
       )
     ) jt
   ORDER BY product_name, tag;
   ```

   Expected output:
   ```
   PRODUCT_NAME                      TAG
   ------------------------------   -----------
   27-inch 4K Monitor               4k
   27-inch 4K Monitor               display
   27-inch 4K Monitor               gaming
   27-inch 4K Monitor               monitor
   Ergonomic Wireless Mouse         computer
   Ergonomic Wireless Mouse         ergonomic
   ...
   ```

2. Create a relational view of products:

   ```sql
   SELECT
     jt.*
   FROM products p,
     JSON_TABLE(p.data, '$'
       COLUMNS (
         product_id VARCHAR2(20) PATH '$._id',
         product_name VARCHAR2(100) PATH '$.name',
         category VARCHAR2(50) PATH '$.category',
         brand VARCHAR2(50) PATH '$.brand',
         price NUMBER PATH '$.price',
         in_stock VARCHAR2(5) PATH '$.in_stock',
         quantity NUMBER PATH '$.quantity',
         avg_rating NUMBER PATH '$.rating.average',
         review_count NUMBER PATH '$.rating.count'
       )
     ) jt
   ORDER BY avg_rating DESC;
   ```

### Step 4: Query with JSON_EXISTS (Check Path Existence)

`JSON_EXISTS` tests whether a JSON path exists in a document.

1. Find products with bluetooth specification:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS product_name,
     JSON_VALUE(data, '$.specifications.bluetooth_version') AS bluetooth
   FROM products
   WHERE JSON_EXISTS(data, '$.specifications.bluetooth_version');
   ```

2. Find products with RGB lighting:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS product_name
   FROM products
   WHERE JSON_EXISTS(data, '$.specifications.rgb_lighting');
   ```

## Task 4: Update JSON Documents

Oracle provides multiple ways to update JSON documents.

### Step 1: Update Entire Document

1. Replace an entire document:

   ```sql
   UPDATE products
   SET data = JSON_OBJECT(
     '_id' VALUE 'PROD-004',
     'name' VALUE '27-inch 4K Monitor',
     'category' VALUE 'Electronics',
     'brand' VALUE 'ViewPerfect',
     'price' VALUE 449.99,
     'currency' VALUE 'USD',
     'in_stock' VALUE true,
     'quantity' VALUE 15,  -- Back in stock!
     'tags' VALUE JSON_ARRAY('monitor', '4k', 'display', 'gaming'),
     'specifications' VALUE JSON_OBJECT(
       'screen_size' VALUE '27 inch',
       'resolution' VALUE '3840x2160',
       'refresh_rate' VALUE 144,
       'panel_type' VALUE 'IPS'
     ),
     'rating' VALUE JSON_OBJECT(
       'average' VALUE 4.6,
       'count' VALUE 234
     )
   )
   WHERE JSON_VALUE(data, '$._id') = 'PROD-004';

   COMMIT;
   ```

   **MongoDB API Approach:**

   ```javascript
   // Connect to Oracle using MongoDB API
   // mongosh "mongodb://jsonuser:WelcomeJson%23123@localhost:27017/jsonuser?authMechanism=PLAIN&authSource=$external&tls=false"

   use jsonuser

   // Update document by _id - restore product to stock
   db.products.updateOne(
     { _id: "PROD-004" },
     {
       $set: {
         in_stock: true,
         quantity: 15
       }
     }
   )
   ```

   Expected output:
   ```javascript
   {
     acknowledged: true,
     matchedCount: 1,
     modifiedCount: 1
   }
   ```

   > **MongoDB API**: Use the `updateOne()` method with `$set` operator to update specific fields. Oracle supports standard MongoDB update operators.

   **REST API Approach:**

   ```bash
   # Update document using ORDS SODA REST API
   # First, get the document key (etag) - required for updates
   ETAG=$(curl -s -X GET \
     "http://localhost:8080/ords/jsonuser/soda/latest/products/PROD-004" \
     -H "Content-Type: application/json" | jq -r '.items[0].id')

   # Now update the document
   curl -X PUT \
     "http://localhost:8080/ords/jsonuser/soda/latest/products/PROD-004" \
     -H "Content-Type: application/json" \
     -H "If-Match: $ETAG" \
     -d '{
       "_id": "PROD-004",
       "name": "27-inch 4K Monitor",
       "category": "Electronics",
       "brand": "ViewPerfect",
       "price": 449.99,
       "currency": "USD",
       "in_stock": true,
       "quantity": 15,
       "tags": ["monitor", "4k", "display", "gaming"],
       "specifications": {
         "screen_size": "27 inch",
         "resolution": "3840x2160",
         "refresh_rate": 144,
         "panel_type": "IPS"
       },
       "rating": {
         "average": 4.6,
         "count": 234
       }
     }'
   ```

   Expected output:
   ```json
   {
     "id": "...",
     "etag": "...",
     "lastModified": "2025-01-15T10:30:00.000Z"
   }
   ```

   > **REST API**: Use HTTP PUT to replace entire documents. The `If-Match` header with the document's etag ensures optimistic locking.

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

   # Update document using SQL
   updated_doc = {
       "_id": "PROD-004",
       "name": "27-inch 4K Monitor",
       "category": "Electronics",
       "brand": "ViewPerfect",
       "price": 449.99,
       "currency": "USD",
       "in_stock": True,
       "quantity": 15,
       "tags": ["monitor", "4k", "display", "gaming"],
       "specifications": {
           "screen_size": "27 inch",
           "resolution": "3840x2160",
           "refresh_rate": 144,
           "panel_type": "IPS"
       },
       "rating": {
           "average": 4.6,
           "count": 234
       }
   }

   cursor.execute("""
       UPDATE products
       SET data = :1
       WHERE JSON_VALUE(data, '$._id') = 'PROD-004'
   """, [json.dumps(updated_doc)])

   connection.commit()
   print("1 row updated.")
   connection.close()
   ```

   Expected output:
   ```
   1 row updated.
   ```

   > **Python**: Use parameterized SQL for safe document updates.

2. Verify the update:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS product,
     JSON_VALUE(data, '$.in_stock') AS in_stock,
     JSON_VALUE(data, '$.quantity') AS quantity
   FROM products
   WHERE JSON_VALUE(data, '$._id') = 'PROD-004';
   ```

### Step 2: Update Specific Fields with JSON_MERGEPATCH

`JSON_MERGEPATCH` updates specific fields without replacing the entire document.

1. Update product price and quantity:

   ```sql
   UPDATE products
   SET data = JSON_MERGEPATCH(
     data,
     '{"price": 69.99, "quantity": 38}'
   )
   WHERE JSON_VALUE(data, '$._id') = 'PROD-001';

   COMMIT;
   ```

2. Verify the update:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS product,
     JSON_VALUE(data, '$.price') AS price,
     JSON_VALUE(data, '$.quantity') AS quantity
   FROM products
   WHERE JSON_VALUE(data, '$._id') = 'PROD-001';
   ```

   Expected output shows updated price (69.99) and quantity (38)

### Step 3: Update Nested Fields

1. Update nested specification:

   ```sql
   UPDATE products
   SET data = JSON_MERGEPATCH(
     data,
     '{"specifications": {"battery_hours": 40}}'
   )
   WHERE JSON_VALUE(data, '$._id') = 'PROD-001';

   COMMIT;
   ```

   > **Note:** JSON_MERGEPATCH merges objects, so other specification fields are preserved

2. Verify:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS product,
     JSON_QUERY(data, '$.specifications') AS specs
   FROM products
   WHERE JSON_VALUE(data, '$._id') = 'PROD-001';
   ```

   > **Note:** Use `JSON_SERIALIZE(data PRETTY)` to pretty-print entire documents. `JSON_QUERY` does not support the PRETTY option.

### Step 4: Update with JSON_TRANSFORM (Recommended)

`JSON_TRANSFORM` is the most powerful method for modifying JSON documents, offering fine-grained control over updates.

1. Update a single field:

   ```sql
   UPDATE products
   SET data = JSON_TRANSFORM(data, SET '$.price' = 64.99)
   WHERE JSON_VALUE(data, '$.name') = 'Wireless Bluetooth Headphones';

   COMMIT;
   ```

2. Update multiple fields at once:

   ```sql
   UPDATE products
   SET data = JSON_TRANSFORM(
     data,
     SET '$.price' = 59.99,
     SET '$.quantity' = 100,
     SET '$.specifications.battery_hours' = 35
   )
   WHERE JSON_VALUE(data, '$.name') = 'Wireless Bluetooth Headphones';

   COMMIT;
   ```

3. Add a new field:

   ```sql
   UPDATE products
   SET data = JSON_TRANSFORM(data, SET '$.on_sale' = true)
   WHERE JSON_VALUE(data, '$.name') = 'Wireless Bluetooth Headphones';

   COMMIT;
   ```

4. Remove a field:

   ```sql
   UPDATE products
   SET data = JSON_TRANSFORM(data, REMOVE '$.on_sale')
   WHERE JSON_VALUE(data, '$.name') = 'Wireless Bluetooth Headphones';

   COMMIT;
   ```

5. Append to an array:

   ```sql
   UPDATE products
   SET data = JSON_TRANSFORM(data, APPEND '$.tags' = 'premium')
   WHERE JSON_VALUE(data, '$.name') = 'Wireless Bluetooth Headphones';

   COMMIT;
   ```

6. Conditional updates (26ai):

   ```sql
   -- Add 10% to all products over $100
   UPDATE products
   SET data = JSON_TRANSFORM(
     data,
     SET '$.price' = JSON_VALUE(data, '$.price' RETURNING NUMBER) * 1.10
   )
   WHERE JSON_VALUE(data, '$.price' RETURNING NUMBER) > 100;

   COMMIT;
   ```

**JSON_TRANSFORM vs JSON_MERGEPATCH:**

| Feature | JSON_TRANSFORM | JSON_MERGEPATCH |
|---------|----------------|-----------------|
| Add fields | SET | Merge semantics |
| Remove fields | REMOVE | Set to null |
| Update nested | Path expressions | Merge semantics |
| Array operations | APPEND, PREPEND, SORT | Replaces entire array |
| Conditional | CASE, WHERE | Not available |
| Arithmetic | Path expressions | Not available |

> **Recommendation:** Use `JSON_TRANSFORM` for most update operations. It provides more control and better handles edge cases with arrays and nested structures.

## Task 5: Create Indexes on JSON Data

Indexes dramatically improve query performance on JSON collections.

### Step 1: Create Functional Index on Scalar Value

1. Create an index on product category:

   ```sql
   CREATE INDEX idx_products_category
   ON products (JSON_VALUE(data, '$.category'));
   ```

2. Create an index on price:

   ```sql
   CREATE INDEX idx_products_price
   ON products (JSON_VALUE(data, '$.price' RETURNING NUMBER));
   ```

3. Query using the index:

   ```sql
   -- This query will use idx_products_category
   SELECT
     JSON_VALUE(data, '$.name') AS product_name,
     JSON_VALUE(data, '$.price') AS price
   FROM products
   WHERE JSON_VALUE(data, '$.category') = 'Electronics';
   ```

### Step 2: Create Multivalue Index on Array

Multivalue indexes enable efficient queries on array values.

1. Create multivalue index on tags array:

   ```sql
   CREATE MULTIVALUE INDEX idx_products_tags
   ON products p (p.data.tags.string());
   ```

   > **Note:** Multivalue indexes use dot-notation syntax to access array elements.

2. Query products by tag using the index:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS product_name,
     JSON_QUERY(data, '$.tags') AS tags
   FROM products
   WHERE JSON_EXISTS(data, '$.tags[*]?(@ == "wireless")');
   ```

   Expected output:
   ```
   PRODUCT_NAME                      TAGS
   ------------------------------   ------------------------------------------------
   Wireless Bluetooth Headphones    ["wireless","bluetooth","audio","headphones"]
   Ergonomic Wireless Mouse         ["wireless","ergonomic","mouse","computer"]
   ```

   > **Note:** Use `JSON_EXISTS` with a filter expression `?(@ == "value")` to query array elements.

### Step 3: Create JSON Search Index (Full-Text + Structural)

JSON Search indexes enable both full-text and structural queries.

1. Create search index:

   ```sql
   CREATE SEARCH INDEX idx_products_search
   ON products (data)
   FOR JSON;
   ```

2. Query using full-text search:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS product_name,
     JSON_VALUE(data, '$.price') AS price
   FROM products
   WHERE JSON_TEXTCONTAINS(data, '$', 'gaming');
   ```

## Task 6: Understand OSON Format and Performance

OSON (Oracle Optimized Binary JSON) is Oracle's internal binary format for JSON storage.

### Step 1: Measure Document Sizes

1. Check document sizes:

   ```sql
   SELECT
     JSON_VALUE(data, '$._id') AS product_id,
     JSON_VALUE(data, '$.name') AS product_name,
     LENGTHB(data) AS oson_bytes,
     CASE
       WHEN LENGTHB(data) < 7950 THEN 'INLINE (Fast)'
       ELSE 'OUT-OF-LINE (Slower)'
     END AS storage_tier
   FROM products
   ORDER BY oson_bytes DESC;
   ```

   Expected output:
   ```
   PRODUCT_ID   PRODUCT_NAME                   OSON_BYTES   STORAGE_TIER
   ----------   ---------------------------   ----------   ----------------
   PROD-001     Wireless Bluetooth Headphones       421    INLINE (Fast)
   PROD-004     27-inch 4K Monitor                  402    INLINE (Fast)
   PROD-003     Mechanical Gaming Keyboard          392    INLINE (Fast)
   PROD-002     Ergonomic Wireless Mouse            391    INLINE (Fast)
   ```

   > **Note:** Document sizes will vary based on actual content. OSON binary format is typically more compact than text JSON.

### Step 2: Understanding OSON Storage

**OSON Storage Tiers:**

1. **Inline storage (< ~7,950 bytes):**
   - Document stored directly in the table row
   - Single I/O operation to read
   - **Best performance** - design documents to stay in this range

2. **Out-of-line/LOB storage (>= ~7,950 bytes):**
   - Document stored in separate LOB segment
   - Additional I/O required to fetch document
   - Larger documents = more "clutter" when accessing specific fields
   - **Maximum document size:** 32MB

> **Design Principle:** The performance difference between inline and out-of-line storage is significant. Once a document exceeds the inline threshold, additional size primarily affects how much unnecessary data is read when querying specific fields. Keep frequently-accessed documents under 7,950 bytes whenever possible.

### Step 3: Measure Query Performance

1. Enable timing and statistics:

   ```sql
   SET TIMING ON
   SET AUTOTRACE ON EXPLAIN
   ```

2. Query products:

   ```sql
   SELECT
     JSON_VALUE(data, '$.name') AS product_name,
     JSON_VALUE(data, '$.price') AS price
   FROM products
   WHERE JSON_VALUE(data, '$.category') = 'Electronics';
   ```

3. Review execution plan to verify index usage:

   Look for `INDEX (RANGE SCAN)` indicating the index was used.

4. Disable autotrace:

   ```sql
   SET AUTOTRACE OFF
   SET TIMING OFF
   ```

## Task 7: MongoDB API Comparison (Optional)

Oracle Database provides a MongoDB-compatible API for developers familiar with MongoDB syntax.

### MongoDB API Examples

Here are equivalent operations using MongoDB syntax (requires Oracle Database API for MongoDB):

> **Note:** MongoDB API requires ACL configuration on Autonomous Database. "Secure access from everywhere" will NOT allow MongoDB API access. You must configure an Access Control List (ACL) or use a private endpoint.

**Connection String Format:**
```javascript
// For Autonomous Database with ACL configured:
// mongosh "mongodb://user:password@host:27017/schema?authMechanism=PLAIN&authSource=$external&tls=true&tlsAllowInvalidCertificates=true"

// For Docker (26ai Free):
// mongosh "mongodb://user:password@localhost:27017/schema?authMechanism=PLAIN&authSource=$external&tls=false"
```

**Insert Document:**
```javascript
db.products.insertOne({
  _id: "PROD-005",
  name: "USB-C Hub",
  category: "Electronics",
  price: 39.99,
  in_stock: true
});
```

**Find Documents:**
```javascript
db.products.find({ category: "Electronics" });
```

**Update Document:**
```javascript
db.products.updateOne(
  { _id: "PROD-005" },
  { $set: { price: 34.99, quantity: 50 } }
);
```

**Query with Projection:**
```javascript
db.products.find(
  { price: { $lt: 100 } },
  { name: 1, price: 1 }
);
```

> **Note:** This workshop focuses on SQL/JSON syntax, but all concepts apply equally to the MongoDB API.

## Task 8: Delete JSON Documents

Oracle provides multiple ways to delete JSON documents from collections.

### Step 1: Delete Specific Documents

1. Delete a single product by ID:

   ```sql
   DELETE FROM products
   WHERE JSON_VALUE(data, '$._id') = 'PROD-002';

   COMMIT;
   ```

   Expected output:
   ```
   1 row deleted.

   Commit complete.
   ```

   **MongoDB API Approach:**

   ```javascript
   // Connect to Oracle using MongoDB API
   // mongosh "mongodb://jsonuser:WelcomeJson%23123@localhost:27017/jsonuser?authMechanism=PLAIN&authSource=$external&tls=false"

   use jsonuser

   // Delete one document by _id
   db.products.deleteOne({ _id: "PROD-002" })
   ```

   Expected output:
   ```javascript
   {
     acknowledged: true,
     deletedCount: 1
   }
   ```

   > **MongoDB API**: Use `deleteOne()` for single document deletion. Returns the count of deleted documents.

   **REST API Approach:**

   ```bash
   # Delete document using ORDS SODA REST API
   curl -X DELETE \
     "http://localhost:8080/ords/jsonuser/soda/latest/products/PROD-002" \
     -H "Content-Type: application/json"
   ```

   Expected output:
   ```json
   {
     "status": "deleted"
   }
   ```

   > **REST API**: Use HTTP DELETE with the document key. Returns status confirmation.

   **Python Approach:**

   ```python
   import oracledb

   connection = oracledb.connect(
       user="jsonuser",
       password="WelcomeJson#123",
       dsn="localhost:1522/myatp_low"
   )

   cursor = connection.cursor()

   # Delete document by _id
   cursor.execute("""
       DELETE FROM products
       WHERE JSON_VALUE(data, '$._id') = 'PROD-002'
   """)

   print(f"{cursor.rowcount} row(s) deleted.")
   connection.commit()
   connection.close()
   ```

   Expected output:
   ```
   1 row(s) deleted.
   ```

   > **Python**: Use standard DELETE with JSON_VALUE for filtering.

2. Verify the deletion:

   ```sql
   SELECT COUNT(*) FROM products;
   ```

   Expected output: `3` (one less than before)

### Step 2: Delete Multiple Documents

1. Delete products with low stock:

   ```sql
   DELETE FROM products
   WHERE JSON_VALUE(data, '$.quantity' RETURNING NUMBER) < 50;

   COMMIT;
   ```

   **MongoDB API Approach:**

   ```javascript
   // Delete multiple documents
   db.products.deleteMany({ quantity: { $lt: 50 } })
   ```

   **Python Approach:**

   ```python
   # Delete multiple documents matching filter
   cursor.execute("""
       DELETE FROM products
       WHERE JSON_VALUE(data, '$.quantity' RETURNING NUMBER) < 50
   """)
   print(f"{cursor.rowcount} document(s) removed.")
   connection.commit()
   ```

### Step 3: Clean Up (Optional)

If you want to remove all test data:

```sql
-- Truncate entire collection
TRUNCATE TABLE products;

-- Or drop collection completely
DROP TABLE products;

-- Recreate if needed
CREATE JSON COLLECTION TABLE products;
```

## Summary

In this lab, you learned:

* How to create JSON Collection Tables using `CREATE JSON COLLECTION TABLE`
* Multiple ways to insert JSON documents (SQL, MongoDB API, REST, Python)
* Core JSON query functions (JSON_VALUE, JSON_QUERY, JSON_TABLE, JSON_EXISTS)
* How to update JSON documents with JSON_MERGEPATCH and JSON_TRANSFORM
* Creating indexes for JSON data (functional, multivalue, search indexes)
* Understanding OSON format and storage tiers (inline vs out-of-line)
* Measuring document sizes and query performance
* MongoDB API equivalents

**Key Takeaways:**

1. **JSON Collection Tables** provide simple, single-column storage for JSON documents
2. **OSON format** provides optimal binary storage for JSON
3. **Keep documents < 7,950 bytes** for inline storage (fastest performance)
4. **Indexes are critical** for JSON query performance
5. **JSON_TABLE** converts JSON to relational rows for analytics
6. **JSON_TRANSFORM** is the most powerful update method
7. **Oracle provides both SQL and MongoDB APIs** for JSON collections

You are now ready to proceed to **Lab 2: Embedded vs Referenced Patterns**, where you will learn when to embed related data in documents versus storing them separately.

## Learn More

* [Oracle AI Database 26ai](https://www.oracle.com/database/ai-native-database-26ai/)
* [Oracle JSON Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/)
* [SQL/JSON Function Reference](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/function-JSON_VALUE.html)
* [JSON_TRANSFORM Reference](https://oracle-base.com/articles/21c/json_transform-21c)
* [JSON Search Index](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/json-search-index.html)
* [OSON Binary Format](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/oson-format.html)
* [Oracle Database API for MongoDB](https://docs.oracle.com/en/database/oracle/mongodb-api/)

## Acknowledgements

* **Author** - Rick Houlihan
* **Contributors** - Oracle JSON Development Team, Oracle LiveLabs Team
* **Last Updated By/Date** - Rick Houlihan, November 2025
