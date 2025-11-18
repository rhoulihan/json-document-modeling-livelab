# JSON Document Modeling for Performance

## Introduction

Welcome to the JSON Document Modeling for Performance workshop! This hands-on workshop teaches you how to design high-performance document data models for Oracle JSON Collections using proven NoSQL design patterns.

You will learn the **Single Collection/Table Design pattern** - the most critical NoSQL pattern for achieving 10-20x query performance improvements - along with other essential document modeling techniques. By the end of this workshop, you will be able to design document models that maximize query efficiency, avoid common performance pitfalls, and leverage Oracle's advanced JSON capabilities.

Estimated Time: 3.5 hours (Foundation series - Labs 0-3)

### About This Workshop

This workshop is **Part 1** of a three-part series on JSON document modeling:

- **Part 1: JSON Collections Fundamentals** (This workshop - Labs 0-3, 3.5 hours)
  - Database setup and JSON Collections basics
  - Understanding embedded vs referenced patterns
  - Introduction to Single Collection design

- **Part 2: Single Collection Deep-Dive** (Separate workshop - Lab 3 expanded, 1.5 hours)
  - Comprehensive coverage of the Single Collection/Table pattern
  - Rick Houlihan's access pattern-first design methodology
  - Real-world implementation and performance testing

- **Part 3: Advanced Document Modeling** (Separate workshop - Labs 4-10, 4-4.5 hours)
  - Computed, bucketing, and polymorphic patterns
  - LOB performance cliff avoidance strategies
  - Advanced indexing and optimization techniques

### What You Will Learn

This workshop teaches document modeling based on industry-leading guidance:

- **Rick Houlihan's DynamoDB Single Table Design** (AWS Principal Technologist, 2024)
- **MongoDB Single Collection Pattern** (current best practices)
- **Oracle JSON Collections 23ai/26ai** optimizations

### Objectives

In this workshop, you will:

* **Understand the paradigm shift** from relational (RDBMS) to document (NoSQL) data modeling
* **Learn the Single Collection/Table Design pattern** - the key to avoiding LOB performance cliffs
* **Learn composite key strategies** for hierarchical entity relationships
* **Apply strategic denormalization** to eliminate application-level joins
* **Implement Oracle JSON Collections** with OSON binary format optimization
* **Use multivalue indexes** to query array values efficiently
* **Measure and compare** performance of different modeling approaches
* **Deploy and configure** Oracle Database 23ai Free or Autonomous Database Free Tier
* **Write optimized queries** using both SQL and MongoDB-compatible API

### Prerequisites

This workshop assumes you have:

* Basic understanding of database concepts (tables, queries, indexes)
* Familiarity with JSON format (objects, arrays, key-value pairs)
* An Oracle Cloud account (Free Tier available)
* Basic SQL knowledge (SELECT, INSERT, UPDATE)
* A web browser and internet connection

**No prior NoSQL or document database experience required** - we will teach you the fundamentals and best practices from the ground up.

### Workshop Scenarios

Throughout this workshop, you will work with realistic use cases:

**Primary Scenario: E-commerce Platform**
- Customers, orders, products, and reviews
- High-volume transactional queries
- Real-time inventory and order tracking
- Demonstrates Single Collection pattern benefits

**Additional Scenarios (referenced):**
- IoT sensor data with time-series patterns
- Social media posts with embedded comments
- Financial transactions with audit trails

### What Makes This Workshop Different

**1. Performance-First Approach**
- Every pattern includes performance benchmarks
- Side-by-side comparisons with actual execution times
- Learn to measure and optimize your designs

**2. Access Pattern-Driven Design**
- Start with how data is accessed, not how it's structured
- Apply Rick Houlihan's principle: "What is accessed together should be stored together"
- Design for queries, not entities

**3. Real-World Focus**
- Production-ready patterns and anti-patterns
- Actual performance numbers and metrics
- Industry-proven techniques from AWS and MongoDB communities

**4. Oracle-Specific Optimizations**
- OSON binary format and performance tiers
- Multivalue indexes for array queries
- JSON Duality Views (introduced in Lab 10)
- Oracle Database 23ai/26ai features

### Key Performance Results You Will Achieve

By applying the patterns in this workshop, you will see:

- **10-20x faster queries** with Single Collection vs multiple collections
- **Sub-5ms query latency** for well-designed access patterns
- **50-70% storage reduction** with strategic denormalization
- **Elimination of application-level joins** for related data
- **Predictable performance** at scale

### Workshop Architecture

```
RDBMS Normalized Approach          Single Collection Document Approach
(40-60ms typical query)            (2-5ms typical query)

┌─────────────┐                    ┌─────────────────────────────┐
│  Customers  │                    │   ecommerce_data            │
├─────────────┤                    │                             │
│ customer_id │◄───┐               │  {                          │
│ name        │    │               │    "_id": "CUSTOMER#456#    │
│ email       │    │               │            ORDER#001",      │
└─────────────┘    │               │    "type": "order",         │
                   │               │    "customer_name": "...",  │
┌─────────────┐    │               │    "items": [...],          │
│   Orders    │    │               │    "total": 125.50          │
├─────────────┤    │               │  }                          │
│ order_id    │────┘               │                             │
│ customer_id │────┐               └─────────────────────────────┘
│ total       │    │
└─────────────┘    │               Single query retrieves
                   │               complete order with
┌─────────────┐    │               customer info
│ Order Items │    │
├─────────────┤    │               No joins needed
│ item_id     │────┘               10-20x faster
│ order_id    │
│ product_id  │
│ quantity    │
└─────────────┘

Requires 3 queries + joins
Application-level assembly
```

### Technology Stack

This workshop uses:

- **Oracle Database 23ai Free** or **Autonomous Database Free Tier**
- **Oracle JSON Collections** with OSON binary format
- **SQL/JSON functions** for querying JSON documents
- **MongoDB-compatible API** (Oracle Database API for MongoDB)
- **SQL Developer Web** or **Database Actions** for SQL execution
- **Python, Node.js, Java** code examples (optional)

### Workshop Flow

**Lab 0: Setup (30 minutes)**
- Provision Oracle Database (23ai Free or Autonomous Database Free Tier)
- Configure JSON Collections
- Load sample data
- Verify environment

**Lab 1: JSON Collections Fundamentals (30 minutes)**
- Create JSON collections
- Insert, query, and update documents
- Understand OSON binary format
- Compare SQL and MongoDB API syntax

**Lab 2: Embedded vs Referenced Patterns (45 minutes)**
- Design embedded documents for related data
- Implement referenced documents with foreign keys
- Compare performance and use cases
- Understand when to use each pattern

**Lab 3: Single Collection/Table Design (60 minutes)** ⭐ **CRITICAL**
- Learn the paradigm shift from RDBMS to NoSQL
- Implement composite keys for entity relationships
- Apply strategic denormalization
- Avoid LOB performance cliffs
- Measure 10-20x performance improvements
- Learn Rick Houlihan's access pattern-first methodology

### What You Will Build

By the end of this workshop, you will have:

1. **Working Oracle Database** with JSON Collections configured
2. **E-commerce data model** with 10,000+ documents
3. **Performance comparison scripts** demonstrating pattern efficiency
4. **Single Collection implementation** following Rick Houlihan's principles
5. **Benchmark results** showing 10-20x query improvements
6. **Production-ready patterns** you can apply to your own projects

### Why Document Modeling Matters

**Traditional RDBMS Approach:**
- Normalize data into multiple tables
- Join tables at query time
- Optimize for storage efficiency
- Pay performance cost for joins

**Modern Document Approach:**
- Denormalize data accessed together
- Store related data in single document
- Optimize for query efficiency
- Pay storage cost for duplication (cheap)

**The Key Insight:**
> "In the cloud era, storage is cheap but compute is expensive. Design for query performance, not storage minimization."
> - Rick Houlihan, AWS Principal Technologist

### Oracle JSON Collections Advantages

Oracle JSON Collections combine the best of both worlds:

- **Native JSON support** with SQL/JSON query capabilities
- **ACID transactions** unlike most NoSQL databases
- **OSON binary format** for optimal storage and performance
- **Multivalue indexes** for efficient array queries
- **JSON Duality Views** to bridge relational and document models
- **MongoDB compatibility** for easy migration
- **Enterprise features** (backup, security, high availability)

### Get Help

If you need assistance during this workshop:

- **In-lab help sections** provide troubleshooting guidance
- **Learn More links** offer deeper technical resources
- **Oracle documentation** for comprehensive reference
- **LiveLabs support** for technical issues

### Workshop Team

This workshop was developed by Oracle Database experts in collaboration with the NoSQL community, incorporating guidance from:

- Rick Houlihan (AWS - DynamoDB Single Table Design)
- MongoDB Building with Patterns team
- Oracle JSON development team
- Oracle LiveLabs content team

## Learn More

* [Oracle JSON Collections Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/json-collections.html)
* [Oracle Database 23ai JSON Features](https://docs.oracle.com/en/database/oracle/oracle-database/23/newft/)
* [Rick Houlihan's DynamoDB Talks](https://www.youtube.com/results?search_query=rick+houlihan+dynamodb)
* [MongoDB Building with Patterns](https://www.mongodb.com/blog/post/building-with-patterns-a-summary)
* [Oracle Database API for MongoDB](https://docs.oracle.com/en/database/oracle/mongodb-api/)

## Acknowledgements

* **Author** - Rick Houlihan, Solution Architect
* **Contributors** - Oracle JSON Development Team, Oracle LiveLabs Team
* **Last Updated By/Date** - Rick Houlihan, November 2024
