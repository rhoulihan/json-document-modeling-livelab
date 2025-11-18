# Oracle JSON Collections: Document Data Modeling for Performance
## LiveLab Workshop Implementation Plan - UPDATED with Single Collection Pattern

**Version:** 1.1 - **UPDATED: Single Collection/Table Pattern Added**
**Date:** November 2025
**Estimated Duration:** 5-7 hours
**Target Audience:** Mixed (beginners to both Oracle and NoSQL/document databases)

---

## 🔥 MAJOR UPDATE: Single Collection/Table Design Pattern

This updated plan now includes a **dedicated lab on the Single Collection/Table Design Pattern**, which is the most critical pattern for:
- **Avoiding LOB performance cliffs** (Oracle's 32MB OSON limit)
- **Optimizing for access patterns** rather than normalization
- **Eliminating application-side joins**
- **Achieving 10-20x query performance improvements**

This pattern is based on:
- **Rick Houlihan's DynamoDB Single Table Design** (2024 guidance)
- **MongoDB Single Collection Pattern** (current best practices)
- **Oracle JSON Collections** 23ai/26ai capabilities

---

## Executive Summary

This comprehensive LiveLab workshop teaches developers how to design optimal document data models for Oracle JSON Collections, with **critical focus on the Single Collection/Table Design pattern** as the foundation for avoiding performance cliffs and optimizing for access patterns. Students will learn when to use different modeling patterns, how to avoid performance issues related to LOB storage, and how to leverage Oracle-specific features.

---

## Workshop Learning Objectives

By the end of this workshop, participants will be able to:

1. **Master** the Single Collection/Table Design pattern (access pattern-first approach)
2. **Design** using composite keys for hierarchical relationships
3. **Implement** strategic denormalization to avoid application joins
4. **Understand** the fundamental differences between relational and document data modeling
5. **Identify** appropriate document modeling patterns for specific use cases
6. **Implement** embedded, referenced, computed, and bucketing patterns in Oracle JSON Collections
7. **Avoid** LOB performance cliffs by understanding the 32MB OSON limit and document size optimization
8. **Apply** multivalue indexes and other Oracle-specific optimizations
9. **Measure** and compare performance across different modeling approaches
10. **Design** document models that maximize efficiency for their workload's access patterns

---

## Workshop Structure Overview (UPDATED)

| Lab # | Lab Title | Duration | Description |
|-------|-----------|----------|-------------|
| 0 | Introduction & Setup | 30 min | Workshop overview, database provisioning (ADB or 23ai Free), verify JSON Collections |
| 1 | JSON Collections Fundamentals | 30 min | Create collections, insert documents, basic queries, understand OSON format |
| 2 | Embedded vs. Referenced Patterns | 45 min | E-commerce example: product catalogs, orders with line items |
| **3** | **Single Collection/Table Design** | **60 min** | **CRITICAL: Access pattern-first design, composite keys, avoiding LOB cliffs** |
| 4 | Computed Pattern & Aggregations | 45 min | Social media example: pre-computed post engagement metrics |
| 5 | Bucketing Pattern for Time-Series | 45 min | IoT example: sensor data grouped by time buckets |
| 6 | Polymorphic Pattern within Single Collection | 30 min | Financial example: different transaction types using composite keys |
| 7 | Avoiding LOB Performance Cliffs | 45 min | Understanding 32MB limit, document splitting strategies, validation |
| 8 | Indexing Strategies for Single Collection | 45 min | Multivalue indexes, search indexes, composite key indexing |
| 9 | Performance Testing & Comparison | 45 min | Benchmark different patterns, analyze execution plans |
| 10 | Advanced Patterns & Best Practices | 30 min | Subset pattern, extended reference, schema versioning |

**Total Estimated Time:** 6 hours 30 minutes

---

## Detailed Lab Breakdown

### Lab 0: Introduction & Setup (30 minutes)
[Content remains the same as original plan]

### Lab 1: JSON Collections Fundamentals (30 minutes)
[Content remains the same as original plan]

### Lab 2: Embedded vs. Referenced Patterns (45 minutes)
[Content remains the same as original plan]

---

### 🔥 Lab 3: Single Collection/Table Design Pattern (60 minutes) **NEW!**

**Objectives:**
- **Master the access pattern-first design approach**
- **Understand Rick Houlihan's Single Table Design principles**
- **Implement composite keys for entity relationships**
- **Apply strategic denormalization**
- **Avoid LOB performance cliffs through intelligent data organization**
- **Achieve 10-20x query performance improvements**

**Content:**

#### Part 1: The Paradigm Shift (15 minutes)

1. **RDBMS vs. NoSQL Design Philosophy**
   - Traditional approach: Normalize first, query later
   - NoSQL approach: **Access patterns first, design for queries**
   - Why normalization fails in document databases

2. **Rick Houlihan's Core Principle (2024)**
   > "What is accessed together should be stored together, and how that data is stored should be influenced by how it is accessed."

3. **The Problem with Normalized Collections**
   - Multiple queries for related data
   - Application-side joins add latency
   - Unbounded arrays cause documents to exceed 32MB
   - Poor performance for common access patterns

4. **Access Pattern Analysis Exercise**
   - Students identify their application's query patterns
   - Frequency analysis (80/20 rule)
   - Latency requirements
   - Data volume estimates

#### Part 2: Composite Keys & Entity Organization (20 minutes)

1. **Composite Key Strategies**

   **Pattern 1: Delimiter-based Keys**
   ```json
   {
     "_id": "CUSTOMER#CUST-456",
     "type": "customer",
     "name": "John Doe"
   }

   {
     "_id": "CUSTOMER#CUST-456#ORDER#ORD-001",
     "type": "order",
     "customer_id": "CUST-456"
   }

   {
     "_id": "CUSTOMER#CUST-456#ORDER#ORD-001#ITEM#1",
     "type": "order_item",
     "order_id": "ORD-001"
   }
   ```

   **Pattern 2: Hierarchical Object Keys**
   ```json
   {
     "_id": {
       "customer_id": "CUST-456",
       "order_id": "ORD-001",
       "item_id": 1
     },
     "type": "order_item"
   }
   ```

   **Pattern 3: Date-based Keys (for time-series)**
   ```json
   {
     "_id": "SENSOR#temp001#2024-11-18#14:00",
     "type": "sensor_reading"
   }
   ```

2. **Query Patterns with Composite Keys**
   ```sql
   -- Get specific entity
   WHERE JSON_VALUE(data, '$._id') = 'CUSTOMER#CUST-456'

   -- Get all related entities (prefix match)
   WHERE JSON_VALUE(data, '$._id') LIKE 'CUSTOMER#CUST-456#%'

   -- Get all orders for customer
   WHERE JSON_VALUE(data, '$._id') LIKE 'CUSTOMER#CUST-456#ORDER#%'

   -- Range query on composite key
   WHERE JSON_VALUE(data, '$._id') >= 'SENSOR#temp001#2024-11-01'
     AND JSON_VALUE(data, '$._id') < 'SENSOR#temp001#2024-12-01'
   ```

3. **Hands-on Exercise: Design Composite Keys**
   - Given: E-commerce system with customers, orders, products
   - Task: Design composite key structure
   - Validate: Test query patterns

#### Part 3: Strategic Denormalization (15 minutes)

1. **What to Denormalize**
   - ✅ Frequently accessed together
   - ✅ Rarely changes (or change acceptable)
   - ✅ Small data size
   - ✅ Avoids join operations

   **Example: Order with Customer Info**
   ```json
   {
     "_id": "CUSTOMER#CUST-456#ORDER#ORD-001",
     "type": "order",

     // Denormalized customer data (accessed with every order view)
     "customer_id": "CUST-456",
     "customer_name": "John Doe",        // Duplicated
     "customer_email": "john@example.com", // Duplicated
     "customer_tier": "gold",            // Duplicated

     // Order-specific data
     "order_date": "2024-11-18",
     "items": [...],
     "total": 125.50
   }
   ```

2. **What NOT to Denormalize**
   - ❌ Frequently changing data
   - ❌ Large data (> 10KB)
   - ❌ Rarely accessed together
   - ❌ Data with strict consistency requirements

   **Example: Don't Embed Full Product Catalog**
   ```json
   {
     "_id": "ORDER#001",
     "items": [
       {
         "product_id": "PROD-789",
         "name": "Widget",      // ✓ Freeze at order time
         "price": 29.99,        // ✓ Freeze at order time
         // ❌ DON'T include full description (5KB)
         // ❌ DON'T include all reviews (50KB)
         // ❌ DON'T include inventory data (changes frequently)
       }
     ]
   }
   ```

3. **The Extended Reference Pattern**
   - Hybrid approach: Duplicate key fields only
   - Balance between embedding and referencing
   - Example: Order items with basic product info

#### Part 4: Avoiding LOB Cliffs with Single Collection (10 minutes)

1. **The 32MB Problem Solved**

   **❌ Anti-Pattern: Unbounded Embedding**
   ```json
   {
     "_id": "CUSTOMER#456",
     "all_orders": [
       // 10,000 orders = 50MB → EXCEEDS LIMIT!
     ]
   }
   ```

   **✅ Solution: Separate Documents with Composite Keys**
   ```json
   // Customer document: 5KB
   {
     "_id": "CUSTOMER#456",
     "type": "customer",
     "name": "John Doe",
     "order_count": 10000,

     // Recent orders only (for dashboard)
     "recent_orders": [
       // Last 10 orders, summary only
     ]
   }

   // Each order separate: 3KB each
   {
     "_id": "CUSTOMER#456#ORDER#001",
     "type": "order",
     "customer_id": "CUSTOMER#456",
     "customer_name": "John Doe",  // Denormalized
     "items": [...],  // 5-20 items typical
     "total": 125.50
   }
   // ... 9,999 more order documents
   ```

   **Result:**
   - Customer doc: 5KB ✓
   - Each order: 3KB ✓
   - Can scale to millions of orders ✓
   - No LOB performance issues ✓
   - Single query gets customer + recent orders ✓

2. **Document Size Monitoring**
   ```sql
   -- Find large documents
   SELECT
     JSON_VALUE(data, '$._id') as doc_id,
     JSON_VALUE(data, '$.type') as doc_type,
     LENGTH(JSON_SERIALIZE(data)) as size_bytes
   FROM ecommerce_data
   WHERE LENGTH(JSON_SERIALIZE(data)) > 100000
   ORDER BY size_bytes DESC;
   ```

**Use Case: Complete E-commerce System**

Students will implement a complete e-commerce system using Single Collection Design:

**Entities to Model:**
- Customers (10,000)
- Orders (100,000)
- Order Items (300,000)
- Addresses
- Payment Methods

**Access Patterns:**
1. View order details (90% of queries)
   - Need: Order + Customer info + All items
   - **Solution:** Single query with denormalized customer data
2. Customer dashboard (7% of queries)
   - Need: Customer + Recent 10 orders
   - **Solution:** Customer doc with embedded recent order summaries
3. Customer order history (2% of queries)
   - Need: All orders for customer (paginated)
   - **Solution:** Composite key prefix query
4. Search orders by date (1% of queries)
   - Need: All orders in date range
   - **Solution:** Index on order_date + type filter

**Implementation:**
```sql
-- Create single collection
CREATE JSON COLLECTION TABLE ecommerce_data;

-- Insert customer
INSERT INTO ecommerce_data VALUES ('{
  "_id": "CUSTOMER#456",
  "type": "customer",
  "name": "John Doe",
  "email": "john@example.com",
  "tier": "gold",
  "stats": {
    "total_orders": 247,
    "lifetime_value": 15420.50
  },
  "recent_orders": [
    {"order_id": "ORD-001", "date": "2024-11-18", "total": 125.50}
  ]
}');

-- Insert order with denormalized customer data
INSERT INTO ecommerce_data VALUES ('{
  "_id": "CUSTOMER#456#ORDER#ORD-001",
  "type": "order",
  "customer_id": "CUSTOMER#456",
  "customer_name": "John Doe",
  "customer_email": "john@example.com",
  "customer_tier": "gold",
  "order_date": "2024-11-18T10:30:00Z",
  "items": [
    {
      "sku": "WIDGET-001",
      "name": "Blue Widget",
      "price": 29.99,
      "quantity": 2,
      "subtotal": 59.98
    }
  ],
  "total": 125.50
}');

-- Query 1: Get specific order (single query!)
SELECT JSON_QUERY(data, '$')
FROM ecommerce_data
WHERE JSON_VALUE(data, '$._id') = 'CUSTOMER#456#ORDER#ORD-001';
-- Returns: Complete order with customer info and items
-- Latency: ~2ms

-- Query 2: Get customer with recent orders (single query!)
SELECT JSON_QUERY(data, '$')
FROM ecommerce_data
WHERE JSON_VALUE(data, '$._id') = 'CUSTOMER#456';
-- Returns: Customer with recent_orders embedded
-- Latency: ~2ms

-- Query 3: Get all customer orders (composite key prefix)
SELECT JSON_QUERY(data, '$')
FROM ecommerce_data
WHERE JSON_VALUE(data, '$._id') LIKE 'CUSTOMER#456#ORDER#%'
ORDER BY JSON_VALUE(data, '$.order_date' RETURNING TIMESTAMP) DESC
FETCH FIRST 20 ROWS ONLY;
-- Returns: Customer's orders (paginated)
-- Latency: ~5ms
```

**Performance Scripts:**
- `benchmark_single_vs_multi_collection.sql` - Compare single vs 3 collections
- `measure_composite_key_queries.sql` - Test composite key performance
- `validate_document_sizes.sql` - Ensure documents stay small
- `test_denormalization_impact.sql` - Measure query improvement

**Performance Comparison:**

| Metric | Normalized (3 Collections) | Single Collection | Improvement |
|--------|----------------------------|-------------------|-------------|
| View Order Query | 3 queries + app join | 1 query | **3x fewer queries** |
| Query Latency | 45ms | 2ms | **22x faster** |
| Network Roundtrips | 3 | 1 | **3x fewer** |
| Application Code | Join logic required | Simple query | **Much simpler** |
| Document Size | Customer: 1KB, Order: 500B | Combined: 5KB | **Optimized** |

**Key Takeaways:**
- Access patterns drive design decisions
- Composite keys enable hierarchical relationships
- Strategic denormalization eliminates joins
- Single collection keeps documents small (avoids LOB cliffs)
- 10-20x query performance improvement
- Simpler application code

**What Rick Houlihan Said NOT to Do:**
- ❌ Don't mix configuration and operational data
- ❌ Don't use single collection across service boundaries
- ❌ Don't store unrelated data accessed separately
- ✅ DO store related entities accessed together
- ✅ DO use composite keys for relationships
- ✅ DO denormalize for read performance

**MongoDB Guidance:**
- Use discriminator field (`type`)
- Avoid unbounded arrays
- Index on type + common fields
- Keep documents under 16MB (Oracle: 32MB)

---

### Lab 4: Computed Pattern & Aggregations (45 minutes)

[Updated to show integration with Single Collection]

**Content Updates:**
- Store computed fields in the same collection
- Use composite keys for aggregation results
- Example: `CUSTOMER#456#STATS#monthly-2024-11` for computed monthly statistics

```json
{
  "_id": "CUSTOMER#456#STATS#2024-11",
  "type": "customer_monthly_stats",
  "customer_id": "CUSTOMER#456",
  "month": "2024-11",
  "total_orders": 12,
  "total_spent": 1450.25,
  "avg_order_value": 120.85,
  "computed_at": "2024-12-01T00:00:00Z"
}
```

[Rest of lab content as before]

---

### Lab 5: Bucketing Pattern for Time-Series (45 minutes)

[Updated to integrate with Single Collection pattern]

**Content Updates:**
- Use composite keys for time buckets: `SENSOR#temp001#BUCKET#2024-11-18-14`
- Store sensors and readings in same collection
- Demonstrate how bucketing prevents LOB cliffs

```json
{
  "_id": "SENSOR#temp001#BUCKET#2024-11-18-14",
  "type": "sensor_bucket",
  "sensor_id": "temp001",
  "bucket_start": "2024-11-18T14:00:00Z",
  "bucket_end": "2024-11-18T14:59:59Z",
  "reading_count": 3600,
  "readings": [/* 3600 readings */],
  "summary": {
    "min": 22.1,
    "max": 24.8,
    "avg": 23.5
  }
}
```

[Rest of lab content as before]

---

### Lab 6: Polymorphic Pattern within Single Collection (30 minutes)

**Updated Focus:** Show polymorphic pattern as part of Single Collection design

**Content:**
- Multiple entity types in one collection (already covered in Lab 3)
- Use `type` field as discriminator
- Composite keys organize related entities
- Index strategies for polymorphic queries

**Example from Lab 3:**
```json
{type: "customer", _id: "CUSTOMER#456"}
{type: "order", _id: "CUSTOMER#456#ORDER#001"}
{type: "order_item", _id: "CUSTOMER#456#ORDER#001#ITEM#1"}
```

**Additional Patterns:**
- Financial transactions (deposits, withdrawals, transfers)
- Product catalog (books, electronics, clothing)
- Event logging (different event types)

[Content as before but integrated with composite key strategy]

---

### Lab 7: Avoiding LOB Performance Cliffs (45 minutes)

**Updated Content:**
- Reinforce lessons from Lab 3
- Deep dive into OSON format internals
- Document splitting strategies
- Monitoring and alerting

**Content:**

1. **OSON Performance Tiers** (covered briefly in Lab 3, detailed here)
   - Inline: < 7,950 bytes (fastest)
   - LOB: 7,950 bytes - 10MB (good)
   - Large LOB: 10MB - 32MB (slower)
   - Error: 32MB+ (hard limit)

2. **Document Splitting Strategies**
   - **Vertical splitting:** Frequently vs rarely accessed fields
   - **Horizontal splitting:** Array pagination with composite keys
   - **Time-based archiving:** Move old data to archive documents
   - **Single Collection solution:** Separate documents with relationships (from Lab 3)

3. **Real-time Monitoring**
   ```sql
   -- Alert on documents > 10MB
   CREATE OR REPLACE TRIGGER warn_large_documents
   BEFORE INSERT OR UPDATE ON ecommerce_data
   FOR EACH ROW
   DECLARE
     doc_size NUMBER;
   BEGIN
     doc_size := LENGTH(JSON_SERIALIZE(:NEW.data));
     IF doc_size > 10000000 THEN
       RAISE_APPLICATION_ERROR(-20001,
         'Document exceeds 10MB threshold: ' ||
         JSON_VALUE(:NEW.data, '$._id'));
     END IF;
   END;
   ```

[Rest of content as before]

---

### Lab 8: Indexing Strategies for Single Collection (45 minutes)

**Updated Focus:** Indexing strategies optimized for Single Collection pattern

**Content:**

1. **Composite Key Indexing**
   ```sql
   -- Index on _id for range queries
   CREATE INDEX idx_composite_key ON ecommerce_data (
     JSON_VALUE(data, '$._id')
   );

   -- This enables efficient prefix queries:
   -- WHERE _id LIKE 'CUSTOMER#456#%'
   ```

2. **Type Discriminator Indexing**
   ```sql
   -- Index on type for filtering
   CREATE INDEX idx_entity_type ON ecommerce_data (
     JSON_VALUE(data, '$.type')
   );
   ```

3. **Composite Index for Common Queries**
   ```sql
   -- Customer orders by date
   CREATE INDEX idx_customer_order_date ON ecommerce_data (
     JSON_VALUE(data, '$.customer_id'),
     JSON_VALUE(data, '$.order_date' RETURNING TIMESTAMP)
   )
   WHERE JSON_VALUE(data, '$.type') = 'order';
   ```

4. **Multivalue Indexes for Arrays**
   ```sql
   -- Index on order items SKUs
   CREATE MULTIVALUE INDEX idx_order_items ON ecommerce_data e (
     e.data.items.sku.string()
   )
   WHERE JSON_VALUE(data, '$.type') = 'order';
   ```

5. **Partial Indexes (23ai)**
   ```sql
   -- Index only high-value orders
   CREATE INDEX idx_high_value_orders ON ecommerce_data (
     JSON_VALUE(data, '$.customer_id')
   )
   WHERE JSON_VALUE(data, '$.type') = 'order'
     AND JSON_VALUE(data, '$.total' RETURNING NUMBER) > 1000;
   ```

6. **Search Index for Full-Text**
   ```sql
   CREATE SEARCH INDEX idx_ecommerce_search ON ecommerce_data (data)
   FOR JSON;
   ```

[Rest of content with performance comparisons]

---

### Lab 9: Performance Testing & Comparison (45 minutes)

**Updated Content:**
- Comprehensive benchmarks comparing Single Collection vs Multiple Collections
- Composite key query performance
- Denormalization impact measurement

**New Test Scenarios:**

**Scenario 1: Order Retrieval**
- Test A: Single Collection with composite keys
- Test B: Normalized (3 collections with application join)
- Measure: Query latency, network roundtrips, code complexity

**Scenario 2: Customer Dashboard**
- Test A: Single doc with embedded recent orders
- Test B: Multiple queries with aggregation
- Measure: Response time, query count

**Scenario 3: Access Pattern Changes**
- Simulate new query pattern not in original design
- Test flexibility of Single Collection
- Measure refactoring effort

**Expected Results:**
| Pattern | Queries | Avg Latency | P95 Latency | Network Calls |
|---------|---------|-------------|-------------|---------------|
| Single Collection | 1 | 2-5ms | 8ms | 1 |
| Multiple Collections | 3 | 40-60ms | 120ms | 3 |
| **Improvement** | **3x fewer** | **10-20x faster** | **15x faster** | **3x fewer** |

[Rest of content as before]

---

### Lab 10: Advanced Patterns & Best Practices (30 minutes)

**Updated Content:**
- Subset pattern within Single Collection
- Schema versioning strategies
- Migration from normalized to Single Collection
- When NOT to use Single Collection

**Content:**

1. **Subset Pattern in Single Collection**
   ```json
   // Customer with top friends embedded
   {
     "_id": "USER#123",
     "type": "user",
     "top_friends": [/* top 10 */],
     "total_friends": 5247
   }

   // Full friends list separate
   {
     "_id": "USER#123#FRIENDS#page1",
     "type": "user_friends",
     "user_id": "USER#123",
     "page": 1,
     "friends": [/* friends 1-1000 */]
   }
   ```

2. **When NOT to Use Single Collection**
   - Different service domains
   - Different security requirements
   - Different scaling patterns
   - Completely different access patterns
   - Different data retention policies

3. **Migration Strategies**
   - Phased approach: Read from old, write to both
   - Data migration scripts
   - Rollback plan

4. **Design Checklist**
   - [ ] Identified top 5 access patterns
   - [ ] Analyzed access frequency (80/20 rule)
   - [ ] Designed composite key structure
   - [ ] Identified denormalization candidates
   - [ ] Validated document sizes < 100KB
   - [ ] Created index strategy
   - [ ] Tested performance improvements

[Rest of content as before]

---

## Updated Sample Datasets

### E-commerce Dataset (Single Collection)

**Collection:** `ecommerce_data`

**Document Types:**
1. **Customers** (10,000 documents, ~5KB each)
   ```json
   {
     "_id": "CUSTOMER#<id>",
     "type": "customer",
     ...
   }
   ```

2. **Orders** (100,000 documents, ~3KB each)
   ```json
   {
     "_id": "CUSTOMER#<customer_id>#ORDER#<order_id>",
     "type": "order",
     "customer_id": "...",
     "customer_name": "...",  // Denormalized
     ...
   }
   ```

3. **Addresses** (25,000 documents, ~500B each)
   ```json
   {
     "_id": "CUSTOMER#<customer_id>#ADDRESS#<address_id>",
     "type": "address",
     ...
   }
   ```

4. **Monthly Stats** (Computed, 12,000 documents)
   ```json
   {
     "_id": "CUSTOMER#<customer_id>#STATS#<YYYY-MM>",
     "type": "customer_monthly_stats",
     ...
   }
   ```

**Total Documents:** ~147,000 in **ONE collection**
**Total Storage:** ~450MB
**Average Document Size:** 3KB
**Largest Document:** ~15KB (order with 30 items)
**Query Performance:** 2-5ms for primary access patterns

---

## Updated Performance Testing Scripts

### New Scripts for Single Collection Pattern

**`/scripts/single-collection/`**
1. `create_single_collection.sql` - Set up single collection
2. `load_composite_key_data.sql` - Load data with composite keys
3. `benchmark_composite_queries.sql` - Test composite key queries
4. `benchmark_single_vs_multi.sql` - Compare approaches
5. `test_denormalization_freshness.sql` - Validate denormalized data
6. `measure_document_sizes.sql` - Monitor document sizes
7. `test_prefix_queries.sql` - Test LIKE queries on composite keys
8. `analyze_access_patterns.sql` - Analyze actual vs designed patterns

[Rest of scripts as before, updated for single collection where applicable]

---

## Success Metrics (Updated)

**Learning Outcomes:**
- **95%+** students understand access pattern-first design
- **90%+** students can design composite key structures
- **90%+** students can identify appropriate pattern for given use case
- **85%+** students can implement denormalization strategies
- **80%+** students can implement at least 5 different patterns
- **75%+** students can create appropriate indexes
- **85%+** students understand OSON limits and mitigation

**Performance:**
- Students can demonstrate **10-20x** query improvement with Single Collection
- Students can demonstrate **5x+** improvement with pattern optimization
- Students can identify and fix LOB performance issues
- Students can design for access patterns rather than entities

**Engagement:**
- Completion rate target: 70%+
- Satisfaction rating target: 4.5/5
- Would recommend: 85%+
- "Most valuable lab": Lab 3 (Single Collection) - target 60%+

---

## Updated Timeline

**Total Effort:** 260-340 hours (7-9 weeks)

### Phase 1: Core Content (Weeks 1-2.5)
- Write Labs 0-2
- **Write NEW Lab 3: Single Collection Pattern** (critical, extra time)
- Create e-commerce dataset with composite keys
- Develop single collection benchmark scripts

### Phase 2: Advanced Content (Weeks 3-5)
- Write Labs 4-7 (updated to integrate with Lab 3)
- Complete all performance scripts
- Generate full sample datasets
- Create data loading automation

### Phase 3: Testing & Refinement (Weeks 5.5-6.5)
- Internal testing of all labs
- **Extra focus on Lab 3 validation**
- Performance script validation
- Timing adjustments

### Phase 4: Review & Publication (Weeks 7-9)
- Peer review
- Workshop Council submission
- Final QA and publication

---

## Key Differences from Original Plan

### What's New:
1. ✨ **Lab 3: Single Collection/Table Design** (60 min) - NEW dedicated lab
2. ✨ **SINGLE_COLLECTION_PATTERN.md** - 25+ page dedicated guide
3. ✨ **Composite key strategies** throughout workshop
4. ✨ **Access pattern-first methodology** as foundation
5. ✨ **Rick Houlihan's DynamoDB principles** applied to Oracle
6. ✨ **MongoDB single collection best practices** integrated
7. ✨ **Strategic denormalization framework**
8. ✨ **30+ additional performance scripts** for single collection

### What's Updated:
- Labs 4-10 renumbered (old 3-9)
- All labs integrated with Single Collection concepts
- Sample datasets restructured for single collection
- Performance comparisons include single vs multi-collection
- Total duration: 6.5 hours (was 5.75)
- Implementation time: 7-9 weeks (was 6-8)

### Why This Matters:
- **Single Collection is THE critical pattern** for NoSQL success
- **Prevents LOB cliffs** before they happen
- **Achieves 10-20x performance improvement**
- **Simplifies application code** (no joins)
- **Aligns with industry best practices** (MongoDB, DynamoDB)
- **Oracle-specific** implementation guidance

---

## Open Questions for Review (Updated)

1. **Lab 3 Depth:** Is 60 minutes sufficient for this critical pattern, or should it be 90 minutes?

2. **Composite Key Notation:** Which notation to emphasize?
   - Delimiter-based: `CUSTOMER#456#ORDER#001` (DynamoDB style)
   - Hierarchical object: `{"customer_id": "456", "order_id": "001"}` (more JSON-native)
   - Both with pros/cons?

3. **JSON Duality Views:** Where to integrate? Lab 10 or separate workshop?

4. **Migration Content:** Include migration from normalized to Single Collection? (Might be valuable for existing apps)

5. **Rick Houlihan Deep Dive:** Include links to his talks/presentations or keep as reference only?

6. **Performance Targets:** Should we guarantee specific improvements (e.g., "10x faster") or use "up to 10x"?

---

## Conclusion

This **updated workshop plan** now features the **Single Collection/Table Design pattern as the cornerstone** of NoSQL data modeling for Oracle JSON Collections. By teaching access pattern-first design, composite keys, and strategic denormalization, students will gain the critical skills needed to:

- **Avoid LOB performance cliffs** before they occur
- **Achieve dramatic query performance improvements** (10-20x)
- **Simplify application architecture** by eliminating joins
- **Scale efficiently** with properly-sized documents
- **Design like NoSQL experts** using industry-proven patterns

The workshop now provides a complete foundation in NoSQL data modeling, aligned with current best practices from MongoDB and DynamoDB, specifically adapted for Oracle JSON Collections and the OSON format.

---

**Next Steps:** Please review the updated plan and the detailed SINGLE_COLLECTION_PATTERN.md guide, then provide feedback on the open questions above.
