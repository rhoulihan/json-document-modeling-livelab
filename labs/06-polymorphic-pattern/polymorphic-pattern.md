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

## Task 2: Implementing Financial Transactions (Multiple Types)

### Step 1: Create the Transactions Collection

```sql
-- Create JSON Collection Table for transactions
CREATE JSON COLLECTION TABLE transactions;

-- Create indexes for polymorphic queries
CREATE INDEX idx_transactions_id ON transactions (JSON_VALUE(data, '$._id'));
CREATE INDEX idx_transactions_type ON transactions (JSON_VALUE(data, '$.type'));
CREATE INDEX idx_transactions_account ON transactions (JSON_VALUE(data, '$.account_id'));
```

### Step 2: Insert Different Transaction Types

```sql
-- Type 1: Deposit
INSERT INTO transactions (data) VALUES (
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

-- Type 2: Withdrawal
INSERT INTO transactions (data) VALUES (
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

-- Type 3: Transfer
INSERT INTO transactions (data) VALUES (
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

### Step 3: Query All Transactions for an Account

```sql
-- Query all transactions for an account (all types)
SELECT JSON_SERIALIZE(data PRETTY)
FROM transactions
WHERE JSON_VALUE(data, '$._id') LIKE 'ACCOUNT#ACC-789#TXN#%'
ORDER BY JSON_VALUE(data, '$.timestamp' RETURNING TIMESTAMP) DESC;
```

Expected output shows all three transaction types with their type-specific fields.

## Task 3: Product Catalog (Different Product Categories)

### Step 1: Create the Products Collection

```sql
-- Create JSON Collection Table for products
CREATE JSON COLLECTION TABLE products;

-- Create indexes
CREATE INDEX idx_products_id ON products (JSON_VALUE(data, '$._id'));
CREATE INDEX idx_products_type ON products (JSON_VALUE(data, '$.type'));
CREATE INDEX idx_products_category ON products (JSON_VALUE(data, '$.category'));
```

### Step 2: Insert Different Product Types

```sql
-- Type 1: Book
INSERT INTO products (data) VALUES (
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
INSERT INTO products (data) VALUES (
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
INSERT INTO products (data) VALUES (
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

### Step 3: Query Products by Type

```sql
-- Query all products and see the different schemas
SELECT
  JSON_VALUE(data, '$._id') AS product_id,
  JSON_VALUE(data, '$.type') AS product_type,
  JSON_VALUE(data, '$.price' RETURNING NUMBER) AS price
FROM products
ORDER BY JSON_VALUE(data, '$.type');
```

Expected output:
```
PRODUCT_ID          PRODUCT_TYPE    PRICE
------------------  --------------  ------
PRODUCT#BOOK-001    book            49.99
PRODUCT#CLOTH-001   clothing        19.99
PRODUCT#ELEC-001    electronics     29.99
```

## Task 4: Indexing Strategies for Polymorphic Collections

### Step 1: Type Discriminator Index (Essential)

The type index is essential for polymorphic queries:

```sql
-- Verify type index exists (already created above)
SELECT index_name FROM user_indexes
WHERE table_name = 'TRANSACTIONS' AND index_name LIKE '%TYPE%';

-- This enables efficient type filtering:
-- WHERE JSON_VALUE(data, '$.type') = 'deposit'
```

### Step 2: Type-Specific Field Indexes

Create indexes on fields specific to each type:

```sql
-- Index for deposit-specific queries (source lookup)
CREATE INDEX idx_deposits_source ON transactions (
  JSON_VALUE(data, '$.source'),
  JSON_VALUE(data, '$.amount' RETURNING NUMBER)
);

-- Index for book-specific queries (ISBN lookup)
CREATE INDEX idx_books_isbn ON products (
  JSON_VALUE(data, '$.isbn')
);

-- Index for electronics-specific queries (brand + model)
CREATE INDEX idx_electronics_brand ON products (
  JSON_VALUE(data, '$.brand'),
  JSON_VALUE(data, '$.model')
);

-- Multivalue index for clothing sizes
CREATE MULTIVALUE INDEX idx_clothing_sizes ON products p (p.data.sizes.string());
```

**Note:** These indexes work in combination with the type discriminator index. The query optimizer will use both indexes when you filter by type AND field:

```sql
-- This query uses both idx_transactions_type and idx_deposits_source
SELECT * FROM transactions
WHERE JSON_VALUE(data, '$.type') = 'deposit'
  AND JSON_VALUE(data, '$.source') = 'wire_transfer';
```

## Task 5: Querying Polymorphic Collections

### Step 1: Type-Specific Queries

```sql
-- Query only deposits with amount > 500
SELECT
  JSON_VALUE(data, '$._id') AS txn_id,
  JSON_VALUE(data, '$.amount' RETURNING NUMBER) AS amount,
  JSON_VALUE(data, '$.source') AS source,
  JSON_VALUE(data, '$.timestamp') AS txn_time
FROM transactions
WHERE JSON_VALUE(data, '$.type') = 'deposit'
  AND JSON_VALUE(data, '$.amount' RETURNING NUMBER) > 500
ORDER BY JSON_VALUE(data, '$.timestamp') DESC;
```

Expected output:
```
TXN_ID                       AMOUNT  SOURCE          TXN_TIME
--------------------------  -------  --------------  -------------------------
ACCOUNT#ACC-789#TXN#001       1000   wire_transfer   2025-11-25T...
```

```sql
-- Query only books by author
SELECT
  JSON_VALUE(data, '$.title') AS title,
  JSON_VALUE(data, '$.author') AS author,
  JSON_VALUE(data, '$.price' RETURNING NUMBER) AS price
FROM products
WHERE JSON_VALUE(data, '$.type') = 'book'
  AND JSON_VALUE(data, '$.author') LIKE '%Smith%';
```

Expected output:
```
TITLE                          AUTHOR       PRICE
------------------------------ ------------ ------
Database Design Patterns       Jane Smith    49.99
```

### Step 2: Cross-Type Aggregations

```sql
-- Count transactions by type
SELECT
  JSON_VALUE(data, '$.type') AS transaction_type,
  COUNT(*) AS count,
  SUM(JSON_VALUE(data, '$.amount' RETURNING NUMBER)) AS total_amount
FROM transactions
GROUP BY JSON_VALUE(data, '$.type')
ORDER BY total_amount DESC;
```

Expected output:
```
TRANSACTION_TYPE   COUNT  TOTAL_AMOUNT
-----------------  -----  ------------
deposit                1       1000.00
transfer               1        500.00
withdrawal             1        250.00
```

```sql
-- Product count and average price by category
SELECT
  JSON_VALUE(data, '$.category') AS category,
  JSON_VALUE(data, '$.type') AS product_type,
  COUNT(*) AS product_count,
  ROUND(AVG(JSON_VALUE(data, '$.price' RETURNING NUMBER)), 2) AS avg_price
FROM products
GROUP BY
  JSON_VALUE(data, '$.category'),
  JSON_VALUE(data, '$.type')
ORDER BY avg_price DESC;
```

### Step 3: Using JSON_TABLE for Type-Specific Fields

```sql
-- Extract type-specific fields using JSON_TABLE
SELECT
  jt.*
FROM products,
     JSON_TABLE(
       data,
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
```

Result shows all columns with NULLs for type-specific fields that don't apply:
```
PRODUCT_ID         TYPE          PRICE   TITLE                      AUTHOR      ISBN               BRAND   MODEL
-----------------  ------------  ------  -------------------------  ----------  -----------------  ------  --------
PRODUCT#BOOK-001   book          49.99   Database Design Patterns   Jane Smith  978-0-123456-78-9  (null)  (null)
PRODUCT#ELEC-001   electronics   29.99   (null)                     (null)      (null)             TechCo  WM-2024
```

### Step 4: Query Clothing by Size (Multivalue Index)

```sql
-- Find clothing available in size 'L' using multivalue index
SELECT
  JSON_VALUE(data, '$._id') AS product_id,
  JSON_VALUE(data, '$.name') AS name,
  JSON_VALUE(data, '$.price' RETURNING NUMBER) AS price
FROM products
WHERE JSON_VALUE(data, '$.type') = 'clothing'
  AND JSON_EXISTS(data, '$.sizes[*]?(@ == "L")');
```

## Task 6: Schema Validation for Polymorphic Documents

### Step 1: Implement Type-Specific Validation

Use SQL queries to validate documents based on their type:

```sql
-- Validate transaction documents by checking required fields based on type
-- This query finds invalid transactions missing required type-specific fields

SELECT
  JSON_VALUE(data, '$._id') AS txn_id,
  JSON_VALUE(data, '$.type') AS txn_type,
  CASE
    WHEN JSON_VALUE(data, '$.type') = 'deposit'
         AND JSON_VALUE(data, '$.source') IS NULL
    THEN 'ERROR: source is required for deposits'

    WHEN JSON_VALUE(data, '$.type') = 'withdrawal'
         AND JSON_VALUE(data, '$.method') IS NULL
    THEN 'ERROR: method is required for withdrawals'

    WHEN JSON_VALUE(data, '$.type') = 'transfer'
         AND (JSON_VALUE(data, '$.from_account') IS NULL
              OR JSON_VALUE(data, '$.to_account') IS NULL)
    THEN 'ERROR: from_account and to_account required for transfers'

    WHEN JSON_VALUE(data, '$.amount' RETURNING NUMBER) IS NULL
         OR JSON_VALUE(data, '$.amount' RETURNING NUMBER) <= 0
    THEN 'ERROR: amount must be positive'

    ELSE 'VALID'
  END AS validation_result
FROM transactions;
```

Expected output (all our test data is valid):
```
TXN_ID                       TXN_TYPE     VALIDATION_RESULT
--------------------------   ----------   ------------------
ACCOUNT#ACC-789#TXN#001      deposit      VALID
ACCOUNT#ACC-789#TXN#002      withdrawal   VALID
ACCOUNT#ACC-789#TXN#003      transfer     VALID
```

### Step 2: Find Invalid Documents

```sql
-- Insert an invalid transaction (missing required source for deposit)
INSERT INTO transactions (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'ACCOUNT#ACC-789#TXN#004',
    'type' VALUE 'deposit',
    'account_id' VALUE 'ACC-789',
    'amount' VALUE 500
    -- Missing 'source' field!
  )
);

-- Query to find invalid transactions
SELECT
  JSON_VALUE(data, '$._id') AS txn_id,
  JSON_VALUE(data, '$.type') AS txn_type,
  'Missing source' AS validation_error
FROM transactions
WHERE JSON_VALUE(data, '$.type') = 'deposit'
  AND JSON_VALUE(data, '$.source') IS NULL;
```

Expected output:
```
TXN_ID                       TXN_TYPE    VALIDATION_ERROR
--------------------------   ----------  ----------------
ACCOUNT#ACC-789#TXN#004      deposit     Missing source
```

```sql
-- Clean up invalid test document
DELETE FROM transactions WHERE JSON_VALUE(data, '$._id') = 'ACCOUNT#ACC-789#TXN#004';
COMMIT;
```

## Task 7: Best Practices for Polymorphic Pattern

### Design Guidelines

**DO:**
- ✅ Use consistent `type` field as discriminator across all documents
- ✅ Include common fields shared by all types (e.g., `_id`, `created_at`)
- ✅ Create indexes on `type` field for efficient filtering
- ✅ Document the schema for each type clearly
- ✅ Validate type-specific required fields

**DON'T:**
- ❌ Mix completely unrelated entity types in one collection
- ❌ Create polymorphic collections with vastly different access patterns
- ❌ Forget to index the `type` field
- ❌ Use ambiguous type names (e.g., "data", "item")

### When to Use Polymorphic Pattern

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

## Task 8: Cleanup

```sql
-- Clean up (optional - keep for subsequent labs)
-- DROP TABLE transactions PURGE;
-- DROP TABLE products PURGE;
```

## Conclusion

In this lab, you learned how to effectively implement the Polymorphic Pattern within a Single Collection design.

**Key Takeaways:**
- ✅ Use `type` field as discriminator for different entity types
- ✅ Index `type` field and create type-specific indexes
- ✅ Query efficiently using type filters and composite indexes
- ✅ Validate type-specific required fields programmatically
- ✅ Apply polymorphic pattern when entities are related and accessed together
- ✅ Use multivalue indexes for array fields like sizes/colors

**Indexing Strategy:**
- Always index the `type` discriminator field
- Create indexes on type-specific fields used in queries
- Use composite indexes combining `type` with frequently queried fields
- Use multivalue indexes for array field queries

**Next Steps:**
- Proceed to **Lab 7: Avoiding LOB Performance Cliffs** for deep dive into OSON storage optimization

## Learn More

* [Oracle JSON Developer's Guide - JSON Collections](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/)
* [MongoDB Polymorphic Pattern Documentation](https://www.mongodb.com/docs/manual/data-modeling/design-patterns/polymorphic-pattern/)

## Acknowledgments

* **Author** - Rick Houlihan
* **Last Updated By/Date** - November 2025
