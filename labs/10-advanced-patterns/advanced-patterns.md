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
-- Create JSON Collection Table
CREATE JSON COLLECTION TABLE social_media;

-- Create indexes
CREATE INDEX idx_social_media_id ON social_media (JSON_VALUE(data, '$._id'));
CREATE INDEX idx_social_media_type ON social_media (JSON_VALUE(data, '$.type'));
```

**Expected output:**
```
Table created.
Index created.
Index created.
```

**SQL Approach:**

if type="sql"

```sql
-- User profile with subset of top friends (frequently accessed)
INSERT INTO social_media (data) VALUES (
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
INSERT INTO social_media (data) VALUES (
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

INSERT INTO social_media (data) VALUES (
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

COMMIT;
```

Expected output:
```
1 row created.
1 row created.
1 row created.
Commit complete.
```

/if

**MongoDB API Approach:**

if type="mongodb"

```javascript
// Connect to Oracle using MongoDB API
// mongosh "mongodb://jsonuser:WelcomeJson%23123@localhost:27017/mydb?authMechanism=PLAIN&authSource=$external&tls=false"

use mydb

// User profile with subset of top friends (hot data)
db.social_media.insertOne({
  _id: "USER#123",
  type: "user",
  username: "jsmith",
  email: "jsmith@example.com",
  follower_count: 5247,

  // Subset Pattern: Only top 10 friends embedded for quick access
  top_friends: [
    { user_id: "USER#456", username: "alice", avatar: "https://..." },
    { user_id: "USER#789", username: "bob", avatar: "https://..." },
    { user_id: "USER#234", username: "carol", avatar: "https://..." }
    // ... 7 more
  ]
})

// Complete friends list stored separately (cold data)
// Only loaded when user clicks "See All Friends"
db.social_media.insertOne({
  _id: "USER#123#FRIENDS#page1",
  type: "friends_page",
  user_id: "USER#123",
  page: 1,
  friends: [
    // All 1000 friends on page 1
  ]
})
```

Expected output:
```javascript
{
  acknowledged: true,
  insertedId: 'USER#123'
}
{
  acknowledged: true,
  insertedId: 'USER#123#FRIENDS#page1'
}
```

> **MongoDB API**: Subset Pattern is common in MongoDB for performance. Store frequently accessed data (top friends) in main document, full dataset in separate documents with pagination.

/if

**REST API Approach:**

if type="rest"

```bash
# Insert user profile with top friends subset
curl -X POST \
  "http://localhost:8080/ords/jsonuser/soda/latest/social_media" \
  -H "Content-Type: application/json" \
  -d '{
    "_id": "USER#123",
    "type": "user",
    "username": "jsmith",
    "email": "jsmith@example.com",
    "follower_count": 5247,
    "top_friends": [
      {"user_id": "USER#456", "username": "alice", "avatar": "https://..."},
      {"user_id": "USER#789", "username": "bob", "avatar": "https://..."},
      {"user_id": "USER#234", "username": "carol", "avatar": "https://..."}
    ]
  }'

# Insert complete friends list (paginated)
curl -X POST \
  "http://localhost:8080/ords/jsonuser/soda/latest/social_media" \
  -H "Content-Type: application/json" \
  -d '{
    "_id": "USER#123#FRIENDS#page1",
    "type": "friends_page",
    "user_id": "USER#123",
    "page": 1,
    "friends": []
  }'
```

Expected output:
```json
{
  "id": "...",
  "etag": "...",
  "lastModified": "2024-11-19T10:30:00.000Z"
}
```

> **REST API**: Subset Pattern optimizes REST API responses. Quick profile API returns user with top_friends. Separate paginated endpoint returns full friends list.

/if

**Python Approach:**

if type="python"

```python
import oracledb

connection = oracledb.connect(
    user="jsonuser",
    password="WelcomeJson#123",
    dsn="localhost/FREEPDB1"
)

soda = connection.getSodaDatabase()
collection = soda.openCollection("social_media")

# Subset Pattern: User profile with top friends (hot data)
user_profile = {
    "_id": "USER#123",
    "type": "user",
    "username": "jsmith",
    "email": "jsmith@example.com",
    "follower_count": 5247,

    # Frequently accessed subset - top 10 friends
    "top_friends": [
        {"user_id": "USER#456", "username": "alice", "avatar": "https://..."},
        {"user_id": "USER#789", "username": "bob", "avatar": "https://..."},
        {"user_id": "USER#234", "username": "carol", "avatar": "https://..."}
        # ... 7 more for top 10
    ]
}

collection.insertOne(user_profile)
print("User profile created (with top friends subset)")

# Complete friends list stored separately (cold data)
# Loaded only when needed for "See All Friends" page
friends_page = {
    "_id": "USER#123#FRIENDS#page1",
    "type": "friends_page",
    "user_id": "USER#123",
    "page": 1,
    "friends": []  # Would contain all friends on this page
}

collection.insertOne(friends_page)
print("Friends page 1 created")

connection.commit()
connection.close()
```

Expected output:
```
User profile created (with top friends subset)
Friends page 1 created
```

> **Python**: Subset Pattern in Python data pipelines. Process and cache frequently accessed subsets separately from complete datasets for performance.

**Subset Pattern Benefits:**
- Fast profile loads (only top friends, ~2KB vs 500KB for all friends)
- Reduced bandwidth for mobile apps
- Pagination for complete data ("See All Friends")
- 80/20 rule: 80% of accesses need only 20% of data

/if

### Step 2: Query Subset Data

```sql
-- Query 1: Get user profile with top friends (fast, single query)
SELECT JSON_SERIALIZE(data PRETTY)
FROM social_media
WHERE JSON_VALUE(data, '$._id') = 'USER#123';
```

**Expected output:**
```json
{
  "_id" : "USER#123",
  "type" : "user",
  "username" : "jsmith",
  "email" : "jsmith@example.com",
  "follower_count" : 5247,
  "top_friends" :
  [
    {
      "user_id" : "USER#456",
      "username" : "alice",
      "avatar" : "https://..."
    },
    {
      "user_id" : "USER#789",
      "username" : "bob",
      "avatar" : "https://..."
    },
    {
      "user_id" : "USER#234",
      "username" : "carol",
      "avatar" : "https://..."
    }
  ]
}
```

> **Note:** User profile with top_friends subset retrieved in single query (~2-3ms). Complete friends list is stored separately.

```sql
-- Query 2: Get all friends when user clicks "See All" (paginated)
SELECT JSON_SERIALIZE(data PRETTY)
FROM social_media
WHERE JSON_VALUE(data, '$._id') LIKE 'USER#123#FRIENDS#%'
ORDER BY JSON_VALUE(data, '$.page' RETURNING NUMBER);
-- Latency: 5-10ms (only when needed)
```

**Benefits:**
- Hot path (profile view) is fast (single small document)
- Cold path (see all friends) is acceptable (paginated)
- Avoids unbounded array growth in profile document
- Subset can be updated independently

## Task 2: Schema Versioning

### Step 1: Schema Version Field

Add versioning to support schema evolution:

**SQL Approach:**

if type="sql"

```sql
-- Version 1 schema
INSERT INTO social_media (data) VALUES (
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
INSERT INTO social_media (data) VALUES (
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

COMMIT;
```

/if

### Step 2: Query Multiple Schema Versions

```sql
-- Query handling multiple schema versions
SELECT
  JSON_VALUE(data, '$._id') AS product_id,
  JSON_VALUE(data, '$.schema_version' RETURNING NUMBER) AS schema_version,
  JSON_VALUE(data, '$.name') AS product_name,
  JSON_VALUE(data, '$.price' RETURNING NUMBER) AS price,
  -- Handle optional field from v2
  COALESCE(JSON_VALUE(data, '$.dimensions.length' RETURNING NUMBER), 0) AS length
FROM social_media
WHERE JSON_VALUE(data, '$.type') = 'product';
```

Expected output:
```
PRODUCT_ID   SCHEMA_VERSION  PRODUCT_NAME  PRICE   LENGTH
-----------  --------------  ------------  ------  ------
PRODUCT#001  1               Widget        29.99   0
PRODUCT#002  2               Gadget        39.99   10
```

### Step 3: Schema Migration Using JSON_TRANSFORM

```sql
-- Batch migration: Migrate all v1 documents to v2 using JSON_TRANSFORM
UPDATE social_media
SET data = JSON_TRANSFORM(
  data,
  SET '$.schema_version' = 2,
  SET '$.dimensions' = JSON_OBJECT(
    'length' VALUE 0,
    'width' VALUE 0,
    'height' VALUE 0,
    'unit' VALUE 'cm'
  )
)
WHERE JSON_VALUE(data, '$.type') = 'product'
  AND JSON_VALUE(data, '$.schema_version' RETURNING NUMBER) = 1;

COMMIT;

-- Verify migration
SELECT
  JSON_VALUE(data, '$._id') AS product_id,
  JSON_VALUE(data, '$.schema_version' RETURNING NUMBER) AS schema_version
FROM social_media
WHERE JSON_VALUE(data, '$.type') = 'product';
```

Expected output (all products now v2):
```
PRODUCT_ID   SCHEMA_VERSION
-----------  --------------
PRODUCT#001  2
PRODUCT#002  2
```

## Task 3: When NOT to Use Single Collection

### Step 1: Anti-Patterns - Inappropriate Use Cases

**1. Different Service Boundaries**

```sql
-- BAD: Mixing user accounts and financial transactions
-- GOOD: Separate collections for separate services
CREATE JSON COLLECTION TABLE user_service;
CREATE JSON COLLECTION TABLE banking_service;
```

**2. Different Security Requirements**

```sql
-- BAD: Mixing public and highly sensitive data
-- GOOD: Separate collections with different access controls
CREATE JSON COLLECTION TABLE public_profiles;
CREATE JSON COLLECTION TABLE sensitive_data;  -- Different tablespace/encryption
```

**3. Different Scaling Patterns**

```sql
-- BAD: Mixing hot and cold data with different growth rates
-- Config (10 documents) vs logs (1M documents/day)
-- GOOD: Separate collections optimized differently
CREATE JSON COLLECTION TABLE app_config;   -- Small, read-heavy
CREATE JSON COLLECTION TABLE app_logs;     -- Large, write-heavy with partitioning
```

**4. Completely Different Access Patterns**

```sql
-- BAD: Mixing entities never accessed together
-- Inventory and email campaigns never queried together
-- GOOD: Separate collections for unrelated entities
CREATE JSON COLLECTION TABLE inventory;
CREATE JSON COLLECTION TABLE marketing_campaigns;
```

### Step 2: Decision Framework

Use this flowchart logic:

```
Are entities accessed together in 80%+ of queries?
├─ YES → Are they in the same service boundary?
│  ├─ YES → Do they have similar security requirements?
│  │  ├─ YES → Use Single Collection
│  │  └─ NO → Use Separate Collections
│  └─ NO → Use Separate Collections
└─ NO → Use Separate Collections
```

## Task 4: Comprehensive Best Practices Checklist

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
- [ ] Planned bucketing strategy for time-series data
- [ ] Identified computed metrics to pre-calculate

### Step 2: Implementation Phase Checklist

**Code Quality:**
- [ ] Implemented schema versioning for all document types
- [ ] Created validation queries for each entity type
- [ ] Implemented document size monitoring
- [ ] Implemented proper error handling

**Testing:**
- [ ] Load tested with realistic data volumes
- [ ] Tested with documents at various sizes (1KB, 10KB, 100KB)
- [ ] Verified query performance meets requirements
- [ ] Tested index effectiveness (before/after comparison)

### Step 3: Production Readiness Checklist

**Monitoring:**
- [ ] Created view to monitor document sizes by type
- [ ] Set up alerts for documents exceeding 9MB (LOB cliff warning)
- [ ] Implemented query performance tracking

**Maintenance:**
- [ ] Scheduled index rebuild job (monthly or when bloat over 20%)
- [ ] Implemented archival strategy for old data
- [ ] Documented schema versions and migration paths

## Task 5: Workshop Summary

### Key Patterns Learned

1. **Single Collection/Table Design (Lab 3)**
   - Use composite keys for hierarchical relationships
   - Denormalize frequently accessed data
   - Avoid unbounded arrays

2. **Computed Pattern (Lab 4)**
   - Pre-calculate frequently accessed metrics
   - Use JSON_TRANSFORM for atomic updates

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
   - Use multivalue indexes for array queries

### Performance Improvements Achieved

| Pattern | Improvement |
|---------|-------------|
| Single Collection vs Multiple Collections | **6-10x faster** |
| Inline (< 7,950 bytes) vs Large LOB (> 10MB) | **70-90x faster** |
| Indexed vs Non-indexed queries | **10-50x faster** |
| Bucketing vs Individual documents | **60x faster** |

## Task 6: Cleanup

```sql
-- Clean up (optional - keep for reference)
-- DROP TABLE social_media PURGE;
```

## Conclusion

Congratulations! You have completed the Oracle JSON Collections Document Modeling workshop.

**You now know how to:**
- Design access pattern-first data models
- Implement Single Collection/Table design pattern
- Use composite keys for hierarchical relationships
- Apply strategic denormalization
- Avoid LOB performance cliffs
- Create efficient indexes for polymorphic collections
- Use JSON_TRANSFORM for atomic updates
- Measure and optimize performance
- Make informed design decisions based on trade-offs

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

## Learn More

* [Oracle JSON Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/)
* [AWS DynamoDB Advanced Design Patterns](https://aws.amazon.com/dynamodb/resources/)
* [MongoDB Data Modeling Patterns](https://www.mongodb.com/docs/manual/data-modeling/)

## Acknowledgments

* **Author** - Rick Houlihan
* **Contributors** - MongoDB Data Modeling Team, AWS DynamoDB Team
* **Last Updated By/Date** - November 2025
