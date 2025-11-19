# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the **json-document-modeling-livelab** repository, which contains a comprehensive Oracle LiveLabs workshop focused on **Document Data Modeling for Performance** in Oracle JSON Collections, with critical emphasis on the **Single Collection/Table Design pattern**.

**Repository:** https://github.com/rhoulihan/json-document-modeling-livelab

### Workshop Focus

This workshop teaches developers how to:
- Design optimal document data models for Oracle JSON Collections
- Apply the **Single Collection/Table Design pattern** (the most critical NoSQL pattern)
- Implement access pattern-first design methodology
- Use composite keys for hierarchical relationships
- Apply strategic denormalization to eliminate application joins
- Avoid LOB performance cliffs (Oracle's 32MB OSON limit)
- Achieve 10-20x query performance improvements

### Based on Industry-Leading Guidance

- **Rick Houlihan's DynamoDB Single Table Design** (AWS, 2024)
- **MongoDB Single Collection Pattern** (current best practices)
- **Oracle JSON Collections 23ai/26ai** optimizations

---

## Workshop Structure

### Three-Part Workshop Series

**Workshop 1: JSON Collections Fundamentals** (2 hours)
- Lab 0: Setup
- Lab 1: JSON Collections Fundamentals
- Lab 2: Embedded vs Referenced Patterns

**Workshop 2: Single Collection Design Pattern** (1.5 hours) ⭐ **FLAGSHIP**
- Lab 3: Single Collection/Table Design (expanded, comprehensive)

**Workshop 3: Advanced Document Modeling** (4-4.5 hours)
- Lab 4: Computed Pattern & Aggregations
- Lab 5: Bucketing Pattern for Time-Series
- Lab 6: Polymorphic Pattern
- Lab 7: Avoiding LOB Performance Cliffs
- Lab 8: Indexing Strategies
- Lab 9: Performance Testing & Comparison
- Lab 10: Advanced Patterns & Best Practices

### Target Audiences

- **Mixed audience:** Beginners to both Oracle and NoSQL/document databases
- **Oracle DBAs/developers** learning NoSQL and JSON Collections
- **NoSQL developers** (MongoDB, DynamoDB) learning Oracle
- **Performance-focused developers** optimizing JSON workloads

---

## Repository Architecture

### Planning Documents (Current Phase)

Located in root directory:

**Primary Planning Documents:**
1. **README.md** - Main overview with Single Collection focus
2. **SINGLE_COLLECTION_PATTERN.md** - 25-page comprehensive guide to the pattern
3. **WORKSHOP_PLAN_UPDATED.md** - Complete workshop plan with all 11 labs
4. **DELIVERY_SUMMARY.md** - Delivery package summary
5. **IMPLEMENTATION_CHECKLIST.md** - Task tracking for development

**Reference Documents:**
- `PATTERN_REFERENCE.md` - Quick reference for all patterns
- `WORKSHOP_PLAN.md` - Original plan (archived)
- `README_ORIGINAL.md` - Original README (archived)

### Directory Structure

```
json-document-modeling-livelab/
├── CLAUDE.md                           # This file
├── README.md                           # Main overview
├── SINGLE_COLLECTION_PATTERN.md        # Core pattern guide
├── WORKSHOP_PLAN_UPDATED.md            # Complete workshop plan
├── DELIVERY_SUMMARY.md                 # Delivery summary
├── IMPLEMENTATION_CHECKLIST.md         # Task tracker
├── PATTERN_REFERENCE.md                # Pattern quick reference
│
├── LICENSE.txt                         # Oracle UPL
├── CONTRIBUTING.md                     # Contribution guidelines
├── SECURITY.md                         # Security policy
│
├── introduction/                       # Workshop introduction (to be created)
│   └── introduction.md
│
├── labs/                               # Lab content (to be created)
│   ├── 00-setup/                      # Database provisioning
│   ├── 01-fundamentals/               # JSON Collections basics
│   ├── 02-embedded-referenced/        # Embedded vs Referenced
│   ├── 03-single-collection/          # ⭐ CRITICAL: Single Collection pattern
│   ├── 04-computed/                   # Computed pattern
│   ├── 05-bucketing/                  # Time-series bucketing
│   ├── 06-polymorphic/                # Polymorphic documents
│   ├── 07-lob-performance/            # LOB cliff avoidance
│   ├── 08-indexing/                   # Indexing strategies
│   ├── 09-performance-testing/        # Benchmarking
│   └── 10-advanced/                   # Advanced patterns
│
├── workshops/                          # Workshop manifests (to be created)
│   ├── tenancy/                       # For user's Oracle Cloud account
│   │   └── manifest.json
│   └── desktop/                       # For noVNC environments
│       └── manifest.json
│
├── data/                               # Sample datasets (to be created)
│   ├── ecommerce/                     # E-commerce dataset
│   ├── iot/                           # IoT sensor dataset
│   ├── social/                        # Social media dataset
│   └── financial/                     # Financial transactions dataset
│
├── scripts/                            # Performance testing scripts (to be created)
│   ├── setup/                         # Database setup scripts
│   ├── patterns/                      # Pattern implementation examples
│   ├── single-collection/             # Single Collection scripts
│   ├── benchmarks/                    # Performance benchmarks
│   ├── indexing/                      # Index creation scripts
│   ├── analysis/                      # Execution plan analysis
│   └── utilities/                     # Helper scripts
│
├── images/                             # Screenshots and diagrams
│   ├── livelabs-banner-formarketplace.png
│   └── [lab-specific images]
│
├── templates/                          # LiveLabs templates from common
│   ├── README.md                      # Template usage guide
│   ├── sample-lab/                    # Lab templates
│   └── sample-workshop/               # Workshop manifest templates
│
└── lintchecker/                        # Vale content quality tools
    ├── .vale.ini                      # Vale configuration
    ├── README.md                      # Linting guide
    └── styles/                        # Oracle, Microsoft, Google styles
```

---

## Development Workflow

### Phase 1: Foundation Labs (Current - Weeks 1-2.5)

**Focus:** Build the foundation and the critical Single Collection lab

**Labs to Create:**
1. Lab 0: Setup (30 min)
2. Lab 1: Fundamentals (30 min)
3. Lab 2: Embedded vs Referenced (45 min)
4. **Lab 3: Single Collection/Table Design (60 min)** ⭐ CRITICAL

**Deliverable:** Labs 0-3 complete, tested, and validated

### Lab Creation Process

**Step 1: Copy Template**
```bash
# Copy sample lab template
cp -r templates/sample-lab/sample-lab labs/03-single-collection
cd labs/03-single-collection

# Rename markdown file
mv query.md single-collection.md
```

**Step 2: Create Lab Content**

Follow structure in `WORKSHOP_PLAN_UPDATED.md` for the specific lab. Each lab should include:

```markdown
# Lab Title

## Introduction

Brief description and estimated time.

### Objectives

* Objective 1
* Objective 2

### Prerequisites

* Previous labs completed
* Basic knowledge required

## Task 1: Task Name

1. Step 1
   - Substep

   ```sql
   -- SQL code example
   ```

2. Step 2

   ![Description](./images/screenshot.png " ")

## Task 2: Another Task

## Learn More

* [Link](url)

## Acknowledgements

* **Author** - Your Name, Title, Company
* **Last Updated By/Date** - Your Name, Month Year
```

**Step 3: Create Supporting Materials**

- Add images to `labs/XX-lab-name/images/`
- Create SQL scripts in `scripts/`
- Generate sample data for `data/`

**Step 4: Lint Content**
```bash
# Run Vale linter
cd lintchecker
vale ../labs/03-single-collection/single-collection.md
```

**Step 5: Test Lab**
- Execute all SQL commands
- Verify all scripts work
- Test on both ADB Free and 23ai Free
- Validate performance benchmarks

---

## Key Patterns and Concepts

### 1. Single Collection/Table Design (Most Important)

**Core Principle (Rick Houlihan):**
> "What is accessed together should be stored together, and how that data is stored should be influenced by how it is accessed."

**Key Concepts:**
- **Access pattern-first design** (not entity-first)
- **Composite keys** for entity relationships (`CUSTOMER#456#ORDER#001`)
- **Strategic denormalization** (duplicate what's accessed together)
- **Avoiding LOB cliffs** (keep documents < 100KB target)
- **10-20x performance improvement** over normalized approach

**Example:**
```json
// Single collection with composite keys
{
  "_id": "CUSTOMER#456#ORDER#ORD-001",
  "type": "order",
  "customer_id": "CUSTOMER#456",
  "customer_name": "John Doe",       // Denormalized
  "customer_email": "john@...",       // Denormalized
  "items": [
    {
      "product_id": "PROD-789",
      "name": "Blue Widget",          // Denormalized
      "price": 29.99,                 // Frozen at order time
      "quantity": 2
    }
  ],
  "total": 125.50
}
```

### 2. Supporting Patterns

- **Embedded:** Data accessed together in same document
- **Referenced:** Separate documents with references
- **Computed:** Pre-calculated aggregations
- **Bucketing:** Time-series data grouped by time intervals
- **Polymorphic:** Multiple document types with discriminator
- **Subset:** Frequently vs rarely accessed data separation
- **Extended Reference:** Denormalize key fields only

### 3. Oracle-Specific Features

- **OSON format:** Binary JSON with 32MB limit
- **Performance tiers:** Inline (< 7,950 bytes), LOB (up to 32MB)
- **Multivalue indexes:** Index array values directly
- **Search indexes:** Full-text + structural queries
- **Partial indexes (23ai):** Index document subsets
- **JSON Duality Views:** Bridge relational and document models

---

## Content Development Guidelines

### Markdown Standards

**File Naming:**
- All lowercase: `single-collection.md`
- Directories match: `03-single-collection/`
- No spaces: use hyphens

**Lab Structure (Required):**
```markdown
# Title (H1)

## Introduction (H2)
Estimated Time: X minutes

### Objectives (H3)
### Prerequisites (H3)

## Task 1: Name (H2)
## Task 2: Name (H2)

## Learn More (H2)
## Acknowledgements (H2)
```

**Images:**
- Include alt text: `![Description](./images/file.png " ")`
- **MUST blur:** IP addresses, emails, OCIDs, passwords, usernames
- Store in lab's `images/` folder
- Use descriptive filenames: `composite-key-query-example.png`

**Code Examples:**
```markdown
```sql
-- Always include comments explaining what the code does
SELECT JSON_QUERY(data, '$')
FROM ecommerce_data
WHERE JSON_VALUE(data, '$._id') = 'CUSTOMER#456#ORDER#ORD-001';
```
```

**Performance Benchmarks:**
- Include before/after metrics
- Document test environment (ADB Free or 23ai Free)
- Show actual execution times
- Compare different approaches

### SQL Script Standards

**Script Header:**
```sql
-- Script: benchmark_single_vs_multi_collection.sql
-- Purpose: Compare query performance: Single Collection vs Multiple Collections
-- Author: [Name]
-- Date: [Date]
--
-- Prerequisites:
-- - Collections created (ecommerce_data OR customers/orders/items)
-- - Sample data loaded (10,000 customers, 100,000 orders)
--
-- Expected Results:
-- - Single Collection: ~2-5ms average
-- - Multiple Collections: ~40-60ms average
-- - Improvement: 10-20x faster
```

**Script Structure:**
```sql
-- 1. Setup
-- Clear cache, warm-up queries

-- 2. Test Configuration
DEFINE iterations = 1000;

-- 3. Benchmark Single Collection
-- [benchmark code]

-- 4. Benchmark Multiple Collections
-- [benchmark code]

-- 5. Results Analysis
-- [comparison queries]

-- 6. Cleanup (optional)
```

### Sample Data Standards

**Dataset Requirements:**

1. **Realistic:** Based on actual use cases
2. **Varied:** Different document sizes, structures
3. **Scalable:** Scripts to generate different volumes
4. **Documented:** README explaining data structure

**E-commerce Dataset Example:**
```
data/ecommerce/
├── README.md                    # Dataset documentation
├── generate_customers.sql       # Generate 10K customers
├── generate_orders.sql          # Generate 100K orders
├── generate_products.sql        # Generate 100K products
├── customers_sample.json        # Sample documents (100 records)
└── load_all_data.sql           # Master load script
```

---

## Performance Testing Framework

### Metrics to Collect

For each pattern comparison:

1. **Query Latency**
   - Average execution time
   - P95, P99 percentiles
   - Min/Max times

2. **Resource Usage**
   - Logical reads (buffer gets)
   - Physical reads (disk I/O)
   - CPU time

3. **Scalability**
   - Throughput (queries/second)
   - Performance at different data volumes

4. **Storage**
   - Document sizes
   - Collection sizes
   - Index sizes

### Standard Test Template

```sql
-- Create metrics table
CREATE TABLE performance_metrics (
  test_id VARCHAR2(100),
  pattern_name VARCHAR2(50),
  operation VARCHAR2(50),
  iteration NUMBER,
  execution_time_ms NUMBER,
  logical_reads NUMBER,
  physical_reads NUMBER,
  cpu_time_ms NUMBER,
  timestamp TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Benchmark template
DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_iterations CONSTANT NUMBER := 1000;
BEGIN
  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;

    -- Query to test

    v_end := SYSTIMESTAMP;

    INSERT INTO performance_metrics VALUES (
      'TEST_ID', 'PATTERN_NAME', 'OPERATION', i,
      EXTRACT(SECOND FROM (v_end - v_start)) * 1000,
      -- ... other metrics
    );
  END LOOP;
  COMMIT;
END;
/

-- Analyze results
SELECT
  pattern_name,
  AVG(execution_time_ms) as avg_time,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_time_ms) as p95_time
FROM performance_metrics
WHERE test_id = 'TEST_ID'
GROUP BY pattern_name;
```

---

## Common Labs Reference

Reference common labs from oracle-livelabs/common via absolute URLs:

```json
{
  "title": "Get Started",
  "filename": "https://oracle-livelabs.github.io/common/labs/cloud-login/cloud-login.md"
},
{
  "title": "Need Help?",
  "filename": "https://oracle-livelabs.github.io/common/labs/need-help/need-help-freetier.md"
}
```

**Available Common Labs:**
- `labs/cloud-login/` - Oracle Cloud login
- `labs/generate-ssh-key/` - SSH key generation
- `labs/need-help/` - Help/FAQ
- `labs/setup-compute/` - Compute setup
- `labs/mongodb/` - MongoDB installation

---

## Language Examples (Required)

Per workshop decisions, include comprehensive language coverage:

### SQL (Primary)
```sql
-- Always primary, full examples
SELECT JSON_QUERY(data, '$')
FROM ecommerce_data
WHERE JSON_VALUE(data, '$._id') = 'CUSTOMER#456';
```

### MongoDB API (Equal Coverage)
```javascript
// MongoDB-compatible API examples
db.ecommerce_data.findOne({ "_id": "CUSTOMER#456" });
```

### Python
```python
import oracledb

conn = oracledb.connect(user="admin", password="...", dsn="...")
cursor = conn.cursor()

cursor.execute("""
    SELECT JSON_QUERY(data, '$')
    FROM ecommerce_data
    WHERE JSON_VALUE(data, '$._id') = :id
""", id='CUSTOMER#456')

result = cursor.fetchone()
```

### Node.js
```javascript
const oracledb = require('oracledb');

const conn = await oracledb.getConnection({
  user: 'admin',
  password: '...',
  connectString: '...'
});

const result = await conn.execute(
  `SELECT JSON_QUERY(data, '$')
   FROM ecommerce_data
   WHERE JSON_VALUE(data, '$._id') = :id`,
  ['CUSTOMER#456']
);
```

### Java
```java
import oracle.jdbc.*;
import oracle.sql.json.*;

Connection conn = DriverManager.getConnection(url, user, pass);
PreparedStatement stmt = conn.prepareStatement(
  "SELECT data FROM ecommerce_data WHERE JSON_VALUE(data, '$._id') = ?"
);
stmt.setString(1, "CUSTOMER#456");
ResultSet rs = stmt.executeQuery();

while (rs.next()) {
  OracleJsonObject json = rs.getObject(1, OracleJsonObject.class);
  // Process JSON
}
```

---

## Quality Assurance

### Vale Linting

**Before committing any markdown:**
```bash
cd lintchecker
vale ../labs/**/*.md
```

**Fix errors, review warnings:**
- ❌ Errors: Must fix
- ⚠️  Warnings: Should review
- ℹ️  Suggestions: Optional

### Testing Checklist

**For each lab:**
- [ ] All SQL commands execute successfully
- [ ] All scripts run without errors
- [ ] Images display correctly and blur sensitive info
- [ ] Links are valid
- [ ] Code examples are tested
- [ ] Performance benchmarks validated
- [ ] Tested on both ADB Free and 23ai Free (if applicable)
- [ ] Vale linting passes
- [ ] Timing estimates accurate

### Pre-Commit Checklist

- [ ] Vale linting clean
- [ ] All images have alt text
- [ ] No sensitive information visible
- [ ] Code snippets tested
- [ ] Acknowledgements updated
- [ ] File names lowercase
- [ ] Git commit signed off

---

## Workshop Submission

When ready to publish:

1. **Submit to WMS** (Workshop Management System - Oracle internal)
2. **Workshop Council review** (3 business days)
3. **QA and testing** with real users
4. **Publication to LiveLabs**

---

## Git Workflow

### Commit Message Standards

```bash
# Use conventional commit format
git commit --signoff -m "feat(lab-3): Add composite key examples

- Add delimiter-based composite key pattern
- Add hierarchical object key pattern
- Include query examples for both approaches
- Add performance comparison script"
```

### Branch Strategy

```bash
# Main branch: stable, tested content
main

# Development branches
git checkout -b lab-03-single-collection
# Work on lab 3
git commit --signoff -m "..."
git push origin lab-03-single-collection
# Create PR to main
```

---

## Key Resources

### Planning Documents (This Repo)
- `SINGLE_COLLECTION_PATTERN.md` - 25-page pattern guide
- `WORKSHOP_PLAN_UPDATED.md` - Complete workshop plan
- `IMPLEMENTATION_CHECKLIST.md` - Task tracking

### Oracle Documentation
- [Oracle JSON Collections](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/json-collections.html)
- [Oracle Database 23ai JSON](https://docs.oracle.com/en/database/oracle/oracle-database/23/newft/)
- [JSON-Relational Duality](https://docs.oracle.com/en/database/oracle/oracle-database/23/jsnvu/)

### LiveLabs Resources
- [LiveLabs Homepage](https://livelabs.oracle.com)
- [Common Repository](https://github.com/oracle-livelabs/common)
- [Markdown Cheat Sheet](https://c4u04.objectstorage.us-ashburn-1.oci.customer-oci.com/p/EcTjWk2IuZPZeNnD_fYMcgUhdNDIDA6rt9gaFj_WZMiL7VvxPBNMY60837hu5hga/n/c4u04/b/livelabsfiles/o/LiveLabs_MD_Cheat_Sheet.pdf)

### Pattern References
- Rick Houlihan's DynamoDB talks (AWS re:Invent)
- MongoDB Building with Patterns series
- NoSQL data modeling resources

---

## Contributing

See `CONTRIBUTING.md` for Oracle Contributor Agreement (OCA) requirements.

**All commits must be signed:**
```bash
git commit --signoff -m "Your commit message"
```

---

**Last Updated:** November 2025
**Repository:** https://github.com/rhoulihan/json-document-modeling-livelab
**Status:** Planning Phase Complete - Ready for Lab Development
