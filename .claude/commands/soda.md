# SODA Implementation Command

You are implementing SODA (Simple Oracle Document Access) for PL/SQL examples in the JSON Document Modeling workshop labs.

## Your Task

Add SODA examples alongside existing SQL examples using conditional tabs. Follow these steps:

### 1. Review the Template

First, carefully read the comprehensive template at:
**docs/SODA_IMPLEMENTATION_TEMPLATE.md**

This template contains:
- When to use SODA vs SQL/JSON
- 8 core SODA code patterns (insert, update, delete, read, etc.)
- Conditional tab syntax for LiveLabs markdown
- Testing and validation procedures
- Common issues and solutions
- Lab-specific guidance

### 2. Identify CRUD Operations

For the lab you're working on:
- ✅ Add SODA for: INSERT, UPDATE, DELETE, simple SELECT by ID
- ❌ Skip SODA for: Complex queries, joins, analytics, indexing, aggregations

**Use SQL/JSON exclusively for:**
- JSON_VALUE, JSON_QUERY, JSON_TABLE queries
- GROUP BY, aggregations (COUNT, SUM, AVG)
- Complex WHERE clauses with multiple conditions
- Index creation and management
- Performance benchmarking queries

### 3. Implementation Pattern

For each CRUD operation in the lab:

**Before:**
```sql
INSERT INTO products (json_document)
VALUES (JSON_OBJECT('_id' VALUE 'PROD-001', 'name' VALUE 'Product'));
```

**After:**
```markdown
**SQL Approach:**

if type="sql"

```sql
<copy>
INSERT INTO products (json_document)
VALUES (JSON_OBJECT('_id' VALUE 'PROD-001', 'name' VALUE 'Product'));
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
        "name": "Product"
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

### 4. Test Every SODA Example

**CRITICAL:** You must test each SODA example before including it:

```bash
sudo docker exec -it oracle23ai bash -c "
sqlplus jsonuser/WelcomeJson#123@FREEPDB1 << 'SQLEOF'
SET SERVEROUTPUT ON

-- Paste SODA code here to test
DECLARE
  collection SODA_COLLECTION_T;
  status NUMBER;
BEGIN
  collection := DBMS_SODA.OPEN_COLLECTION('collection_name');
  -- Test code...
END;
/

EXIT;
SQLEOF
"
```

Capture the actual output and use it as the expected output in the markdown.

### 5. Update Manifests

After adding SODA examples to a lab, update both manifest files:

**File 1:** workshops/tenancy/manifest.json
**File 2:** workshops/desktop/manifest.json

Add the `"type": "sql,soda"` attribute:
```json
{
  "title": "Lab N: Lab Title",
  "description": "Lab description",
  "filename": "../../labs/0N-labname/labname.md",
  "type": "sql,soda"
},
```

### 6. Common SODA Patterns from Template

Refer to docs/SODA_IMPLEMENTATION_TEMPLATE.md for these patterns:

1. **Pattern 1:** Insert Single Document
2. **Pattern 2:** Insert Multiple Documents
3. **Pattern 3:** Insert from Raw JSON String
4. **Pattern 4:** Replace Entire Document
5. **Pattern 5:** MERGEPATCH Pattern (fetch, merge, replace)
6. **Pattern 6:** Delete Document by Key
7. **Pattern 7:** Simple Read by Key
8. **Pattern 8:** Count Documents

### 7. Key Reminders

- **DO NOT indent** the `if type="sql"` and `/if` tags
- Always include `<copy>` tags around code blocks
- Include expected output after each code block
- Use `UTL_RAW.cast_to_raw()` for JSON strings in SODA
- SODA adds "PL/SQL procedure successfully completed." to output
- For MERGEPATCH, use the 3-step pattern: fetch → merge in SQL → replace

### 8. Lab-Specific Estimates

Based on template guidance:

- **Lab 2:** ~8-10 CRUD operations (embedded arrays, referenced IDs)
- **Lab 3:** ~15-20 CRUD operations (composite keys, hierarchical data)
- **Lab 4:** ~5-8 CRUD operations (pre-calculated fields)
- **Lab 5:** ~3-5 CRUD operations (bucket inserts only)
- **Lab 6:** ~3-5 CRUD operations (polymorphic types)
- **Lab 7:** ~5-8 CRUD operations (document sizes)
- **Lab 8:** 0 CRUD operations (indexing is SQL-only, skip SODA)
- **Lab 9:** ~5-8 CRUD operations (benchmark inserts)
- **Lab 10:** ~5-8 CRUD operations (subset, extended reference)

### 9. Workflow Summary

For each lab:

1. ✅ Read docs/SODA_IMPLEMENTATION_TEMPLATE.md thoroughly
2. ✅ Identify all CRUD operations in the lab content
3. ✅ Add "SQL Approach:" and "SODA Approach:" with conditional tabs
4. ✅ Test each SODA example in Oracle Database
5. ✅ Capture and include actual output
6. ✅ Update both manifest.json files
7. ✅ Commit changes with descriptive message
8. ✅ Push to repository

### 10. Quality Checklist

Before marking a lab complete:

- [ ] All CRUD operations have SODA alternatives
- [ ] Complex queries remain SQL-only (no forced SODA)
- [ ] All SODA code has been executed and tested
- [ ] Expected outputs match actual outputs
- [ ] Conditional tab syntax is correct (not indented)
- [ ] Both manifest files updated with "type": "sql,soda"
- [ ] Code blocks have `<copy>` tags
- [ ] Blank lines maintained for readability
- [ ] Commit message describes the changes
- [ ] Changes pushed to repository

---

## Example Usage

When the user says: "/soda Lab 2" or just "/soda", you should:

1. Read docs/SODA_IMPLEMENTATION_TEMPLATE.md
2. Open the lab file (e.g., labs/02-embedded-referenced/embedded-referenced.md)
3. Identify CRUD operations
4. Add SODA examples with conditional tabs
5. Test each SODA example
6. Update manifests
7. Commit and push

## Important Notes

- **Token efficiency:** You have the full template in docs/SODA_IMPLEMENTATION_TEMPLATE.md, so reference it rather than recreating patterns
- **Consistency:** Use the exact pattern syntax from the template
- **Testing required:** Never include untested SODA code
- **SQL for complexity:** When in doubt, leave complex operations as SQL-only

---

**Ready to implement SODA for a lab? Just say which lab number, and I'll get started!**
