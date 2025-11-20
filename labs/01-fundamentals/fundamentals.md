# JSON Collections Fundamentals

## Introduction

This lab introduces you to Oracle JSON Collections, teaching you how to create collections, insert documents, query data, and understand Oracle's OSON (Oracle Optimized Binary JSON) format. You will work with both SQL/JSON functions and the MongoDB-compatible API.

By the end of this lab, you will understand how Oracle JSON Collections provide the flexibility of NoSQL with the power and reliability of Oracle Database.

Estimated Time: 30 minutes

### Objectives

In this lab, you will:

* Create JSON collections using both SODA and SQL approaches
* Insert JSON documents with various data types (strings, numbers, arrays, nested objects)
* Query documents using JSON_VALUE, JSON_QUERY, and JSON_TABLE
* Update and delete documents
* Understand OSON binary format and its performance implications
* Create indexes on JSON data for query optimization
* Compare SQL and MongoDB API syntax
* Measure document sizes and query performance

### Prerequisites

This lab assumes you have:

* Completed Lab 0: Setup
* Access to Oracle Database as JSONUSER
* Basic understanding of JSON format

## Task 1: Create JSON Collections

In Oracle Database, JSON collections can be created using SODA (Simple Oracle Document Access) or directly with SQL. Both approaches create optimized storage for JSON documents.

### Step 1: Create Collection Using SODA

1. Create a products collection:

   ```sql
   DECLARE
     collection SODA_COLLECTION_T;
   BEGIN
     collection := DBMS_SODA.CREATE_COLLECTION('products');
   END;
   /
   ```

2. Verify the collection was created:

   ```sql
   SELECT collection_name, table_name
   FROM user_soda_collections;
   ```

   Expected output:
   ```
   COLLECTION_NAME    TABLE_NAME
   ----------------   -----------
   PRODUCTS           PRODUCTS
   TEST_COLLECTION    TEST_COLLECTION
   ```

3. Examine the underlying table structure:

   ```sql
   DESC products
   ```

   You will see columns including:
   - `ID` - Unique document identifier (system-generated)
   - `JSON_DOCUMENT` - The actual JSON document stored in OSON format
   - `VERSION` - Document version for optimistic locking
   - `CREATED_ON` - Timestamp when document was created
   - `LAST_MODIFIED` - Timestamp when document was last updated

### Step 2: Create Collection Using SQL

Alternatively, you can create a JSON collection using standard SQL:

1. Create a customers table for JSON documents:

   ```sql
   CREATE TABLE customers (
     id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
     json_document JSON,
     created_on TIMESTAMP DEFAULT SYSTIMESTAMP,
     last_modified TIMESTAMP DEFAULT SYSTIMESTAMP
   );
   ```

   > **Note:** The `JSON` data type (introduced in Oracle 21c) provides automatic JSON validation and OSON storage

2. Create a trigger to update last_modified timestamp:

   ```sql
   CREATE OR REPLACE TRIGGER customers_update_trigger
   BEFORE UPDATE ON customers
   FOR EACH ROW
   BEGIN
     :NEW.last_modified := SYSTIMESTAMP;
   END;
   /
   ```

### Step 3: Understanding the Differences

**SODA Approach:**
- Simpler, MongoDB-like experience
- Automatic ID generation and versioning
- Built-in document management features
- Best for: Pure document-centric applications

**SQL Approach:**
- More control over table structure
- Can add custom columns and constraints
- Full SQL capabilities (triggers, constraints, partitioning)
- Best for: Applications mixing relational and document data

Both approaches use OSON format and provide identical query performance.

## Task 2: Insert JSON Documents

Let's populate our collections with sample data representing an e-commerce product catalog.

### Step 1: Insert Documents

1. Insert a product document:

   if type="sql"

   ```sql
   INSERT INTO products (json_document)
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
   ```

   /if

   if type="soda"

   ```sql
   DECLARE
     collection SODA_COLLECTION_T;
     status NUMBER;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('products');

     status := collection.insert_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw('{
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
         }')
       )
     );

     IF status = 1 THEN
       DBMS_OUTPUT.PUT_LINE('1 row created.');
     END IF;
   END;
   /
   ```

   /if

   **MongoDB API Approach:**

   if type="mongodb"

   ```javascript
   // Connect to Oracle using MongoDB API (via ORDS)
   // mongosh "mongodb://user:password@localhost:27017/mydb"

   use mydb

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

   /if

   **REST API Approach:**

   if type="rest"

   ```bash
   # Insert document via ORDS SODA REST API
   curl -X POST \
     http://localhost:8080/ords/mydb/_soda/latest/products \
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
     "lastModified": "2024-11-20T12:30:45.123Z"
   }
   ```

   > **Note:** REST API enables web and mobile applications to interact with JSON Collections over HTTP.

   /if

   **Python Approach:**

   if type="python"

   ```python
   import oracledb

   # Connect to Oracle Database
   connection = oracledb.connect(
       user="myuser",
       password="mypass",
       dsn="localhost/FREEPDB1"
   )

   # Get SODA database handle
   soda = connection.getSodaDatabase()

   # Create or open collection
   collection = soda.createCollection("products")

   # Insert document
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

   inserted_doc = collection.insertOne(doc)
   print(f"1 row created. Document key: {inserted_doc.key}")

   connection.commit()
   connection.close()
   ```

   Expected output:
   ```
   1 row created. Document key: PROD-001
   ```

   > **Note:** Python's python-oracledb driver provides native SODA support for data science and Python applications.

   /if

2. Insert multiple products:

   if type="sql"

   ```sql
   INSERT INTO products (json_document)
   VALUES
   (JSON_OBJECT(
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
   )),
   (JSON_OBJECT(
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
   )),
   (JSON_OBJECT(
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

   /if

   if type="soda"

   ```sql
   DECLARE
     collection SODA_COLLECTION_T;
     status NUMBER;
     total_inserted NUMBER := 0;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('products');

     -- Insert PROD-002
     status := collection.insert_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw('{
           "_id": "PROD-002",
           "name": "Ergonomic Wireless Mouse",
           "category": "Electronics",
           "brand": "TechComfort",
           "price": 34.99,
           "currency": "USD",
           "in_stock": true,
           "quantity": 120,
           "tags": ["wireless", "ergonomic", "mouse", "computer"],
           "specifications": {
             "color": "Silver",
             "dpi": 1600,
             "buttons": 6,
             "battery_months": 18
           },
           "rating": {
             "average": 4.7,
             "count": 342
           }
         }')
       )
     );
     total_inserted := total_inserted + status;

     -- Insert PROD-003
     status := collection.insert_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw('{
           "_id": "PROD-003",
           "name": "Mechanical Gaming Keyboard",
           "category": "Electronics",
           "brand": "GamePro",
           "price": 129.99,
           "currency": "USD",
           "in_stock": true,
           "quantity": 67,
           "tags": ["mechanical", "gaming", "keyboard", "rgb"],
           "specifications": {
             "switch_type": "Cherry MX Red",
             "rgb_lighting": true,
             "keys": 104,
             "wired": true
           },
           "rating": {
             "average": 4.8,
             "count": 891
           }
         }')
       )
     );
     total_inserted := total_inserted + status;

     -- Insert PROD-004
     status := collection.insert_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw('{
           "_id": "PROD-004",
           "name": "27-inch 4K Monitor",
           "category": "Electronics",
           "brand": "ViewPerfect",
           "price": 449.99,
           "currency": "USD",
           "in_stock": false,
           "quantity": 0,
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
         }')
       )
     );
     total_inserted := total_inserted + status;

     DBMS_OUTPUT.PUT_LINE(total_inserted || ' rows created.');
     DBMS_OUTPUT.PUT_LINE('');
     DBMS_OUTPUT.PUT_LINE('Commit complete.');
   END;
   /
   ```

   /if

3. Verify the products were inserted:

   ```sql
   SELECT COUNT(*) FROM products;
   ```

   Expected output: `4` (including the first product)

### Step 2: Insert Documents with Raw JSON

You can also insert JSON documents as raw JSON strings:

1. Insert a customer document:

   if type="sql"

   ```sql
   INSERT INTO customers (json_document)
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

   /if

   if type="soda"

   ```sql
   DECLARE
     collection SODA_COLLECTION_T;
     status NUMBER;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('customers');

     status := collection.insert_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw('{
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
         }')
       )
     );

     IF status = 1 THEN
       DBMS_OUTPUT.PUT_LINE('1 row created.');
       DBMS_OUTPUT.PUT_LINE('');
       DBMS_OUTPUT.PUT_LINE('Commit complete.');
     END IF;
   END;
   /
   ```

   /if

2. Insert another customer:

   if type="sql"

   ```sql
   INSERT INTO customers (json_document) VALUES (
     '{"_id": "CUST-002", "name": "Bob Martinez", "email": "bob.m@email.com", "phone": "+1-555-0124", "address": {"street": "456 Oak Avenue", "city": "Austin", "state": "TX", "zip": "78701", "country": "USA"}, "preferences": {"newsletter": false, "notifications": "sms"}, "loyalty_points": 890, "member_since": "2023-06-22"}'
   );

   COMMIT;
   ```

   /if

   if type="soda"

   ```sql
   DECLARE
     collection SODA_COLLECTION_T;
     status NUMBER;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('customers');

     status := collection.insert_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw('{"_id": "CUST-002", "name": "Bob Martinez", "email": "bob.m@email.com", "phone": "+1-555-0124", "address": {"street": "456 Oak Avenue", "city": "Austin", "state": "TX", "zip": "78701", "country": "USA"}, "preferences": {"newsletter": false, "notifications": "sms"}, "loyalty_points": 890, "member_since": "2023-06-22"}')
       )
     );

     IF status = 1 THEN
       DBMS_OUTPUT.PUT_LINE('1 row created.');
       DBMS_OUTPUT.PUT_LINE('');
       DBMS_OUTPUT.PUT_LINE('Commit complete.');
     END IF;
   END;
   /
   ```

   /if

## Task 3: Query JSON Documents

Oracle provides powerful SQL/JSON functions to query JSON data. Let's explore the main functions.

### Step 1: Query with JSON_VALUE (Extract Scalar Values)

`JSON_VALUE` extracts a single scalar value (string, number, boolean) from a JSON document.

1. Extract product names and prices:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$._id') AS product_id,
     JSON_VALUE(json_document, '$.name') AS product_name,
     JSON_VALUE(json_document, '$.price' RETURNING NUMBER) AS price
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
     JSON_VALUE(json_document, '$.name') AS product_name,
     JSON_VALUE(json_document, '$.price' RETURNING NUMBER) AS price,
     JSON_VALUE(json_document, '$.quantity' RETURNING NUMBER) AS quantity
   FROM products
   WHERE JSON_VALUE(json_document, '$.category') = 'Electronics'
     AND JSON_VALUE(json_document, '$.in_stock' RETURNING VARCHAR2) = 'true'
   ORDER BY price;
   ```

3. Extract nested values:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS product_name,
     JSON_VALUE(json_document, '$.specifications.color') AS color,
     JSON_VALUE(json_document, '$.rating.average' RETURNING NUMBER) AS rating
   FROM products
   WHERE JSON_VALUE(json_document, '$.rating.average' RETURNING NUMBER) >= 4.5
   ORDER BY rating DESC;
   ```

### Step 2: Query with JSON_QUERY (Extract Objects and Arrays)

`JSON_QUERY` extracts JSON objects or arrays (non-scalar values).

1. Extract the specifications object:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS product_name,
     JSON_QUERY(json_document, '$.specifications') AS specifications
   FROM products;
   ```

2. Extract the tags array:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS product_name,
     JSON_QUERY(json_document, '$.tags') AS tags
   FROM products;
   ```

3. Pretty-print entire documents:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$._id') AS id,
     JSON_SERIALIZE(json_document PRETTY) AS document
   FROM products
   WHERE JSON_VALUE(json_document, '$._id') = 'PROD-001';
   ```

### Step 3: Query with JSON_TABLE (Convert JSON to Relational Rows)

`JSON_TABLE` converts JSON data into relational rows and columns - extremely useful for analytics.

1. Expand product tags into rows:

   ```sql
   SELECT
     JSON_VALUE(p.json_document, '$.name') AS product_name,
     jt.tag
   FROM products p,
     JSON_TABLE(p.json_document, '$.tags[*]'
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
     JSON_TABLE(p.json_document, '$'
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
     JSON_VALUE(json_document, '$.name') AS product_name,
     JSON_VALUE(json_document, '$.specifications.bluetooth_version') AS bluetooth
   FROM products
   WHERE JSON_EXISTS(json_document, '$.specifications.bluetooth_version');
   ```

2. Find products with RGB lighting:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS product_name
   FROM products
   WHERE JSON_EXISTS(json_document, '$.specifications.rgb_lighting');
   ```

## Task 4: Update JSON Documents

Oracle provides multiple ways to update JSON documents.

### Step 1: Update Entire Document

1. Replace an entire document:

   if type="sql"

   ```sql
   UPDATE products
   SET json_document = JSON_OBJECT(
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
   WHERE JSON_VALUE(json_document, '$._id') = 'PROD-004';

   COMMIT;
   ```

   /if

   if type="soda"

   ```sql
   DECLARE
     collection SODA_COLLECTION_T;
     doc SODA_DOCUMENT_T;
     status NUMBER;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('products');

     -- Find and replace by key using QBE
     status := collection.find().key('PROD-004').replace_one(
       SODA_DOCUMENT_T(
         b_content => UTL_RAW.cast_to_raw('{
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
         }')
       )
     );

     IF status = 1 THEN
       DBMS_OUTPUT.PUT_LINE('1 row updated.');
       DBMS_OUTPUT.PUT_LINE('');
       DBMS_OUTPUT.PUT_LINE('Commit complete.');
     END IF;
   END;
   /
   ```

   /if

2. Verify the update:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS product,
     JSON_VALUE(json_document, '$.in_stock') AS in_stock,
     JSON_VALUE(json_document, '$.quantity') AS quantity
   FROM products
   WHERE JSON_VALUE(json_document, '$._id') = 'PROD-004';
   ```

### Step 2: Update Specific Fields with JSON_MERGEPATCH

`JSON_MERGEPATCH` updates specific fields without replacing the entire document.

1. Update product price and quantity:

   if type="sql"

   ```sql
   UPDATE products
   SET json_document = JSON_MERGEPATCH(
     json_document,
     '{"price": 69.99, "quantity": 38}'
   )
   WHERE JSON_VALUE(json_document, '$._id') = 'PROD-001';

   COMMIT;
   ```

   /if

   if type="soda"

   > **Note:** SODA doesn't have a direct equivalent to JSON_MERGEPATCH. You need to fetch the document, merge the changes, and replace it.

   ```sql
   DECLARE
     collection SODA_COLLECTION_T;
     doc SODA_DOCUMENT_T;
     doc_content CLOB;
     merged_content CLOB;
     status NUMBER;
   BEGIN
     collection := DBMS_SODA.OPEN_COLLECTION('products');

     -- Get the existing document
     doc := collection.find().key('PROD-001').get_one();
     doc_content := doc.get_clob();

     -- Merge the patch (using JSON_MERGEPATCH in SQL)
     SELECT JSON_MERGEPATCH(doc_content, '{"price": 69.99, "quantity": 38}')
     INTO merged_content
     FROM DUAL;

     -- Replace with merged document
     status := collection.find().key('PROD-001').replace_one(
       SODA_DOCUMENT_T(b_content => UTL_RAW.cast_to_raw(merged_content))
     );

     IF status = 1 THEN
       DBMS_OUTPUT.PUT_LINE('1 row updated.');
       DBMS_OUTPUT.PUT_LINE('');
       DBMS_OUTPUT.PUT_LINE('Commit complete.');
     END IF;
   END;
   /
   ```

   /if

2. Verify the update:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS product,
     JSON_VALUE(json_document, '$.price') AS price,
     JSON_VALUE(json_document, '$.quantity') AS quantity
   FROM products
   WHERE JSON_VALUE(json_document, '$._id') = 'PROD-001';
   ```

   Expected output shows updated price (69.99) and quantity (38)

### Step 3: Update Nested Fields

1. Update nested specification:

   ```sql
   UPDATE products
   SET json_document = JSON_MERGEPATCH(
     json_document,
     '{"specifications": {"battery_hours": 40}}'
   )
   WHERE JSON_VALUE(json_document, '$._id') = 'PROD-001';

   COMMIT;
   ```

   > **Note:** JSON_MERGEPATCH merges objects, so other specification fields are preserved

2. Verify:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS product,
     JSON_QUERY(json_document, '$.specifications' PRETTY) AS specs
   FROM products
   WHERE JSON_VALUE(json_document, '$._id') = 'PROD-001';
   ```

## Task 5: Create Indexes on JSON Data

Indexes dramatically improve query performance on JSON collections.

### Step 1: Create Functional Index on Scalar Value

1. Create an index on product category:

   ```sql
   CREATE INDEX idx_products_category
   ON products (JSON_VALUE(json_document, '$.category'));
   ```

2. Create an index on price:

   ```sql
   CREATE INDEX idx_products_price
   ON products (JSON_VALUE(json_document, '$.price' RETURNING NUMBER));
   ```

3. Query using the index:

   ```sql
   -- This query will use idx_products_category
   SELECT
     JSON_VALUE(json_document, '$.name') AS product_name,
     JSON_VALUE(json_document, '$.price') AS price
   FROM products
   WHERE JSON_VALUE(json_document, '$.category') = 'Electronics';
   ```

### Step 2: Create Multivalue Index on Array

Multivalue indexes (Oracle 21c+) enable efficient queries on array values.

1. Create multivalue index on tags array:

   ```sql
   CREATE MULTIVALUE INDEX idx_products_tags
   ON products (JSON_VALUE(json_document, '$.tags[*]' RETURNING VARCHAR2(50)));
   ```

2. Query products by tag using the index:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS product_name,
     JSON_QUERY(json_document, '$.tags') AS tags
   FROM products
   WHERE JSON_VALUE(json_document, '$.tags[*]' RETURNING VARCHAR2(50)) = 'wireless';
   ```

   Expected output:
   ```
   PRODUCT_NAME                      TAGS
   ------------------------------   -----------------------------------
   Wireless Bluetooth Headphones    ["wireless","bluetooth","audio"...]
   Ergonomic Wireless Mouse         ["wireless","ergonomic","mouse"...]
   ```

### Step 3: Create JSON Search Index (Full-Text + Structural)

JSON Search indexes enable both full-text and structural queries.

1. Create search index:

   ```sql
   CREATE SEARCH INDEX idx_products_search
   ON products (json_document)
   FOR JSON;
   ```

2. Query using full-text search:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS product_name,
     JSON_VALUE(json_document, '$.price') AS price
   FROM products
   WHERE JSON_TEXTCONTAINS(json_document, '$', 'gaming');
   ```

## Task 6: Understand OSON Format and Performance

OSON (Oracle Optimized Binary JSON) is Oracle's internal binary format for JSON storage.

### Step 1: Measure Document Sizes

1. Check document sizes:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$._id') AS product_id,
     JSON_VALUE(json_document, '$.name') AS product_name,
     LENGTHB(json_document) AS oson_bytes,
     CASE
       WHEN LENGTHB(json_document) < 7950 THEN 'INLINE (Fast)'
       WHEN LENGTHB(json_document) < 10240 THEN 'LOB (OK)'
       WHEN LENGTHB(json_document) < 102400 THEN 'LOB (Slower)'
       ELSE 'LOB (Avoid if possible)'
     END AS storage_tier
   FROM products
   ORDER BY oson_bytes DESC;
   ```

   Expected output:
   ```
   PRODUCT_ID   PRODUCT_NAME                   OSON_BYTES   STORAGE_TIER
   ----------   ---------------------------   ----------   -------------
   PROD-003     Mechanical Gaming Keyboard          890    INLINE (Fast)
   PROD-004     27-inch 4K Monitor                  850    INLINE (Fast)
   PROD-001     Wireless Bluetooth Headphones       820    INLINE (Fast)
   PROD-002     Ergonomic Wireless Mouse            780    INLINE (Fast)
   ```

### Step 2: Understanding OSON Performance Tiers

**OSON Storage Tiers:**

1. **Inline storage (< 7,950 bytes):**
   - Stored directly in the table row
   - Fastest query performance
   - Best practice: Keep documents in this range

2. **LOB storage (7,950 bytes - 32MB):**
   - Stored in separate LOB segment
   - Slower performance (additional I/O required)
   - Acceptable for < 100KB documents
   - Avoid documents over 10MB

3. **Maximum document size: 32MB**
   - Hard limit for OSON format
   - Documents exceeding 32MB will fail to insert

**Key Design Principle:**
> Keep frequently queried documents under 7,950 bytes for optimal performance. Use patterns like Single Collection design to avoid bloated documents.

### Step 3: Measure Query Performance

1. Enable timing and statistics:

   ```sql
   SET TIMING ON
   SET AUTOTRACE ON EXPLAIN
   ```

2. Query products:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$.name') AS product_name,
     JSON_VALUE(json_document, '$.price') AS price
   FROM products
   WHERE JSON_VALUE(json_document, '$.category') = 'Electronics';
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

## Task 8: Clean Up Test Data (Optional)

If you want to remove the test data:

```sql
-- Delete specific products
DELETE FROM products
WHERE JSON_VALUE(json_document, '$._id') IN ('PROD-001', 'PROD-002');

-- Or truncate entire collection
TRUNCATE TABLE products;

-- Drop collection
BEGIN
  DBMS_SODA.DROP_COLLECTION('products');
END;
/
```

## Summary

In this lab, you learned:

* ✅ How to create JSON collections using SODA and SQL
* ✅ Multiple ways to insert JSON documents
* ✅ Core JSON query functions (JSON_VALUE, JSON_QUERY, JSON_TABLE, JSON_EXISTS)
* ✅ How to update JSON documents with JSON_MERGEPATCH
* ✅ Creating indexes for JSON data (functional, multivalue, search indexes)
* ✅ Understanding OSON format and performance tiers
* ✅ Measuring document sizes and query performance
* ✅ MongoDB API equivalents

**Key Takeaways:**

1. **OSON format** provides optimal binary storage for JSON
2. **Keep documents < 7,950 bytes** for inline storage (fastest performance)
3. **Indexes are critical** for JSON query performance
4. **JSON_TABLE** converts JSON to relational rows for analytics
5. **Oracle provides both SQL and MongoDB APIs** for JSON collections

You are now ready to proceed to **Lab 2: Embedded vs Referenced Patterns**, where you will learn when to embed related data in documents versus storing them separately.

## Learn More

* [Oracle JSON Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/)
* [SQL/JSON Function Reference](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/function-JSON_VALUE.html)
* [JSON Search Index](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/json-search-index.html)
* [OSON Binary Format](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/oson-format.html)
* [Oracle Database API for MongoDB](https://docs.oracle.com/en/database/oracle/mongodb-api/)

## Acknowledgements

* **Author** - Rick Houlihan
* **Contributors** - Oracle JSON Development Team, Oracle LiveLabs Team
* **Last Updated By/Date** - Rick Houlihan, November 2024
