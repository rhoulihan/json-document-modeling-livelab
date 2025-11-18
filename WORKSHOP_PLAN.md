# Oracle JSON Collections: Document Data Modeling for Performance
## LiveLab Workshop Implementation Plan

**Version:** 1.0
**Date:** November 2025
**Estimated Duration:** 4-6 hours
**Target Audience:** Mixed (beginners to both Oracle and NoSQL/document databases)

---

## Executive Summary

This comprehensive LiveLab workshop teaches developers how to design optimal document data models for Oracle JSON Collections, focusing on performance optimization for common access patterns. Students will learn when to use different modeling patterns (embedded, referenced, computed, bucketing), how to avoid performance cliffs related to LOB storage, and how to leverage Oracle-specific features like multivalue indexes and OSON binary format.

---

## Workshop Learning Objectives

By the end of this workshop, participants will be able to:

1. **Understand** the fundamental differences between relational and document data modeling
2. **Identify** appropriate document modeling patterns for specific use cases
3. **Implement** embedded, referenced, computed, and bucketing patterns in Oracle JSON Collections
4. **Avoid** LOB performance cliffs by understanding the 32MB OSON limit and document size optimization
5. **Apply** multivalue indexes and other Oracle-specific optimizations
6. **Measure** and compare performance across different modeling approaches
7. **Design** document models that maximize efficiency for their workload's access patterns

---

## Technical Requirements

### Database Platforms (User Choice)
1. **Option A: Oracle Autonomous Database Free Tier** (Recommended)
   - Always-free tier (up to 2 DBs)
   - Preconfigured JSON Collections support
   - Automatic indexing recommendations
   - Easier provisioning for workshop users

2. **Option B: Oracle Database 23ai Free - Developer Release**
   - Container-based deployment
   - Full feature parity with 23ai
   - More control over configuration
   - Suitable for local development

### Prerequisites for Students
- Basic SQL knowledge (SELECT, INSERT, UPDATE)
- General programming familiarity (any language)
- Understanding of basic data structures (arrays, objects/dictionaries)
- Oracle Cloud account (for Option A) OR Docker installed (for Option B)

### Tools and Technologies
- Oracle SQL Developer Web (built-in to ADB) OR SQL*Plus
- Optional: MongoDB-compatible client (mongosh) for API demonstrations
- Performance monitoring tools (built-in Oracle performance views)
- Browser with JavaScript console for REST API examples

---

## Workshop Structure Overview

| Lab # | Lab Title | Duration | Description |
|-------|-----------|----------|-------------|
| 0 | Introduction & Setup | 30 min | Workshop overview, database provisioning (ADB or 23ai Free), verify JSON Collections |
| 1 | JSON Collections Fundamentals | 30 min | Create collections, insert documents, basic queries, understand OSON format |
| 2 | Embedded vs. Referenced Patterns | 45 min | E-commerce example: product catalogs, orders with line items |
| 3 | Computed Pattern & Aggregations | 45 min | Social media example: pre-computed post engagement metrics |
| 4 | Bucketing Pattern for Time-Series | 45 min | IoT example: sensor data grouped by time buckets |
| 5 | Polymorphic Pattern | 30 min | Financial example: different transaction types in one collection |
| 6 | Avoiding LOB Performance Cliffs | 45 min | Understanding 32MB limit, document splitting strategies |
| 7 | Indexing Strategies | 45 min | Multivalue indexes, search indexes, composite indexes |
| 8 | Performance Testing & Comparison | 45 min | Benchmark different patterns, analyze execution plans |
| 9 | Advanced Patterns & Best Practices | 30 min | Subset pattern, extended reference, schema versioning |

**Total Estimated Time:** 5 hours 45 minutes

---

## Detailed Lab Breakdown

### Lab 0: Introduction & Setup (30 minutes)

**Objectives:**
- Understand workshop goals and document modeling concepts
- Provision Oracle database (user chooses ADB Free or 23ai Free)
- Verify JSON Collections functionality
- Set up performance monitoring tools

**Content:**
1. Workshop introduction and use case overview
2. Relational vs. Document modeling paradigm shift
3. Database provisioning:
   - Path A: Create ADB Free Tier instance
   - Path B: Pull and run Oracle Database 23ai Free container
4. Create first JSON collection
5. Insert sample document and verify OSON storage
6. Enable SQL Developer Web or connect via SQL*Plus
7. Set up performance monitoring queries

**Deliverables:**
- Working Oracle database with JSON Collections enabled
- Sample collection with test documents
- Performance monitoring queries saved

**Performance Scripts:**
- `setup_monitoring.sql` - Create views for tracking query performance
- `verify_json_setup.sql` - Validate JSON Collections configuration

---

### Lab 1: JSON Collections Fundamentals (30 minutes)

**Objectives:**
- Master basic JSON Collection CRUD operations
- Understand document structure and the `_id` field
- Learn JSON query syntax (json_value, json_query, json_exists)
- Understand OSON binary format benefits

**Content:**
1. Create JSON collections using SQL and MongoDB API
2. Document structure requirements (_id field)
3. Insert documents (single and bulk)
4. Query documents using:
   - Simple paths (json_value)
   - Array paths (json_query)
   - Existence checks (json_exists)
   - Dot notation
5. Update operations (json_transform, json_mergepatch)
6. Delete documents
7. OSON format explanation and benefits

**Use Case:** Simple product catalog

**Sample Data:** 100 product documents

**Performance Scripts:**
- `benchmark_oson_vs_clob.sql` - Compare OSON vs CLOB storage performance
- `measure_insert_performance.sql` - Benchmark bulk insert speeds

**Key Takeaways:**
- OSON format provides 2-10x query performance vs CLOB
- Inline storage (< 7950 bytes for 8KB blocks) is faster
- Document structure affects query efficiency

---

### Lab 2: Embedded vs. Referenced Patterns (45 minutes)

**Objectives:**
- Understand when to embed vs. reference data
- Implement both patterns for the same use case
- Measure performance differences
- Learn trade-offs (data duplication, update complexity, read performance)

**Content:**
1. **Embedded Pattern:**
   - E-commerce order with embedded line items
   - Product catalog with embedded reviews
   - One-to-few relationships
   - Benefits: Single read operation, atomic updates
   - Drawbacks: Document size growth, data duplication

2. **Referenced Pattern:**
   - Orders reference products in separate collection
   - Users reference addresses in separate collection
   - One-to-many and many-to-many relationships
   - Benefits: No duplication, smaller documents, easier updates
   - Drawbacks: Multiple queries, application-side joins

3. **Performance Comparison:**
   - Read performance: embedded vs referenced
   - Update performance: embedded vs referenced
   - Storage efficiency comparison
   - Network round-trip analysis

**Use Cases:**
- Order processing system
- Product catalog with reviews
- Customer profiles with addresses

**Sample Data:**
- 10,000 products
- 5,000 customers
- 20,000 orders
- 50,000 order line items
- 15,000 product reviews

**Performance Scripts:**
- `benchmark_embedded_orders.sql` - Test embedded order retrieval
- `benchmark_referenced_orders.sql` - Test referenced order retrieval
- `compare_update_patterns.sql` - Compare update performance
- `storage_comparison.sql` - Analyze storage footprint

**Key Decision Matrix:**
| Criteria | Embedded | Referenced |
|----------|----------|------------|
| Read frequency | High | Low |
| Document size | Small (<32MB) | Large |
| Update frequency | Low | High |
| Data duplication | Acceptable | Unacceptable |
| Relationship cardinality | One-to-few | One-to-many |

---

### Lab 3: Computed Pattern & Aggregations (45 minutes)

**Objectives:**
- Implement pre-computed aggregates to optimize read performance
- Understand write-time vs read-time computation trade-offs
- Use triggers and application logic for maintaining computed fields
- Measure performance gains

**Content:**
1. **Pattern Overview:**
   - Pre-compute expensive aggregations at write time
   - Store results in document
   - Update computed fields on changes
   - Trade write complexity for read speed

2. **Implementation Approaches:**
   - Application-managed computed fields
   - Database triggers for automatic updates
   - Materialized views (Oracle-specific)
   - Batch computation jobs

3. **Use Case Implementations:**
   - Social media post with engagement metrics:
     - Total likes count
     - Total comments count
     - Average rating
     - Trending score
   - Product catalog with statistics:
     - Average review rating
     - Total reviews
     - Purchase count
     - Inventory status

4. **Maintenance Strategies:**
   - Incremental updates
   - Full recomputation schedules
   - Eventual consistency considerations

**Sample Data:**
- 50,000 social media posts
- 200,000 likes
- 100,000 comments
- 25,000 products with varying review counts

**Performance Scripts:**
- `benchmark_computed_vs_aggregate.sql` - Compare pre-computed vs on-the-fly
- `measure_write_overhead.sql` - Measure additional write cost
- `trigger_performance.sql` - Test trigger-based maintenance
- `materialized_view_comparison.sql` - Test Oracle materialized views

**Key Metrics:**
- Read performance improvement: Target 10-50x faster
- Write performance overhead: Typically 20-40% slower
- Storage overhead: Minimal (few bytes per document)
- Freshness requirements: Determine sync vs async updates

---

### Lab 4: Bucketing Pattern for Time-Series (45 minutes)

**Objectives:**
- Understand the bucketing pattern for time-series and streaming data
- Avoid document size explosions and LOB performance issues
- Implement time-based and count-based bucketing
- Optimize for IoT and sensor data workloads

**Content:**
1. **Problem Statement:**
   - Individual documents per reading = too many documents
   - All readings in one document = exceeds 32MB OSON limit
   - Solution: Bucket readings into groups

2. **Bucketing Strategies:**
   - **Time-based bucketing:**
     - Hourly buckets (e.g., sensor readings per hour)
     - Daily buckets (e.g., user activities per day)
     - Custom intervals based on data volume
   - **Count-based bucketing:**
     - Fixed array size (e.g., 1000 readings per document)
     - Split when threshold reached
   - **Hybrid approach:**
     - Time-based with count limits

3. **Implementation:**
   - IoT sensor data bucketed by hour
   - User activity logs bucketed by day
   - Transaction batches bucketed by count
   - Document structure:
     ```json
     {
       "_id": "sensor123_2024-11-18-10",
       "sensorId": "sensor123",
       "bucket_start": "2024-11-18T10:00:00Z",
       "bucket_end": "2024-11-18T10:59:59Z",
       "reading_count": 3600,
       "readings": [
         {"timestamp": "...", "value": 23.5, ...},
         ...
       ],
       "summary": {
         "min": 20.1,
         "max": 25.3,
         "avg": 23.2
       }
     }
     ```

4. **Query Patterns:**
   - Range queries across buckets
   - Point lookups within buckets
   - Aggregations across buckets
   - Latest value queries

**Use Cases:**
- IoT sensor monitoring (temperature, pressure, etc.)
- Application performance metrics
- User activity tracking
- Financial tick data

**Sample Data:**
- 100 sensors
- 1,000,000 readings
- Bucketed into ~300 documents per sensor
- Time range: 30 days

**Performance Scripts:**
- `benchmark_bucketing_strategies.sql` - Compare different bucket sizes
- `measure_document_growth.sql` - Track document size over time
- `bucket_query_performance.sql` - Test range and point queries
- `optimal_bucket_size.sql` - Find optimal bucket size for use case

**Bucketing Decision Matrix:**
| Data Rate | Bucket Interval | Approx Records/Bucket |
|-----------|-----------------|------------------------|
| 1/second | Hour | 3,600 |
| 10/second | Hour | 36,000 |
| 100/second | 10 minutes | 60,000 |
| 1000/second | 1 minute | 60,000 |

**Key Considerations:**
- Keep documents under 10MB for optimal performance (well below 32MB limit)
- Balance between too many documents (overhead) and too large (LOB issues)
- Include summary statistics for faster aggregations

---

### Lab 5: Polymorphic Pattern (30 minutes)

**Objectives:**
- Store different document types in the same collection
- Handle varying schemas flexibly
- Query across polymorphic documents efficiently
- Understand when polymorphism is beneficial

**Content:**
1. **Pattern Overview:**
   - Multiple document shapes in one collection
   - Common fields + type-specific fields
   - Use a discriminator field (e.g., "type", "kind")

2. **Use Cases:**
   - **Financial transactions:**
     - Deposits (type: "deposit", fields: amount, account)
     - Withdrawals (type: "withdrawal", fields: amount, account, fee)
     - Transfers (type: "transfer", fields: amount, from_account, to_account)
     - Payments (type: "payment", fields: amount, merchant, category)
   - **Product catalog:**
     - Books (ISBN, author, publisher)
     - Electronics (brand, model, warranty)
     - Clothing (size, color, material)
   - **Event logging:**
     - Different event types with shared + unique attributes

3. **Implementation:**
   ```json
   // Deposit
   {
     "_id": "txn001",
     "type": "deposit",
     "timestamp": "2024-11-18T10:00:00Z",
     "account": "ACC123",
     "amount": 1000.00,
     "currency": "USD",
     "channel": "ATM"
   }

   // Transfer
   {
     "_id": "txn002",
     "type": "transfer",
     "timestamp": "2024-11-18T10:05:00Z",
     "from_account": "ACC123",
     "to_account": "ACC456",
     "amount": 500.00,
     "currency": "USD",
     "reference": "Payment for services"
   }
   ```

4. **Querying Polymorphic Collections:**
   - Filter by type
   - Type-specific field queries
   - Cross-type aggregations
   - Handling optional fields

5. **Indexing Strategies:**
   - Index common fields
   - Partial indexes for type-specific fields
   - Multivalue indexes for array fields

**Sample Data:**
- 50,000 financial transactions (25% deposits, 30% withdrawals, 35% transfers, 10% payments)
- 10,000 products (40% books, 30% electronics, 30% clothing)

**Performance Scripts:**
- `benchmark_polymorphic_queries.sql` - Test type-specific queries
- `compare_collection_splitting.sql` - Compare to separate collections
- `polymorphic_indexing.sql` - Test different indexing strategies

**When to Use Polymorphic Pattern:**
- ✅ Documents share many common fields
- ✅ Querying across all types is common
- ✅ Types are related conceptually
- ❌ Documents have completely different schemas
- ❌ Type-specific queries dominate workload

---

### Lab 6: Avoiding LOB Performance Cliffs (45 minutes)

**Objectives:**
- Understand Oracle's OSON format and the 32MB limit
- Identify when documents approach performance boundaries
- Implement document splitting strategies
- Measure impact of document size on performance

**Content:**
1. **OSON Format Deep Dive:**
   - Binary format for efficient parsing
   - Inline storage threshold: 7,950 bytes (8KB blocks) / 3,964 bytes (older versions)
   - LOB storage: 7,951 bytes - 32MB
   - Hard limit: 32MB per document

2. **Performance Boundaries:**
   - **Inline storage (< 7,950 bytes):**
     - Fastest performance
     - Stored in table block
     - No LOB overhead
   - **Out-of-line LOB (7,950 bytes - 10MB):**
     - Moderate performance
     - LOB segment access
     - Still uses OSON
   - **Large LOB (10MB - 32MB):**
     - Slower performance
     - Memory allocation overhead
     - Network transfer impact

3. **Document Splitting Strategies:**

   **Strategy 1: Vertical Splitting (Frequently vs. Rarely Accessed)**
   ```json
   // Main document (frequently accessed)
   {
     "_id": "user123",
     "name": "John Doe",
     "email": "john@example.com",
     "profile_id": "profile_user123"  // Reference to extended data
   }

   // Extended profile (rarely accessed)
   {
     "_id": "profile_user123",
     "user_id": "user123",
     "full_bio": "...", // Large text
     "all_posts": [...], // Large array
     "detailed_history": {...}
   }
   ```

   **Strategy 2: Horizontal Splitting (Array Pagination)**
   ```json
   // Main document with recent items
   {
     "_id": "order123",
     "customer": "...",
     "recent_items": [...], // Last 10 items
     "total_items": 5000,
     "has_more_items": true
   }

   // Additional items documents
   {
     "_id": "order123_items_page1",
     "order_id": "order123",
     "page": 1,
     "items": [...] // Items 11-1000
   }
   ```

   **Strategy 3: Archive Pattern**
   - Keep active data in main document
   - Move old/inactive data to archive collection
   - Use time-based partitioning

4. **Monitoring Document Sizes:**
   - Query to find large documents
   - Track document growth over time
   - Alert on approaching limits

5. **Practical Exercise:**
   - Create documents of varying sizes
   - Measure query performance at different thresholds
   - Implement splitting for large documents
   - Compare before/after performance

**Sample Data:**
- 1,000 documents ranging from 1KB to 31MB
- Test documents at key thresholds: 5KB, 7KB, 8KB, 100KB, 1MB, 5MB, 10MB, 20MB, 30MB

**Performance Scripts:**
- `measure_size_impact.sql` - Test performance across size ranges
- `find_large_documents.sql` - Identify documents approaching limits
- `benchmark_splitting_strategies.sql` - Compare splitting approaches
- `monitor_document_growth.sql` - Track size trends over time

**Key Performance Findings:**
| Document Size | Storage Type | Relative Performance |
|---------------|--------------|---------------------|
| < 7,950 bytes | Inline | 1x (baseline - fastest) |
| 8KB - 100KB | LOB | 1.2-1.5x slower |
| 100KB - 1MB | LOB | 1.5-2x slower |
| 1MB - 10MB | LOB | 2-3x slower |
| 10MB - 32MB | LOB | 3-5x slower |

**Design Guidelines:**
- **Target:** Keep frequently-accessed documents < 100KB
- **Warning:** Monitor documents approaching 1MB
- **Critical:** Split documents approaching 10MB
- **Hard Limit:** 32MB - must split

---

### Lab 7: Indexing Strategies (45 minutes)

**Objectives:**
- Create and use multivalue indexes for JSON arrays
- Implement search indexes for full-text queries
- Build composite indexes for multi-field queries
- Understand partial and subsetting indexes
- Measure index impact on query performance

**Content:**
1. **Index Types for JSON Collections:**

   **A. Multivalue Indexes (for arrays)**
   - Index values within JSON arrays
   - Automatically handle multiple values per document
   - Support both SQL and MongoDB API queries
   ```sql
   CREATE MULTIVALUE INDEX idx_product_tags
   ON products p (p.data.tags.string());

   CREATE MULTIVALUE INDEX idx_order_items_sku
   ON orders o (o.data.items.sku.string());
   ```

   **B. Search Indexes (for full-text)**
   - Full-text search across JSON fields
   - Structural and text queries
   - Automatic field detection
   ```sql
   CREATE SEARCH INDEX idx_product_search ON products (data)
   FOR JSON;
   ```

   **C. Function-Based Indexes**
   - Index specific JSON paths
   - Type-specific extraction
   ```sql
   CREATE INDEX idx_product_price
   ON products (JSON_VALUE(data, '$.price' RETURNING NUMBER));
   ```

   **D. Composite Indexes**
   - Multiple JSON fields
   - Support complex query patterns
   ```sql
   CREATE INDEX idx_product_category_price
   ON products (
     JSON_VALUE(data, '$.category' RETURNING VARCHAR2(100)),
     JSON_VALUE(data, '$.price' RETURNING NUMBER)
   );
   ```

   **E. Partial Indexes (23ai)**
   - Index subset of documents
   - Reduce index size
   ```sql
   CREATE INDEX idx_expensive_products
   ON products (JSON_VALUE(data, '$.name' RETURNING VARCHAR2(200)))
   WHERE JSON_VALUE(data, '$.price' RETURNING NUMBER) > 1000;
   ```

   **F. Subsetting Indexes (23ai)**
   - Index specific nested structures
   - Optimize deep path queries

2. **Index Selection Strategy:**
   - Analyze query patterns
   - Identify frequently filtered fields
   - Consider cardinality
   - Balance index count vs. query performance

3. **Practical Exercises:**
   - Create indexes for e-commerce queries
   - Compare query plans with/without indexes
   - Measure index creation time
   - Test index effectiveness

**Use Cases & Queries:**
- **E-commerce:**
  - Find products by tag (multivalue)
  - Search product descriptions (search index)
  - Filter by category and price (composite)
  - Find premium products (partial)

- **Social Media:**
  - Find posts by hashtag (multivalue)
  - Search post content (search index)
  - Filter by author and date (composite)

- **IoT:**
  - Find sensors by location (function-based)
  - Search sensor metadata (search index)
  - Filter by sensor type and status (composite)

**Sample Data:**
- 100,000 products with tags, categories, prices
- Variety of query patterns to test

**Performance Scripts:**
- `benchmark_no_indexes.sql` - Baseline performance
- `benchmark_multivalue_index.sql` - Test array indexing
- `benchmark_search_index.sql` - Test full-text search
- `benchmark_composite_index.sql` - Test multi-field queries
- `analyze_execution_plans.sql` - Compare query plans
- `measure_index_overhead.sql` - Test write performance impact

**Index Decision Matrix:**
| Query Pattern | Recommended Index Type |
|--------------|------------------------|
| Array membership (tags, categories) | Multivalue |
| Text search | Search index |
| Single field equality/range | Function-based |
| Multiple field filters | Composite |
| Subset of documents | Partial |
| Deep nested paths | Subsetting |

**Key Findings:**
- Indexes can provide 100-1000x query speedup
- Each index adds ~10-20% write overhead
- Choose indexes based on read:write ratio
- Monitor index usage and remove unused indexes

---

### Lab 8: Performance Testing & Comparison (45 minutes)

**Objectives:**
- Establish performance testing methodology
- Benchmark all learned patterns
- Analyze execution plans
- Make data-driven design decisions
- Document findings

**Content:**
1. **Performance Testing Framework:**

   **A. Metrics to Collect:**
   - Query execution time (average, min, max, p95, p99)
   - Logical reads (buffer gets)
   - Physical reads (disk I/O)
   - CPU time
   - Throughput (operations/second)
   - Storage footprint
   - Index size

   **B. Testing Methodology:**
   - Warm-up runs (prime buffer cache)
   - Multiple iterations (statistical significance)
   - Consistent data volumes
   - Isolated environment (no other workload)
   - Clear cache between pattern tests

   **C. Oracle Performance Tools:**
   - EXPLAIN PLAN analysis
   - DBMS_XPLAN.DISPLAY
   - V$SQL_PLAN and V$SQL views
   - AWR (Automatic Workload Repository) snapshots
   - SQL Monitor reports

2. **Comprehensive Pattern Comparison:**

   **Scenario 1: E-commerce Order Retrieval**
   - Test: Retrieve order with all items
   - Patterns:
     - A: Embedded items (all in one document)
     - B: Referenced items (separate collection)
     - C: Hybrid (summary embedded, details referenced)
   - Workload: 10,000 queries
   - Measure: Response time, I/O

   **Scenario 2: Social Media Feed**
   - Test: Get user posts with engagement metrics
   - Patterns:
     - A: Computed metrics (pre-aggregated)
     - B: On-the-fly aggregation
     - C: Materialized view
   - Workload: 5,000 queries
   - Measure: Response time, CPU

   **Scenario 3: IoT Sensor Queries**
   - Test: Get sensor readings for time range
   - Patterns:
     - A: Individual documents per reading
     - B: Hourly bucketing
     - C: Daily bucketing
   - Workload: 1,000 range queries
   - Measure: Response time, document count

   **Scenario 4: Product Search**
   - Test: Find products by tags and price range
   - Patterns:
     - A: No indexes
     - B: Multivalue index on tags only
     - C: Composite index on tags + price
     - D: Search index
   - Workload: 10,000 queries
   - Measure: Response time, index usage

3. **Analysis and Decision Framework:**

   **Step 1: Define workload characteristics**
   - Read:write ratio
   - Query patterns (point lookup, range, aggregation)
   - Data size and growth rate
   - Latency requirements
   - Consistency requirements

   **Step 2: Match patterns to workload**
   - Use decision matrices from previous labs
   - Consider hybrid approaches
   - Balance trade-offs

   **Step 3: Validate with testing**
   - Test with realistic data volumes
   - Include both common and edge cases
   - Measure under expected load

   **Step 4: Document decisions**
   - Record chosen pattern and rationale
   - Document expected performance
   - Note monitoring strategy

4. **Hands-on Exercise:**
   - Students receive a workload description
   - Design document model
   - Implement and test
   - Compare with alternative designs
   - Present findings

**Sample Workloads for Testing:**
- 100,000 orders (embedded vs referenced)
- 50,000 posts (computed vs aggregated)
- 1,000,000 sensor readings (bucketing)
- 100,000 products (indexing strategies)

**Performance Scripts:**
- `run_all_benchmarks.sql` - Master test suite
- `compare_patterns.sql` - Side-by-side comparison
- `generate_performance_report.sql` - Summary report
- `workload_simulator.sql` - Simulate realistic mixed workload
- `collect_metrics.sql` - Gather all performance metrics

**Deliverables:**
- Performance comparison spreadsheet
- Execution plan analysis
- Pattern recommendation guide
- Personal testing framework

**Sample Results Format:**
| Pattern | Avg Response Time | P95 Time | I/O Reads | CPU Time | Storage |
|---------|-------------------|----------|-----------|----------|---------|
| Embedded | 2ms | 5ms | 10 | 1ms | 100MB |
| Referenced | 8ms | 15ms | 45 | 2ms | 80MB |
| Computed | 1ms | 3ms | 5 | 0.5ms | 105MB |

---

### Lab 9: Advanced Patterns & Best Practices (30 minutes)

**Objectives:**
- Learn additional advanced patterns
- Understand schema versioning strategies
- Implement document validation
- Review production best practices
- Consolidate learning

**Content:**
1. **Additional Design Patterns:**

   **A. Subset Pattern**
   - Store frequently-accessed subset in main document
   - Full data in separate collection
   - Example: User profile with "top friends" embedded
   ```json
   {
     "_id": "user123",
     "name": "John Doe",
     "top_friends": [...], // 10 closest friends
     "total_friends": 5000,
     "all_friends_ref": "user123_friends" // Reference to full list
   }
   ```

   **B. Extended Reference Pattern**
   - Duplicate frequently-accessed fields from referenced documents
   - Reduce joins while avoiding full embedding
   - Example: Order with basic product info
   ```json
   {
     "_id": "order123",
     "items": [
       {
         "product_id": "prod456",
         "product_name": "Widget", // Duplicated for convenience
         "product_price": 29.99,   // Duplicated for convenience
         "quantity": 2
       }
     ]
   }
   ```

   **C. Approximation Pattern**
   - Store approximate values for expensive calculations
   - Periodically update
   - Example: "About 1.2M followers" vs exact count
   - Trade accuracy for performance

   **D. Attribute Pattern**
   - Handle variable attributes
   - Use key-value arrays
   ```json
   {
     "_id": "prod123",
     "name": "Laptop",
     "attributes": [
       {"key": "RAM", "value": "16GB"},
       {"key": "Storage", "value": "512GB SSD"},
       {"key": "Screen", "value": "15.6 inch"}
     ]
   }
   ```

2. **Schema Versioning:**

   **Strategy 1: Schema Version Field**
   ```json
   {
     "_id": "doc123",
     "schema_version": 2,
     "name": "...",
     "new_field": "..." // Added in v2
   }
   ```
   - Application handles multiple versions
   - Migrate on read/write
   - Background migration jobs

   **Strategy 2: Collection-Based Versioning**
   - Separate collections per schema version
   - Clean migration path
   - More storage overhead

   **Strategy 3: Backward-Compatible Changes**
   - Additive changes only
   - Optional fields with defaults
   - Graceful degradation

3. **Document Validation (Oracle 23ai):**
   ```sql
   ALTER TABLE products ADD CONSTRAINT check_product_schema
   CHECK (JSON_EXISTS(data, '$?(@.name && @.price && @.category)'));
   ```
   - Enforce required fields
   - Validate data types
   - Ensure business rules

4. **Production Best Practices:**

   **A. Design:**
   - Model for query patterns, not entities
   - Denormalize for read performance
   - Use appropriate pattern for use case
   - Plan for growth (size and volume)

   **B. Performance:**
   - Index judiciously based on queries
   - Monitor document sizes
   - Use OSON format (JSON type)
   - Leverage in-memory when possible

   **C. Operations:**
   - Version your schemas
   - Validate documents
   - Monitor performance metrics
   - Plan migration strategies

   **D. Security:**
   - Use JSON duality views for fine-grained access
   - Validate input documents
   - Audit sensitive data access
   - Encrypt sensitive fields

5. **Design Checklist:**
   - [ ] Identified primary access patterns
   - [ ] Chosen appropriate modeling pattern(s)
   - [ ] Estimated document sizes
   - [ ] Planned for 32MB limit
   - [ ] Designed indexes for common queries
   - [ ] Considered read:write ratio
   - [ ] Planned schema versioning
   - [ ] Set up monitoring
   - [ ] Documented design decisions

6. **Workshop Recap:**
   - Review all patterns learned
   - Pattern selection flowchart
   - Common pitfalls and solutions
   - Additional resources
   - Next steps

**Sample Data:**
- Examples of each advanced pattern
- Schema evolution examples

**Scripts:**
- `implement_subset_pattern.sql`
- `implement_extended_reference.sql`
- `schema_validation_examples.sql`
- `migration_strategies.sql`

**Final Deliverables:**
- Complete pattern reference guide
- Personal design checklist
- Performance testing templates
- Certificate of completion

---

## Sample Datasets Specification

### 1. E-commerce Dataset
- **Products:** 100,000
  - Categories: Electronics, Books, Clothing, Home, Sports (20K each)
  - Fields: id, name, description, price, tags[], images[], reviews[]
  - Size distribution: 2KB - 50KB per product

- **Customers:** 50,000
  - Fields: id, name, email, addresses[], orderHistory[], preferences
  - Size: ~5KB average

- **Orders:** 200,000
  - Date range: Last 2 years
  - Fields: id, customerId, orderDate, items[], shipping, payment, status
  - Embedded version: 5-50KB
  - Referenced version: 2KB + separate items

- **Reviews:** 500,000
  - Fields: id, productId, customerId, rating, text, helpful_count, date
  - Size: 500 bytes - 5KB

### 2. IoT Sensor Dataset
- **Sensors:** 1,000
  - Types: Temperature, Humidity, Pressure, Motion
  - Fields: id, type, location, metadata, status

- **Readings:** 10,000,000
  - Frequency: 1 per second per sensor over 3 months
  - Fields: timestamp, value, quality, anomaly
  - Individual: ~200 bytes each
  - Bucketed (hourly): ~720KB per bucket
  - Bucketed (daily): ~17MB per bucket

### 3. Social Media Dataset
- **Users:** 100,000
  - Fields: id, username, profile, followers[], following[], stats
  - Size: 2-10KB

- **Posts:** 1,000,000
  - Fields: id, userId, content, media[], hashtags[], mentions[]
  - Size: 1-20KB

- **Interactions:** 10,000,000
  - Likes, comments, shares
  - Embedded in posts OR separate collection
  - With computed: +500 bytes per post

### 4. Financial Dataset
- **Accounts:** 50,000
  - Fields: id, accountNumber, type, balance, owner, metadata
  - Size: 1-3KB

- **Transactions:** 5,000,000
  - Types: Deposit, Withdrawal, Transfer, Payment (polymorphic)
  - Fields: Common (id, timestamp, amount, account) + type-specific
  - Size: 300 bytes - 2KB
  - Date range: Last year

---

## Performance Testing Scripts Architecture

### Script Categories

**1. Setup Scripts (`/scripts/setup/`)**
- `create_collections.sql` - Create all collections
- `load_sample_data.sql` - Load datasets
- `create_monitoring_views.sql` - Set up performance views
- `initialize_performance_schema.sql` - Create metrics tables

**2. Pattern Implementation Scripts (`/scripts/patterns/`)**
- `embedded_pattern.sql` - Embedded examples
- `referenced_pattern.sql` - Referenced examples
- `computed_pattern.sql` - Computed field examples
- `bucketing_pattern.sql` - Time-series bucketing
- `polymorphic_pattern.sql` - Multi-type documents

**3. Indexing Scripts (`/scripts/indexing/`)**
- `create_multivalue_indexes.sql`
- `create_search_indexes.sql`
- `create_composite_indexes.sql`
- `create_partial_indexes.sql`

**4. Benchmark Scripts (`/scripts/benchmarks/`)**
- `benchmark_embedded_vs_referenced.sql`
- `benchmark_computed_pattern.sql`
- `benchmark_bucketing.sql`
- `benchmark_indexing.sql`
- `benchmark_document_sizes.sql`

**5. Analysis Scripts (`/scripts/analysis/`)**
- `execution_plan_analysis.sql`
- `collect_metrics.sql`
- `generate_reports.sql`
- `compare_results.sql`

**6. Utility Scripts (`/scripts/utilities/`)**
- `clear_cache.sql` - Flush buffer cache for testing
- `generate_test_data.sql` - Create synthetic data
- `measure_document_size.sql` - Calculate sizes
- `find_large_documents.sql` - Identify large docs

### Performance Metrics Collection Framework

**Metrics Table:**
```sql
CREATE TABLE performance_metrics (
  test_id VARCHAR2(100),
  pattern_name VARCHAR2(50),
  operation VARCHAR2(50),
  iteration NUMBER,
  execution_time_ms NUMBER,
  logical_reads NUMBER,
  physical_reads NUMBER,
  cpu_time_ms NUMBER,
  rows_processed NUMBER,
  timestamp TIMESTAMP DEFAULT SYSTIMESTAMP
);
```

**Standard Test Template:**
```sql
-- Clear cache
ALTER SYSTEM FLUSH BUFFER_CACHE;

-- Warm-up
FOR i IN 1..10 LOOP
  -- Execute query
END LOOP;

-- Actual test
DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_iterations CONSTANT NUMBER := 1000;
BEGIN
  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;

    -- Execute query

    v_end := SYSTIMESTAMP;

    INSERT INTO performance_metrics VALUES (
      'TEST_ID',
      'PATTERN_NAME',
      'OPERATION',
      i,
      EXTRACT(SECOND FROM (v_end - v_start)) * 1000,
      ... -- other metrics
    );
  END LOOP;
  COMMIT;
END;
/

-- Analyze results
SELECT
  pattern_name,
  AVG(execution_time_ms) as avg_time,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_time_ms) as p95_time,
  MIN(execution_time_ms) as min_time,
  MAX(execution_time_ms) as max_time
FROM performance_metrics
WHERE test_id = 'TEST_ID'
GROUP BY pattern_name;
```

---

## Workshop Materials Checklist

### Documentation
- [ ] Introduction presentation slides
- [ ] Lab markdown files (0-9)
- [ ] Pattern reference guide (PDF)
- [ ] Performance comparison report template
- [ ] Design decision flowcharts
- [ ] Troubleshooting guide

### Scripts and Code
- [ ] 60+ SQL scripts across all categories
- [ ] Data generation scripts
- [ ] Sample JSON documents
- [ ] MongoDB API examples
- [ ] REST API examples

### Sample Data
- [ ] E-commerce dataset (SQL scripts + JSON files)
- [ ] IoT sensor dataset
- [ ] Social media dataset
- [ ] Financial dataset
- [ ] Data loading scripts

### Supplementary Materials
- [ ] Oracle JSON Collections quick reference
- [ ] OSON format deep-dive document
- [ ] Index selection decision matrix
- [ ] Performance tuning cheat sheet
- [ ] Additional resources and links

---

## Workshop Manifest Structure

```json
{
  "workshoptitle": "Oracle JSON Collections: Document Data Modeling for Performance",
  "help": "livelabs-help-db_us@oracle.com",
  "variables": ["../variables/variables.json"],
  "tutorials": [
    {
      "title": "Introduction",
      "filename": "../introduction/introduction.md"
    },
    {
      "title": "Lab 0: Setup Your Environment",
      "filename": "../labs/00-setup/setup.md"
    },
    {
      "title": "Lab 1: JSON Collections Fundamentals",
      "filename": "../labs/01-fundamentals/fundamentals.md"
    },
    {
      "title": "Lab 2: Embedded vs. Referenced Patterns",
      "filename": "../labs/02-embedded-referenced/embedded-referenced.md"
    },
    {
      "title": "Lab 3: Computed Pattern & Aggregations",
      "filename": "../labs/03-computed/computed.md"
    },
    {
      "title": "Lab 4: Bucketing Pattern for Time-Series",
      "filename": "../labs/04-bucketing/bucketing.md"
    },
    {
      "title": "Lab 5: Polymorphic Pattern",
      "filename": "../labs/05-polymorphic/polymorphic.md"
    },
    {
      "title": "Lab 6: Avoiding LOB Performance Cliffs",
      "filename": "../labs/06-lob-performance/lob-performance.md"
    },
    {
      "title": "Lab 7: Indexing Strategies",
      "filename": "../labs/07-indexing/indexing.md"
    },
    {
      "title": "Lab 8: Performance Testing & Comparison",
      "filename": "../labs/08-performance-testing/performance-testing.md"
    },
    {
      "title": "Lab 9: Advanced Patterns & Best Practices",
      "filename": "../labs/09-advanced/advanced.md"
    },
    {
      "title": "Need Help?",
      "filename": "https://oracle-livelabs.github.io/common/labs/need-help/need-help-freetier.md"
    }
  ]
}
```

### Multiple Deployment Paths

**Tenancy manifest** (`workshops/tenancy/manifest.json`):
- For users with their own Oracle Cloud accounts
- Includes ADB provisioning lab

**Desktop manifest** (`workshops/desktop/manifest.json`):
- For noVNC environment with pre-installed Oracle 23ai
- Skips provisioning, goes straight to JSON Collections

---

## Success Metrics

**Learning Outcomes:**
- 90%+ students can identify appropriate pattern for given use case
- 80%+ students can implement at least 4 different patterns
- 75%+ students can create appropriate indexes
- 85%+ students understand OSON limits and mitigation

**Performance:**
- Students can demonstrate 10x+ query improvement with indexing
- Students can demonstrate 5x+ improvement with pattern optimization
- Students can identify and fix LOB performance issues

**Engagement:**
- Completion rate target: 70%+
- Satisfaction rating target: 4.5/5
- Would recommend: 85%+

---

## Next Steps for Implementation

1. **Phase 1: Core Content (Weeks 1-2)**
   - Write lab markdown files for Labs 0-5
   - Create basic sample datasets
   - Develop fundamental performance scripts

2. **Phase 2: Advanced Content (Weeks 3-4)**
   - Write labs 6-9
   - Complete all performance scripts
   - Generate full sample datasets
   - Create data loading automation

3. **Phase 3: Testing & Refinement (Week 5)**
   - Internal testing of all labs
   - Performance script validation
   - Timing adjustments
   - Bug fixes

4. **Phase 4: Review & Publication (Week 6)**
   - Peer review
   - Council submission
   - Image preparation
   - Final QA
   - Publish to LiveLabs

---

## Open Questions for Review

1. **Data Generation:** Should we provide pre-generated datasets or scripts to generate them? (Recommendation: Both - scripts for learning, pre-generated for speed)

2. **MongoDB API Coverage:** How much emphasis on MongoDB-compatible API vs. SQL? (Recommendation: Primarily SQL with MongoDB examples for multivalue indexes)

3. **JSON Duality Views:** Should we include a section on JSON Relational Duality? (Recommendation: Brief mention in advanced lab, could be separate workshop)

4. **Language-Specific Examples:** Include examples in Python, Node.js, Java? (Recommendation: Keep workshop database-focused, provide links to language-specific resources)

5. **Performance Targets:** Should we provide specific performance targets (e.g., "queries under 10ms") or relative comparisons? (Recommendation: Relative comparisons to avoid hardware dependencies)

6. **Workshop Series:** Split into Beginner/Advanced workshops or keep comprehensive? (Recommendation: Keep comprehensive with clear sections, allow partial completion)

---

## Resources Required

**Database Resources:**
- Autonomous Database Free Tier instances (2 max per account)
- OR Oracle Database 23ai Free container (local installation)
- Estimated storage: 5-10 GB for all sample data

**Development Time Estimate:**
- Content creation: 80-100 hours
- Script development: 60-80 hours
- Data generation: 20-30 hours
- Testing: 40-50 hours
- Review and refinement: 20-30 hours
- **Total: 220-290 hours (approximately 6-8 weeks)**

**Team:**
- Technical writer: 1
- Database SME: 1
- QA tester: 1
- Reviewer: 1-2

---

## Conclusion

This comprehensive workshop will provide developers with practical, hands-on experience in designing high-performance document data models for Oracle JSON Collections. By focusing on real-world use cases, measurable performance comparisons, and Oracle-specific optimizations, students will gain the skills needed to build efficient JSON-based applications.

The workshop balances theoretical understanding with practical implementation, ensuring students can immediately apply what they learn to their own projects.
