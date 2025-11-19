# Setup Your Environment

## Introduction

In this lab, you will provision an Oracle Database and configure it for JSON Collections development. You have two options: **Oracle Autonomous Database Free Tier** (cloud-based) or **Oracle Database 23ai Free** (local Docker container). Both options provide full JSON Collections capabilities.

Estimated Time: 30 minutes

### Objectives

In this lab, you will:

* Choose between Autonomous Database Free Tier or Oracle Database 23ai Free
* Provision and configure your Oracle Database
* Connect to the database using SQL Developer Web or Database Actions
* Enable JSON Collections
* Create your first JSON collection
* Verify your environment is ready for the workshop

### Prerequisites

This lab assumes you have:

* An Oracle Cloud account (for Autonomous Database Free Tier option) **OR**
* Docker Desktop installed (for 23ai Free option)
* A web browser (Chrome, Firefox, or Edge recommended)
* Internet connection

## Task 1: Choose Your Database Option

You have two options for this workshop. Choose the one that best fits your needs:

### Option A: Autonomous Database Free Tier (Recommended)

**Advantages:**
- No local installation required
- Always available from any device
- Automatic backups and updates
- Production-grade infrastructure
- Free forever (up to 2 databases)

**Requirements:**
- Oracle Cloud account (Free Tier available)
- Web browser

**Best for:** Users who want a cloud-based environment or don't have Docker installed

### Option B: Oracle Database 23ai Free (Docker)

**Advantages:**
- Runs entirely on your local machine
- No cloud account required
- Fastest performance (local)
- Latest Oracle Database 23ai features

**Requirements:**
- Docker Desktop installed
- 8GB RAM minimum, 16GB recommended
- 20GB available disk space
- macOS, Windows, or Linux

**Best for:** Users with Docker experience or who prefer local development

**Choose one option and proceed to the corresponding task below.**

## Task 2A: Provision Autonomous Database Free Tier

> **Note:** If you chose Option B (23ai Free), skip to Task 2B.

### Step 1: Sign in to Oracle Cloud

1. Navigate to [cloud.oracle.com](https://cloud.oracle.com)

2. Click **Sign In** and enter your cloud account credentials

3. Select your **tenancy** and sign in

### Step 2: Create Autonomous JSON Database

1. From the Oracle Cloud Console navigation menu (hamburger icon ≡), select:
   - **Oracle Database** → **Autonomous Database**

2. Click **Create Autonomous Database**

3. Configure your database with these settings:

   **Compartment:** Select your compartment (or use root compartment)

   **Display name:** `JSON-Workshop`

   **Database name:** `JSONDB`

   **Workload type:** Select **JSON**

   **Deployment type:** Select **Serverless**

   **Always Free:** Toggle **ON** (ensure the "Always Free" option is enabled)

   **Database version:** Select **23ai** (or latest available)

4. Under **Create administrator credentials**:

   **Password:** Create a strong password (must be 12-30 characters with uppercase, lowercase, and numbers)

   **Confirm password:** Re-enter your password

   > **IMPORTANT:** Save this password securely - you will need it throughout the workshop

5. Under **Network access**:

   - Select **Secure access from everywhere**

   > **Note:** For production environments, you would configure VCN access

6. Under **License type**:

   - Select **License Included**

7. Click **Create Autonomous Database**

   The database will take 2-3 minutes to provision. Wait for the status to change from **PROVISIONING** to **AVAILABLE** (green icon).

### Step 3: Access Database Actions

1. Once your database is **AVAILABLE**, click the **Database Actions** button

2. Sign in with:
   - **Username:** `ADMIN`
   - **Password:** The password you created in Step 2

3. From the Database Actions launchpad, click **SQL** tile

   This opens SQL Developer Web, where you will execute all SQL commands in this workshop.

4. Verify you see the SQL worksheet interface with:
   - SQL command area (top)
   - Script Output area (bottom)
   - Object navigator (left)

**Proceed to Task 3**

## Task 2B: Setup Oracle Database 23ai Free with Docker

> **Note:** If you chose Option A (Autonomous Database Free Tier), skip to Task 3.

### Step 1: Verify Docker Installation

1. Open a terminal or command prompt

2. Verify Docker is installed and running:

   ```bash
   docker --version
   ```

   You should see output like: `Docker version 24.x.x`

3. Verify Docker is running:

   ```bash
   docker ps
   ```

   If Docker is not running, start Docker Desktop.

### Step 2: Pull Oracle Database 23ai Free Image

1. Pull the latest Oracle Database 23ai Free image:

   ```bash
   docker pull container-registry.oracle.com/database/free:latest
   ```

   This will download approximately 3GB of data. The download may take 5-15 minutes depending on your internet connection.

### Step 3: Run Oracle Database 23ai Free Container

1. Create and start the container:

   ```bash
   docker run -d \
     --name oracle23ai \
     -p 1521:1521 \
     -p 5500:5500 \
     -e ORACLE_PWD=Welcome123456 \
     container-registry.oracle.com/database/free:latest
   ```

   **Parameter explanation:**
   - `-d`: Run container in detached mode (background)
   - `--name oracle23ai`: Container name
   - `-p 1521:1521`: Database listener port
   - `-p 5500:5500`: Enterprise Manager Express port
   - `-e ORACLE_PWD=Welcome123456`: SYSTEM and SYS password

   > **IMPORTANT:** Change `Welcome123456` to your own secure password if desired

2. Monitor the database startup:

   ```bash
   docker logs -f oracle23ai
   ```

   Wait for the message: **DATABASE IS READY TO USE!**

   This takes approximately 3-5 minutes on first startup.

   Press `Ctrl+C` to exit the log viewer.

### Step 4: Connect to Database

1. Access the database using SQL*Plus:

   ```bash
   docker exec -it oracle23ai sqlplus sys/Welcome123456@FREE as sysdba
   ```

   > **Note:** Replace `Welcome123456` with your password if you changed it

2. Alternatively, access Enterprise Manager Express in your browser:

   ```
   https://localhost:5500/em
   ```

   - **Container Name:** FREE
   - **Username:** SYSTEM
   - **Password:** Welcome123456 (or your password)

   > **Note:** You may see a certificate warning - this is expected for the self-signed certificate

3. For this workshop, we recommend using SQL Developer Web. To enable it, run:

   ```sql
   -- Connect as SYSTEM first
   sqlplus system/Welcome123456@localhost:1521/FREEPDB1

   -- Enable ORDS for SQL Developer Web
   EXEC ORDS.ENABLE_SCHEMA;
   ```

**Proceed to Task 3**

## Task 3: Create Workshop User and Enable JSON Collections

Both Autonomous Database Free Tier and 23ai Free users continue with this task.

### Step 1: Create Workshop User

1. In your SQL worksheet (Database Actions for Autonomous Database, or SQL*Plus for 23ai), create a new user:

   ```sql
   -- Create workshop user
   CREATE USER jsonuser IDENTIFIED BY "WelcomeJson#123";

   -- Grant necessary privileges
   GRANT CONNECT, RESOURCE TO jsonuser;
   GRANT UNLIMITED TABLESPACE TO jsonuser;
   GRANT CREATE VIEW TO jsonuser;
   GRANT CREATE MATERIALIZED VIEW TO jsonuser;

   -- Grant JSON-specific privileges
   GRANT SODA_APP TO jsonuser;
   ```

   > **Note:** `SODA_APP` role provides privileges for Simple Oracle Document Access (SODA), the foundation for JSON Collections

2. Verify the user was created:

   ```sql
   SELECT username, account_status
   FROM dba_users
   WHERE username = 'JSONUSER';
   ```

   Expected output:
   ```
   USERNAME    ACCOUNT_STATUS
   ----------  --------------
   JSONUSER    OPEN
   ```

### Step 2: Connect as JSONUSER

1. **For Autonomous Database Free Tier users:**
   - Sign out from Database Actions (click user icon → Sign Out)
   - Sign back in with:
     - **Username:** `JSONUSER`
     - **Password:** `WelcomeJson#123`

2. **For 23ai Free users:**
   - Exit SQL*Plus (type `EXIT`)
   - Connect as JSONUSER:

   ```bash
   docker exec -it oracle23ai sqlplus jsonuser/WelcomeJson#123@FREE
   ```

## Task 4: Create Your First JSON Collection

JSON Collections in Oracle Database are schema-flexible collections of JSON documents, similar to MongoDB collections or DynamoDB tables.

### Step 1: Understand JSON Collection Basics

Oracle Database provides two ways to work with JSON:

1. **SQL/JSON** - Use SQL with JSON functions
2. **SODA (Simple Oracle Document Access)** - MongoDB-compatible API

We will use **SQL/JSON** as the primary method, with SODA examples provided.

### Step 2: Create a JSON Collection

1. Create a simple JSON collection:

   ```sql
   -- Create a JSON collection using SQL
   -- This creates a table optimized for JSON documents
   CREATE TABLE test_collection (
     id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
     json_document JSON,
     CONSTRAINT ensure_json CHECK (json_document IS JSON)
   );
   ```

2. Verify the collection was created:

   ```sql
   SELECT table_name, column_name, data_type
   FROM user_tab_columns
   WHERE table_name = 'TEST_COLLECTION'
   ORDER BY column_id;
   ```

   Expected output:
   ```
   TABLE_NAME        COLUMN_NAME     DATA_TYPE
   ---------------   -------------   ---------
   TEST_COLLECTION   ID              RAW
   TEST_COLLECTION   JSON_DOCUMENT   JSON
   ```

   > **Note:** The table has an `ID` column (primary key) and a `JSON_DOCUMENT` column to store JSON documents

### Step 3: Insert Your First JSON Document

1. Insert a document using SQL:

   ```sql
   INSERT INTO test_collection (json_document)
   VALUES (
     JSON_OBJECT(
       '_id' VALUE 'doc001',
       'name' VALUE 'Alice Smith',
       'email' VALUE 'alice@example.com',
       'role' VALUE 'developer',
       'skills' VALUE JSON_ARRAY('SQL', 'Python', 'JavaScript'),
       'active' VALUE true
     )
   );

   COMMIT;
   ```

2. Query the document:

   ```sql
   SELECT JSON_SERIALIZE(json_document PRETTY)
   FROM test_collection;
   ```

   Expected output:
   ```json
   {
     "_id" : "doc001",
     "name" : "Alice Smith",
     "email" : "alice@example.com",
     "role" : "developer",
     "skills" :
     [
       "SQL",
       "Python",
       "JavaScript"
     ],
     "active" : true
   }
   ```

3. Query specific fields using JSON_VALUE:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$._id') AS id,
     JSON_VALUE(json_document, '$.name') AS name,
     JSON_VALUE(json_document, '$.email') AS email
   FROM test_collection;
   ```

   Expected output:
   ```
   ID       NAME          EMAIL
   ------   -----------   -------------------
   doc001   Alice Smith   alice@example.com
   ```

### Step 4: Understand OSON Binary Format

Oracle stores JSON documents in **OSON (Oracle Optimized Binary JSON)** format for optimal performance.

1. Check the storage format:

   ```sql
   SELECT
     JSON_VALUE(json_document, '$._id') AS id,
     LENGTH(json_document) AS oson_bytes
   FROM test_collection;
   ```

   Expected output:
   ```
   ID         OSON_BYTES
   ------     ----------
   doc001     163
   ```

2. Understanding OSON performance tiers:

   - **Inline storage** (< 7,950 bytes): Fastest performance
   - **LOB storage** (7,950 bytes - 32MB): Slower performance
   - **Maximum document size:** 32MB

   > **Key Insight:** Keeping documents under 7,950 bytes (inline storage) provides the best performance. This workshop will teach you how to design documents to stay within optimal size ranges.

## Task 5: Verify Environment Setup

### Step 1: Check JSON Collections Feature

1. Verify JSON is enabled:

   ```sql
   SELECT
     PROPERTY_NAME,
     PROPERTY_VALUE
   FROM DATABASE_PROPERTIES
   WHERE PROPERTY_NAME = 'COMPATIBLE';
   ```

   The version should be 19.0.0 or higher (23ai recommended).

### Step 2: Create Performance Metrics Table

You will use this table throughout the workshop to track performance benchmarks.

1. Create the metrics table:

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
     timestamp TIMESTAMP DEFAULT SYSTIMESTAMP,
     notes VARCHAR2(500)
   );
   ```

2. Verify the table was created:

   ```sql
   SELECT table_name
   FROM user_tables
   WHERE table_name = 'PERFORMANCE_METRICS';
   ```

### Step 3: Test JSON Query Functions

1. Test core JSON functions:

   ```sql
   -- JSON_VALUE: Extract scalar values
   SELECT JSON_VALUE(json_document, '$.name') FROM test_collection;

   -- JSON_QUERY: Extract objects or arrays
   SELECT JSON_QUERY(json_document, '$.skills') FROM test_collection;

   -- JSON_EXISTS: Check if path exists
   SELECT COUNT(*)
   FROM test_collection
   WHERE JSON_EXISTS(json_document, '$.skills');

   -- JSON_TABLE: Convert JSON to relational rows
   SELECT jt.*
   FROM test_collection,
     JSON_TABLE(json_document, '$.skills[*]'
       COLUMNS (skill VARCHAR2(50) PATH '$')
     ) jt;
   ```

2. If all queries execute successfully, your environment is ready!

## Task 6: Download Workshop Scripts (Optional)

For convenience, you can download pre-built scripts for this workshop.

### Option 1: Clone the Repository

If you have Git installed:

```bash
git clone https://github.com/rhoulihan/json-document-modeling-livelab.git
cd json-document-modeling-livelab/scripts
```

### Option 2: Manual Download

1. Navigate to: https://github.com/rhoulihan/json-document-modeling-livelab

2. Click **Code** → **Download ZIP**

3. Extract the ZIP file

4. Navigate to the `scripts/` directory

### Use the Scripts

Throughout the workshop, you will find references to scripts like:

- `scripts/setup/create_collections.sql`
- `scripts/patterns/single_collection_example.sql`
- `scripts/benchmarks/compare_patterns.sql`

You can either:
- **Copy and paste** SQL from the lab instructions (recommended for learning)
- **Run the scripts** directly if you downloaded them

## Task 7: Environment Checklist

Before proceeding to Lab 1, verify you have completed:

- [ ] Oracle Database provisioned (Autonomous Database Free Tier OR 23ai Free)
- [ ] Connected to database using SQL interface
- [ ] Created JSONUSER with proper privileges
- [ ] Created first JSON collection (test_collection)
- [ ] Inserted and queried test document
- [ ] Created performance_metrics table
- [ ] Tested JSON query functions (JSON_VALUE, JSON_QUERY, etc.)
- [ ] (Optional) Downloaded workshop scripts

If you checked all items, you are ready to proceed to **Lab 1: JSON Collections Fundamentals**!

## Troubleshoot Issues

### Issue: Cannot connect to Autonomous Database

**Solution:**
- Verify you are using the correct username (JSONUSER, not ADMIN)
- Ensure your password is correct (remember: case-sensitive)
- Check that database status is AVAILABLE (not STOPPED or PROVISIONING)
- Try signing out and signing back in

### Issue: Docker container won't start

**Solution:**
```bash
# Check container status
docker ps -a

# View container logs
docker logs oracle23ai

# If container exists but is stopped, start it
docker start oracle23ai

# If container is corrupted, remove and recreate
docker rm -f oracle23ai
# Then re-run the docker run command from Task 2B, Step 3
```

### Issue: SODA_APP role does not exist

**Solution:**
- Verify you are running Oracle Database 19c or higher
- Ensure JSON features are enabled (should be by default in 23ai and Autonomous Database)
- Grant alternative privileges:

```sql
GRANT CREATE TABLE, CREATE INDEX TO jsonuser;
```

### Issue: JSON functions not recognized

**Solution:**
- Verify database compatibility:

```sql
SELECT PROPERTY_VALUE
FROM DATABASE_PROPERTIES
WHERE PROPERTY_NAME = 'COMPATIBLE';
```

- Ensure you are connected as JSONUSER (not ADMIN or SYSTEM)

### Issue: Cannot create collection

**Error:** `ORA-00955: name is already used by an existing object`

**Solution:**
```sql
-- Drop existing collection
BEGIN
  DBMS_SODA.DROP_COLLECTION('test_collection');
END;
/

-- Recreate collection
DECLARE
  collection SODA_COLLECTION_T;
BEGIN
  collection := DBMS_SODA.CREATE_COLLECTION('test_collection');
END;
/
```

## Learn More

* [Oracle Autonomous Database Free Tier](https://www.oracle.com/autonomous-database/free-trial/)
* [Oracle Database 23ai Free](https://www.oracle.com/database/free/)
* [JSON Collections in Oracle Database](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/json-collections.html)
* [SODA (Simple Oracle Document Access)](https://docs.oracle.com/en/database/oracle/simple-oracle-document-access/)
* [Oracle JSON Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/)

## Acknowledgements

* **Author** - Rick Houlihan, Solution Architect
* **Contributors** - Oracle JSON Development Team, Oracle LiveLabs Team
* **Last Updated By/Date** - Rick Houlihan, November 2024
