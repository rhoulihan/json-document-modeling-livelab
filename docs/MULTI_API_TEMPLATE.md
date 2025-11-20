# Multi-API Implementation Template for Oracle JSON Collections

## Overview

This template provides patterns for implementing JSON Collections operations across multiple APIs:
- SQL (baseline)
- SODA PL/SQL (Oracle-native document API)
- MongoDB API (via ORDS - MongoDB compatibility)
- REST API (via ORDS - HTTP/web applications)
- Python (python-oracledb driver)
- Node.js (node-oracledb driver)
- Java (SODA for Java)
- GraphQL (for Duality Views only)

## API Applicability Matrix

| Lab | SQL | SODA | MongoDB | REST | Python | Node.js | Java | GraphQL |
|-----|-----|------|---------|------|--------|---------|------|---------|
| Lab 1: Fundamentals | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ❌ |
| Lab 2: Embedded/Referenced | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ❌ |
| Lab 3: Single Collection | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ❌ |
| Lab 4: Computed | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ❌ | ❌ | ❌ |
| Lab 5: Bucketing | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ❌ | ❌ | ❌ |
| Lab 6: Polymorphic | ✅ | ✅ | ✅ | ✅ | ⚠️ | ❌ | ❌ | ❌ |
| Lab 7: LOB Cliffs | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Lab 8: Indexing | ✅ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Lab 9: Performance | ✅ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Lab 10: Advanced | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | ❌ | ❌ | ✅ |

Legend: ✅ Full support | ⚠️ Limited examples | ❌ Not applicable

## 1. INSERT Operations

### SQL
```sql
INSERT INTO products (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'PROD-001',
    'name' VALUE 'Widget',
    'price' VALUE 29.99
  )
);
```

### SODA PL/SQL
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
        "name": "Widget",
        "price": 29.99
      }')
    )
  );

  DBMS_OUTPUT.PUT_LINE(status || ' row created.');
END;
/
```

### MongoDB API (via mongosh)
```javascript
// Connect to Oracle using MongoDB API
use mydb

// Insert document using MongoDB syntax
db.products.insertOne({
  _id: "PROD-001",
  name: "Widget",
  price: 29.99
})

// Bulk insert
db.products.insertMany([
  { _id: "PROD-002", name: "Gadget", price: 39.99 },
  { _id: "PROD-003", name: "Tool", price: 19.99 }
])
```

### REST API (curl)
```bash
# Insert single document
curl -X POST \
  http://localhost:8080/ords/mydb/_soda/latest/products \
  -H 'Content-Type: application/json' \
  -d '{
    "_id": "PROD-001",
    "name": "Widget",
    "price": 29.99
  }'

# Response:
# {
#   "id": "PROD-001",
#   "etag": "...",
#   "lastModified": "2024-11-20T..."
# }
```

### Python (python-oracledb)
```python
import oracledb
import json

# Connect to database
connection = oracledb.connect(
    user="myuser",
    password="mypass",
    dsn="localhost/FREEPDB1"
)

# Get SODA database
soda = connection.getSodaDatabase()

# Create or open collection
collection = soda.createCollection("products")

# Insert document
doc = {
    "_id": "PROD-001",
    "name": "Widget",
    "price": 29.99
}

inserted_doc = collection.insertOne(doc)
print(f"Document inserted with key: {inserted_doc.key}")

connection.close()
```

### Node.js (node-oracledb)
```javascript
const oracledb = require('oracledb');

async function insertProduct() {
  const connection = await oracledb.getConnection({
    user: "myuser",
    password: "mypass",
    connectString: "localhost/FREEPDB1"
  });

  const soda = connection.getSodaDatabase();
  const collection = await soda.createCollection("products");

  const doc = {
    _id: "PROD-001",
    name: "Widget",
    price: 29.99
  };

  const insertedDoc = await collection.insertOne(doc);
  console.log(`Document inserted with key: ${insertedDoc.key}`);

  await connection.close();
}

insertProduct();
```

### Java (SODA for Java)
```java
import oracle.soda.rdbms.OracleRDBMSClient;
import oracle.soda.OracleDatabase;
import oracle.soda.OracleCollection;
import oracle.soda.OracleDocument;

OracleRDBMSClient client = new OracleRDBMSClient();
OracleDatabase db = client.getDatabase(connection);

OracleCollection collection = db.openCollection("products");

String jsonDoc = "{\"_id\": \"PROD-001\", \"name\": \"Widget\", \"price\": 29.99}";
OracleDocument doc = db.createDocumentFromString(jsonDoc);

collection.insert(doc);
System.out.println("Document inserted: " + doc.getKey());
```

## 2. QUERY/FIND Operations

### SQL
```sql
SELECT JSON_QUERY(json_document, '$' PRETTY)
FROM products
WHERE JSON_VALUE(json_document, '$.price' RETURNING NUMBER) < 30;
```

### SODA PL/SQL
```sql
DECLARE
  collection SODA_COLLECTION_T;
  doc_cursor SODA_CURSOR_T;
  doc SODA_DOCUMENT_T;
  doc_count NUMBER := 0;
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('products');

  -- Find documents with price < 30
  doc_cursor := collection.find()
    .filter('{"price": {"$lt": 30}}')
    .getCursor();

  LOOP
    doc := doc_cursor.getNext();
    EXIT WHEN doc IS NULL;
    doc_count := doc_count + 1;
    DBMS_OUTPUT.PUT_LINE(doc.getContentAsClob());
  END LOOP;

  doc_cursor.close();
  DBMS_OUTPUT.PUT_LINE('Found ' || doc_count || ' documents.');
END;
/
```

### MongoDB API (via mongosh)
```javascript
// Find with filter
db.products.find({ price: { $lt: 30 } })

// Find one
db.products.findOne({ _id: "PROD-001" })

// Find with projection
db.products.find(
  { price: { $lt: 30 } },
  { name: 1, price: 1 }
)

// Count
db.products.countDocuments({ price: { $lt: 30 } })
```

### REST API (curl)
```bash
# Query documents with filter
curl -X POST \
  http://localhost:8080/ords/mydb/_soda/latest/products?action=query \
  -H 'Content-Type: application/json' \
  -d '{
    "$query": { "price": { "$lt": 30 } }
  }'

# Get single document by key
curl -X GET \
  http://localhost:8080/ords/mydb/_soda/latest/products/PROD-001
```

### Python (python-oracledb)
```python
# Find documents with filter
documents = collection.find().filter({"price": {"$lt": 30}}).getDocuments()

for doc in documents:
    content = doc.getContent()
    print(f"Product: {content['name']}, Price: ${content['price']}")

# Find one document
doc = collection.find().key("PROD-001").getOne()
if doc:
    print(doc.getContent())

# Count
count = collection.find().filter({"price": {"$lt": 30}}).count()
print(f"Found {count} products")
```

### Node.js (node-oracledb)
```javascript
// Find documents
const documents = await collection.find()
  .filter({ price: { $lt: 30 } })
  .getDocuments();

for (const doc of documents) {
  const content = doc.getContent();
  console.log(`Product: ${content.name}, Price: $${content.price}`);
}

// Find one
const doc = await collection.find().key("PROD-001").getOne();
if (doc) {
  console.log(doc.getContent());
}
```

### Java (SODA for Java)
```java
// Find documents with filter
OracleCursor cursor = collection.find()
  .filter("{\"price\": {\"$lt\": 30}}")
  .getCursor();

while (cursor.hasNext()) {
  OracleDocument doc = cursor.next();
  System.out.println(doc.getContentAsString());
}

cursor.close();
```

## 3. UPDATE Operations

### SQL
```sql
UPDATE products
SET json_document = JSON_MERGEPATCH(
  json_document,
  '{"price": 24.99, "updated": true}'
)
WHERE JSON_VALUE(json_document, '$._id') = 'PROD-001';
```

### SODA PL/SQL
```sql
DECLARE
  collection SODA_COLLECTION_T;
  doc SODA_DOCUMENT_T;
  doc_content CLOB;
  merged_content CLOB;
  status NUMBER;
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('products');

  -- Get existing document
  doc := collection.find().key('PROD-001').getOne();

  IF doc IS NOT NULL THEN
    doc_content := doc.get_clob();

    -- Merge patch
    SELECT JSON_MERGEPATCH(doc_content, '{"price": 24.99, "updated": true}')
    INTO merged_content
    FROM DUAL;

    -- Replace document
    status := collection.find().key('PROD-001').replaceOne(
      SODA_DOCUMENT_T(b_content => UTL_RAW.cast_to_raw(merged_content))
    );

    DBMS_OUTPUT.PUT_LINE(status || ' row updated.');
    COMMIT;
  END IF;
END;
/
```

### MongoDB API (via mongosh)
```javascript
// Update single document
db.products.updateOne(
  { _id: "PROD-001" },
  { $set: { price: 24.99, updated: true } }
)

// Update multiple documents
db.products.updateMany(
  { price: { $lt: 30 } },
  { $set: { sale: true } }
)

// Replace entire document
db.products.replaceOne(
  { _id: "PROD-001" },
  { _id: "PROD-001", name: "Widget", price: 24.99, updated: true }
)
```

### REST API (curl)
```bash
# Update document using PATCH
curl -X PATCH \
  http://localhost:8080/ords/mydb/_soda/latest/products/PROD-001 \
  -H 'Content-Type: application/json' \
  -d '{
    "price": 24.99,
    "updated": true
  }'
```

### Python (python-oracledb)
```python
# Get document
doc = collection.find().key("PROD-001").getOne()

if doc:
    # Modify content
    content = doc.getContent()
    content['price'] = 24.99
    content['updated'] = True

    # Replace document
    collection.find().key("PROD-001").replaceOne(content)
    print("Document updated")

connection.commit()
```

### Node.js (node-oracledb)
```javascript
// Get and update document
const doc = await collection.find().key("PROD-001").getOne();

if (doc) {
  const content = doc.getContent();
  content.price = 24.99;
  content.updated = true;

  await collection.find().key("PROD-001").replaceOne(content);
  console.log("Document updated");
}

await connection.commit();
```

## 4. DELETE Operations

### SQL
```sql
DELETE FROM products
WHERE JSON_VALUE(json_document, '$._id') = 'PROD-001';
```

### SODA PL/SQL
```sql
DECLARE
  collection SODA_COLLECTION_T;
  status NUMBER;
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('products');

  status := collection.find().key('PROD-001').remove();

  DBMS_OUTPUT.PUT_LINE(status || ' row deleted.');
  COMMIT;
END;
/
```

### MongoDB API (via mongosh)
```javascript
// Delete single document
db.products.deleteOne({ _id: "PROD-001" })

// Delete multiple documents
db.products.deleteMany({ price: { $lt: 20 } })
```

### REST API (curl)
```bash
# Delete document
curl -X DELETE \
  http://localhost:8080/ords/mydb/_soda/latest/products/PROD-001
```

### Python (python-oracledb)
```python
# Delete document by key
count = collection.find().key("PROD-001").remove()
print(f"{count} document(s) deleted")

connection.commit()
```

### Node.js (node-oracledb)
```javascript
// Delete document
const result = await collection.find().key("PROD-001").remove();
console.log(`${result.count} document(s) deleted`);

await connection.commit();
```

## 5. GraphQL Syntax (Duality Views Only)

### Creating a Duality View with GraphQL

**GraphQL Syntax (Simplified):**
```sql
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW products_dv AS
Product @insert @update @delete {
  _id: product_id,
  name: product_name,
  price: product_price,
  category: category_name,

  -- Computed field using @generated
  inventory_value @generated(path: "$.inventory.quantity * $.price"),

  -- Nested relationship (auto-correlated by foreign key)
  inventory: Inventory [{
    warehouse: warehouse_location,
    quantity: stock_quantity,
    last_updated: update_timestamp
  }]
};
```

**Equivalent SQL Syntax (Verbose):**
```sql
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW products_dv AS
SELECT JSON {
  '_id' IS p.product_id,
  'name' IS p.product_name,
  'price' IS p.product_price,
  'category' IS p.category_name,
  'inventory' IS [
    SELECT JSON {
      'warehouse' IS i.warehouse_location,
      'quantity' IS i.stock_quantity,
      'last_updated' IS i.update_timestamp
    }
    FROM inventory i
    WHERE i.product_id = p.product_id
  ]
}
FROM products p WITH INSERT UPDATE DELETE;
```

**Using Duality View (all APIs work):**
```sql
-- SQL
SELECT * FROM products_dv WHERE JSON_VALUE(data, '$.price') < 30;

-- MongoDB API
db.products_dv.find({ price: { $lt: 30 } })

-- REST API
GET /ords/mydb/duality/products_dv?q={"price":{"$lt":30}}
```

## LiveLabs Conditional Tab Syntax

### For CRUD Operations (Labs 1-6, 10)
```markdown
**SQL Approach:**

if type="sql"

```sql
<copy>
-- SQL code here
</copy>
```

/if

**SODA Approach:**

if type="soda"

```sql
<copy>
-- SODA code here
</copy>
```

/if

**MongoDB Approach:**

if type="mongodb"

```javascript
<copy>
// MongoDB code here
</copy>
```

/if

**REST API Approach:**

if type="rest"

```bash
<copy>
# REST API curl command here
</copy>
```

/if

**Python Approach:**

if type="python"

```python
<copy>
# Python code here
</copy>
```

/if
```

### Manifest.json Configuration
```json
{
  "title": "Lab 1: JSON Collections Fundamentals",
  "description": "Master CRUD operations with multiple APIs",
  "filename": "../../labs/01-fundamentals/fundamentals.md",
  "type": "sql,soda,mongodb,rest,python"
}
```

## Implementation Strategy

### Phase 1: Core APIs (Labs 1-3)
Focus on fundamental operations with most common APIs:
- SQL (already complete)
- SODA (already complete)
- MongoDB API (high priority - migration story)
- REST API (web applications)
- Python (most popular data science language)

### Phase 2: Pattern-Specific APIs (Labs 4-6)
Add APIs where they demonstrate pattern benefits:
- Lab 4 (Computed): SQL, SODA, MongoDB aggregation
- Lab 5 (Bucketing): SQL, SODA, MongoDB time-series
- Lab 6 (Polymorphic): SQL, SODA, MongoDB, REST

### Phase 3: Advanced Features (Lab 10)
- GraphQL for Duality View creation
- REST API for Duality View CRUD
- Demonstrate unified JSON/relational access

### Skip or Minimal Coverage
- Lab 7: Focus on SQL (document sizing analysis)
- Lab 8: Focus on SQL (indexing DDL)
- Lab 9: Focus on SQL (performance benchmarking)
- Node.js/Java: Similar to Python, skip to reduce redundancy

## Prerequisites for Each API

### MongoDB API (via ORDS)
```sql
-- Enable MongoDB API in ORDS
-- Requires ORDS 21.4+ configured with MongoDB API endpoint
-- Default: http://localhost:8080/mongo/
```

### REST API (via ORDS)
```sql
-- Enable SODA REST in ORDS
BEGIN
  ORDS.ENABLE_SCHEMA(
    p_enabled => TRUE,
    p_schema => 'MYUSER',
    p_url_mapping_type => 'BASE_PATH',
    p_url_mapping_pattern => 'mydb',
    p_auto_rest_auth => FALSE
  );
  COMMIT;
END;
/
```

### Python
```bash
pip install oracledb
```

### Node.js
```bash
npm install oracledb
```

### Java
```xml
<dependency>
  <groupId>com.oracle.database.soda</groupId>
  <artifactId>orajsoda</artifactId>
  <version>1.1.8</version>
</dependency>
```

## Testing Each API Example

Before adding examples to labs, test each pattern:

1. **SQL**: Test in SQL*Plus or SQL Developer
2. **SODA**: Test in PL/SQL block
3. **MongoDB**: Test in mongosh connected to Oracle
4. **REST**: Test with curl or Postman
5. **Python**: Test with python script
6. **Node.js**: Test with node script
7. **Java**: Test with Java application
8. **GraphQL**: Verify Duality View creation

## Documentation References

- **SODA**: https://docs.oracle.com/en/database/oracle/simple-oracle-document-access/
- **MongoDB API**: https://docs.oracle.com/en/database/oracle/mongodb-api/
- **REST API**: https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/
- **python-oracledb**: https://python-oracledb.readthedocs.io/
- **node-oracledb**: https://node-oracledb.readthedocs.io/
- **Duality Views**: https://docs.oracle.com/en/database/oracle/oracle-database/23/jsnvu/
- **GraphQL**: https://oracle-base.com/articles/23/graphql-23

## Summary

This template provides a comprehensive framework for adding multi-API examples to the workshop. The strategy focuses on:

1. **Coverage**: All major APIs where applicable
2. **Practicality**: Skip APIs that don't add value for specific patterns
3. **User Experience**: Clear conditional tabs in LiveLabs
4. **Learning Path**: Progress from SQL → SODA → MongoDB → REST → Python

Total estimated examples to add: **~60-80 new code blocks** across Labs 1-6, 10.
