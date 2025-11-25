# JSON Document Modeling for Performance
## Oracle LiveLabs Workshop

**Status:** Active Development (95% Complete)
**Last Updated:** November 2025
**Version:** 2.1

---

## 📋 Overview

This Oracle LiveLabs workshop teaches document data modeling for Oracle JSON Collections using proven NoSQL design patterns. Learn how to design high-performance document models that maximize query efficiency and leverage Oracle AI Database 26ai features.

### Workshop Details
- **Duration:** 6.5 hours total (Foundation series: 3.5 hours)
- **Labs:** 11 labs (Lab 0-10)
- **Target Audience:** Database developers new to NoSQL/document modeling
- **Deployment:** Oracle Autonomous AI JSON Database or Oracle AI Database 26ai Free (Docker)
- **Part of:** Three-part workshop series on JSON document modeling

---

## 📁 Directory Structure

```
json-document-modeling-livelab/
├── README.md                         # This file - Workshop overview
├── introduction/                     # Workshop introduction
│   └── introduction.md
├── labs/                             # Lab content (Labs 0-10)
│   ├── 00-setup/
│   ├── 01-json-collections-fundamentals/
│   ├── 02-embedded-referenced/
│   ├── 03-single-collection/        # Single Collection/Table Design pattern
│   ├── 04-computed-pattern/
│   ├── 05-bucketing-pattern/
│   ├── 06-polymorphic-pattern/
│   ├── 07-lob-performance/
│   ├── 08-indexing-strategies/
│   ├── 09-performance-testing/
│   └── 10-advanced-patterns/
├── workshops/                        # Workshop manifests
│   ├── tenancy/                     # For Oracle Cloud tenancies
│   └── desktop/                     # For noVNC environments
├── docs/                             # 📚 Documentation and reference materials
│   ├── README.md                    # ⭐ START HERE - Documentation guide
│   ├── WORKSHOP_PLAN.md             # Complete workshop plan
│   ├── SINGLE_COLLECTION_PATTERN.md # Deep-dive pattern guide
│   ├── PATTERN_REFERENCE.md         # Quick pattern reference
│   ├── IMPLEMENTATION_CHECKLIST.md  # Development progress tracking
│   ├── CLAUDE.md                    # Development guide
│   ├── CONTRIBUTING.md              # Contribution guidelines
│   ├── SECURITY.md                  # Security policy
│   └── archive/                     # Historical documents
│       ├── WORKSHOP_PLAN.md (original)
│       ├── DELIVERY_SUMMARY.md
│       ├── README_ORIGINAL.md
│       └── SETUP_GITHUB.md
├── data/                             # Sample datasets (TBD)
├── scripts/                          # Performance scripts (TBD)
└── images/                           # Screenshots and diagrams
```

**📖 For complete documentation guide:** See [docs/README.md](docs/README.md)

---

## 📚 Workshop Content

### Three-Part Workshop Series

This repository contains **Part 1: JSON Collections Fundamentals** (Labs 0-3, 3.5 hours):

**Part 1: JSON Collections Fundamentals** (This workshop)
- Lab 0: Setup and environment configuration
- Lab 1: JSON Collections basics and OSON format
- Lab 2: Embedded vs Referenced patterns
- Lab 3: Introduction to Single Collection design

**Part 2: Single Collection Deep-Dive** (Separate workshop, 1.5 hours)
- Comprehensive coverage of Single Collection/Table pattern
- Access pattern-first methodology
- Real-world implementation and performance testing

**Part 3: Advanced Document Modeling** (Separate workshop, 4-4.5 hours)
- Lab 4: Computed Pattern & Pre-Aggregations
- Lab 5: Bucketing Pattern for Time-Series
- Lab 6: Polymorphic Pattern
- Lab 7: LOB Performance Optimization
- Lab 8: Indexing Strategies
- Lab 9: Performance Testing
- Lab 10: Advanced Patterns & Best Practices

### Current Lab Status

| Lab | Title | Duration | Status |
|-----|-------|----------|--------|
| 0 | Setup & Configuration | 30 min | ✅ Complete |
| 1 | JSON Collections Fundamentals | 30 min | ✅ Complete |
| 2 | Embedded vs Referenced Patterns | 45 min | ✅ Complete |
| 3 | Single Collection/Table Design | 60 min | ✅ Complete |
| 4 | Computed Pattern & Aggregations | 45 min | ✅ Complete |
| 5 | Bucketing Pattern for Time-Series | 45 min | 🔧 In Development |
| 6 | Polymorphic Pattern | 30 min | ✅ Complete |
| 7 | Avoiding LOB Performance Cliffs | 45 min | ✅ Complete |
| 8 | Indexing Strategies | 45 min | 🔧 In Development |
| 9 | Performance Testing & Comparison | 45 min | 🔧 In Development |
| 10 | Advanced Patterns & Best Practices | 30 min | ✅ Complete |

**Total: 6.5 hours across all labs**

### Documentation

For comprehensive documentation, pattern guides, and development resources:

**👉 See [docs/README.md](docs/README.md) for complete documentation guide**

Key resources:
- **[docs/WORKSHOP_PLAN.md](docs/WORKSHOP_PLAN.md)** - Complete workshop design
- **[docs/SINGLE_COLLECTION_PATTERN.md](docs/SINGLE_COLLECTION_PATTERN.md)** - 25-page pattern deep-dive
- **[docs/PATTERN_REFERENCE.md](docs/PATTERN_REFERENCE.md)** - Quick pattern lookup
- **[docs/IMPLEMENTATION_CHECKLIST.md](docs/IMPLEMENTATION_CHECKLIST.md)** - Development progress

---

## 🎯 What You Will Learn

By completing this workshop series, you will be able to:

1. **Understand document modeling fundamentals**
   - Paradigm shift from relational to document modeling
   - When to use embedded vs referenced patterns
   - Access pattern-first design principles

2. **Apply core modeling patterns**
   - Single Collection/Table Design pattern
   - Embedded and Referenced patterns
   - Computed, Bucketing, and Polymorphic patterns
   - Subset and Extended Reference patterns

3. **Optimize for performance**
   - Avoid LOB performance cliffs (32MB OSON limit)
   - Strategic denormalization to eliminate joins
   - Composite key strategies for hierarchical data
   - Multivalue indexes for array queries

4. **Leverage Oracle-specific features**
   - OSON binary format and performance tiers
   - JSON Collections with SQL/JSON queries
   - Multivalue and search indexes
   - JSON Duality Views (Lab 10)

5. **Measure and compare performance**
   - Benchmark different modeling approaches
   - Identify performance bottlenecks
   - Optimize query patterns

---

## 🔑 Key Concepts

### Document Modeling Patterns

This workshop covers essential patterns for document design:

- **Embedded Pattern** - Store related data together in a single document
- **Referenced Pattern** - Link documents using IDs (like foreign keys)
- **Single Collection Pattern** - Store multiple entity types in one collection using composite keys
- **Computed Pattern** - Pre-calculate aggregations for faster queries
- **Bucketing Pattern** - Group time-series data into manageable chunks
- **Polymorphic Pattern** - Multiple entity types with type discriminator
- **Subset Pattern** - Separate frequently vs rarely accessed data

### Core Principles

**Access Pattern-First Design:**
> "What is accessed together should be stored together"

This approach, developed for DynamoDB and adopted across the NoSQL industry, starts with analyzing how your application queries data before designing the data model.

**Strategic Denormalization:**
- Duplicate data when it's accessed together
- Keep documents under 8KB for optimal OSON performance
- Avoid unbounded arrays that could cause documents to exceed 32MB

**Composite Keys:**
- Use hierarchical keys like `CUSTOMER#456#ORDER#001`
- Enable efficient prefix queries (`WHERE _id LIKE 'CUSTOMER#456#%'`)
- Support multiple entity types in one collection

---

## 🛠️ Oracle-Specific Features

This workshop leverages Oracle AI Database 26ai JSON capabilities:

- **JSON Collection Tables** - Native single-column tables for JSON documents (`CREATE JSON COLLECTION TABLE`)
- **OSON Binary Format** - Optimized storage with 32MB limit and performance tiers
- **SQL/JSON Functions** - Query JSON using standard SQL
- **Multivalue Indexes** - Index array elements for efficient queries
- **Search Indexes** - Full-text search across JSON documents
- **Partial Indexes** - Index specific document types
- **JSON Duality Views** - Bridge relational and document models
- **MongoDB API Compatibility** - Use MongoDB drivers with Oracle (requires ACL configuration)

---

## 🚀 Getting Started

### Prerequisites

- Basic database knowledge (tables, queries, indexes)
- Familiarity with JSON format
- Oracle Cloud account (Free Tier available)
- Basic SQL knowledge

### Quick Start

1. **Access the workshop** - Available on Oracle LiveLabs (link TBD)
2. **Provision database** - Follow Lab 0 to set up Oracle AI Database 26ai Free (Docker) or Autonomous AI JSON Database
3. **Complete labs in sequence** - Start with Lab 0 and progress through Lab 3 (Foundation series)
4. **Refer to pattern guides** - Use [docs/](docs/) for deep-dives and references

### Docker Quick Start (26ai Free)

```bash
# Pull the Oracle AI Database 26ai Free image
docker pull ghcr.io/oracle/adb-free:latest-26ai

# Run the container
docker run -d \
  --name oracle26ai \
  -p 1521:1521 -p 1522:1522 -p 8443:8443 -p 27017:27017 \
  -e WORKLOAD_TYPE=ATP \
  -e WALLET_PASSWORD=WalletPass1234 \
  -e ADMIN_PASSWORD=WelcomeOracle1 \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  ghcr.io/oracle/adb-free:latest-26ai

# Access Database Actions at https://localhost:8443/ords/sql-developer
```

### Resources

- **Workshop Introduction:** [introduction/introduction.md](introduction/introduction.md)
- **Pattern Deep-Dive:** [docs/SINGLE_COLLECTION_PATTERN.md](docs/SINGLE_COLLECTION_PATTERN.md)
- **Complete Documentation:** [docs/README.md](docs/README.md)
- **Development Status:** [docs/IMPLEMENTATION_CHECKLIST.md](docs/IMPLEMENTATION_CHECKLIST.md)

---

## 🤝 Contributing

We welcome contributions! Please see [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

For security vulnerabilities, see [docs/SECURITY.md](docs/SECURITY.md).

---

## 📚 Learn More

### Oracle Documentation
- [Oracle AI Database 26ai](https://www.oracle.com/database/ai-native-database-26ai/)
- [Oracle JSON Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/)
- [JSON Collection Tables](https://oracle-base.com/articles/23/json-collections-23)
- [Oracle Database API for MongoDB](https://docs.oracle.com/en/database/oracle/mongodb-api/)

### Industry Patterns
- [AWS DynamoDB Design Patterns](https://aws.amazon.com/dynamodb/resources/)
- [MongoDB Building with Patterns](https://www.mongodb.com/blog/post/building-with-patterns-a-summary)

---

## 📄 License

Copyright (c) 2025 Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

---

## 👥 Acknowledgements

**Author:** Rick Houlihan
**Contributors:** Oracle JSON Development Team, Oracle LiveLabs Team
**Last Updated:** November 2025

---

**Questions or feedback?** Please open an issue in this repository or contact the workshop team through Oracle LiveLabs support channels.
