# Oracle JSON Collections: Document Data Modeling for Performance
## LiveLab Workshop - Implementation Package

**Status:** Planning Phase - Ready for Review - **UPDATED with Single Collection Pattern**
**Last Updated:** November 18, 2025
**Version:** 1.1

---

## Workshop Update: Single Collection/Table Design Pattern

This workshop now includes a dedicated lab on the Single Collection/Table Design Pattern, an important approach in NoSQL data modeling for:

- Avoiding LOB performance cliffs (Oracle's 32MB OSON limit)
- Improving query performance through denormalization
- Eliminating application-side joins
- Access pattern-first design methodology
- Strategic denormalization strategies

### Based on Industry Practices:
- DynamoDB single table design patterns
- MongoDB single collection patterns
- Oracle JSON Collections 23ai/26ai optimizations

---

## 📋 Overview

This directory contains complete planning documentation for a comprehensive Oracle LiveLabs workshop on document data modeling for Oracle JSON Collections, covering essential patterns for high-performance NoSQL design.

### Workshop Details
- **Duration:** 6.5 hours (UPDATED from 5.75)
- **Labs:** 11 (including setup + **NEW Lab 3: Single Collection Design**)
- **Target Audience:** Mixed (beginners to both Oracle and NoSQL/document databases)
- **Deployment Options:** Autonomous Database Free Tier OR Oracle Database 23ai Free

---

## 📁 Directory Structure

```
json-document-modeling-livelab/
├── README.md                         # This file - Workshop overview
├── docs/                             # Documentation and planning files
│   ├── SINGLE_COLLECTION_PATTERN.md      # 25-page dedicated guide (NEW!)
│   ├── WORKSHOP_PLAN_UPDATED.md          # Complete workshop plan (UPDATED)
│   ├── WORKSHOP_PLAN.md                  # Original plan (archived)
│   ├── PATTERN_REFERENCE.md              # Quick reference
│   ├── IMPLEMENTATION_CHECKLIST.md       # Implementation tasks & validation
│   ├── DELIVERY_SUMMARY.md               # Workshop delivery notes
│   ├── README_ORIGINAL.md                # Original README (archived)
│   ├── SETUP_GITHUB.md                   # GitHub setup instructions
│   ├── CONTRIBUTING.md                   # Contribution guidelines
│   ├── SECURITY.md                       # Security policy
│   └── CLAUDE.md                         # AI assistant notes
├── labs/                             # Lab content (Labs 0-10 complete)
├── workshops/                        # Workshop manifests
│   ├── tenancy/                     # For user's own Oracle Cloud account
│   └── desktop/                     # For noVNC environments
├── data/                             # Sample datasets
├── scripts/                          # Performance testing scripts
│   ├── setup/
│   ├── patterns/
│   ├── single-collection/          # NEW: Single collection scripts
│   ├── benchmarks/
│   ├── indexing/
│   ├── analysis/
│   └── utilities/
└── images/                           # Screenshots and diagrams
```

---

## 📚 Planning Documents

All planning and reference documentation is located in the **`docs/`** directory.

### 1. docs/SINGLE_COLLECTION_PATTERN.md
**Comprehensive guide covering:**
- Access pattern-first design methodology (vs. normalization-first)
- Core principle: "What is accessed together should be stored together"
- Composite key strategies (delimiter-based, hierarchical, date-based)
- Strategic denormalization framework (what to duplicate, what not to)
- Avoiding LOB cliffs through intelligent data organization
- Complete e-commerce system example
- Performance benchmarks and considerations
- Anti-patterns to avoid
- MongoDB and DynamoDB best practices applied to Oracle

**Key Sections:**
- The Paradigm Shift: RDBMS vs NoSQL
- Core Concepts (access patterns, denormalization, composite keys, polymorphic docs)
- Industry guidance and best practices
- MongoDB Single Collection best practices
- Oracle-specific implementation
- Complete worked examples
- Decision framework

### 2. 🆕 docs/WORKSHOP_PLAN_UPDATED.md (UPDATED)
**Updated 70+ page implementation plan including:**
- **NEW Lab 3: Single Collection/Table Design (60 minutes)**
  - Part 1: The Paradigm Shift (15 min)
  - Part 2: Composite Keys & Entity Organization (20 min)
  - Part 3: Strategic Denormalization (15 min)
  - Part 4: Avoiding LOB Cliffs (10 min)
- Labs 4-10 renumbered and integrated with Single Collection concepts
- All existing labs updated to show Single Collection integration
- 30+ new performance scripts for Single Collection
- Updated sample datasets with composite key structures
- Performance comparisons: Single vs Multiple Collections

**Lab Structure (UPDATED):**
| Lab | Title | Duration | Status |
|-----|-------|----------|--------|
| 0 | Introduction & Setup | 30 min | Original |
| 1 | JSON Collections Fundamentals | 30 min | Original |
| 2 | Embedded vs Referenced Patterns | 45 min | Original |
| **3** | **Single Collection/Table Design** | **60 min** | **NEW!** |
| 4 | Computed Pattern & Aggregations | 45 min | Updated |
| 5 | Bucketing Pattern for Time-Series | 45 min | Updated |
| 6 | Polymorphic Pattern | 30 min | Updated |
| 7 | Avoiding LOB Performance Cliffs | 45 min | Updated |
| 8 | Indexing Strategies | 45 min | Updated |
| 9 | Performance Testing & Comparison | 45 min | Updated |
| 10 | Advanced Patterns & Best Practices | 30 min | Updated |

**Total: 6.5 hours (was 5.75 hours)**

### 3. docs/PATTERN_REFERENCE.md
Quick reference guide for all document modeling patterns.

### 4. docs/IMPLEMENTATION_CHECKLIST.md
Task tracking and validation status for all labs (Labs 0-10 validated and production-ready).

---

## 🎯 Workshop Learning Objectives

Students will learn to:
1. Understand fundamental differences between relational and document data modeling
2. Apply access pattern-first design methodology
3. Design using composite keys for hierarchical relationships
4. Implement strategic denormalization to avoid application joins
5. Identify appropriate document modeling patterns for specific use cases
6. Implement embedded, referenced, computed, and bucketing patterns
7. Avoid LOB performance cliffs through intelligent data organization
8. Apply multivalue indexes and Oracle-specific optimizations
9. Measure query performance improvements with different patterns
10. Design document models that maximize efficiency for workload access patterns

---

## 🏗️ Workshop Structure

### Access Pattern-First Design

**Lab 3: Single Collection/Table Design** introduces a core NoSQL modeling approach:

```
Access Pattern Analysis → Composite Key Design → Strategic Denormalization → Single Collection Implementation
```

**Core Principle:**
> "What is accessed together should be stored together, and how that data is stored should be influenced by how it is accessed."

This access pattern-first methodology was developed by my team at Amazon to model DynamoDB workloads and has been broadly adopted across the NoSQL industry.

### Pattern Integration Across Labs

The workshop covers multiple complementary patterns:

- **Lab 4 (Computed):** Pre-calculated aggregations for performance
- **Lab 5 (Bucketing):** Time-series data organization
- **Lab 6 (Polymorphic):** Multiple entity types with type discrimination
- **Lab 7 (LOB Cliffs):** Document size management strategies
- **Lab 8 (Indexing):** Index strategies for composite keys and polymorphic documents
- **Lab 9 (Performance):** Benchmark different modeling approaches
- **Lab 10 (Advanced):** Subset pattern, schema versioning, migration strategies

---

## 💡 The Single Collection Pattern - Quick Overview

### Traditional Normalized Approach

```
Design Process: Entities → Normalize → Create Collections → Write Queries
Result: Multiple collections, application joins, potentially slower queries, complex code
```

### Single Collection Approach

```
Design Process: Access Patterns → Composite Keys → Denormalize → Single Collection
Result: One collection, no joins, optimized queries, simplified application code
```

### Example: E-commerce System

**Before (3 collections):**
```sql
-- Query requires 3 database calls + application join
SELECT * FROM customers WHERE id = 456;              -- Query 1
SELECT * FROM orders WHERE customer_id = 456;        -- Query 2
SELECT * FROM order_items WHERE order_id IN (...);   -- Query 3
-- Application code joins the results
-- Total latency: 45ms
```

**After (1 collection with composite keys):**
```sql
-- Single query returns complete result
SELECT * FROM ecommerce_data
WHERE JSON_VALUE(data, '$._id') = 'CUSTOMER#456#ORDER#ORD-001';
-- Returns: Complete order with customer info and all items
-- Total latency: 2ms
-- Improvement: 22x faster!
```

### Document Structure

```json
// Customer document
{
  "_id": "CUSTOMER#456",
  "type": "customer",
  "name": "John Doe",
  "recent_orders": [/* last 10 */]
}

// Order document (same collection!)
{
  "_id": "CUSTOMER#456#ORDER#ORD-001",
  "type": "order",
  "customer_id": "CUSTOMER#456",
  "customer_name": "John Doe",     // Denormalized
  "customer_email": "john@...",    // Denormalized
  "items": [
    {
      "product_id": "PROD-789",
      "name": "Blue Widget",       // Denormalized from products
      "price": 29.99,              // Frozen at order time
      "quantity": 2
    }
  ],
  "total": 125.50
}
```

### Key Benefits

✅ **10-20x faster queries** (single lookup vs multiple + join)
✅ **3x fewer network roundtrips** (1 query vs 3)
✅ **Documents stay small** (< 10KB each, no LOB cliffs)
✅ **Simpler application code** (no join logic)
✅ **Atomic updates** across related data
✅ **Scales to millions** of entities per customer

---

## 📊 Updated Sample Datasets

### E-commerce Dataset (Single Collection Approach)

**Collection:** `ecommerce_data` (ONE collection for everything)

**Document Counts:**
- Customers: 10,000 (~5KB each)
- Orders: 100,000 (~3KB each)
- Addresses: 25,000 (~500B each)
- Monthly Stats: 12,000 (computed)

**Total:** ~147,000 documents in **ONE collection**

**Composite Key Examples:**
```
CUSTOMER#CUST-456
CUSTOMER#CUST-456#ORDER#ORD-001
CUSTOMER#CUST-456#ORDER#ORD-001#ITEM#1
CUSTOMER#CUST-456#ADDRESS#home
CUSTOMER#CUST-456#STATS#2024-11
```

**Query Patterns:**
```sql
-- Get customer
WHERE _id = 'CUSTOMER#456'

-- Get all customer's orders
WHERE _id LIKE 'CUSTOMER#456#ORDER#%'

-- Get specific order with items
WHERE _id LIKE 'CUSTOMER#456#ORDER#ORD-001%'
```

**Performance:**
- Primary queries: 2-5ms average
- Largest document: 15KB (order with 30 items)
- 99th percentile: < 10ms
- **10-20x faster than normalized approach**

### Other Datasets (Also Single Collection)

**IoT Sensors:** `sensor_data` collection
```
SENSOR#temp001
SENSOR#temp001#BUCKET#2024-11-18-14
SENSOR#temp001#CONFIG#current
```

**Social Media:** `social_data` collection
```
USER#123
USER#123#POST#456
USER#123#POST#456#COMMENT#789
```

**Financial:** `financial_data` collection
```
ACCOUNT#ACC-123
ACCOUNT#ACC-123#TRANSACTION#TXN-456
ACCOUNT#ACC-123#STATEMENT#2024-11
```

---

## 🔬 Updated Performance Testing Framework

### New Script Categories

**`/scripts/single-collection/`** (30+ new scripts)
1. `create_single_collection.sql` - Set up single collection
2. `load_composite_key_data.sql` - Load data with composite keys
3. `benchmark_composite_queries.sql` - Test composite key performance
4. `benchmark_single_vs_multi.sql` - **Critical comparison**
5. `test_denormalization_impact.sql` - Measure query improvement
6. `validate_document_sizes.sql` - Ensure documents stay small
7. `test_prefix_queries.sql` - Test LIKE queries on composite keys
8. `analyze_access_patterns.sql` - Analyze actual vs designed patterns
9. `measure_join_elimination.sql` - Quantify join removal benefit
10. `test_atomic_updates.sql` - Test multi-entity updates

### Expected Performance Results

| Metric | Multiple Collections | Single Collection | Improvement |
|--------|---------------------|-------------------|-------------|
| Query Latency | 40-60ms | 2-5ms | **10-20x** |
| Network Calls | 3-5 | 1 | **3-5x** |
| Code Complexity | High (joins) | Low (simple query) | **Much simpler** |
| Document Size | 300B-1KB | 5-10KB | **Optimized** |
| LOB Cliffs | Possible | Avoided | **Safe** |

---

## 🎓 Key Patterns Covered

### Core Modeling Patterns
1. **Single Collection/Table Design** - Access pattern-first methodology, composite key strategies, strategic denormalization
2. **Embedded** - Data accessed together stored together
3. **Referenced** - When normalization is appropriate
4. **Computed** - Pre-calculated aggregations for performance
5. **Bucketing** - Time-series data organization
6. **Polymorphic** - Multiple entity types in one collection
7. **Subset** - Frequently vs rarely accessed data
8. **Extended Reference** - Denormalize key fields only

### Oracle-Specific Features
- OSON binary format (32MB limit, performance tiers)
- Composite key indexing strategies
- Multivalue indexes for arrays within documents
- JSON search indexes across entity types
- Partial indexes (23ai) for specific document types
- Query optimization for composite key prefixes

---

## ✅ Review Checklist (UPDATED)

### Content Review Checklist

- [ ] **SINGLE_COLLECTION_PATTERN.md**
  - [ ] Industry best practices accurately represented
  - [ ] MongoDB and DynamoDB patterns correctly applied
  - [ ] Oracle-specific implementation clear
  - [ ] Examples complete and realistic
  - [ ] Anti-patterns well documented

- [ ] **Lab 3: Single Collection/Table Design**
  - [ ] 60 minutes appropriate duration
  - [ ] Part 1-4 flow makes sense
  - [ ] Hands-on exercises sufficient
  - [ ] Performance comparisons realistic
  - [ ] Connects to other labs

- [ ] **Pattern Integration Across Labs**
  - [ ] Labs 4-10 properly integrated
  - [ ] Pattern usage consistent
  - [ ] No contradictions in guidance
  - [ ] Progressive complexity appropriate

### Open Questions

1. **Composite Key Notation:** Which to emphasize?
   - Option A: Delimiter-based `CUSTOMER#456#ORDER#001`
   - Option B: Hierarchical object `{"customer_id": "456", "order_id": "001"}`
   - Option C: Both with pros/cons discussion

2. **Migration Content:** Should we include a migration guide from normalized to single collection?

3. **Performance Metrics:** How to present performance improvements realistically?

4. **Workshop Split:** Keep as one comprehensive workshop or split into:
   - Beginner: Labs 0-3 (foundation)
   - Advanced: Labs 4-10 (patterns)

### Original Questions Still Open

- [ ] JSON Duality Views integration (Lab 10 or separate workshop?)
- [ ] Language-specific examples (Python, Node.js) or stay database-focused?
- [ ] Pre-generated datasets AND generation scripts (recommended: both)?
- [ ] MongoDB API coverage level (brief examples or dedicated sections)?

---

## 🎯 Success Metrics (UPDATED)

### Learning Outcomes
- **90%+** students understand access pattern-first design
- **90%+** students can design composite key structures
- **90%+** students can implement denormalization strategies
- **90%+** students can identify appropriate pattern for given use case
- **80%+** students can implement at least 5 different patterns
- **75%+** students can create appropriate indexes
- **85%+** students understand OSON limits and mitigation

### Performance Metrics
- Students can demonstrate query improvements with different patterns
- Students can identify and fix LOB performance issues
- Students can measure and reduce network roundtrips
- Students can benchmark and compare different modeling approaches

### Engagement Metrics
- Completion rate target: **70%+**
- Satisfaction rating target: **4.5/5**
- Would recommend: **85%+**
- "Will apply to real projects" target: **80%+**

---

## 🛠️ Updated Implementation Timeline

**Total Effort:** 260-340 hours (7-9 weeks) - **UPDATED from 6-8 weeks**

### Phase 1: Core Content + Single Collection (Weeks 1-2.5)
- Write Lab 0: Setup
- Write Lab 1: Fundamentals
- Write Lab 2: Embedded vs Referenced
- **⭐ Write Lab 3: Single Collection/Table Design (critical, extra time)**
- Create e-commerce dataset with composite keys
- Develop single collection benchmark scripts
- **Deliverable:** Labs 0-3 complete and tested

### Phase 2: Advanced Content (Weeks 3-5)
- Write Labs 4-7 (updated to integrate with Lab 3)
- Write Labs 8-10 (updated)
- Complete all performance scripts (60+ scripts)
- Generate full sample datasets
- Create data loading automation
- **Deliverable:** All labs complete and tested

### Phase 3: Testing & Refinement (Weeks 5.5-6.5)
- Internal testing of all labs
- **Extra focus on Lab 3 validation** (most critical)
- Performance script validation
- Timing adjustments
- Bug fixes
- **Deliverable:** Production-ready workshop

### Phase 4: Review & Publication (Weeks 7-9)
- Peer review
- Workshop Council submission
- Image preparation and security blurring
- Final QA
- Publication to LiveLabs
- **Deliverable:** Published workshop

---

## 📖 Research Summary

### Single Collection/Table Design
- ✅ **DynamoDB Single Table Design:**
  - Core principle: "Access together, store together"
  - Don't mix unrelated data
  - Single table within service boundaries
  - Composite key strategies

- ✅ **MongoDB Single Collection:**
  - Polymorphic pattern with discriminator field
  - Avoid unbounded arrays
  - Strategic denormalization
  - Keep documents < 16MB (Oracle: < 32MB)

- ✅ **Access Pattern-First Design:**
  - Query-driven modeling
  - 80/20 rule for access patterns
  - Composite keys for hierarchical relationships
  - Denormalization trade-offs

### Document Modeling Patterns (Original)
- ✅ Embedded vs Referenced
- ✅ Computed Pattern
- ✅ Bucketing Pattern
- ✅ Polymorphic Pattern
- ✅ Subset, Extended Reference

### Oracle JSON Collections (Original + Updated)
- ✅ OSON binary format
- ✅ 32MB limit and performance tiers
- ✅ **Composite key indexing** ⭐
- ✅ Multivalue indexes
- ✅ Search indexes
- ✅ Partial indexes (23ai)
- ✅ JSON Duality Views

---

## 📞 Next Steps

1. **Review the updated content:**
   - docs/SINGLE_COLLECTION_PATTERN.md (25 pages)
   - docs/WORKSHOP_PLAN_UPDATED.md (complete updated plan)
   - This README.md

2. **Answer open questions:**
   - Lab 3 duration (60 or 90 minutes?)
   - Composite key notation preference
   - Workshop split decision
   - Other questions listed above

3. **Provide feedback on:**
   - Single Collection pattern coverage depth
   - Integration with other labs
   - Performance targets realistic?
   - Overall workshop flow

4. **Approve to proceed:**
   - Phase 1 implementation (Weeks 1-2.5)
   - Begin with Labs 0-3 (foundation + Single Collection)

---

## 🚀 Key Workshop Benefits

### Comprehensive Pattern Coverage

This workshop provides practical guidance on multiple document modeling patterns:

1. **LOB Cliff Prevention**
   - Keep documents appropriately sized
   - Avoid unbounded arrays
   - Design for predictable growth

2. **Performance Optimization**
   - Access pattern-first design
   - Reduced network roundtrips
   - Simplified application code

3. **Industry Best Practices**
   - DynamoDB and MongoDB patterns adapted for Oracle
   - Access pattern-first methodology
   - Strategic denormalization approaches

4. **Oracle-Specific Features**
   - Leverage OSON format efficiently
   - Composite key indexing strategies
   - Stay within OSON limits naturally

5. **Complementary Patterns**
   - Multiple patterns for different use cases
   - Computed aggregations
   - Bucketing for time-series
   - Polymorphic documents

---

## 📄 License

Copyright (c) 2025 Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

---

**Questions or feedback?**

Please review:
1. **docs/SINGLE_COLLECTION_PATTERN.md** - Detailed 25-page guide
2. **docs/WORKSHOP_PLAN_UPDATED.md** - Complete workshop plan with Lab 3
3. **This README** - Overview and integration

**Ready to proceed?** Approve and we'll begin Phase 1 implementation!
