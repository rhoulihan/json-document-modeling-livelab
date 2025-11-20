# SODA Implementation Template
**Oracle JSON Collections Workshop - SODA for PL/SQL Integration Guide**

**Purpose:** Guide for systematically adding SODA (Simple Oracle Document Access) examples alongside SQL examples in workshop labs using conditional tabs.

**Last Updated:** November 2024
**Version:** 1.0

---

## Table of Contents

1. [Overview](#overview)
2. [When to Use SODA vs SQL/JSON](#when-to-use-soda-vs-sqljson)
3. [Conditional Tab Syntax](#conditional-tab-syntax)
4. [SODA Code Patterns](#soda-code-patterns)
5. [Manifest Configuration](#manifest-configuration)
6. [Testing and Validation](#testing-and-validation)
7. [Common Issues](#common-issues)

---

## Overview

This template provides standardized patterns for adding SODA for PL/SQL examples to workshop labs. SODA provides a simple document-centric API for CRUD operations, while SQL/JSON provides powerful querying, analytics, and indexing capabilities.

### Key Principles

- **SODA for CRUD:** Use SODA for Create, Read (simple), Update, Delete operations
- **SQL for Queries:** Use SQL/JSON for complex queries, analytics, aggregations, joins
- **SQL for Indexing:** Use SQL for creating and managing indexes
- **Both Where Appropriate:** Show both approaches for CRUD to demonstrate Oracle's flexibility

### SODA API Overview

```sql
-- Open or create collection
collection SODA_COLLECTION_T := DBMS_SODA.OPEN_COLLECTION('collection_name');
collection SODA_COLLECTION_T := DBMS_SODA.CREATE_COLLECTION('collection_name');

-- Insert document
status := collection.insert_one(SODA_DOCUMENT_T(b_content => UTL_RAW.cast_to_raw('json_string')));

-- Replace document by key
status := collection.find().key('document_id').replace_one(SODA_DOCUMENT_T(...));

-- Get document by key
doc := collection.find().key('document_id').get_one();

-- Delete document by key
status := collection.find().key('document_id').remove();
```

---

## When to Use SODA vs SQL/JSON

### ✅ Use SODA For:

**Create Operations:**
- Inserting single documents
- Inserting multiple documents
- Creating documents from raw JSON

**Read Operations (Simple):**
- Retrieving by document ID/key
- Simple QBE (Query-by-Example) filters
- Counting documents

**Update Operations:**
- Replacing entire documents
- Updating documents by key
- MERGEPATCH pattern (fetch, merge, replace)

**Delete Operations:**
- Deleting by document ID/key
- Deleting with simple filters

### ✅ Use SQL/JSON For:

**Complex Queries:**
- JSON_VALUE, JSON_QUERY for field extraction
- JSON_TABLE for relational projections
- Complex WHERE clauses with multiple conditions
- Aggregations (COUNT, SUM, AVG, MIN, MAX)
- GROUP BY queries
- Joins between collections

**Indexing:**
- Creating multivalue indexes
- Creating search indexes
- Creating partial indexes
- Managing index strategies

**Analytics:**
- Performance benchmarking
- Execution plan analysis
- Query optimization

**Schema Validation:**
- Constraint management
- Data validation rules

### 🔄 Show Both For:

**Basic CRUD in Introductory Labs:**
- Lab 1: Fundamentals - show both SQL and SODA for all CRUD
- Lab 2-3: Show both where it teaches flexibility
- Lab 4+: Use SODA only where it simplifies the example

---

## Conditional Tab Syntax

### Oracle LiveLabs Markdown Format

```markdown
**SQL Approach:**

if type="sql"

```sql
<copy>
-- SQL code here
INSERT INTO products (json_document)
VALUES (
  JSON_OBJECT(
    '_id' VALUE 'PROD-001',
    'name' VALUE 'Product Name'
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
  collection := DBMS_SODA.OPEN_COLLECTION('products');

  status := collection.insert_one(
    SODA_DOCUMENT_T(
      b_content => UTL_RAW.cast_to_raw('{
        "_id": "PROD-001",
        "name": "Product Name"
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
```

### Important Notes:

1. **Section Headers:** Use "SQL Approach:" and "SODA Approach:" before conditional blocks
2. **Indentation:** Do not indent the `if type="..."` and `/if` tags
3. **Code Blocks:** Use triple backticks with `<copy>` tags for executable code
4. **Expected Output:** Include expected output after each code block
5. **Blank Lines:** Maintain blank lines between sections for readability

---

## SODA Code Patterns

### Pattern 1: Insert Single Document

**SQL Version:**
```sql
INSERT INTO products (json_document)
VALUES (
  JSON_OBJECT(
    '_id' VALUE 'PROD-001',
    'name' VALUE 'Wireless Bluetooth Headphones',
    'price' VALUE 79.99,
    'quantity' VALUE 45
  )
);
```

**SODA Version:**
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
        "price": 79.99,
        "quantity": 45
      }')
    )
  );

  IF status = 1 THEN
    DBMS_OUTPUT.PUT_LINE('1 row created.');
  END IF;
END;
/
```

**Expected Output:**
```
1 row created.

PL/SQL procedure successfully completed.
```

---

### Pattern 2: Insert Multiple Documents

**SQL Version:**
```sql
INSERT INTO products (json_document)
VALUES
  (JSON_OBJECT('_id' VALUE 'PROD-002', 'name' VALUE 'Product 2')),
  (JSON_OBJECT('_id' VALUE 'PROD-003', 'name' VALUE 'Product 3')),
  (JSON_OBJECT('_id' VALUE 'PROD-004', 'name' VALUE 'Product 4'));
```

**SODA Version:**
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
        "name": "Product 2"
      }')
    )
  );
  total_inserted := total_inserted + status;

  -- Insert PROD-003
  status := collection.insert_one(
    SODA_DOCUMENT_T(
      b_content => UTL_RAW.cast_to_raw('{
        "_id": "PROD-003",
        "name": "Product 3"
      }')
    )
  );
  total_inserted := total_inserted + status;

  -- Insert PROD-004
  status := collection.insert_one(
    SODA_DOCUMENT_T(
      b_content => UTL_RAW.cast_to_raw('{
        "_id": "PROD-004",
        "name": "Product 4"
      }')
    )
  );
  total_inserted := total_inserted + status;

  DBMS_OUTPUT.PUT_LINE(total_inserted || ' rows created.');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Commit complete.');

  COMMIT;
END;
/
```

**Expected Output:**
```
3 rows created.

Commit complete.

PL/SQL procedure successfully completed.
```

---

### Pattern 3: Insert from Raw JSON String

**SQL Version:**
```sql
INSERT INTO products (json_document)
VALUES ('{"_id": "PROD-005", "name": "Product 5", "price": 29.99}');
```

**SODA Version:**
```sql
DECLARE
  collection SODA_COLLECTION_T;
  status NUMBER;
  json_string VARCHAR2(4000) := '{"_id": "PROD-005", "name": "Product 5", "price": 29.99}';
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('products');

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
```

**Expected Output:**
```
1 row created.

PL/SQL procedure successfully completed.
```

---

### Pattern 4: Replace Entire Document

**SQL Version:**
```sql
UPDATE products
SET json_document = JSON_OBJECT(
  '_id' VALUE 'PROD-004',
  'name' VALUE 'Updated Product Name',
  'price' VALUE 99.99
)
WHERE JSON_VALUE(json_document, '$._id') = 'PROD-004';
```

**SODA Version:**
```sql
DECLARE
  collection SODA_COLLECTION_T;
  status NUMBER;
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('products');

  status := collection.find().key('PROD-004').replace_one(
    SODA_DOCUMENT_T(
      b_content => UTL_RAW.cast_to_raw('{
        "_id": "PROD-004",
        "name": "Updated Product Name",
        "price": 99.99
      }')
    )
  );

  IF status = 1 THEN
    DBMS_OUTPUT.PUT_LINE('1 row updated.');
  END IF;
END;
/
```

**Expected Output:**
```
1 row updated.

PL/SQL procedure successfully completed.
```

---

### Pattern 5: MERGEPATCH Pattern (Partial Update)

**SQL Version:**
```sql
UPDATE products
SET json_document = JSON_MERGEPATCH(
  json_document,
  '{"price": 69.99, "quantity": 38}'
)
WHERE JSON_VALUE(json_document, '$._id') = 'PROD-001';
```

**SODA Version:**
```sql
DECLARE
  collection SODA_COLLECTION_T;
  doc SODA_DOCUMENT_T;
  doc_content CLOB;
  merged_content CLOB;
  status NUMBER;
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('products');

  -- Step 1: Get the existing document
  doc := collection.find().key('PROD-001').get_one();
  doc_content := doc.get_clob();

  -- Step 2: Merge the patch using SQL
  SELECT JSON_MERGEPATCH(doc_content, '{"price": 69.99, "quantity": 38}')
  INTO merged_content
  FROM DUAL;

  -- Step 3: Replace with merged document
  status := collection.find().key('PROD-001').replace_one(
    SODA_DOCUMENT_T(b_content => UTL_RAW.cast_to_raw(merged_content))
  );

  IF status = 1 THEN
    DBMS_OUTPUT.PUT_LINE('1 row updated.');
  END IF;
END;
/
```

**Note to Add:**
> **Note:** SODA doesn't have a direct equivalent to JSON_MERGEPATCH. You need to fetch the document, merge the changes using SQL, and replace it.

**Expected Output:**
```
1 row updated.

PL/SQL procedure successfully completed.
```

---

### Pattern 6: Delete Document by Key

**SQL Version:**
```sql
DELETE FROM products
WHERE JSON_VALUE(json_document, '$._id') = 'PROD-999';
```

**SODA Version:**
```sql
DECLARE
  collection SODA_COLLECTION_T;
  status NUMBER;
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('products');

  status := collection.find().key('PROD-999').remove();

  IF status = 1 THEN
    DBMS_OUTPUT.PUT_LINE('1 row deleted.');
  END IF;
END;
/
```

**Expected Output:**
```
1 row deleted.

PL/SQL procedure successfully completed.
```

---

### Pattern 7: Simple Read by Key

**SQL Version:**
```sql
SELECT JSON_SERIALIZE(json_document PRETTY) AS product
FROM products
WHERE JSON_VALUE(json_document, '$._id') = 'PROD-001';
```

**SODA Version:**
```sql
DECLARE
  collection SODA_COLLECTION_T;
  doc SODA_DOCUMENT_T;
  doc_content CLOB;
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('products');

  doc := collection.find().key('PROD-001').get_one();

  IF doc IS NOT NULL THEN
    doc_content := doc.get_clob();
    DBMS_OUTPUT.PUT_LINE(doc_content);
  ELSE
    DBMS_OUTPUT.PUT_LINE('Document not found.');
  END IF;
END;
/
```

**Expected Output:**
```
{
  "_id": "PROD-001",
  "name": "Wireless Bluetooth Headphones",
  "price": 69.99,
  "quantity": 38
}

PL/SQL procedure successfully completed.
```

---

### Pattern 8: Count Documents

**SQL Version:**
```sql
SELECT COUNT(*) AS total_products
FROM products;
```

**SODA Version:**
```sql
DECLARE
  collection SODA_COLLECTION_T;
  doc_count NUMBER;
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('products');

  doc_count := collection.find().count();

  DBMS_OUTPUT.PUT_LINE('Total products: ' || doc_count);
END;
/
```

**Expected Output:**
```
Total products: 4

PL/SQL procedure successfully completed.
```

---

## Manifest Configuration

### Add Type Attribute to Lab Entry

For each lab that includes SODA examples, add the `"type": "sql,soda"` attribute to the lab entry in both manifest files:

**File 1:** `workshops/tenancy/manifest.json`
**File 2:** `workshops/desktop/manifest.json`

**Example:**
```json
{
  "title": "Lab 2: Embedded vs Referenced Patterns",
  "description": "Compare denormalized vs normalized approaches with performance benchmarks",
  "filename": "../../labs/02-embedded-referenced/embedded-referenced.md",
  "type": "sql,soda"
},
```

### Checklist:
- [ ] Update `workshops/tenancy/manifest.json`
- [ ] Update `workshops/desktop/manifest.json`
- [ ] Verify JSON syntax is valid (no trailing commas)
- [ ] Test rendering in LiveLabs preview (if available)

---

## Testing and Validation

### Pre-Implementation Checklist:

1. **Identify CRUD Operations in Lab:**
   - [ ] Review lab content for INSERT, UPDATE, DELETE operations
   - [ ] Identify simple SELECT by ID operations
   - [ ] Skip complex queries, analytics, indexing operations

2. **Set Up Test Environment:**
   ```sql
   -- Ensure DBMS_OUTPUT is enabled
   SET SERVEROUTPUT ON

   -- Verify collection exists
   SELECT table_name FROM user_tables WHERE table_name = 'COLLECTION_NAME';
   ```

3. **Test Each SODA Example:**
   - [ ] Copy SODA code to SQL*Plus or SQL Developer
   - [ ] Execute and verify no errors
   - [ ] Capture actual output
   - [ ] Compare with SQL version output
   - [ ] Update expected output if different

4. **Validate Conditional Formatting:**
   - [ ] Check `if type="sql"` and `/if` tags are not indented
   - [ ] Verify blank lines between SQL and SODA sections
   - [ ] Confirm code blocks have `<copy>` tags
   - [ ] Test markdown rendering (if possible)

### Testing Workflow:

```bash
# 1. Connect to Oracle Database
sudo docker exec -it oracle23ai bash -c "
sqlplus jsonuser/WelcomeJson#123@FREEPDB1 << 'SQLEOF'
SET SERVEROUTPUT ON

-- Paste SODA code here
DECLARE
  collection SODA_COLLECTION_T;
  status NUMBER;
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('products');
  -- Test code...
END;
/

EXIT;
SQLEOF
"

# 2. Capture output and update markdown
# 3. Repeat for each SODA example
```

### Common Validation Issues:

**Issue:** "PLS-00201: identifier 'DBMS_SODA' must be declared"
- **Cause:** User doesn't have SODA privileges
- **Fix:** Grant SODA_APP role: `GRANT SODA_APP TO jsonuser;`

**Issue:** "ORA-30625: method dispatch on NULL SELF argument"
- **Cause:** Collection doesn't exist
- **Fix:** Create collection: `DBMS_SODA.CREATE_COLLECTION('collection_name')`

**Issue:** Output doesn't match SQL version
- **Cause:** PL/SQL adds "PL/SQL procedure successfully completed."
- **Fix:** Update expected output to include this line

---

## Common Issues

### 1. Wrong SODA API Signature

**Problem:**
```sql
status := collection.insert_one('{"_id": "001"}');  -- ❌ Wrong
```

**Error:**
```
ORA-06550: wrong number or types of arguments in call to 'INSERT_ONE'
```

**Solution:**
```sql
status := collection.insert_one(
  SODA_DOCUMENT_T(
    b_content => UTL_RAW.cast_to_raw('{"_id": "001"}')
  )
);  -- ✅ Correct
```

---

### 2. Collection Doesn't Exist

**Problem:**
```sql
collection := DBMS_SODA.OPEN_COLLECTION('nonexistent');
```

**Error:**
```
ORA-30625: method dispatch on NULL SELF argument is disallowed
```

**Solution:**
```sql
-- Create the collection first
collection := DBMS_SODA.CREATE_COLLECTION('products');

-- Or verify it exists
SELECT table_name FROM user_tables WHERE table_name = 'PRODUCTS';
```

---

### 3. JSON Syntax Errors in PL/SQL Strings

**Problem:**
```sql
b_content => UTL_RAW.cast_to_raw('{
  "name": "Product's Name"  -- ❌ Single quote breaks string
}')
```

**Solution:**
```sql
b_content => UTL_RAW.cast_to_raw('{
  "name": "Product''s Name"  -- ✅ Escape single quotes with double quotes
}')

-- Or use Q-quote notation:
b_content => UTL_RAW.cast_to_raw(q'[{
  "name": "Product's Name"
}]')  -- ✅ Q-quote handles single quotes
```

---

### 4. DBMS_OUTPUT Not Showing

**Problem:** SODA code executes but no output appears

**Solution:**
```sql
-- Enable DBMS_OUTPUT before running
SET SERVEROUTPUT ON

-- Then execute SODA code
DECLARE
  collection SODA_COLLECTION_T;
BEGIN
  DBMS_OUTPUT.PUT_LINE('This will now appear');
END;
/
```

---

### 5. Document Key vs ID Confusion

**Problem:**
```sql
-- Document has "_id" field
{"_id": "PROD-001"}

-- But using wrong key in find()
collection.find().key('_id').get_one();  -- ❌ Wrong
```

**Solution:**
```sql
-- Use the value of _id, not the field name
collection.find().key('PROD-001').get_one();  -- ✅ Correct
```

---

## Implementation Workflow

### Step-by-Step Process:

1. **Read Lab Content**
   - Identify all SQL INSERT, UPDATE, DELETE operations
   - Identify simple SELECT by ID operations
   - Skip complex queries, joins, analytics

2. **For Each CRUD Operation:**
   - Add "SQL Approach:" header before existing SQL
   - Wrap existing SQL in `if type="sql"` ... `/if`
   - Add "SODA Approach:" header
   - Add SODA version in `if type="soda"` ... `/if`
   - Use patterns from this template

3. **Test SODA Code:**
   - Execute in Oracle Database
   - Capture actual output
   - Update expected output if different

4. **Update Manifests:**
   - Add `"type": "sql,soda"` to lab in tenancy/manifest.json
   - Add `"type": "sql,soda"` to lab in desktop/manifest.json

5. **Commit Changes:**
   - Commit lab content changes
   - Commit manifest changes
   - Push to repository

---

## Lab-Specific Guidance

### Lab 1: JSON Collections Fundamentals
**SODA Coverage:** All CRUD operations (inserts, updates, deletes)
**Status:** ✅ Complete (5 SODA examples implemented)

### Lab 2: Embedded vs Referenced Patterns
**SODA Coverage:** Document inserts for both patterns, updates to embedded documents
**Estimate:** ~8-10 CRUD operations
**Focus:** Show how SODA handles embedded arrays and referenced IDs

### Lab 3: Single Collection/Table Design
**SODA Coverage:** Composite key inserts, updates by composite key
**Estimate:** ~15-20 CRUD operations
**Focus:** Demonstrate SODA with hierarchical composite keys

### Lab 4: Computed Pattern & Pre-Aggregations
**SODA Coverage:** Insert documents with pre-calculated fields
**Estimate:** ~5-8 CRUD operations
**Note:** Aggregation queries should remain SQL-only

### Lab 5: Bucketing Pattern for Time-Series
**SODA Coverage:** Limited - time-series queries are better in SQL
**Estimate:** ~3-5 CRUD operations for bucket inserts
**Note:** Skip complex time-range queries

### Lab 6: Polymorphic Pattern
**SODA Coverage:** Insert different entity types, updates by type
**Estimate:** ~3-5 CRUD operations
**Focus:** Show SODA handling documents with type discriminators

### Lab 7: Avoiding LOB Performance Cliffs
**SODA Coverage:** Insert documents of various sizes
**Estimate:** ~5-8 CRUD operations
**Note:** Performance analysis should remain SQL-focused

### Lab 8: Indexing Strategies
**SODA Coverage:** None - indexing is SQL-only
**Estimate:** 0 SODA operations
**Note:** Skip this lab for SODA

### Lab 9: Performance Testing & Comparison
**SODA Coverage:** Basic CRUD for benchmarking
**Estimate:** ~5-8 CRUD operations
**Note:** Performance queries should remain SQL

### Lab 10: Advanced Patterns & Best Practices
**SODA Coverage:** Examples for Subset and Extended Reference patterns
**Estimate:** ~5-8 CRUD operations
**Note:** JSON Duality Views section is SQL-only

---

## Quick Reference Card

### SODA API Essentials

```sql
-- Collection Management
collection := DBMS_SODA.OPEN_COLLECTION('name');
collection := DBMS_SODA.CREATE_COLLECTION('name');

-- Insert
status := collection.insert_one(SODA_DOCUMENT_T(b_content => UTL_RAW.cast_to_raw('json')));

-- Replace
status := collection.find().key('id').replace_one(SODA_DOCUMENT_T(...));

-- Get
doc := collection.find().key('id').get_one();
doc_content := doc.get_clob();

-- Delete
status := collection.find().key('id').remove();

-- Count
count := collection.find().count();

-- Query by Example (QBE)
doc := collection.find().filter('{"category": "Electronics"}').get_one();
```

### Conditional Tab Template

```markdown
**SQL Approach:**

if type="sql"

```sql
<copy>
-- SQL code
</copy>
```

Expected output:
```
-- Output
```

/if

**SODA Approach:**

if type="soda"

```sql
<copy>
-- SODA code
</copy>
```

Expected output:
```
-- Output
```

/if
```

---

## Resources

### Oracle Documentation
- [SODA for PL/SQL Guide](https://docs.oracle.com/en/database/oracle/simple-oracle-document-access/adsdi/)
- [DBMS_SODA Package Reference](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_SODA.html)
- [Oracle JSON Collections](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/json-collections.html)

### Workshop Documentation
- [docs/CLAUDE.md](CLAUDE.md) - Development workflow
- [docs/IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md) - Lab status
- [docs/WORKSHOP_PLAN.md](WORKSHOP_PLAN.md) - Workshop design

---

## Version History

- **v1.0 (November 2024):** Initial template created based on Lab 1 implementation
  - 8 core SODA patterns documented
  - Conditional tab syntax standardized
  - Testing workflow established
  - Lab-specific guidance added

---

**Questions or Issues?** Please refer to [docs/CLAUDE.md](CLAUDE.md) for development support or open an issue in the workshop repository.
