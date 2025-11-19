# Document Modeling Patterns - Quick Reference Guide

## Pattern Selection Flowchart

```
START: What is your primary use case?
│
├─ ONE-TO-FEW relationships (1:N where N < 100)
│  └─> How often do you read parent+children together?
│     ├─ Always/Frequently → EMBEDDED PATTERN
│     └─ Rarely → REFERENCED PATTERN
│
├─ ONE-TO-MANY relationships (1:N where N > 100)
│  └─> Are children accessed independently?
│     ├─ Yes → REFERENCED PATTERN
│     └─ No, only with parent → Consider BUCKETING PATTERN
│
├─ FREQUENTLY COMPUTED AGGREGATIONS
│  └─> What is your read:write ratio?
│     ├─ Read-heavy (10:1 or more) → COMPUTED PATTERN
│     └─ Write-heavy → Compute on-the-fly or use Materialized Views
│
├─ TIME-SERIES / STREAMING DATA
│  └─> How much data per time unit?
│     ├─ Low volume → Individual documents
│     ├─ Medium volume → BUCKETING PATTERN (hourly/daily)
│     └─ High volume → BUCKETING + ROLLUP/ARCHIVE
│
├─ MULTIPLE DOCUMENT TYPES with shared fields
│  └─> How similar are the document types?
│     ├─ Very similar (>70% shared fields) → POLYMORPHIC PATTERN
│     └─ Different → Separate collections
│
└─ VERY LARGE DOCUMENTS (>100KB)
   └─> Can you split frequently vs rarely accessed data?
      ├─ Yes → SUBSET PATTERN or EXTENDED REFERENCE
      └─ No → BUCKETING or rethink model
```

---

## Pattern Catalog

### 1. Embedded Pattern

**When to Use:**
- ✅ One-to-few relationships (parent has < 100 children)
- ✅ Data accessed together frequently
- ✅ Children rarely accessed independently
- ✅ Atomic updates needed across parent and children
- ✅ Total document size stays < 100KB

**When NOT to Use:**
- ❌ One-to-many (hundreds/thousands of children)
- ❌ Children frequently updated independently
- ❌ Children accessed separately often
- ❌ Document approaches 10MB+ size
- ❌ Significant data duplication

**Structure:**
```json
{
  "_id": "order123",
  "customer": "John Doe",
  "orderDate": "2024-11-18",
  "items": [
    {
      "sku": "WIDGET-001",
      "name": "Blue Widget",
      "price": 29.99,
      "quantity": 2
    },
    {
      "sku": "GADGET-005",
      "name": "Red Gadget",
      "price": 49.99,
      "quantity": 1
    }
  ],
  "total": 109.97
}
```

**Performance Characteristics:**
- Read: ⚡⚡⚡ Excellent (single query)
- Write: ⚡⚡ Good (single document update)
- Storage: ⚠️ Moderate (data duplication if items shared)
- Scalability: ⚠️ Limited by document size

**Indexing:**
- Multivalue indexes on array fields
- Example: `CREATE MULTIVALUE INDEX idx ON orders o (o.data.items.sku.string());`

---

### 2. Referenced Pattern

**When to Use:**
- ✅ One-to-many (hundreds/thousands of children)
- ✅ Children accessed independently
- ✅ Children shared across multiple parents
- ✅ Frequent updates to children
- ✅ Avoiding data duplication is critical

**When NOT to Use:**
- ❌ Always need parent + children together
- ❌ Network round-trips are expensive
- ❌ Simple one-to-few relationships
- ❌ Atomic updates required across documents

**Structure:**
```json
// Orders collection
{
  "_id": "order123",
  "customer": "John Doe",
  "orderDate": "2024-11-18",
  "itemIds": ["item456", "item789"],
  "total": 109.97
}

// Items collection
{
  "_id": "item456",
  "orderId": "order123",
  "sku": "WIDGET-001",
  "name": "Blue Widget",
  "price": 29.99,
  "quantity": 2
}
```

**Performance Characteristics:**
- Read: ⚡ Moderate (multiple queries or application joins)
- Write: ⚡⚡⚡ Excellent (update only what changed)
- Storage: ⚡⚡⚡ Excellent (no duplication)
- Scalability: ⚡⚡⚡ Excellent (unlimited children)

**Indexing:**
- Index foreign key fields
- Example: `CREATE INDEX idx ON items (JSON_VALUE(data, '$.orderId'));`

**Oracle-Specific Optimization:**
- Consider JSON Duality Views for automatic join handling

---

### 3. Computed Pattern

**When to Use:**
- ✅ Expensive aggregations computed frequently
- ✅ Read-heavy workload (10:1 read:write or higher)
- ✅ Staleness acceptable (eventually consistent)
- ✅ Simple computations (sums, counts, averages)

**When NOT to Use:**
- ❌ Write-heavy workload
- ❌ Real-time accuracy required
- ❌ Complex computations (use materialized views)
- ❌ Data changes frequently

**Structure:**
```json
{
  "_id": "post123",
  "author": "user456",
  "content": "Check out this amazing view!",
  "created": "2024-11-18T10:00:00Z",
  "comments": [...], // Embedded or referenced
  // COMPUTED FIELDS:
  "engagement": {
    "likes_count": 1543,
    "comments_count": 87,
    "shares_count": 234,
    "total_engagement": 1864,
    "engagement_rate": 0.0931,  // engagement / followers
    "last_updated": "2024-11-18T15:30:00Z"
  }
}
```

**Maintenance Strategies:**
- Application-managed: Update on write
- Trigger-based: Automatic database triggers
- Batch jobs: Periodic recomputation
- Hybrid: Real-time for criticalfields, batch for others

**Performance Characteristics:**
- Read: ⚡⚡⚡ Excellent (no computation needed)
- Write: ⚡ Slower (additional computation)
- Accuracy: ⚠️ Eventually consistent
- Storage: ⚡⚡ Good (small overhead)

**Implementation Example:**
```sql
-- Trigger to maintain computed fields
CREATE OR REPLACE TRIGGER update_engagement
AFTER INSERT OR DELETE ON interactions
FOR EACH ROW
BEGIN
  UPDATE posts p
  SET p.data = JSON_TRANSFORM(
    p.data,
    SET '$.engagement.likes_count' = (
      SELECT COUNT(*) FROM interactions
      WHERE post_id = :NEW.post_id AND type = 'like'
    )
  )
  WHERE JSON_VALUE(p.data, '$._id') = :NEW.post_id;
END;
```

**Alternative: Materialized Views (Oracle)**
```sql
CREATE MATERIALIZED VIEW post_engagement_mv
BUILD IMMEDIATE
REFRESH FAST ON COMMIT AS
SELECT
  p.id,
  COUNT(CASE WHEN i.type = 'like' THEN 1 END) as likes_count,
  COUNT(CASE WHEN i.type = 'comment' THEN 1 END) as comments_count
FROM posts p
LEFT JOIN interactions i ON p.id = i.post_id
GROUP BY p.id;
```

---

### 4. Bucketing Pattern

**When to Use:**
- ✅ Time-series data
- ✅ High-volume streaming data
- ✅ IoT sensor readings
- ✅ Event logs
- ✅ Many small related documents

**When NOT to Use:**
- ❌ Low volume data (< 100 records/day)
- ❌ Random access patterns (not time-based)
- ❌ Individual records frequently updated
- ❌ Bucket size unpredictable

**Structure:**
```json
{
  "_id": "sensor_temp001_2024-11-18-14",
  "sensorId": "temp001",
  "sensorType": "temperature",
  "bucket_start": "2024-11-18T14:00:00Z",
  "bucket_end": "2024-11-18T14:59:59Z",
  "reading_count": 3600,
  "readings": [
    {
      "timestamp": "2024-11-18T14:00:00Z",
      "value": 23.5,
      "quality": "good"
    },
    {
      "timestamp": "2024-11-18T14:00:01Z",
      "value": 23.6,
      "quality": "good"
    }
    // ... 3598 more readings
  ],
  "summary": {
    "min": 22.1,
    "max": 24.8,
    "avg": 23.5,
    "stddev": 0.8
  }
}
```

**Bucket Size Guidelines:**

| Data Rate | Recommended Bucket | Approx Records/Bucket | Document Size |
|-----------|-------------------|----------------------|---------------|
| 1/sec | 1 hour | 3,600 | ~360KB |
| 10/sec | 10 minutes | 6,000 | ~600KB |
| 100/sec | 1 minute | 6,000 | ~600KB |
| 1000/sec | 10 seconds | 10,000 | ~1MB |

**Key Principle:** Keep documents between 100KB - 5MB for optimal performance.

**Performance Characteristics:**
- Read: ⚡⚡ Good (few documents for range queries)
- Write: ⚡⚡ Good (append to array)
- Storage: ⚡⚡⚡ Excellent (compact)
- Scalability: ⚡⚡⚡ Excellent

**Query Patterns:**
```sql
-- Range query across buckets
SELECT j.*
FROM sensor_readings s,
     JSON_TABLE(s.data, '$.readings[*]'
       COLUMNS (
         timestamp TIMESTAMP PATH '$.timestamp',
         value NUMBER PATH '$.value'
       )
     ) j
WHERE JSON_VALUE(s.data, '$.sensorId') = 'temp001'
  AND JSON_VALUE(s.data, '$.bucket_start') >= '2024-11-18T10:00:00Z'
  AND JSON_VALUE(s.data, '$.bucket_end') <= '2024-11-18T16:00:00Z'
  AND j.timestamp BETWEEN TIMESTAMP '2024-11-18 12:30:00'
                      AND TIMESTAMP '2024-11-18 14:45:00';

-- Use summary for fast aggregations
SELECT
  JSON_VALUE(data, '$.sensorId') as sensor,
  AVG(JSON_VALUE(data, '$.summary.avg')) as overall_avg,
  MIN(JSON_VALUE(data, '$.summary.min')) as overall_min,
  MAX(JSON_VALUE(data, '$.summary.max')) as overall_max
FROM sensor_readings
WHERE JSON_VALUE(data, '$.bucket_start') >= '2024-11-01'
GROUP BY JSON_VALUE(data, '$.sensorId');
```

**Indexing:**
```sql
CREATE INDEX idx_sensor_bucket ON sensor_readings (
  JSON_VALUE(data, '$.sensorId'),
  JSON_VALUE(data, '$.bucket_start' RETURNING TIMESTAMP)
);
```

---

### 5. Polymorphic Pattern

**When to Use:**
- ✅ Multiple document types with 60%+ shared fields
- ✅ Querying across all types is common
- ✅ Types are conceptually related
- ✅ Adding new types frequently

**When NOT to Use:**
- ❌ Document types completely different
- ❌ Type-specific queries dominate
- ❌ Complex type-specific validation needed
- ❌ Performance critical for specific type

**Structure:**
```json
// Deposit transaction
{
  "_id": "txn001",
  "type": "deposit",
  "timestamp": "2024-11-18T10:00:00Z",
  "account": "ACC123",
  "amount": 1000.00,
  "currency": "USD",
  "channel": "ATM",
  "location": "Branch #42"
}

// Transfer transaction
{
  "_id": "txn002",
  "type": "transfer",
  "timestamp": "2024-11-18T10:05:00Z",
  "from_account": "ACC123",
  "to_account": "ACC456",
  "amount": 500.00,
  "currency": "USD",
  "reference": "Invoice #789",
  "fee": 2.50
}

// Payment transaction
{
  "_id": "txn003",
  "type": "payment",
  "timestamp": "2024-11-18T10:10:00Z",
  "account": "ACC123",
  "amount": 45.99,
  "currency": "USD",
  "merchant": "Coffee Shop",
  "category": "dining",
  "rewards_points": 46
}
```

**Performance Characteristics:**
- Read: ⚡⚡ Good (filtered by type)
- Write: ⚡⚡⚡ Excellent
- Flexibility: ⚡⚡⚡ Excellent
- Complexity: ⚠️ Moderate (application logic)

**Querying:**
```sql
-- All transactions
SELECT * FROM transactions
WHERE JSON_VALUE(data, '$.account') = 'ACC123'
ORDER BY JSON_VALUE(data, '$.timestamp' RETURNING TIMESTAMP) DESC;

-- Specific type
SELECT * FROM transactions
WHERE JSON_VALUE(data, '$.type') = 'transfer'
  AND JSON_VALUE(data, '$.amount' RETURNING NUMBER) > 1000;

-- Cross-type aggregation
SELECT
  JSON_VALUE(data, '$.type') as transaction_type,
  COUNT(*) as count,
  SUM(JSON_VALUE(data, '$.amount' RETURNING NUMBER)) as total
FROM transactions
WHERE JSON_VALUE(data, '$.timestamp' RETURNING TIMESTAMP) >= CURRENT_DATE
GROUP BY JSON_VALUE(data, '$.type');
```

**Indexing:**
```sql
-- Index on type for filtering
CREATE INDEX idx_type ON transactions (JSON_VALUE(data, '$.type'));

-- Composite index for common queries
CREATE INDEX idx_account_timestamp ON transactions (
  JSON_VALUE(data, '$.account'),
  JSON_VALUE(data, '$.timestamp' RETURNING TIMESTAMP)
);

-- Partial index for specific type
CREATE INDEX idx_large_transfers ON transactions (
  JSON_VALUE(data, '$.amount' RETURNING NUMBER)
)
WHERE JSON_VALUE(data, '$.type') = 'transfer';
```

---

### 6. Subset Pattern

**When to Use:**
- ✅ Large related datasets
- ✅ Frequently access a small subset
- ✅ Need quick access to "top N" items
- ✅ Full data rarely needed

**Structure:**
```json
{
  "_id": "user123",
  "username": "johndoe",
  "profile": {...},
  "friends_count": 5247,
  "top_friends": [
    // Top 10 most interacted friends
    {"id": "user456", "name": "Jane Smith", "interaction_score": 95},
    {"id": "user789", "name": "Bob Jones", "interaction_score": 87},
    // ... 8 more
  ],
  "all_friends_ref": "user123_friends" // Reference to full list
}

// Separate collection for full friends list
{
  "_id": "user123_friends",
  "user_id": "user123",
  "friends": [
    // All 5247 friends
  ]
}
```

**Performance Characteristics:**
- Read (common case): ⚡⚡⚡ Excellent
- Read (full data): ⚡ Moderate (additional query)
- Write: ⚡⚡ Good (maintain subset)
- Storage: ⚡⚡ Good (small duplication)

---

### 7. Extended Reference Pattern

**When to Use:**
- ✅ Reducing joins while avoiding full embedding
- ✅ Referenced data rarely changes
- ✅ Need basic info without full document fetch
- ✅ Balancing performance and data duplication

**Structure:**
```json
{
  "_id": "order123",
  "customer_id": "cust456",
  "customer_name": "John Doe",  // Duplicated for convenience
  "customer_email": "john@example.com",  // Duplicated
  "items": [
    {
      "product_id": "prod789",
      "product_name": "Blue Widget",  // Duplicated
      "current_price": 29.99,  // Duplicated at order time
      "quantity": 2,
      "subtotal": 59.98
    }
  ],
  "total": 59.98
}
```

**Trade-offs:**
- ✅ Faster reads (no joins for common fields)
- ⚠️ Data duplication
- ⚠️ Stale data if source changes
- Use when: Source data rarely changes or staleness acceptable

---

## Oracle-Specific Optimizations

### OSON Format and Size Limits

**Storage Tiers:**
| Document Size | Storage | Performance | Action |
|--------------|---------|-------------|--------|
| 0 - 7,950 bytes | Inline | ⚡⚡⚡ Fastest | Optimal |
| 7,951 - 100 KB | LOB | ⚡⚡ Good | Acceptable |
| 100 KB - 1 MB | LOB | ⚡ Moderate | Consider splitting |
| 1 MB - 10 MB | LOB | ⚠️ Slower | Split recommended |
| 10 MB - 32 MB | LOB | ⚠️⚠️ Slow | Must split |
| 32 MB+ | N/A | ❌ ERROR | Hard limit |

**Recommendations:**
- **Target:** Keep documents < 100 KB
- **Warning threshold:** 1 MB
- **Critical threshold:** 10 MB
- **Split strategy:** Use Subset, Extended Reference, or Bucketing patterns

### Multivalue Indexes (23ai)

Index array values directly:
```sql
CREATE MULTIVALUE INDEX idx_tags ON products p (p.data.tags.string());
CREATE MULTIVALUE INDEX idx_order_skus ON orders o (o.data.items.sku.string());
```

### Search Indexes

Full-text and structural queries:
```sql
CREATE SEARCH INDEX idx_product_search ON products (data) FOR JSON;
```

Enables:
- Text search: `json_textcontains(data, '$.description', 'wireless')`
- Structural queries with better performance

### JSON Duality Views

Bridge relational and document worlds:
```sql
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW orders_dv AS
SELECT JSON {
  '_id': o.order_id,
  'customer': c.customer_name,
  'items': [
    SELECT JSON {
      'product': p.product_name,
      'quantity': oi.quantity
    }
    FROM order_items oi, products p
    WHERE oi.order_id = o.order_id
      AND oi.product_id = p.product_id
  ]
}
FROM orders o, customers c
WHERE o.customer_id = c.customer_id;
```

---

## Decision Framework

### Step 1: Analyze Workload
- [ ] Read:write ratio
- [ ] Primary query patterns
- [ ] Data volume and growth
- [ ] Latency requirements
- [ ] Consistency requirements

### Step 2: Choose Pattern(s)
- [ ] Use flowchart above
- [ ] Consider hybrid approaches
- [ ] Validate with estimated data sizes

### Step 3: Design Schema
- [ ] Define document structure
- [ ] Plan for growth
- [ ] Identify index requirements
- [ ] Consider document size limits

### Step 4: Implement & Test
- [ ] Build prototype
- [ ] Load realistic data volumes
- [ ] Benchmark performance
- [ ] Compare alternatives

### Step 5: Monitor & Optimize
- [ ] Track document sizes
- [ ] Monitor query performance
- [ ] Adjust indexes
- [ ] Refactor if patterns change

---

## Common Anti-Patterns

### ❌ The Mega-Document
**Problem:** Embedding everything, document grows to 20MB+
**Solution:** Use Referenced, Subset, or Bucketing patterns

### ❌ The Join Explosion
**Problem:** Everything referenced, application makes 50 queries
**Solution:** Use Embedded or Extended Reference for common data

### ❌ The Stale Computed Field
**Problem:** Pre-computed values never updated
**Solution:** Use triggers, batch jobs, or materialized views

### ❌ The Unbounded Array
**Problem:** Array grows indefinitely, document size explodes
**Solution:** Use Bucketing or Referenced pattern

### ❌ The Missing Index
**Problem:** Full collection scans for filtered queries
**Solution:** Create multivalue or function-based indexes

### ❌ The Premature Optimization
**Problem:** Complex design before understanding workload
**Solution:** Start simple, measure, then optimize

---

## Additional Resources

- [Oracle JSON Collections Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/)
- [Oracle Database 23ai JSON Features](https://docs.oracle.com/en/database/oracle/oracle-database/23/newft/new-features.html#GUID-8C7A84B8-8F3E-4F7D-9F1D-8B1E9E9E9E9E)
- [MongoDB Data Modeling Patterns](https://www.mongodb.com/blog/post/building-with-patterns-a-summary)
- [Oracle LiveLabs - JSON Workshops](https://apexapps.oracle.com/pls/apex/r/dbpm/livelabs/home)

---

**Last Updated:** November 2024
**Version:** 1.0
