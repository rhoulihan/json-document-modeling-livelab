# Oracle Team Feedback Implementation Plan

**Created:** November 2024
**Status:** Ready for Implementation
**Estimated Scope:** 11 lab files + supporting docs (~421 occurrences to review)

---

## Summary of Decisions

Based on Oracle team feedback and clarification discussions:

| Decision | Choice |
|----------|--------|
| Database Version | 26ai only (remove 19c references), keep Docker option |
| Table Creation | `CREATE JSON COLLECTION TABLE` exclusively |
| SODA References | Remove all SODA/DBMS_SODA references |
| Terminology | Use "JSON Collection Table" terminology |
| JSON_TRANSFORM | Add new examples in fundamentals.md |
| MongoDB API | Keep with proper ACL configuration |
| GitHub Repo | Keep current repo link for now |
| OSON Tiers | Simplify to two tiers (inline vs out-of-line) |
| Multi-row INSERT | Use individual INSERT statements (multi-row is broken) |
| Custom `_id` values | Supported - use for composite key labs |

---

## Phase 1: Global Search & Replace

### 1.1 Version Naming Changes

**Files Affected:** All 11 labs + introduction.md + README.md

| Find | Replace With |
|------|--------------|
| `Oracle Database 23ai` | `Oracle AI Database 26ai` |
| `23ai` (standalone) | `26ai` |
| `Oracle Database 23ai Free` | `Oracle AI Database 26ai Free` |
| Any 19c references | Remove or update to 26ai |

**Docker Image Updates:**
```
Old: container-registry.oracle.com/database/free:latest
New: container-registry.oracle.com/database/adb-free:latest
```

### 1.2 SODA Removal

**Search patterns to remove/replace:**
- `DBMS_SODA` → Remove or replace with SQL equivalent
- `SODA_COLLECTION_T` → Remove
- `SODA_DOCUMENT_T` → Remove
- `SODA_CURSOR_T` → Remove
- `user_soda_collections` → `user_json_collections`
- All `if type="soda"` blocks → Remove entirely

### 1.3 Column Name Changes

| Find | Replace With |
|------|--------------|
| `json_document` | `data` |
| `JSON_DOCUMENT` | `DATA` |

---

## Phase 2: setup.md Changes

### 2.1 Task 1 - Database Options (Lines 29-64)

**Current:** Options A (Autonomous) and B (23ai Docker)
**Change to:**
- Option A: Autonomous AI JSON Database (26ai) - Recommended
- Option B: Oracle AI Database 26ai Free (Docker)

Update advantages list for both options.

### 2.2 Task 2A - Autonomous Database Setup (Lines 66-140)

**Line 94:** Change workload type description
```
Old: **Workload type:** Select **JSON**
New: **Workload type:** Select **JSON** (Autonomous AI JSON Database)
```

**Line 99:** Update version selection
```
Old: **Database version:** Select **23ai** (or latest available)
New: **Database version:** Select **26ai** (or latest available)
```

**Lines 109-113:** Add MongoDB API ACL Configuration

**NEW SECTION - Insert after Line 113:**
```markdown
6. Under **Network access** (IMPORTANT for MongoDB API):

   - Select **Secure access from allowed IPs and VCNs only**
   - Click **Add My IP Address** to add your current IP to the ACL

   > **Note:** MongoDB API requires ACL configuration. "Secure access from everywhere"
   > will NOT allow MongoDB API access. You must configure an Access Control List (ACL)
   > or use a private endpoint.

   > **Tip:** Your public IP may change. If you lose database access, check your ACL
   > configuration first.
```

### 2.3 Task 2B - Docker Setup (Lines 142-242)

**Line 169-173:** Update Docker pull command
```bash
# Old
docker pull container-registry.oracle.com/database/free:latest

# New
docker pull container-registry.oracle.com/database/adb-free:latest
```

**Lines 179-187:** Update docker run command
```bash
docker run -d \
  --name oracle26ai \
  -p 1521:1521 \
  -p 8443:8443 \
  -p 27017:27017 \
  -e ORACLE_PWD=Welcome123456 \
  container-registry.oracle.com/database/adb-free:latest
```

Add note about MongoDB port 27017.

### 2.4 Task 3 - Create Workshop User (Lines 244-308)

**Lines 263-264:** Remove SODA_APP grant
```sql
-- Remove this line:
GRANT SODA_APP TO jsonuser;

-- Keep these privileges for MongoDB API:
GRANT CREATE SESSION, CREATE TABLE TO jsonuser;
```

### 2.5 Task 4 - Create First JSON Collection (Lines 309-426)

**COMPLETE REWRITE of Step 2 (Lines 324-358):**

```markdown
### Step 2: Create a JSON Collection Table

1. Create a JSON Collection Table:

   ```sql
   -- Create a JSON Collection Table (26ai syntax)
   CREATE JSON COLLECTION TABLE test_collection;
   ```

   **Expected output:**
   ```
   Table created.
   ```

2. Verify the collection was created:

   ```sql
   SELECT table_name, collection_type
   FROM user_json_collections
   WHERE table_name = 'TEST_COLLECTION';
   ```

   Expected output:
   ```
   TABLE_NAME        COLLECTION_TYPE
   ---------------   ---------------
   TEST_COLLECTION   TABLE
   ```

3. Examine the table structure:

   ```sql
   DESC test_collection
   ```

   You will see:
   ```
   Name   Null?    Type
   ----   -----    ----
   DATA            JSON
   ```

   > **Note:** JSON Collection Tables have a single `DATA` column of type JSON.
   > The database automatically manages document IDs via the `_id` field.
```

**UPDATE Step 3 - Insert Document (Lines 361-408):**

```sql
-- Insert using the DATA column
INSERT INTO test_collection (data)
VALUES (
  JSON_OBJECT(
    'name' VALUE 'Alice Smith',
    'email' VALUE 'alice@example.com',
    'role' VALUE 'developer',
    'skills' VALUE JSON_ARRAY('SQL', 'Python', 'JavaScript'),
    'active' VALUE true
  )
);

COMMIT;
```

Note: Remove manual `_id` - let database generate it automatically.

**UPDATE Queries (Lines 389-425):**

```sql
-- Query the document
SELECT JSON_SERIALIZE(data PRETTY) FROM test_collection;

-- Query specific fields
SELECT
  data."_id".string() AS id,
  JSON_VALUE(data, '$.name') AS name,
  JSON_VALUE(data, '$.email') AS email
FROM test_collection;
```

### 2.6 Task 5 - Verify Environment (Lines 455-557)

**Lines 459-469:** Remove COMPATIBLE check for 19c
```sql
-- Remove this query about COMPATIBLE version
-- Replace with:
SELECT * FROM user_json_collections;
```

### 2.7 Troubleshooting Section (Lines 609-680)

**UPDATE "Cannot create collection" (Lines 661-680):**

```markdown
### Issue: Cannot create collection

**Error:** `ORA-00955: name is already used by an existing object`

**Solution:**
```sql
-- For 26ai, simply drop the table
DROP TABLE test_collection;

-- Recreate the JSON Collection Table
CREATE JSON COLLECTION TABLE test_collection;
```
```

---

## Phase 3: fundamentals.md Changes

### 3.1 Task 1 - Create JSON Collections (Lines 32-120)

**COMPLETE REWRITE - Remove all SODA, use JSON Collection Tables only:**

```markdown
## Task 1: Create JSON Collection Tables

Oracle AI Database 26ai introduces JSON Collection Tables - single-column tables
optimized for JSON document storage.

### Step 1: Create a Products Collection

1. Create the products collection:

   ```sql
   CREATE JSON COLLECTION TABLE products;
   ```

2. Verify the collection was created:

   ```sql
   SELECT table_name, collection_type
   FROM user_json_collections;
   ```

   Expected output:
   ```
   TABLE_NAME    COLLECTION_TYPE
   ----------    ---------------
   PRODUCTS      TABLE
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

   > **Key Point:** JSON Collection Tables have a single `DATA` column. The database
   > automatically injects an `_id` field into each document for identification.

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
```

### 3.2 Task 2 - Insert Documents (Lines 122-659)

**REMOVE all `if type="soda"` blocks entirely.**

**UPDATE SQL INSERT syntax to use DATA column (Lines 130-158):**

```sql
INSERT INTO products (data)
VALUES (
  JSON_OBJECT(
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

**FIX Multi-record INSERT bug (Lines 357-427):**

Multi-row INSERT (`VALUES (...), (...), (...)`) is broken with JSON Collection Tables.
Convert to individual INSERT statements. Custom `_id` values ARE supported for composite key patterns.

```sql
-- Insert PROD-001 (with custom _id for composite key patterns)
INSERT INTO products (data)
VALUES (JSON_OBJECT(
  '_id' VALUE 'PROD-001',
  'name' VALUE 'Wireless Bluetooth Headphones',
  'category' VALUE 'Electronics',
  -- ... rest of document
));

-- Insert PROD-002
INSERT INTO products (data)
VALUES (JSON_OBJECT(
  '_id' VALUE 'PROD-002',
  'name' VALUE 'Ergonomic Wireless Mouse',
  'category' VALUE 'Electronics',
  -- ... rest of document
));

-- Insert PROD-003
INSERT INTO products (data)
VALUES (JSON_OBJECT(
  '_id' VALUE 'PROD-003',
  'name' VALUE 'Mechanical Gaming Keyboard',
  'category' VALUE 'Electronics',
  -- ... rest of document
));

-- Insert PROD-004
INSERT INTO products (data)
VALUES (JSON_OBJECT(
  '_id' VALUE 'PROD-004',
  'name' VALUE '27-inch 4K Monitor',
  'category' VALUE 'Electronics',
  -- ... rest of document
));

COMMIT;
```

> **Note on `_id` values:**
> - Custom `_id` values (strings like 'PROD-001') are fully supported
> - Essential for composite key patterns (e.g., 'CUSTOMER#123#ORDER#456')
> - If omitted, database auto-generates a RAW-based `_id`
> - Once set, `_id` cannot be changed (immutable)

**UPDATE REST API example path (Lines 253-294):**

```bash
# OLD (wrong):
http://localhost:8080/ords/mydb/_soda/latest/products

# NEW (correct):
http://localhost:8080/ords/jsonuser/soda/latest/products
```

Add prerequisite note:
```markdown
> **Prerequisite:** The schema must be REST-enabled before using SODA REST API.
> Enable with: `EXEC ORDS.ENABLE_SCHEMA;`
```

### 3.3 Task 3 - Query Documents (Lines 661-1052)

**UPDATE all queries to use `data` column instead of `json_document`:**

```sql
-- OLD
SELECT JSON_VALUE(json_document, '$.name') FROM products;

-- NEW
SELECT JSON_VALUE(data, '$.name') FROM products;
```

**REMOVE all `if type="soda"` query blocks.**

### 3.4 Task 4 - Update Documents (Lines 1054-1396)

**UPDATE all references from `json_document` to `data`:**

```sql
-- OLD
UPDATE products
SET json_document = JSON_MERGEPATCH(json_document, '{"price": 69.99}')
WHERE JSON_VALUE(json_document, '$._id') = 'PROD-001';

-- NEW
UPDATE products
SET data = JSON_MERGEPATCH(data, '{"price": 69.99}')
WHERE data."_id".string() = 'generated_id_here';
```

**ADD NEW SECTION - JSON_TRANSFORM (After Step 3, around line 1396):**

```markdown
### Step 4: Update with JSON_TRANSFORM (Recommended)

`JSON_TRANSFORM` is the most powerful method for modifying JSON documents,
offering fine-grained control over updates.

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

6. Conditional updates with NESTED PATH (26ai):

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
| Add fields | ✅ SET | ✅ |
| Remove fields | ✅ REMOVE | ✅ (set to null) |
| Update nested | ✅ Path expressions | ✅ Merge semantics |
| Array operations | ✅ APPEND, PREPEND, SORT | ❌ Replaces entire array |
| Conditional | ✅ CASE, NESTED PATH | ❌ |
| Arithmetic | ✅ PATH expressions | ❌ |

> **Recommendation:** Use `JSON_TRANSFORM` for most update operations. It provides
> more control and better handles edge cases with arrays and nested structures.
```

**REMOVE all `if type="soda"` update blocks.**

### 3.5 Task 6 - OSON Format (Lines 1479-1563)

**FIX OSON size tiers (Lines 1495-1510):**

```sql
-- OLD (incorrect thresholds)
SELECT
  ...
  CASE
    WHEN LENGTHB(json_document) < 7950 THEN 'INLINE (Fast)'
    WHEN LENGTHB(json_document) < 10240 THEN 'LOB (OK)'
    WHEN LENGTHB(json_document) < 102400 THEN 'LOB (Slower)'
    ELSE 'LOB (Avoid if possible)'
  END AS storage_tier
...

-- NEW (simplified two-tier)
SELECT
  data."_id".string() AS document_id,
  JSON_VALUE(data, '$.name') AS product_name,
  LENGTHB(data) AS oson_bytes,
  CASE
    WHEN LENGTHB(data) < 7950 THEN 'INLINE (Fast)'
    ELSE 'OUT-OF-LINE (Slower)'
  END AS storage_tier
FROM products
ORDER BY oson_bytes DESC;
```

**UPDATE explanation (Lines 1514-1532):**

```markdown
### Step 2: Understanding OSON Storage

**OSON Storage Tiers:**

1. **Inline storage (< ~7,950 bytes):**
   - Document stored directly in the table row
   - Single I/O operation to read
   - **Best performance** - design documents to stay in this range

2. **Out-of-line/LOB storage (≥ ~7,950 bytes):**
   - Document stored in separate LOB segment
   - Additional I/O required to fetch document
   - Larger documents = more "clutter" when accessing specific fields
   - **Maximum document size:** 32MB

> **Design Principle:** The performance difference between inline and out-of-line
> storage is significant. Once a document exceeds the inline threshold, additional
> size primarily affects how much unnecessary data is read when querying specific
> fields. Keep frequently-accessed documents under 7,950 bytes whenever possible.
```

### 3.6 Task 7 - MongoDB API (Lines 1564-1604)

Keep this section but update connection string to reflect ACL requirement:

```javascript
// Note: MongoDB API requires ACL configuration on Autonomous Database
// Connection string format:
// mongosh "mongodb://user:password@host:27017/schema?authMechanism=PLAIN&authSource=$external&tls=true&tlsAllowInvalidCertificates=true"
```

### 3.7 Task 8 - Delete Documents (Lines 1606-1820)

**UPDATE all queries to use `data` column:**

```sql
-- OLD
DELETE FROM products
WHERE JSON_VALUE(json_document, '$._id') = 'PROD-002';

-- NEW
DELETE FROM products
WHERE data."_id".string() = 'generated_id_here';
-- Or filter by other fields:
DELETE FROM products
WHERE JSON_VALUE(data, '$.name') = 'Ergonomic Wireless Mouse';
```

**REMOVE all `if type="soda"` delete blocks.**

**UPDATE Clean Up section (Lines 1810-1819):**

```sql
-- Truncate entire collection
TRUNCATE TABLE products;

-- Or drop collection completely
DROP TABLE products;

-- Recreate if needed
CREATE JSON COLLECTION TABLE products;
```

---

## Phase 4: Other Lab Files

Apply similar changes to remaining labs (2-10):

### 4.1 Changes Required in All Labs

1. Replace `json_document` → `data`
2. Replace `23ai` → `26ai`
3. Remove all SODA blocks (`if type="soda"`)
4. Update table creation to `CREATE JSON COLLECTION TABLE`
5. Update `user_soda_collections` → `user_json_collections`

### 4.2 Files and Estimated Changes

| File | SODA/23ai Refs | Priority |
|------|----------------|----------|
| labs/02-embedded-referenced/embedded-referenced.md | 30 | High |
| labs/03-single-collection/single-collection.md | 39 | High |
| labs/04-computed-pattern/computed-pattern.md | 13 | Medium |
| labs/05-bucketing-pattern/bucketing-pattern.md | 5 | Medium |
| labs/06-polymorphic-pattern/polymorphic-pattern.md | 18 | Medium |
| labs/07-lob-cliffs/lob-cliffs.md | 28 | High |
| labs/08-indexing-strategies/indexing-strategies.md | 9 | Medium |
| labs/09-performance-testing/performance-testing.md | 8 | Medium |
| labs/10-advanced-patterns/advanced-patterns.md | 16 | Medium |
| introduction/introduction.md | 6 | High |
| README.md | 6 | High |

---

## Phase 5: Documentation Updates

### 5.1 Files to Update

- `docs/PATTERN_REFERENCE.md` - Update examples
- `docs/CLAUDE.md` - Update instructions
- `docs/WORKSHOP_PLAN.md` - Update version references
- `.claude/commands/soda.md` - Remove or repurpose (36 SODA refs)
- `docs/SODA_IMPLEMENTATION_TEMPLATE.md` - Remove or archive (105 SODA refs)

### 5.2 Files to Archive/Remove

Consider moving to `docs/archive/`:
- `docs/SODA_IMPLEMENTATION_TEMPLATE.md`
- `.claude/commands/soda.md`

---

## Phase 6: Validation Checklist

After all changes:

- [ ] All `CREATE TABLE` statements use `CREATE JSON COLLECTION TABLE`
- [ ] All column references use `data` not `json_document`
- [ ] No SODA/DBMS_SODA references remain (except archived docs)
- [ ] All version references say 26ai, not 23ai or 19c
- [ ] Docker instructions use correct 26ai image
- [ ] MongoDB API section includes ACL requirements
- [ ] OSON tiers simplified to inline vs out-of-line
- [ ] JSON_TRANSFORM examples added to fundamentals.md
- [ ] REST API paths corrected (`soda` not `_soda`)
- [ ] Multi-record INSERTs converted to individual statements
- [ ] All queries updated for `_id` access pattern (`data."_id".string()`)

---

## Implementation Order

1. **setup.md** - Foundation, must be done first
2. **fundamentals.md** - Core concepts, second priority
3. **introduction.md + README.md** - User-facing, high visibility
4. **Labs 2-3** - High reference count
5. **Lab 7 (LOB cliffs)** - OSON changes relevant
6. **Labs 4-6, 8-10** - Pattern labs
7. **Documentation cleanup** - Archive SODA docs

---

## References

- [Oracle JSON Collection Tables](https://oracle-base.com/articles/23/json-collections-23)
- [MongoDB API ACL Configuration](https://martincarstenbach.com/2024/10/25/enable-the-mongodb-api-on-always-free-autonomous-database/)
- [Oracle MongoDB API Documentation](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/mongo-using-oracle-database-api-mongodb.html)
- [JSON_TRANSFORM Reference](https://oracle-base.com/articles/21c/json_transform-21c)
- [JSON_TRANSFORM Enhancements 23ai](https://oracle-base.com/articles/23/json_transform-enhancements-23)
- [Oracle 26ai Docker](https://github.com/shakiyam/Oracle-AI-Database-26ai-Free-on-Docker)
