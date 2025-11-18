# Templates Directory

This directory contains sample templates from oracle-livelabs/common repository to help with workshop development.

## Contents

### sample-lab/

**introduction/** - Sample introduction lab template
- Shows standard introduction structure
- Includes objectives, prerequisites sections
- Reference for creating introduction.md

**sample-lab/** - Complete sample lab structure
- Full lab example with all sections
- Images folder structure
- Files folder structure
- Standard lab markdown format

**Usage:**
```bash
# Create new lab based on template
cp -r templates/sample-lab/sample-lab labs/03-my-new-lab
cd labs/03-my-new-lab
mv query.md my-new-lab.md
# Edit my-new-lab.md with your content
```

### sample-workshop/

**workshops/** - Workshop manifest templates
- `tenancy/` - For workshops using user's Oracle Cloud tenancy
- `sandbox/` - For workshops using LiveLabs sandbox/green button
- `desktop/` - For workshops using noVNC remote desktop

Each contains:
- `manifest.json` - Workshop structure and lab list
- Example of how to reference labs
- Variables and includes examples

**Usage:**
```bash
# Create workshop manifest
cp templates/sample-workshop/workshops/tenancy/manifest.json workshops/tenancy/
# Edit manifest.json:
# - Update workshoptitle
# - Update help email
# - List your labs in tutorials array
# - Add variables/includes as needed
```

## Workshop Structure Reference

Standard LiveLabs workshop structure:

```
workshop-repo/
├── introduction/
│   └── introduction.md
├── labs/
│   ├── 01-lab-name/
│   │   ├── lab-name.md
│   │   ├── images/
│   │   └── files/
│   ├── 02-another-lab/
│   └── ...
├── workshops/
│   ├── tenancy/
│   │   └── manifest.json
│   ├── sandbox/
│   │   └── manifest.json
│   └── desktop/
│       └── manifest.json
├── images/            # Common images
├── data/              # Sample data files
└── scripts/           # SQL/shell scripts
```

## Lab Markdown Template

```markdown
# Lab Title

## Introduction

Brief description of what this lab covers.

Estimated Time: X minutes

### Objectives

In this lab, you will:
* Objective 1
* Objective 2
* Objective 3

### Prerequisites

This lab assumes you have:
* Prerequisite 1
* Prerequisite 2

## Task 1: Task Name

1. Step 1 description

   ```sql
   -- SQL code example
   SELECT * FROM table;
   ```

2. Step 2 description

   ![Description](./images/screenshot.png " ")

## Task 2: Another Task

1. Step 1
2. Step 2

## Learn More

* [Link to documentation](https://docs.oracle.com)

## Acknowledgements

* **Author** - Your Name, Title, Company
* **Contributors** - Contributor Name
* **Last Updated By/Date** - Your Name, Month Year
```

## Manifest.json Template

```json
{
  "workshoptitle": "Your Workshop Title",
  "help": "livelabs-help-db_us@oracle.com",
  "tutorials": [
    {
      "title": "Introduction",
      "description": "Workshop introduction",
      "filename": "../../introduction/introduction.md"
    },
    {
      "title": "Get Started",
      "filename": "https://oracle-livelabs.github.io/common/labs/cloud-login/cloud-login.md"
    },
    {
      "title": "Lab 1: First Lab",
      "filename": "../../labs/01-first-lab/first-lab.md"
    },
    {
      "title": "Need Help?",
      "filename": "https://oracle-livelabs.github.io/common/labs/need-help/need-help-freetier.md"
    }
  ]
}
```

## LiveLabs Standards

### File Naming
- All lowercase filenames
- Use hyphens for spaces: `my-lab-name.md`
- Directories match lab names

### Image Requirements
- Blur all personal information (IPs, emails, OCIDs)
- Include alt text: `![Description](image.png " ")`
- Store in `images/` folder within lab

### Lab Structure
- Must have Introduction (##)
- Must have Objectives (###)
- Must have Acknowledgements (##)
- Tasks are (##) level headings

### Common Labs
Reference via absolute URLs:
```
https://oracle-livelabs.github.io/common/labs/cloud-login/cloud-login.md
https://oracle-livelabs.github.io/common/labs/need-help/need-help-freetier.md
```

## Resources

- [LiveLabs Workshop Development Guide](https://oracle-livelabs.github.io/common/sample-livelabs-templates/create-labs/labs/workshops/tenancy/index.html)
- [Markdown Cheat Sheet](https://c4u04.objectstorage.us-ashburn-1.oci.customer-oci.com/p/EcTjWk2IuZPZeNnD_fYMcgUhdNDIDA6rt9gaFj_WZMiL7VvxPBNMY60837hu5hga/n/c4u04/b/livelabsfiles/o/LiveLabs_MD_Cheat_Sheet.pdf)
- [Oracle LiveLabs Common Repository](https://github.com/oracle-livelabs/common)
