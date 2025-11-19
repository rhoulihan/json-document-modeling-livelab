# Lab 10: Advanced Patterns and Best Practices

## Introduction

In this final lab, you will learn additional advanced patterns, migration strategies for existing applications, and a comprehensive set of best practices for Oracle JSON Collections document modeling.

**Estimated Time:** 30 minutes

## Prerequisites

- Completed Labs 1-9
- Understanding of all document modeling patterns covered
- Familiarity with Single Collection design principles

## Objectives

In this lab, you will:
- Implement the Subset Pattern for frequently accessed data
- Learn schema versioning strategies
- Understand migration approaches from normalized to Single Collection
- Review comprehensive design decision framework
- Learn when NOT to use Single Collection
- Review complete best practices checklist

## Task 1: The Subset Pattern

### Step 1: Understanding the Subset Pattern

The Subset Pattern involves storing a subset of frequently accessed data alongside a complete dataset stored separately:

```sql
-- Create collection
CREATE TABLE social_media (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- User profile with subset of top friends (frequently accessed)
INSERT INTO social_media (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'USER#123',
    'type' VALUE 'user',
    'username' VALUE 'jsmith',
    'email' VALUE 'jsmith@example.com',
    'follower_count' VALUE 5247,

    -- Subset: Top 10 friends (for quick profile display)
    'top_friends' VALUE JSON_ARRAY(
      JSON_OBJECT('user_id' VALUE 'USER#456', 'username' VALUE 'alice', 'avatar' VALUE 'https://...'),
      JSON_OBJECT('user_id' VALUE 'USER#789', 'username' VALUE 'bob', 'avatar' VALUE 'https://...'),
      JSON_OBJECT('user_id' VALUE 'USER#234', 'username' VALUE 'carol', 'avatar' VALUE 'https://...')
      -- ... 7 more
    )
  )
);

-- Complete friends list (paginated, for "See All Friends" view)
INSERT INTO social_media (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'USER#123#FRIENDS#page1',
    'type' VALUE 'friends_page',
    'user_id' VALUE 'USER#123',
    'page' VALUE 1,
    'friends' VALUE JSON_ARRAY(
      /* Friends 1-1000 */
    )
  )
);

INSERT INTO social_media (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'USER#123#FRIENDS#page2',
    'type' VALUE 'friends_page',
    'user_id' VALUE 'USER#123',
    'page' VALUE 2,
    'friends' VALUE JSON_ARRAY(
      /* Friends 1001-2000 */
    )
  )
);

-- Query 1: Get user profile with top friends (fast, single query)
SELECT JSON_QUERY(json_document, '$' PRETTY)
FROM social_media
WHERE JSON_VALUE(json_document, '$._id') = 'USER#123';
-- Latency: 2-3ms (inline document with subset)

-- Query 2: Get all friends when user clicks "See All" (paginated)
SELECT JSON_QUERY(json_document, '$' PRETTY)
FROM social_media
WHERE JSON_VALUE(json_document, '$._id') = 'USER#123#FRIENDS#page1';
-- Latency: 5-10ms (only when needed)
```

**Benefits:**
- ✅ Hot path (profile view) is fast (single small document)
- ✅ Cold path (see all friends) is acceptable (paginated)
- ✅ Avoids unbounded array growth in profile document
- ✅ Subset can be updated independently

## Task 2: Schema Versioning

### Step 1: Schema Version Field

Add versioning to support schema evolution:

```sql
-- Version 1 schema
INSERT INTO social_media (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'PRODUCT#001',
    'schema_version' VALUE 1,
    'type' VALUE 'product',
    'name' VALUE 'Widget',
    'price' VALUE 29.99,
    'category' VALUE 'gadgets'
  )
);

-- Version 2 schema (added dimensions field)
INSERT INTO social_media (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'PRODUCT#002',
    'schema_version' VALUE 2,
    'type' VALUE 'product',
    'name' VALUE 'Gadget',
    'price' VALUE 39.99,
    'category' VALUE 'gadgets',
    'dimensions' VALUE JSON_OBJECT(
      'length' VALUE 10,
      'width' VALUE 5,
      'height' VALUE 3,
      'unit' VALUE 'cm'
    )
  )
);

-- Query handling multiple schema versions
SELECT
  JSON_VALUE(json_document, '$._id') AS product_id,
  JSON_VALUE(json_document, '$.schema_version' RETURNING NUMBER) AS schema_version,
  JSON_VALUE(json_document, '$.name') AS product_name,
  JSON_VALUE(json_document, '$.price' RETURNING NUMBER) AS price,
  -- Handle optional field from v2
  COALESCE(JSON_VALUE(json_document, '$.dimensions.length' RETURNING NUMBER), 0) AS length
FROM social_media
WHERE JSON_VALUE(json_document, '$.type') = 'product';

/*
Result:
PRODUCT_ID   SCHEMA_VERSION  PRODUCT_NAME  PRICE   LENGTH
-----------  --------------  ------------  ------  ------
PRODUCT#001  1               Widget        29.99   0
PRODUCT#002  2               Gadget        39.99   10
*/
```

### Step 2: Schema Migration Strategy

```sql
-- Lazy migration: Migrate documents on read/write
CREATE OR REPLACE FUNCTION migrate_product_v1_to_v2(
  p_doc JSON_OBJECT_T
) RETURN JSON_OBJECT_T IS
  v_migrated JSON_OBJECT_T;
BEGIN
  v_migrated := p_doc;

  -- Check if migration needed
  IF v_migrated.get_Number('schema_version') = 1 THEN
    -- Add default dimensions
    v_migrated.put('dimensions', JSON_OBJECT_T(JSON_OBJECT(
      'length' VALUE 0,
      'width' VALUE 0,
      'height' VALUE 0,
      'unit' VALUE 'cm'
    )));

    -- Update schema version
    v_migrated.put('schema_version', 2);
  END IF;

  RETURN v_migrated;
END;
/

-- Batch migration: Migrate all v1 documents to v2
BEGIN
  FOR doc_rec IN (
    SELECT id, json_document
    FROM social_media
    WHERE JSON_VALUE(json_document, '$.type') = 'product'
      AND JSON_VALUE(json_document, '$.schema_version' RETURNING NUMBER) = 1
  ) LOOP
    UPDATE social_media
    SET json_document = JSON_MERGEPATCH(
      doc_rec.json_document,
      JSON_OBJECT(
        'schema_version' VALUE 2,
        'dimensions' VALUE JSON_OBJECT(
          'length' VALUE 0,
          'width' VALUE 0,
          'height' VALUE 0,
          'unit' VALUE 'cm'
        )
      )
    )
    WHERE id = doc_rec.id;
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Migration complete: v1 → v2');
END;
/
```

## Task 3: Migration from Normalized to Single Collection

### Step 1: Phased Migration Strategy

**Phase 1: Dual Write**
```sql
-- Write to both old (normalized) and new (single collection) systems
-- Application code:
-- 1. Write to normalized tables (existing system)
-- 2. Also write to single collection (new system)
-- 3. Read from normalized tables (maintain consistency)

-- Phase 2: Verify Data Consistency
-- Compare counts and sample data between systems

SELECT 'Normalized' AS system, COUNT(*) AS customer_count FROM customers_normalized
UNION ALL
SELECT 'Single Collection', COUNT(*) FROM ecommerce_single WHERE JSON_VALUE(json_document, '$.type') = 'customer';

-- Phase 3: Switch Reads to Single Collection
-- Application code:
-- 1. Write to both systems (continue)
-- 2. Read from single collection (new)
-- 3. Keep old system for rollback

-- Phase 4: Deprecate Normalized System
-- Once confident, stop writes to old system
```

### Step 2: Data Migration Script

```sql
-- Migrate existing data from normalized to single collection
DECLARE
  v_migrated_count NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('Starting migration...');

  -- Migrate customers
  FOR cust IN (SELECT * FROM customers_normalized) LOOP
    INSERT INTO ecommerce_single (json_document) VALUES (
      JSON_MERGEPATCH(
        cust.json_document,
        JSON_OBJECT(
          '_id' VALUE 'CUSTOMER#' || JSON_VALUE(cust.json_document, '$._id')
        )
      )
    );
    v_migrated_count := v_migrated_count + 1;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Migrated ' || v_migrated_count || ' customers');

  -- Migrate orders with denormalized customer data
  v_migrated_count := 0;
  FOR ord IN (SELECT * FROM orders_normalized) LOOP
    DECLARE
      v_customer_data JSON_OBJECT_T;
      v_customer_id VARCHAR2(100);
    BEGIN
      v_customer_id := JSON_VALUE(ord.json_document, '$.customer_id');

      -- Get customer data for denormalization
      SELECT JSON_OBJECT_T(json_document)
      INTO v_customer_data
      FROM customers_normalized
      WHERE JSON_VALUE(json_document, '$._id') = v_customer_id;

      -- Insert order with denormalized customer data
      INSERT INTO ecommerce_single (json_document) VALUES (
        JSON_MERGEPATCH(
          ord.json_document,
          JSON_OBJECT(
            '_id' VALUE 'CUSTOMER#' || v_customer_id || '#ORDER#' || JSON_VALUE(ord.json_document, '$._id'),
            'customer_name' VALUE v_customer_data.get_String('name'),
            'customer_email' VALUE v_customer_data.get_String('email'),
            'customer_tier' VALUE v_customer_data.get_String('tier')
          )
        )
      );
      v_migrated_count := v_migrated_count + 1;
    END;
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Migrated ' || v_migrated_count || ' orders');
  DBMS_OUTPUT.PUT_LINE('Migration complete!');
END;
/
```

## Task 4: When NOT to Use Single Collection

### Step 1: Anti-Patterns - Inappropriate Use Cases

**❌ Don't Use Single Collection When:**

1. **Completely Different Service Boundaries**
```sql
-- ❌ BAD: Mixing user accounts and financial transactions
{
  "_id": "USER#123",
  "type": "user"
}
{
  "_id": "TRANSACTION#456",
  "type": "bank_transaction"  -- Different service domain!
}

-- ✅ GOOD: Separate collections for separate services
CREATE TABLE user_service (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE TABLE banking_service (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
);
```

2. **Different Security Requirements**
```sql
-- ❌ BAD: Mixing public and highly sensitive data
{
  "_id": "USER#123",
  "type": "user_profile",  -- Public data
  "security_clearance": "top_secret"  -- Shouldn't be in same collection!
}

-- ✅ GOOD: Separate collections with different access controls
CREATE TABLE public_profiles (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE TABLE sensitive_data (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
) TABLESPACE secure_tablespace;
```

3. **Different Scaling Patterns**
```sql
-- ❌ BAD: Mixing hot and cold data with different growth rates
{
  "_id": "CONFIG#app-settings",
  "type": "config"  -- 10 documents, rarely changes
}
{
  "_id": "LOG#2024-11-19#001",
  "type": "log"  -- 1M documents/day, high write volume
}

-- ✅ GOOD: Separate collections optimized differently
CREATE TABLE app_config (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
);  -- Small, read-heavy

CREATE TABLE app_logs (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
);  -- Large, write-heavy with partitioning
```

4. **Completely Different Access Patterns**
```sql
-- ❌ BAD: Mixing entities never accessed together
{
  "_id": "WAREHOUSE#inventory-item",
  "type": "inventory"
}
{
  "_id": "MARKETING#email-campaign",
  "type": "email_campaign"  -- Never queried with inventory!
}

-- ✅ GOOD: Separate collections for unrelated entities
CREATE TABLE inventory (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE TABLE marketing_campaigns (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
);
```

### Step 2: Decision Framework

Use this flowchart logic:

```
Are entities accessed together in 80%+ of queries?
├─ YES → Are they in the same service boundary?
│  ├─ YES → Do they have similar security requirements?
│  │  ├─ YES → Use Single Collection ✅
│  │  └─ NO → Use Separate Collections ❌
│  └─ NO → Use Separate Collections ❌
└─ NO → Use Separate Collections ❌
```

## Task 5: Comprehensive Best Practices Checklist

### Step 1: Design Phase Checklist

**Access Pattern Analysis:**
- [ ] Identified top 5 most frequent query patterns (80/20 rule)
- [ ] Determined read:write ratios for each entity type
- [ ] Estimated data volumes (1 year, 5 years)
- [ ] Identified entities accessed together
- [ ] Mapped query latency requirements

**Data Model Design:**
- [ ] Designed composite key structure for hierarchical relationships
- [ ] Identified denormalization candidates (frequently accessed together)
- [ ] Validated no unbounded arrays (all arrays have fixed maximum size)
- [ ] Estimated document sizes (target < 100KB, max < 500KB)
- [ ] Designed type discriminator field consistently

**Performance Optimization:**
- [ ] Identified required indexes (composite key, type, frequently queried fields)
- [ ] Planned multivalue indexes for array fields
- [ ] Considered partial indexes for subset queries
- [ ] Planned bucketing strategy for time-series data
- [ ] Identified computed metrics to pre-calculate

### Step 2: Implementation Phase Checklist

**Code Quality:**
- [ ] Implemented schema versioning for all document types
- [ ] Created validation functions for each entity type
- [ ] Implemented document size monitoring
- [ ] Created triggers to prevent oversized documents (over 29MB)
- [ ] Implemented proper error handling

**Testing:**
- [ ] Load tested with realistic data volumes
- [ ] Tested with documents at various sizes (1KB, 10KB, 100KB)
- [ ] Verified query performance meets requirements
- [ ] Tested index effectiveness (before/after comparison)
- [ ] Simulated growth over time (1 year, 5 years)

### Step 3: Production Readiness Checklist

**Monitoring:**
- [ ] Created view to monitor document sizes by type
- [ ] Set up alerts for documents exceeding 9MB (LOB cliff warning)
- [ ] Implemented query performance tracking
- [ ] Created dashboard for collection statistics

**Maintenance:**
- [ ] Scheduled index rebuild job (monthly or when bloat over 20%)
- [ ] Implemented archival strategy for old data
- [ ] Created backup and recovery procedures
- [ ] Documented schema versions and migration paths

**Documentation:**
- [ ] Documented composite key patterns used
- [ ] Documented all entity types and their schemas
- [ ] Created query pattern examples for developers
- [ ] Documented denormalization decisions and rationale

## Task 6: Workshop Summary

### Key Patterns Learned

1. **Single Collection/Table Design (Lab 3)**
   - Use composite keys for hierarchical relationships
   - Denormalize frequently accessed data
   - Avoid unbounded arrays

2. **Computed Pattern (Lab 4)**
   - Pre-calculate frequently accessed metrics
   - Use incremental updates or batch jobs

3. **Bucketing Pattern (Lab 5)**
   - Group time-series data into fixed-size buckets
   - Reduce document count by 99%+

4. **Polymorphic Pattern (Lab 6)**
   - Store multiple entity types with `type` discriminator
   - Index type field for efficient filtering

5. **LOB Cliff Avoidance (Lab 7)**
   - Keep documents under 100KB for optimal performance
   - Split large documents vertically or horizontally

6. **Indexing Strategies (Lab 8)**
   - Always index composite keys and type discriminator
   - Use partial indexes for subset queries

### Performance Improvements Achieved

- Single Collection vs Multiple Collections: **6-10x faster**
- Inline (< 7,950 bytes) vs Large LOB (> 10MB): **70-90x faster**
- Indexed vs Non-indexed queries: **10-50x faster**
- Bucketing vs Individual documents: **60x faster** for time-series

## Conclusion

Congratulations! You have completed the Oracle JSON Collections Document Modeling workshop.

**You now know how to:**
- ✅ Design access pattern-first data models
- ✅ Implement Single Collection/Table design pattern
- ✅ Use composite keys for hierarchical relationships
- ✅ Apply strategic denormalization
- ✅ Avoid LOB performance cliffs
- ✅ Create efficient indexes for polymorphic collections
- ✅ Measure and optimize performance
- ✅ Make informed design decisions based on trade-offs

**Key Principles:**
1. **Access patterns first** - Design for how data is queried, not how it's structured
2. **Store together what's accessed together** - Minimize queries and joins
3. **Keep documents small** - Target < 100KB for optimal performance
4. **Monitor and measure** - Validate design decisions with benchmarks
5. **Iterate and improve** - Document models can evolve over time

**Next Steps:**
- Apply these patterns to your own applications
- Benchmark your specific workloads
- Share learnings with your team
- Contribute feedback to improve this workshop

## Learn More

* [Oracle JSON Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/)
* [Rick Houlihan - DynamoDB Advanced Design Patterns](https://www.youtube.com/watch?v=6yqfmXiZTlM)
* [MongoDB Data Modeling Patterns](https://www.mongodb.com/docs/manual/data-modeling/)

## Acknowledgments

* **Author** - Rick Houlihan
* **Contributors** - MongoDB Data Modeling Team, AWS DynamoDB Team
* **Last Updated By/Date** - November 2024

---

**Thank you for completing this workshop!** 🎉

We hope you found it valuable. Please provide feedback to help us improve future workshops.
