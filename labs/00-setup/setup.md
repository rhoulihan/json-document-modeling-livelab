# Setup Your Environment

## Introduction

In this lab, you will provision an Oracle Database and configure it for JSON Collections development. You have two options: **Oracle Autonomous AI JSON Database** (cloud-based) or **Oracle AI Database 26ai Free** (local Docker container). Both options provide full JSON Collections capabilities.

Estimated Time: 30 minutes

### Objectives

In this lab, you will:

* Choose between Autonomous AI JSON Database or Oracle AI Database 26ai Free
* Provision and configure your Oracle Database
* Connect to the database using SQL Developer Web or Database Actions
* Create your first JSON Collection Table
* Verify your environment is ready for the workshop

### Prerequisites

This lab assumes you have:

* An Oracle Cloud account (for Autonomous AI JSON Database option) **OR**
* Docker Desktop installed (for 26ai Free option)
* A web browser (Chrome, Firefox, or Edge recommended)
* Internet connection

## Task 1: Choose Your Database Option

You have two options for this workshop. Choose the one that best fits your needs:

### Option A: Autonomous AI JSON Database (Recommended)

**Advantages:**
- No local installation required
- Always available from any device
- Automatic backups and updates
- Production-grade infrastructure
- Free forever (up to 2 databases)
- MongoDB API included

**Requirements:**
- Oracle Cloud account (Free Tier available)
- Web browser

**Best for:** Users who want a cloud-based environment or don't have Docker installed

### Option B: Oracle AI Database 26ai Free (Docker)

**Advantages:**
- Runs entirely on your local machine
- No cloud account required
- Fastest performance (local)
- Latest Oracle AI Database 26ai features
- MongoDB API included

**Requirements:**
- Docker Desktop installed
- 8GB RAM minimum, 16GB recommended
- 20GB available disk space
- macOS, Windows, or Linux

**Best for:** Users with Docker experience or who prefer local development

**Choose one option and proceed to the corresponding task below.**

## Task 2A: Provision Autonomous AI JSON Database

> **Note:** If you chose Option B (26ai Free Docker), skip to Task 2B.

### Step 1: Sign in to Oracle Cloud

1. Navigate to [cloud.oracle.com](https://cloud.oracle.com)

2. Click **Sign In** and enter your cloud account credentials

3. Select your **tenancy** and sign in

### Step 2: Create Autonomous AI JSON Database

1. From the Oracle Cloud Console navigation menu (hamburger icon ≡), select:
   - **Oracle Database** → **Autonomous Database**

2. Click **Create Autonomous Database**

3. Configure your database with these settings:

   **Compartment:** Select your compartment (or use root compartment)

   **Display name:** `JSON-Workshop`

   **Database name:** `JSONDB`

   **Workload type:** Select **JSON** (Autonomous AI JSON Database)

   **Deployment type:** Select **Serverless**

   **Always Free:** Toggle **ON** (ensure the "Always Free" option is enabled)

   **Database version:** Select **26ai** (or latest available)

4. Under **Create administrator credentials**:

   **Password:** Create a strong password (must be 12-30 characters with uppercase, lowercase, and numbers)

   **Confirm password:** Re-enter your password

   > **IMPORTANT:** Save this password securely - you will need it throughout the workshop

5. Under **Network access** (IMPORTANT for MongoDB API):

   - Select **Secure access from allowed IPs and VCNs only**
   - Click **Add My IP Address** to add your current IP to the Access Control List (ACL)

   > **Note:** MongoDB API requires ACL configuration. "Secure access from everywhere" will NOT allow MongoDB API access. You must configure an Access Control List (ACL) or use a private endpoint.

   > **Tip:** Your public IP address may change. If you lose database access later, check your ACL configuration first. You can find your current IP at [ifconfig.me](https://ifconfig.me).

6. Under **License type**:

   - Select **License Included**

7. Click **Create Autonomous Database**

   The database will take 2-3 minutes to provision. Wait for the status to change from **PROVISIONING** to **AVAILABLE** (green icon).

### Step 3: Enable MongoDB API

1. Once your database is **AVAILABLE**, go to the **Tool configuration** tab

2. Click **Edit** next to MongoDB API

3. Select **Enable** and click **Apply**

   The MongoDB API URL will appear once enabled. Save this URL for later use.

### Step 4: Access Database Actions

1. On your database details page, click the **Database Actions** button

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

## Task 2B: Setup Oracle AI Database 26ai Free with Docker

> **Note:** If you chose Option A (Autonomous AI JSON Database), skip to Task 3.

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

### Step 2: Pull Oracle AI Database 26ai Free Image

1. Pull the Oracle AI Database 26ai Free container image:

   ```bash
   docker pull ghcr.io/oracle/adb-free:latest-26ai
   ```

   This will download approximately 3GB of data. The download may take 5-15 minutes depending on your internet connection.

   > **Note:** The `latest-26ai` tag ensures you get the 26ai version. The `latest` tag pulls the 19c version.

### Step 3: Run Oracle AI Database 26ai Free Container

1. Create and start the container:

   ```bash
   docker run -d \
     --name oracle26ai \
     -p 1521:1521 \
     -p 1522:1522 \
     -p 8443:8443 \
     -p 27017:27017 \
     -e WORKLOAD_TYPE=ATP \
     -e WALLET_PASSWORD=WalletPass1234 \
     -e ADMIN_PASSWORD=WelcomeOracle1 \
     --cap-add SYS_ADMIN \
     --device /dev/fuse \
     ghcr.io/oracle/adb-free:latest-26ai
   ```

   **Parameter explanation:**
   - `-d`: Run container in detached mode (background)
   - `--name oracle26ai`: Container name
   - `-p 1521:1521`: Database listener port (TLS)
   - `-p 1522:1522`: Database listener port (mTLS)
   - `-p 8443:8443`: HTTPS port for Database Actions/APEX
   - `-p 27017:27017`: MongoDB API port
   - `-e WORKLOAD_TYPE=ATP`: Autonomous Transaction Processing workload
   - `-e WALLET_PASSWORD`: Password for wallet encryption (8-30 chars with letters and numbers/special chars)
   - `-e ADMIN_PASSWORD`: ADMIN user password (12-30 chars with uppercase, lowercase, and numbers)
   - `--cap-add SYS_ADMIN`: Required capability for the container
   - `--device /dev/fuse`: Required device for the container

   > **IMPORTANT:** The ADMIN_PASSWORD must be 12-30 characters with at least one uppercase, one lowercase, and one numeric character

2. Monitor the database startup:

   ```bash
   docker logs -f oracle26ai
   ```

   Wait for the message: **DATABASE IS READY TO USE!**

   This takes approximately 3-5 minutes on first startup.

   Press `Ctrl+C` to exit the log viewer.

### Step 4: Connect to Database

1. Access Database Actions in your browser:

   ```
   https://localhost:8443/ords/sql-developer
   ```

   - **Username:** ADMIN
   - **Password:** WelcomeOracle1 (or your ADMIN_PASSWORD)

   > **Note:** You may see a certificate warning - this is expected for the self-signed certificate. Click "Advanced" and proceed.

2. Alternatively, access the database using SQL*Plus from within the container:

   ```bash
   docker exec oracle26ai bash -c "export TNS_ADMIN=/u01/app/oracle/wallets/tls_wallet && sqlplus admin/WelcomeOracle1@myatp_low"
   ```

   > **Note:** Replace `WelcomeOracle1` with your ADMIN_PASSWORD if you changed it.
   > The database name is `myatp` (for ATP workload type) with service levels: `_low`, `_medium`, `_high`, `_tp`, `_tpurgent`.

3. The MongoDB API is available at:

   ```
   mongodb://admin:WelcomeOracle1@localhost:27017/admin?authMechanism=PLAIN&authSource=$external&tls=true&tlsAllowInvalidCertificates=true
   ```

4. Verify the database version:

   ```bash
   docker exec oracle26ai bash -c "export TNS_ADMIN=/u01/app/oracle/wallets/tls_wallet && echo 'SELECT banner_full FROM v\$version WHERE ROWNUM = 1;' | sqlplus -s admin/WelcomeOracle1@myatp_low"
   ```

   Expected output:
   ```
   BANNER_FULL
   --------------------------------------------------------------------------------
   Oracle AI Database 26ai Enterprise Edition Release 23.26.0.1.0 - for Oracle Cloud
   and Engineered Systems
   Version 23.26.0.1.0
   ```

**Proceed to Task 3**

## Task 3: Create Workshop User

Both Autonomous AI JSON Database and 26ai Free Docker users continue with this task.

### Step 1: Create Workshop User

1. In your SQL worksheet (Database Actions), create a new user:

   ```sql
   -- Create workshop user
   CREATE USER jsonuser IDENTIFIED BY "WelcomeJson#123";

   -- Grant necessary privileges
   GRANT CONNECT, RESOURCE TO jsonuser;
   GRANT UNLIMITED TABLESPACE TO jsonuser;
   GRANT CREATE VIEW TO jsonuser;
   GRANT CREATE MATERIALIZED VIEW TO jsonuser;
   GRANT CREATE SESSION TO jsonuser;
   ```

   **Expected output:**
   ```
   User created.
   Grant succeeded.
   Grant succeeded.
   Grant succeeded.
   Grant succeeded.
   Grant succeeded.
   ```

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

1. **For Autonomous AI JSON Database users:**
   - Sign out from Database Actions (click user icon → Sign Out)
   - Sign back in with:
     - **Username:** `JSONUSER`
     - **Password:** `WelcomeJson#123`

2. **For 26ai Free Docker users:**
   - Sign out from Database Actions
   - Sign back in with JSONUSER credentials, OR
   - Connect via SQL*Plus:

   ```bash
   docker exec oracle26ai bash -c "export TNS_ADMIN=/u01/app/oracle/wallets/tls_wallet && sqlplus jsonuser/WelcomeJson#123@myatp_low"
   ```

## Task 4: Create Your First JSON Collection Table

JSON Collection Tables in Oracle AI Database 26ai are schema-flexible collections of JSON documents, similar to MongoDB collections or DynamoDB tables.

### Step 1: Understand JSON Collection Tables

Oracle AI Database 26ai introduces **JSON Collection Tables** - optimized single-column tables for storing JSON documents:

- Single `DATA` column of type JSON
- Automatic `_id` field generation for each document
- Full SQL/JSON query capabilities
- MongoDB API compatible
- Support for partitioning and indexing

### Step 2: Create a JSON Collection Table

1. Create your first JSON Collection Table:

   ```sql
   -- Create a JSON Collection Table (26ai syntax)
   CREATE JSON COLLECTION TABLE test_collection;
   ```

   **Expected output:**
   ```
   Table created.
   ```

2. Verify the collection was created:

   ```sql
   SELECT collection_name, collection_type
   FROM user_json_collections
   WHERE collection_name = 'TEST_COLLECTION';
   ```

   Expected output:
   ```
   COLLECTION_NAME      COLLECTION_TYPE
   -------------------- ---------------
   TEST_COLLECTION      TABLE
   ```

3. Examine the table structure:

   ```sql
   DESC test_collection
   ```

   Expected output:
   ```
   Name   Null?    Type
   ----   -----    ----
   DATA            JSON
   ```

   > **Note:** JSON Collection Tables have a single `DATA` column of type JSON.
   > The database automatically manages document IDs via the `_id` field.

### Step 3: Insert Your First JSON Document

1. Insert a document using SQL:

   ```sql
   INSERT INTO test_collection (data)
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

   **Expected output:**
   ```
   1 row created.
   Commit complete.
   ```

   > **Note:** You can provide a custom `_id` value (like 'doc001') or omit it to let the database generate one automatically.

2. Query the document:

   ```sql
   SELECT JSON_SERIALIZE(data PRETTY)
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
     JSON_VALUE(data, '$._id') AS id,
     JSON_VALUE(data, '$.name') AS name,
     JSON_VALUE(data, '$.email') AS email
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
     JSON_VALUE(data, '$._id') AS id,
     LENGTHB(data) AS oson_bytes
   FROM test_collection;
   ```

   Expected output:
   ```
   ID         OSON_BYTES
   ------     ----------
   doc001     163
   ```

2. Understanding OSON storage tiers:

   - **Inline storage** (< ~7,950 bytes): Fastest performance - document stored in table row
   - **Out-of-line/LOB storage** (≥ ~7,950 bytes): Slower - requires additional I/O
   - **Maximum document size:** 32MB

   > **Key Insight:** The performance difference between inline and out-of-line storage is significant. Keep frequently-accessed documents under 7,950 bytes whenever possible. This workshop will teach you how to design documents to stay within optimal size ranges.

## Task 5: Verify Environment Setup

### Step 1: Check JSON Collections Feature

1. Verify your JSON Collection Tables:

   ```sql
   SELECT collection_name, collection_type
   FROM user_json_collections;
   ```

   Expected output:
   ```
   COLLECTION_NAME      COLLECTION_TYPE
   -------------------- ---------------
   TEST_COLLECTION      TABLE
   ```

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

   **Expected output:**
   ```
   Table created.
   ```

2. Verify the table was created:

   ```sql
   SELECT table_name
   FROM user_tables
   WHERE table_name = 'PERFORMANCE_METRICS';
   ```

   **Expected output:**
   ```
   TABLE_NAME
   ------------------
   PERFORMANCE_METRICS
   ```

### Step 3: Test JSON Query Functions

1. Test core JSON functions:

   ```sql
   -- JSON_VALUE: Extract scalar values
   SELECT JSON_VALUE(data, '$.name') FROM test_collection;

   -- JSON_QUERY: Extract objects or arrays
   SELECT JSON_QUERY(data, '$.skills') FROM test_collection;

   -- JSON_EXISTS: Check if path exists
   SELECT COUNT(*)
   FROM test_collection
   WHERE JSON_EXISTS(data, '$.skills');

   -- JSON_TABLE: Convert JSON to relational rows
   SELECT jt.*
   FROM test_collection,
     JSON_TABLE(data, '$.skills[*]'
       COLUMNS (skill VARCHAR2(50) PATH '$')
     ) jt;
   ```

   **Expected output:**
   ```
   NAME
   ---------------
   Alice Smith

   SKILLS
   ----------------------------------------
   ["SQL","Python","JavaScript"]

   COUNT(*)
   --------
          1

   SKILL
   ---------------
   SQL
   Python
   JavaScript
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

- [ ] Oracle Database provisioned (Autonomous AI JSON Database OR 26ai Free Docker)
- [ ] Connected to database using Database Actions SQL interface
- [ ] Created JSONUSER with proper privileges
- [ ] Created first JSON Collection Table (test_collection)
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
- If using MongoDB API, verify your IP is in the ACL (Access Control List)
- Try signing out and signing back in

### Issue: MongoDB API URL not showing

**Solution:**
- MongoDB API requires ACL configuration - "Secure access from everywhere" will not work
- Go to your database details → Network → Edit Access Control List
- Add your IP address using "Add My IP Address"
- Wait a few minutes for the configuration to apply
- Check the Tool Configuration tab for the MongoDB API URL

### Issue: Docker container won't start

**Solution:**
```bash
# Check container status
docker ps -a

# View container logs
docker logs oracle26ai

# If container exists but is stopped, start it
docker start oracle26ai

# If container is corrupted, remove and recreate
docker rm -f oracle26ai
# Then re-run the docker run command from Task 2B, Step 3
```

### Issue: Password validation error on container startup

**Error:** `The ADMIN_PASSWORD must be between 12 and 30 characters long...`

**Solution:**
- Ensure ADMIN_PASSWORD is 12-30 characters
- Must include at least one uppercase letter
- Must include at least one lowercase letter
- Must include at least one numeric character
- Example: `WelcomeOracle1`

### Issue: TNS could not resolve connect identifier

**Solution:**
- Set the TNS_ADMIN environment variable before connecting:
```bash
docker exec oracle26ai bash -c "export TNS_ADMIN=/u01/app/oracle/wallets/tls_wallet && sqlplus admin/WelcomeOracle1@myatp_low"
```
- The database name is `myatp` with service levels: `_low`, `_medium`, `_high`

### Issue: JSON functions not recognized

**Solution:**
- Ensure you are connected as JSONUSER (not ADMIN or SYSTEM)
- Verify you're using the correct column name (`data` for JSON Collection Tables)

### Issue: Cannot create collection

**Error:** `ORA-00955: name is already used by an existing object`

**Solution:**
```sql
-- For 26ai, simply drop the table
DROP TABLE test_collection;

-- Recreate the JSON Collection Table
CREATE JSON COLLECTION TABLE test_collection;
```

### Issue: CREATE JSON COLLECTION TABLE not recognized

**Solution:**
- Ensure you are using Oracle AI Database 26ai or later
- This syntax is not available in older database versions
- For older versions, create a regular table with a JSON column instead

## Learn More

* [Oracle Autonomous AI JSON Database](https://www.oracle.com/autonomous-database/autonomous-json-database/)
* [Oracle AI Database 26ai Free](https://www.oracle.com/database/free/)
* [JSON Collection Tables in Oracle Database](https://oracle-base.com/articles/23/json-collections-23)
* [Oracle Database API for MongoDB](https://docs.oracle.com/en/database/oracle/mongodb-api/)
* [Oracle JSON Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/)
* [MongoDB API ACL Configuration](https://martincarstenbach.com/2024/10/25/enable-the-mongodb-api-on-always-free-autonomous-database/)

## Acknowledgements

* **Author** - Rick Houlihan
* **Contributors** - Oracle JSON Development Team, Oracle LiveLabs Team
* **Last Updated By/Date** - Rick Houlihan, November 2025
