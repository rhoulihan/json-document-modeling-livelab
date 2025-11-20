# Documentation Guide

This directory contains comprehensive documentation for the JSON Document Modeling for Performance workshop.

## 📋 Quick Navigation

### For Workshop Development
- **[CLAUDE.md](CLAUDE.md)** - Development guide for AI-assisted workshop development and maintenance
- **[IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md)** - Progress tracking and status of all labs

### For Workshop Planning & Overview
- **[WORKSHOP_PLAN.md](WORKSHOP_PLAN.md)** - Complete workshop design and structure (11 labs, 6.5 hours)

### For Pattern Reference
- **[SINGLE_COLLECTION_PATTERN.md](SINGLE_COLLECTION_PATTERN.md)** - Comprehensive guide to Single Collection/Table Design pattern (25 pages)
- **[PATTERN_REFERENCE.md](PATTERN_REFERENCE.md)** - Quick reference for all document modeling patterns

### For Contributors
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Oracle Contributor Agreement and contribution guidelines
- **[SECURITY.md](SECURITY.md)** - Security vulnerability reporting procedures

## 📚 Document Descriptions

### Development & Operations

#### CLAUDE.md
**Purpose:** Operational guide for AI-assisted development
**Size:** ~60KB (695 lines)
**Audience:** Developers working on workshop content
**Key Contents:**
- Repository structure and workshop overview
- Development workflow and lab creation process
- Performance testing framework
- Quality assurance checklist
- Git workflow and best practices
- Language examples (SQL, MongoDB API, Python, Node.js, Java)

**When to use:** Reference this when creating new labs, updating content, or maintaining the workshop.

---

#### IMPLEMENTATION_CHECKLIST.md
**Purpose:** Tracks development progress and completion status
**Size:** ~26KB (598 lines)
**Audience:** Project managers, developers tracking progress
**Key Contents:**
- Status of all 11 labs (Lab 0-10)
- Phase completion percentages
- Testing and QA status
- Content metrics and performance benchmarks
- Known issues and blockers
- Change log

**When to use:** Check current status, identify what's complete, find blockers or issues.

---

### Planning & Design

#### WORKSHOP_PLAN.md
**Purpose:** Authoritative workshop design and structure
**Size:** ~28KB (897 lines)
**Audience:** Instructors, curriculum designers, developers
**Key Contents:**
- Executive summary and learning objectives
- Complete breakdown of all 11 labs
- Workshop structure (Foundation → Deep-Dive → Advanced)
- Sample datasets specification
- Performance testing architecture
- Success metrics and timeline
- Technical requirements

**When to use:** Understand overall workshop design, lab sequencing, and learning path.

---

### Pattern References

#### SINGLE_COLLECTION_PATTERN.md
**Purpose:** Deep-dive guide on the Single Collection/Table Design pattern
**Size:** ~22KB (884 lines)
**Audience:** Students, instructors, developers implementing the pattern
**Key Contents:**
- Core principles and paradigm shift (RDBMS → NoSQL)
- Access pattern-first design methodology
- Composite key strategies
- DynamoDB Single Table Design adapted for Oracle
- MongoDB Single Collection Pattern guidance
- Oracle-specific optimizations (OSON, indexes)
- Complete e-commerce example with queries
- Anti-patterns and what NOT to do
- Performance benchmarks and decision frameworks

**When to use:**
- Learning the Single Collection pattern in depth
- Designing single collection implementations
- Teaching Lab 3 content
- Reference during pattern implementation

---

#### PATTERN_REFERENCE.md
**Purpose:** Quick lookup guide for all document modeling patterns
**Size:** ~17KB (647 lines)
**Audience:** Students, developers needing quick pattern reference
**Key Contents:**
- Pattern selection flowchart
- 7 core patterns with specifications:
  - Embedded Pattern
  - Referenced Pattern
  - Computed Pattern
  - Bucketing Pattern
  - Polymorphic Pattern
  - Subset Pattern
  - Extended Reference Pattern
- Oracle-specific optimizations
- Performance characteristics
- When to use each pattern
- Anti-patterns to avoid

**When to use:**
- Quick pattern lookup during development
- Choosing the right pattern for a use case
- Teaching Labs 4-10 content
- Reference card for pattern characteristics

---

### Governance

#### CONTRIBUTING.md
**Purpose:** Contribution guidelines and Oracle Contributor Agreement
**Size:** ~1KB (30 lines)
**Audience:** External contributors, open-source collaborators
**Key Contents:**
- Oracle Contributor Agreement (OCA) requirements
- Pull request signing requirements
- Link to OCA details

**When to use:** Before submitting pull requests or contributions.

---

#### SECURITY.md
**Purpose:** Security vulnerability reporting procedures
**Size:** ~1KB (39 lines)
**Audience:** Security researchers, users finding vulnerabilities
**Key Contents:**
- How to report security vulnerabilities
- Oracle security contact information
- Security-related policies

**When to use:** When discovering or reporting security issues.

---

## 📦 Archive

The `archive/` directory contains historical documents that are no longer actively used but preserved for reference:

- **DELIVERY_SUMMARY.md** - Initial delivery summary and approval documentation
- **WORKSHOP_PLAN.md** (original) - Original 10-lab workshop plan before Single Collection pattern integration
- **README_ORIGINAL.md** - Original workshop README before updates
- **SETUP_GITHUB.md** - One-time GitHub repository setup instructions

These documents are kept for historical context but are superseded by current versions.

---

## 🎯 Common Tasks

### I want to...

**...understand what this workshop teaches**
→ Read [WORKSHOP_PLAN.md](WORKSHOP_PLAN.md) - Executive Summary section

**...learn about the Single Collection pattern**
→ Read [SINGLE_COLLECTION_PATTERN.md](SINGLE_COLLECTION_PATTERN.md)

**...check which labs are complete**
→ Check [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md)

**...develop new workshop content**
→ Reference [CLAUDE.md](CLAUDE.md) for development workflow

**...look up a specific pattern quickly**
→ Use [PATTERN_REFERENCE.md](PATTERN_REFERENCE.md)

**...understand Oracle-specific optimizations**
→ Read OSON sections in [SINGLE_COLLECTION_PATTERN.md](SINGLE_COLLECTION_PATTERN.md) or [PATTERN_REFERENCE.md](PATTERN_REFERENCE.md)

**...contribute to the workshop**
→ Read [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 📊 Workshop Status Summary

Based on [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md):

- **Total Labs:** 11 (Lab 0-10)
- **Content Complete:** 95%+
- **Labs Fully Implemented:** 8/11
- **Labs In Development:** 3/11 (Labs 5, 8, 9)
- **Total Workshop Time:** 6.5 hours (Foundation series: 3.5 hours)
- **Performance Improvements:** Up to 15x faster queries with Single Collection pattern

---

## 🔗 External Resources

### Oracle Documentation
- [Oracle JSON Collections](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/json-collections.html)
- [Oracle Database 23ai JSON Features](https://docs.oracle.com/en/database/oracle/oracle-database/23/newft/)
- [OSON Binary Format](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/oson-format.html)

### Industry Patterns
- [AWS DynamoDB Design Patterns](https://aws.amazon.com/dynamodb/resources/)
- [MongoDB Building with Patterns](https://www.mongodb.com/blog/post/building-with-patterns-a-summary)
- [Oracle Database API for MongoDB](https://docs.oracle.com/en/database/oracle/mongodb-api/)

---

## 📝 Document Maintenance

**Last Updated:** November 2024
**Maintained By:** Rick Houlihan
**Status:** Active Development

For questions or issues with documentation, please refer to the workshop repository issues or contact the workshop team.

---

## Document Organization Principles

This documentation follows these principles:

1. **Active documents in root** - Frequently referenced materials in docs/ root
2. **Historical documents in archive/** - Superseded versions preserved for reference
3. **Clear purpose statements** - Each document has explicit audience and use cases
4. **No duplication** - Each topic covered in one authoritative location
5. **Navigation-first** - This README helps find the right document quickly

---

**Navigation:** [← Back to Workshop Root](../README.md)
