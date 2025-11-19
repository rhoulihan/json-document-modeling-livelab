# Lab 6: Polymorphic Pattern within Single Collection

## Introduction

The Polymorphic Pattern allows you to store multiple different entity types in a single collection while maintaining type-specific schemas and query capabilities. This pattern, combined with composite keys from Lab 3, enables flexible and performant data models for heterogeneous data.

In this lab, you will learn advanced polymorphic techniques, indexing strategies, and when to use this pattern effectively.

**Estimated Time:** 30 minutes

## Prerequisites

- Completed Lab 3: Single Collection/Table Design Pattern
- Understanding of composite keys and Single Collection design
- Familiarity with JSON schema validation

## Objectives

In this lab, you will:
- Implement polymorphic documents using type discriminators
- Design schemas for multiple entity types in one collection
- Create efficient indexes for polymorphic queries
- Handle type-specific validation and constraints
- Query across entity types efficiently

## Task 1: Understanding Polymorphic Design

### Step 1: The Polymorphic Pattern in Single Collection

The Polymorphic Pattern is already at the core of Single Collection design (from Lab 3):

```json
// Customer document
{
  "_id": "CUSTOMER#456",
  "type": "customer",
  "name": "John Doe",
  "email": "john@example.com"
}

// Order document
{
  "_id": "CUSTOMER#456#ORDER#001",
  "type": "order",
  "customer_id": "CUSTOMER#456",
  "total": 125.50
}

// Payment document
{
  "_id": "CUSTOMER#456#ORDER#001#PAYMENT#001",
  "type": "payment",
  "amount": 125.50,
  "method": "credit_card"
}
```

**Key Principle:**
> **Use a `type` field as the discriminator to identify which schema/entity the document represents.**

## Task 2: Advanced Polymorphic Scenarios

### Step 1: Financial Transactions (Multiple Transaction Types)

```sql
-- Create transactions collection
CREATE TABLE transactions (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
);
```

**Expected output:**
```
Table created.
```

```sql
-- Type 1: Deposit
INSERT INTO transactions (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'ACCOUNT#ACC-789#TXN#001',
    'type' VALUE 'deposit',
    'account_id' VALUE 'ACC-789',
    'amount' VALUE 1000.00,
    'source' VALUE 'wire_transfer',
    'reference_number' VALUE 'WIR-2024-123456',
    'timestamp' VALUE SYSTIMESTAMP
  )
);
```

**Expected output:**
```
1 row created.
```

```sql
-- Type 2: Withdrawal
INSERT INTO transactions (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'ACCOUNT#ACC-789#TXN#002',
    'type' VALUE 'withdrawal',
    'account_id' VALUE 'ACC-789',
    'amount' VALUE 250.00,
    'method' VALUE 'atm',
    'atm_location' VALUE 'Main St Branch',
    'fee' VALUE 2.50,
    'timestamp' VALUE SYSTIMESTAMP
  )
);
```

**Expected output:**
```
1 row created.
```

```sql
-- Type 3: Transfer
INSERT INTO transactions (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'ACCOUNT#ACC-789#TXN#003',
    'type' VALUE 'transfer',
    'from_account' VALUE 'ACC-789',
    'to_account' VALUE 'ACC-456',
    'amount' VALUE 500.00,
    'memo' VALUE 'Rent payment',
    'timestamp' VALUE SYSTIMESTAMP
  )
);

COMMIT;
```

**Expected output:**
```
1 row created.
Commit complete.
```

```sql
-- Query all transactions for an account
SELECT JSON_QUERY(json_document, '$' PRETTY)
FROM transactions
WHERE JSON_VALUE(json_document, '$._id') LIKE 'ACCOUNT#ACC-789#TXN#%'
ORDER BY JSON_VALUE(json_document, '$.timestamp' RETURNING TIMESTAMP) DESC;
```

**Expected output:**
```json
{
  "_id" : "ACCOUNT#ACC-789#TXN#003",
  "type" : "transfer",
  "from_account" : "ACC-789",
  "to_account" : "ACC-456",
  "amount" : 500,
  "memo" : "Rent payment",
  "timestamp" : "2025-11-19T..."
}

{
  "_id" : "ACCOUNT#ACC-789#TXN#002",
  "type" : "withdrawal",
  "account_id" : "ACC-789",
  "amount" : 250,
  "method" : "atm",
  "atm_location" : "Main St Branch",
  "fee" : 2.5,
  "timestamp" : "2025-11-19T..."
}

{
  "_id" : "ACCOUNT#ACC-789#TXN#001",
  "type" : "deposit",
  "account_id" : "ACC-789",
  "amount" : 1000,
  "source" : "wire_transfer",
  "reference_number" : "WIR-2024-123456",
  "timestamp" : "2025-11-19T..."
}
```

### Step 2: Product Catalog (Different Product Categories)

```sql
-- Create product catalog collection
CREATE TABLE products (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
);
```

**Expected output:**
```
Table created.
```

```sql
-- Type 1: Book
INSERT INTO products (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'PRODUCT#BOOK-001',
    'type' VALUE 'book',
    'category' VALUE 'books',
    'title' VALUE 'Database Design Patterns',
    'author' VALUE 'Jane Smith',
    'isbn' VALUE '978-0-123456-78-9',
    'pages' VALUE 420,
    'publisher' VALUE 'Tech Publishing',
    'price' VALUE 49.99
  )
);

-- Type 2: Electronics
INSERT INTO products (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'PRODUCT#ELEC-001',
    'type' VALUE 'electronics',
    'category' VALUE 'electronics',
    'name' VALUE 'Wireless Mouse',
    'brand' VALUE 'TechCo',
    'model' VALUE 'WM-2024',
    'warranty_months' VALUE 24,
    'specifications' VALUE JSON_OBJECT(
      'connectivity' VALUE 'Bluetooth 5.0',
      'battery_life' VALUE '6 months',
      'dpi' VALUE 1600
    ),
    'price' VALUE 29.99
  )
);

-- Type 3: Clothing
INSERT INTO products (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'PRODUCT#CLOTH-001',
    'type' VALUE 'clothing',
    'category' VALUE 'clothing',
    'name' VALUE 'Cotton T-Shirt',
    'brand' VALUE 'FashionCo',
    'sizes' VALUE JSON_ARRAY('S', 'M', 'L', 'XL'),
    'colors' VALUE JSON_ARRAY('black', 'white', 'blue'),
    'material' VALUE '100% Cotton',
    'price' VALUE 19.99
  )
);

COMMIT;
```

**Expected output:**
```
1 row created.
1 row created.
1 row created.
Commit complete.
```

## Task 3: Indexing Strategies for Polymorphic Collections

### Step 1: Create Type Discriminator Index

```sql
-- Index on type field (essential for polymorphic queries)
CREATE INDEX idx_transactions_type ON transactions (
  JSON_VALUE(json_document, '$.type')
);

-- This enables efficient type filtering:
-- WHERE JSON_VALUE(json_document, '$.type') = 'deposit'
```

**Expected output:**
```
Index created.
```

### Step 2: Create Composite Indexes with Type Filter

```sql
-- Index on account_id with type filter (for account transaction queries)
CREATE INDEX idx_transactions_account ON transactions (
  JSON_VALUE(json_document, '$.account_id'),
  JSON_VALUE(json_document, '$.timestamp' RETURNING TIMESTAMP)
)
WHERE JSON_VALUE(json_document, '$.type') IN ('deposit', 'withdrawal', 'transfer');

-- Index on product category with type (for category browsing)
CREATE INDEX idx_products_category ON products (
  JSON_VALUE(json_document, '$.category'),
  JSON_VALUE(json_document, '$.price' RETURNING NUMBER)
);
```

**Expected output:**
```
Index created.
```

> **Note:** The WHERE clause on line 284 will produce an error in Oracle. Remove it or see the updated Task 3 Step 3 below for the correct Oracle approach.

### Step 3: Type-Specific Indexes

> **Note:** Oracle Database doesn't support partial indexes with WHERE clauses like PostgreSQL. Instead, create regular indexes on type-specific fields and rely on the type discriminator index for filtering.

```sql
-- Index for deposit-specific queries (source lookup)
CREATE INDEX idx_deposits_source ON transactions (
  JSON_VALUE(json_document, '$.source'),
  JSON_VALUE(json_document, '$.amount' RETURNING NUMBER)
);

-- Index for book-specific queries (ISBN lookup)
CREATE INDEX idx_books_isbn ON products (
  JSON_VALUE(json_document, '$.isbn')
);

-- Index for electronics-specific queries (brand lookup)
CREATE INDEX idx_electronics_brand ON products (
  JSON_VALUE(json_document, '$.brand')
);

-- These indexes work in combination with the type discriminator index
-- Query optimizer will use both indexes when you filter by type AND field:
-- WHERE JSON_VALUE(json_document, '$.type') = 'book'
--   AND JSON_VALUE(json_document, '$.isbn') = '978-0-123456-78-9'
```

**Expected output:**
```
Index created.
Index created.
Index created.
```

## Task 4: Querying Polymorphic Collections

### Step 1: Type-Specific Queries

```sql
-- Query only deposits
SELECT
  JSON_VALUE(json_document, '$._id') AS txn_id,
  JSON_VALUE(json_document, '$.amount' RETURNING NUMBER) AS amount,
  JSON_VALUE(json_document, '$.source') AS source,
  JSON_VALUE(json_document, '$.timestamp' RETURNING TIMESTAMP) AS txn_time
FROM transactions
WHERE JSON_VALUE(json_document, '$.type') = 'deposit'
  AND JSON_VALUE(json_document, '$.amount' RETURNING NUMBER) > 1000
ORDER BY JSON_VALUE(json_document, '$.timestamp' RETURNING TIMESTAMP) DESC;
```

**Expected output:**
```
TXN_ID                       AMOUNT SOURCE          TXN_TIME
--------------------------- ------- --------------- ----------------------------
ACCOUNT#ACC-789#TXN#001        1000 wire_transfer   2025-11-19 15:30:45.123456
```

> **Note:** Only deposits with amount > 1000 are returned. In our test data, we have 1 matching row.

```sql
-- Query only books by author
SELECT
  JSON_VALUE(json_document, '$.title') AS title,
  JSON_VALUE(json_document, '$.author') AS author,
  JSON_VALUE(json_document, '$.price' RETURNING NUMBER) AS price
FROM products
WHERE JSON_VALUE(json_document, '$.type') = 'book'
  AND JSON_VALUE(json_document, '$.author') LIKE '%Smith%';
```

**Expected output:**
```
TITLE                          AUTHOR       PRICE
------------------------------ ------------ ------
Database Design Patterns       Jane Smith    49.99
```

### Step 2: Cross-Type Aggregations

```sql
-- Count transactions by type
SELECT
  JSON_VALUE(json_document, '$.type') AS transaction_type,
  COUNT(*) AS count,
  SUM(JSON_VALUE(json_document, '$.amount' RETURNING NUMBER)) AS total_amount
FROM transactions
WHERE JSON_VALUE(json_document, '$.account_id') = 'ACC-789'
GROUP BY JSON_VALUE(json_document, '$.type')
ORDER BY total_amount DESC;

/*
Expected Result:
TRANSACTION_TYPE   COUNT  TOTAL_AMOUNT
-----------------  -----  ------------
deposit            45     125000.00
transfer           23     45000.00
withdrawal         67     32000.00
*/

-- Product count and revenue by category
SELECT
  JSON_VALUE(json_document, '$.category') AS category,
  JSON_VALUE(json_document, '$.type') AS product_type,
  COUNT(*) AS product_count,
  ROUND(AVG(JSON_VALUE(json_document, '$.price' RETURNING NUMBER)), 2) AS avg_price
FROM products
GROUP BY
  JSON_VALUE(json_document, '$.category'),
  JSON_VALUE(json_document, '$.type')
ORDER BY product_count DESC;
```

### Step 3: Using JSON_TABLE for Type-Specific Fields

```sql
-- Extract type-specific fields using JSON_TABLE
SELECT
  jt.*
FROM products,
     JSON_TABLE(
       json_document,
       '$'
       COLUMNS (
         product_id VARCHAR2(50) PATH '$._id',
         product_type VARCHAR2(20) PATH '$.type',
         -- Common fields
         price NUMBER PATH '$.price',
         -- Book-specific fields
         title VARCHAR2(200) PATH '$.title',
         author VARCHAR2(100) PATH '$.author',
         isbn VARCHAR2(20) PATH '$.isbn',
         -- Electronics-specific fields
         brand VARCHAR2(50) PATH '$.brand',
         model VARCHAR2(50) PATH '$.model',
         warranty_months NUMBER PATH '$.warranty_months'
       )
     ) jt
WHERE jt.product_type IN ('book', 'electronics')
ORDER BY jt.product_id;

/*
Result shows all columns with NULLs for type-specific fields that don't apply:
PRODUCT_ID         PRODUCT_TYPE  PRICE   TITLE                      AUTHOR      ISBN               BRAND   MODEL     WARRANTY_MONTHS
-----------------  ------------  ------  -------------------------  ----------  -----------------  ------  --------  ---------------
PRODUCT#BOOK-001   book          49.99   Database Design Patterns   Jane Smith  978-0-123456-78-9  (null)  (null)    (null)
PRODUCT#ELEC-001   electronics   29.99   (null)                     (null)      (null)             TechCo  WM-2024   24
*/
```

## Task 5: Schema Validation for Polymorphic Documents

### Step 1: Implement Type-Specific Validation

```sql
-- Create validation function for polymorphic documents
CREATE OR REPLACE FUNCTION validate_transaction(
  p_doc JSON_OBJECT_T
) RETURN BOOLEAN IS
  v_type VARCHAR2(50);
  v_valid BOOLEAN := TRUE;
BEGIN
  v_type := p_doc.get_String('type');

  -- Validate common fields
  IF p_doc.get_String('account_id') IS NULL THEN
    RETURN FALSE;
  END IF;

  IF p_doc.get_Number('amount') IS NULL OR p_doc.get_Number('amount') <= 0 THEN
    RETURN FALSE;
  END IF;

  -- Type-specific validation
  CASE v_type
    WHEN 'deposit' THEN
      -- Deposits must have source
      IF p_doc.get_String('source') IS NULL THEN
        v_valid := FALSE;
      END IF;

    WHEN 'withdrawal' THEN
      -- Withdrawals must have method
      IF p_doc.get_String('method') IS NULL THEN
        v_valid := FALSE;
      END IF;

    WHEN 'transfer' THEN
      -- Transfers must have from_account and to_account
      IF p_doc.get_String('from_account') IS NULL OR
         p_doc.get_String('to_account') IS NULL THEN
        v_valid := FALSE;
      END IF;

    ELSE
      -- Unknown type
      v_valid := FALSE;
  END CASE;

  RETURN v_valid;
END;
/

-- Test validation
DECLARE
  v_doc JSON_OBJECT_T;
  v_valid BOOLEAN;
BEGIN
  -- Valid deposit
  v_doc := JSON_OBJECT_T('{
    "type": "deposit",
    "account_id": "ACC-789",
    "amount": 1000,
    "source": "wire_transfer"
  }');
  v_valid := validate_transaction(v_doc);
  DBMS_OUTPUT.PUT_LINE('Valid deposit: ' || CASE WHEN v_valid THEN 'YES' ELSE 'NO' END);

  -- Invalid deposit (missing source)
  v_doc := JSON_OBJECT_T('{
    "type": "deposit",
    "account_id": "ACC-789",
    "amount": 1000
  }');
  v_valid := validate_transaction(v_doc);
  DBMS_OUTPUT.PUT_LINE('Invalid deposit: ' || CASE WHEN v_valid THEN 'YES' ELSE 'NO' END);
END;
/

/*
Expected Output:
Valid deposit: YES
Invalid deposit: NO
*/
```

## Task 6: Best Practices for Polymorphic Pattern

### Step 1: Design Guidelines

**DO:**
- ✅ Use consistent `type` field as discriminator across all documents
- ✅ Include common fields shared by all types (e.g., `_id`, `created_at`)
- ✅ Create indexes with type filters for efficient queries
- ✅ Document the schema for each type clearly
- ✅ Validate type-specific required fields

**DON'T:**
- ❌ Mix completely unrelated entity types in one collection
- ❌ Create polymorphic collections with vastly different access patterns
- ❌ Forget to index the `type` field
- ❌ Use ambiguous type names (e.g., "data", "item")

### Step 2: When to Use Polymorphic Pattern

**Use Polymorphic Pattern when:**
- ✅ Entities are related and accessed together (e.g., customer, orders, payments)
- ✅ Entities share common fields and operations
- ✅ Access patterns frequently span multiple entity types
- ✅ Composite keys can organize related entities hierarchically

**Avoid Polymorphic Pattern when:**
- ❌ Entities have completely different access patterns
- ❌ Entities have different security/permissions requirements
- ❌ Entities have different retention/archival policies
- ❌ Schemas are highly divergent with few shared fields

## Conclusion

In this lab, you learned how to effectively implement the Polymorphic Pattern within a Single Collection design.

**Key Takeaways:**
- ✅ Use `type` field as discriminator for different entity types
- ✅ Index `type` field and create type-specific partial indexes
- ✅ Query efficiently using type filters and composite indexes
- ✅ Validate type-specific required fields programmatically
- ✅ Apply polymorphic pattern when entities are related and accessed together

**Indexing Strategy:**
- Always index the `type` discriminator field
- Create partial indexes for type-specific queries
- Use composite indexes combining `type` with frequently queried fields

**Next Steps:**
- Proceed to **Lab 7: Avoiding LOB Performance Cliffs** for deep dive into OSON storage optimization

## Learn More

* [Oracle JSON Developer's Guide - JSON Collections](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/)
* [MongoDB Polymorphic Pattern Documentation](https://www.mongodb.com/docs/manual/data-modeling/design-patterns/polymorphic-pattern/)

## Acknowledgments

* **Author** - Rick Houlihan
* **Last Updated By/Date** - November 2024
