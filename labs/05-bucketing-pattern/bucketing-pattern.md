# Lab 5: Bucketing Pattern for Time-Series Data

## Introduction

The Bucketing Pattern is essential for managing high-volume time-series data where individual events would create millions of small documents. By grouping related events into time-based "buckets," you can optimize storage, improve query performance, and avoid the LOB performance cliff.

In this lab, you will learn how to implement the Bucketing Pattern within a Single Collection design using composite keys for IoT sensor data, application logs, and other time-series use cases.

**Estimated Time:** 45 minutes

## Prerequisites

- Completed Lab 3: Single Collection/Table Design Pattern
- Completed Lab 4: Computed Pattern and Aggregations
- Understanding of composite keys and time-series data challenges

## Objectives

In this lab, you will:
- Understand the Bucketing Pattern and its benefits for time-series data
- Implement time-based buckets using composite keys (e.g., `SENSOR#temp001#BUCKET#2024-11-18-14`)
- Choose appropriate bucket sizes for different data volumes
- Query bucketed data efficiently using composite key prefixes
- Handle bucket overflow scenarios
- Measure storage and query performance improvements

## Task 1: Understanding the Bucketing Pattern

### Step 1: The Problem with Unbucketed Time-Series Data

Consider an IoT application collecting temperature readings every second:

```sql
-- ❌ Anti-Pattern: One document per reading
-- 86,400 readings/day per sensor = 86,400 documents/day
-- 100 sensors = 8.6M documents/day = 3.1B documents/year

-- Each reading as a separate document
INSERT INTO sensor_data (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'SENSOR#temp001#2024-11-18T14:30:01Z',
    'type' VALUE 'reading',
    'sensor_id' VALUE 'temp001',
    'timestamp' VALUE '2024-11-18T14:30:01Z',
    'value' VALUE 23.5,
    'unit' VALUE 'celsius'
  )
);

-- Problems:
-- ❌ Millions of tiny documents (< 200 bytes each)
-- ❌ High index overhead (one index entry per document)
-- ❌ Inefficient range queries (scan millions of documents)
-- ❌ Poor storage efficiency (overhead per document)
```

### Step 2: The Solution - Time-Based Bucketing

Group readings into hourly buckets:

```json
{
  "_id": "SENSOR#temp001#BUCKET#2024-11-18-14",
  "type": "sensor_bucket",
  "sensor_id": "temp001",
  "bucket_start": "2024-11-18T14:00:00Z",
  "bucket_end": "2024-11-18T14:59:59Z",
  "reading_count": 3600,
  "readings": [
    {"timestamp": "2024-11-18T14:00:01Z", "value": 23.5},
    {"timestamp": "2024-11-18T14:00:02Z", "value": 23.6},
    // ... 3,598 more readings
  ],
  "summary": {
    "min": 22.1,
    "max": 24.8,
    "avg": 23.5,
    "stddev": 0.82
  }
}
```

**Benefits:**
- ✅ 3,600 readings in one document (vs 3,600 separate documents)
- ✅ 99.97% fewer documents (24 buckets/day vs 86,400 documents/day)
- ✅ One index entry per bucket (vs 3,600 index entries)
- ✅ Efficient range queries using composite key prefix
- ✅ Pre-computed summary statistics per bucket
- ✅ Document size: 50-150KB (inline storage tier)

### Step 3: Choosing the Right Bucket Size

**Bucket Size Guidelines:**

| Data Volume | Bucket Size | Documents/Day | Doc Size | Use Case |
|-------------|-------------|---------------|----------|----------|
| 1 reading/sec | 1 hour | 24 | 50-100KB | IoT sensors, metrics |
| 10 readings/sec | 1 hour | 24 | 150-300KB | High-frequency sensors |
| 100 readings/sec | 10 min | 144 | 100-200KB | Application logs |
| 1 reading/min | 1 day | 1 | 20-50KB | Low-frequency monitoring |
| 1 reading/hour | 1 month | 12/year | 10-30KB | Daily summaries |

**Key Principle:**
> **Keep bucket documents under 500KB (ideally under 200KB) to stay in Oracle's fast inline storage tier (< 7,950 bytes for optimal performance, < 500KB for good performance).**

## Task 2: Implementing Bucketed Sensor Data

### Step 1: Create the Sensor Collection

```sql
-- Create JSON Collection Table for sensor data
CREATE JSON COLLECTION TABLE sensor_data;

-- Create indexes for efficient querying
CREATE INDEX idx_sensor_id ON sensor_data (JSON_VALUE(data, '$._id'));
CREATE INDEX idx_sensor_type ON sensor_data (JSON_VALUE(data, '$.type'));
CREATE INDEX idx_sensor_sensor_id ON sensor_data (JSON_VALUE(data, '$.sensor_id'));
```

### Step 2: Insert Sensor Metadata and Initial Bucket

```sql
-- Insert sensor metadata document
INSERT INTO sensor_data (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'SENSOR#temp001',
    'type' VALUE 'sensor',
    'sensor_id' VALUE 'temp001',
    'name' VALUE 'Warehouse Temperature Sensor',
    'location' VALUE 'Warehouse A - Zone 3',
    'unit' VALUE 'celsius',
    'config' VALUE JSON_OBJECT(
      'sample_rate_seconds' VALUE 1,
      'alert_threshold_min' VALUE 18,
      'alert_threshold_max' VALUE 26
    ),
    'installed_date' VALUE '2024-01-15'
  )
);

-- Insert an initial hourly bucket (empty, ready to receive readings)
INSERT INTO sensor_data (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'SENSOR#temp001#BUCKET#2024-11-18-14',
    'type' VALUE 'sensor_bucket',
    'sensor_id' VALUE 'temp001',
    'bucket_start' VALUE '2024-11-18T14:00:00Z',
    'bucket_end' VALUE '2024-11-18T14:59:59Z',
    'reading_count' VALUE 0,
    'readings' VALUE JSON_ARRAY(),
    'summary' VALUE JSON_OBJECT(
      'min' VALUE NULL,
      'max' VALUE NULL,
      'avg' VALUE NULL,
      'computed' VALUE FALSE
    )
  )
);

-- Query sensor with its bucket
SELECT JSON_SERIALIZE(data PRETTY)
FROM sensor_data
WHERE JSON_VALUE(data, '$._id') LIKE 'SENSOR#temp001%'
ORDER BY JSON_VALUE(data, '$._id');
```

### Step 3: Create Helper Functions for Bucket Management

```sql
-- Function to determine bucket ID from timestamp (hourly buckets)
CREATE OR REPLACE FUNCTION get_bucket_id(
  p_sensor_id VARCHAR2,
  p_timestamp TIMESTAMP
) RETURN VARCHAR2 IS
  v_bucket_hour VARCHAR2(13);
BEGIN
  -- Format: SENSOR#temp001#BUCKET#2024-11-18-14
  v_bucket_hour := TO_CHAR(p_timestamp, 'YYYY-MM-DD-HH24');
  RETURN 'SENSOR#' || p_sensor_id || '#BUCKET#' || v_bucket_hour;
END;
/

-- Test the function
SELECT get_bucket_id('temp001', TIMESTAMP '2024-11-18 14:35:42') AS bucket_id FROM DUAL;
```

Expected output:
```
BUCKET_ID
-----------------------------------
SENSOR#temp001#BUCKET#2024-11-18-14
```

### Step 4: Procedure to Append Readings to Buckets

```sql
-- Procedure to append a reading to the appropriate bucket
CREATE OR REPLACE PROCEDURE append_sensor_reading(
  p_sensor_id VARCHAR2,
  p_timestamp TIMESTAMP,
  p_value NUMBER
) IS
  v_bucket_id VARCHAR2(100);
  v_bucket_exists NUMBER;
  v_bucket_start TIMESTAMP;
BEGIN
  -- Determine bucket ID
  v_bucket_id := get_bucket_id(p_sensor_id, p_timestamp);
  v_bucket_start := TRUNC(p_timestamp, 'HH24');

  -- Check if bucket exists
  SELECT COUNT(*)
  INTO v_bucket_exists
  FROM sensor_data
  WHERE JSON_VALUE(data, '$._id') = v_bucket_id;

  -- Create bucket if it doesn't exist
  IF v_bucket_exists = 0 THEN
    INSERT INTO sensor_data (data) VALUES (
      JSON_OBJECT(
        '_id' VALUE v_bucket_id,
        'type' VALUE 'sensor_bucket',
        'sensor_id' VALUE p_sensor_id,
        'bucket_start' VALUE TO_CHAR(v_bucket_start, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'bucket_end' VALUE TO_CHAR(v_bucket_start + INTERVAL '1' HOUR - INTERVAL '1' SECOND, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'reading_count' VALUE 0,
        'readings' VALUE JSON_ARRAY(),
        'summary' VALUE JSON_OBJECT('computed' VALUE FALSE)
      )
    );
  END IF;

  -- Append reading to bucket using JSON_TRANSFORM
  UPDATE sensor_data
  SET data = JSON_TRANSFORM(
    data,
    APPEND '$.readings' = JSON_OBJECT(
      'timestamp' VALUE TO_CHAR(p_timestamp, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'value' VALUE p_value
    ),
    SET '$.reading_count' = (JSON_VALUE(data, '$.reading_count' RETURNING NUMBER) + 1)
  )
  WHERE JSON_VALUE(data, '$._id') = v_bucket_id;

  COMMIT;
END;
/
```

### Step 5: Test Appending Readings

```sql
-- Append 10 sample readings to the bucket
BEGIN
  FOR i IN 1..10 LOOP
    append_sensor_reading(
      'temp001',
      TIMESTAMP '2024-11-18 14:00:00' + INTERVAL '1' SECOND * i,
      22 + DBMS_RANDOM.VALUE(0, 5)
    );
  END LOOP;
END;
/

-- Verify the bucket now has readings
SELECT
  JSON_VALUE(data, '$._id') AS bucket_id,
  JSON_VALUE(data, '$.reading_count' RETURNING NUMBER) AS reading_count,
  LENGTHB(data) AS size_bytes
FROM sensor_data
WHERE JSON_VALUE(data, '$.type') = 'sensor_bucket';
```

Expected output:
```
BUCKET_ID                              READING_COUNT  SIZE_BYTES
-------------------------------------  -------------  ----------
SENSOR#temp001#BUCKET#2024-11-18-14               10         850
```

## Task 3: Generate Bulk Time-Series Data

### Step 1: Generate Data for Multiple Sensors

```sql
-- Generate realistic sensor data for multiple sensors
-- This creates 5 sensors with 24 hours of data each

DECLARE
  v_sensor_id VARCHAR2(20);
  v_bucket_id VARCHAR2(100);
  v_bucket_start TIMESTAMP;
  v_readings CLOB;
  v_min_val NUMBER;
  v_max_val NUMBER;
  v_sum_val NUMBER;
  v_value NUMBER;
BEGIN
  -- Create 5 sensors
  FOR sensor_num IN 1..5 LOOP
    v_sensor_id := 'temp' || LPAD(sensor_num, 3, '0');

    -- Insert sensor metadata
    INSERT INTO sensor_data (data) VALUES (
      JSON_OBJECT(
        '_id' VALUE 'SENSOR#' || v_sensor_id,
        'type' VALUE 'sensor',
        'sensor_id' VALUE v_sensor_id,
        'name' VALUE 'Temperature Sensor ' || sensor_num,
        'location' VALUE 'Zone ' || sensor_num,
        'unit' VALUE 'celsius'
      )
    );

    -- Generate 24 hours of data (24 hourly buckets per sensor)
    FOR hour_offset IN 0..23 LOOP
      v_bucket_start := TRUNC(SYSTIMESTAMP, 'DD') - INTERVAL '1' DAY + INTERVAL '1' HOUR * hour_offset;
      v_bucket_id := get_bucket_id(v_sensor_id, v_bucket_start);

      -- Initialize statistics
      v_min_val := 999;
      v_max_val := -999;
      v_sum_val := 0;

      -- Build readings array as JSON string (simplified - 60 readings per bucket for demo)
      v_readings := '[';
      FOR second_offset IN 0..59 LOOP
        v_value := ROUND(22 + DBMS_RANDOM.VALUE(-2, 4) + SIN(second_offset / 10) * 1.5, 2);

        IF second_offset > 0 THEN
          v_readings := v_readings || ',';
        END IF;

        v_readings := v_readings || '{"timestamp":"' ||
          TO_CHAR(v_bucket_start + INTERVAL '1' MINUTE * second_offset, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') ||
          '","value":' || v_value || '}';

        -- Update statistics
        v_sum_val := v_sum_val + v_value;
        IF v_value < v_min_val THEN v_min_val := v_value; END IF;
        IF v_value > v_max_val THEN v_max_val := v_value; END IF;
      END LOOP;
      v_readings := v_readings || ']';

      -- Insert bucket with readings
      INSERT INTO sensor_data (data) VALUES (
        JSON_OBJECT(
          '_id' VALUE v_bucket_id,
          'type' VALUE 'sensor_bucket',
          'sensor_id' VALUE v_sensor_id,
          'bucket_start' VALUE TO_CHAR(v_bucket_start, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
          'bucket_end' VALUE TO_CHAR(v_bucket_start + INTERVAL '1' HOUR - INTERVAL '1' SECOND, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
          'reading_count' VALUE 60,
          'readings' VALUE JSON(v_readings),
          'summary' VALUE JSON_OBJECT(
            'min' VALUE v_min_val,
            'max' VALUE v_max_val,
            'avg' VALUE ROUND(v_sum_val / 60, 2),
            'computed' VALUE TRUE,
            'computed_at' VALUE SYSTIMESTAMP
          )
        )
      );
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Generated 24 hours of data for sensor ' || v_sensor_id);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('=== Data Generation Complete ===');
  DBMS_OUTPUT.PUT_LINE('Sensors: 5');
  DBMS_OUTPUT.PUT_LINE('Hours per sensor: 24');
  DBMS_OUTPUT.PUT_LINE('Readings per hour: 60 (for demo)');
  DBMS_OUTPUT.PUT_LINE('Total readings: 7,200');
  DBMS_OUTPUT.PUT_LINE('Total buckets: 120');
END;
/
```

### Step 2: Verify Generated Data

```sql
-- Count documents by type
SELECT
  JSON_VALUE(data, '$.type') AS doc_type,
  COUNT(*) AS count,
  ROUND(AVG(LENGTHB(data)), 0) AS avg_size_bytes
FROM sensor_data
GROUP BY JSON_VALUE(data, '$.type');
```

Expected output:
```
DOC_TYPE        COUNT  AVG_SIZE_BYTES
-------------   -----  --------------
sensor              5             250
sensor_bucket     120            3200
```

## Task 4: Querying Bucketed Time-Series Data

### Step 1: Query Recent Data (Single Bucket)

```sql
-- Get the most recent bucket for a sensor
SELECT
  JSON_VALUE(data, '$._id') AS bucket_id,
  JSON_VALUE(data, '$.sensor_id') AS sensor_id,
  JSON_VALUE(data, '$.reading_count' RETURNING NUMBER) AS reading_count,
  JSON_VALUE(data, '$.summary.min' RETURNING NUMBER) AS min_temp,
  JSON_VALUE(data, '$.summary.max' RETURNING NUMBER) AS max_temp,
  JSON_VALUE(data, '$.summary.avg' RETURNING NUMBER) AS avg_temp,
  LENGTHB(data) AS size_bytes
FROM sensor_data
WHERE JSON_VALUE(data, '$.type') = 'sensor_bucket'
  AND JSON_VALUE(data, '$.sensor_id') = 'temp001'
ORDER BY JSON_VALUE(data, '$._id') DESC
FETCH FIRST 1 ROW ONLY;

-- Latency: 2-3ms (single document read with index)
```

### Step 2: Query Time Range (Multiple Buckets)

```sql
-- Get 6 hours of data using composite key prefix
SELECT
  JSON_VALUE(data, '$._id') AS bucket_id,
  JSON_VALUE(data, '$.bucket_start') AS bucket_start,
  JSON_VALUE(data, '$.reading_count' RETURNING NUMBER) AS reading_count,
  JSON_VALUE(data, '$.summary.avg' RETURNING NUMBER) AS avg_temp,
  ROUND(LENGTHB(data) / 1024, 2) AS size_kb
FROM sensor_data
WHERE JSON_VALUE(data, '$._id') >= 'SENSOR#temp001#BUCKET#2024-11-17-08'
  AND JSON_VALUE(data, '$._id') < 'SENSOR#temp001#BUCKET#2024-11-17-15'
  AND JSON_VALUE(data, '$.type') = 'sensor_bucket'
ORDER BY JSON_VALUE(data, '$._id');

-- Efficient range scan using composite key prefix
-- Latency: 8-12ms for 6 buckets
```

### Step 3: Extract Individual Readings from Bucket

```sql
-- Extract all readings from a specific bucket using JSON_TABLE
SELECT
  jt.reading_timestamp,
  jt.value
FROM sensor_data,
     JSON_TABLE(
       data,
       '$.readings[*]'
       COLUMNS (
         reading_timestamp VARCHAR2(30) PATH '$.timestamp',
         value NUMBER PATH '$.value'
       )
     ) jt
WHERE JSON_VALUE(data, '$.type') = 'sensor_bucket'
  AND JSON_VALUE(data, '$.sensor_id') = 'temp001'
ORDER BY JSON_VALUE(data, '$._id') DESC, jt.reading_timestamp
FETCH FIRST 10 ROWS ONLY;
```

### Step 4: Aggregate Across Multiple Buckets

```sql
-- Get daily summary across all buckets for a sensor
SELECT
  SUBSTR(JSON_VALUE(data, '$.bucket_start'), 1, 10) AS date_str,
  JSON_VALUE(data, '$.sensor_id') AS sensor_id,
  SUM(JSON_VALUE(data, '$.reading_count' RETURNING NUMBER)) AS total_readings,
  ROUND(MIN(JSON_VALUE(data, '$.summary.min' RETURNING NUMBER)), 2) AS min_temp,
  ROUND(MAX(JSON_VALUE(data, '$.summary.max' RETURNING NUMBER)), 2) AS max_temp,
  ROUND(AVG(JSON_VALUE(data, '$.summary.avg' RETURNING NUMBER)), 2) AS avg_temp
FROM sensor_data
WHERE JSON_VALUE(data, '$.type') = 'sensor_bucket'
  AND JSON_VALUE(data, '$.sensor_id') = 'temp001'
GROUP BY
  SUBSTR(JSON_VALUE(data, '$.bucket_start'), 1, 10),
  JSON_VALUE(data, '$.sensor_id')
ORDER BY date_str;

-- Aggregates 24 buckets efficiently using pre-computed summaries
```

## Task 5: Performance Comparison - Bucketed vs Unbucketed

### Step 1: Create Unbucketed Comparison Data

```sql
-- Create unbucketed collection for comparison
CREATE JSON COLLECTION TABLE sensor_data_unbucketed;

-- Create index
CREATE INDEX idx_unbucketed_sensor ON sensor_data_unbucketed (JSON_VALUE(data, '$.sensor_id'));

-- Load 1000 unbucketed readings using CONNECT BY (efficient bulk insert)
INSERT INTO sensor_data_unbucketed (data)
SELECT JSON_OBJECT(
  '_id' VALUE 'READING#temp001#' || LPAD(LEVEL-1, 6, '0'),
  'type' VALUE 'reading',
  'sensor_id' VALUE 'temp001',
  'timestamp' VALUE TO_CHAR(SYSTIMESTAMP + INTERVAL '1' SECOND * (LEVEL-1), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  'value' VALUE ROUND(22 + DBMS_RANDOM.VALUE(-2, 4), 2)
)
FROM DUAL
CONNECT BY LEVEL <= 1000;

COMMIT;
```

### Step 2: Compare Storage Efficiency

```sql
-- Compare storage efficiency
SELECT
  'Bucketed (24 hours)' AS approach,
  COUNT(*) AS document_count,
  ROUND(SUM(LENGTHB(data)) / 1024, 2) AS total_size_kb,
  ROUND(AVG(LENGTHB(data)), 0) AS avg_doc_size_bytes
FROM sensor_data
WHERE JSON_VALUE(data, '$.type') = 'sensor_bucket'
  AND JSON_VALUE(data, '$.sensor_id') = 'temp001'
UNION ALL
SELECT
  'Unbucketed (1000 readings)' AS approach,
  COUNT(*) AS document_count,
  ROUND(SUM(LENGTHB(data)) / 1024, 2) AS total_size_kb,
  ROUND(AVG(LENGTHB(data)), 0) AS avg_doc_size_bytes
FROM sensor_data_unbucketed
WHERE JSON_VALUE(data, '$.sensor_id') = 'temp001';
```

Expected output:
```
APPROACH                    DOCUMENT_COUNT  TOTAL_SIZE_KB  AVG_DOC_SIZE_BYTES
--------------------------  --------------  -------------  ------------------
Bucketed (24 hours)                     24          76.80                3200
Unbucketed (1000 readings)            1000         195.00                 195

Key Insights:
- Bucketed: 24 documents covering 24 hours of data
- Unbucketed: 1000 documents for just 1000 readings
- Bucketing provides ~40x reduction in document count
```

### Step 3: Benchmark Query Performance

```sql
SET SERVEROUTPUT ON;

-- Test bucketed query
DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_duration NUMBER;
  v_count NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Bucketed Query (summary from buckets) ===');

  v_start := SYSTIMESTAMP;

  SELECT SUM(JSON_VALUE(data, '$.reading_count' RETURNING NUMBER))
  INTO v_count
  FROM sensor_data
  WHERE JSON_VALUE(data, '$.type') = 'sensor_bucket'
    AND JSON_VALUE(data, '$.sensor_id') = 'temp001';

  v_end := SYSTIMESTAMP;
  v_duration := EXTRACT(SECOND FROM (v_end - v_start)) * 1000;

  DBMS_OUTPUT.PUT_LINE('Total readings: ' || v_count);
  DBMS_OUTPUT.PUT_LINE('Query time: ' || ROUND(v_duration, 2) || ' ms');
  DBMS_OUTPUT.PUT_LINE('Documents scanned: 24 buckets');
END;
/

-- Test unbucketed query
DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_duration NUMBER;
  v_count NUMBER;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Unbucketed Query (count documents) ===');

  v_start := SYSTIMESTAMP;

  SELECT COUNT(*)
  INTO v_count
  FROM sensor_data_unbucketed
  WHERE JSON_VALUE(data, '$.sensor_id') = 'temp001';

  v_end := SYSTIMESTAMP;
  v_duration := EXTRACT(SECOND FROM (v_end - v_start)) * 1000;

  DBMS_OUTPUT.PUT_LINE('Total readings: ' || v_count);
  DBMS_OUTPUT.PUT_LINE('Query time: ' || ROUND(v_duration, 2) || ' ms');
  DBMS_OUTPUT.PUT_LINE('Documents scanned: 1000 documents');
END;
/
```

## Task 6: Handling Bucket Overflow

### Step 1: Monitor Bucket Size

```sql
-- Check bucket sizes to detect potential overflow
SELECT
  JSON_VALUE(data, '$._id') AS bucket_id,
  JSON_VALUE(data, '$.sensor_id') AS sensor_id,
  JSON_VALUE(data, '$.reading_count' RETURNING NUMBER) AS reading_count,
  ROUND(LENGTHB(data) / 1024, 2) AS size_kb,
  CASE
    WHEN LENGTHB(data) < 7950 THEN 'Inline (Optimal)'
    WHEN LENGTHB(data) < 102400 THEN 'LOB (Good)'
    WHEN LENGTHB(data) < 524288 THEN 'LOB (Acceptable)'
    ELSE 'LOB (Too Large - Split Required)'
  END AS storage_tier
FROM sensor_data
WHERE JSON_VALUE(data, '$.type') = 'sensor_bucket'
ORDER BY LENGTHB(data) DESC
FETCH FIRST 10 ROWS ONLY;
```

### Step 2: Create 10-Minute Bucket Function (for Higher Volume)

If your data volume exceeds expectations, split buckets into smaller time windows:

```sql
-- Function for 10-minute buckets (for higher volume data)
CREATE OR REPLACE FUNCTION get_bucket_id_10min(
  p_sensor_id VARCHAR2,
  p_timestamp TIMESTAMP
) RETURN VARCHAR2 IS
  v_bucket VARCHAR2(16);
BEGIN
  -- Format: SENSOR#temp001#BUCKET#2024-11-18-1430 (10-minute bucket)
  v_bucket := TO_CHAR(p_timestamp, 'YYYY-MM-DD-HH24') ||
              LPAD(TRUNC(TO_NUMBER(TO_CHAR(p_timestamp, 'MI')) / 10) * 10, 2, '0');
  RETURN 'SENSOR#' || p_sensor_id || '#BUCKET#' || v_bucket;
END;
/

-- Test the function - compare 10-minute vs hourly buckets
SELECT
  get_bucket_id_10min('temp001', TIMESTAMP '2024-11-18 14:35:42') AS bucket_10min,
  get_bucket_id('temp001', TIMESTAMP '2024-11-18 14:35:42') AS bucket_1hour
FROM DUAL;
```

Expected output:
```
BUCKET_10MIN                             BUCKET_1HOUR
---------------------------------------  -------------------------------------
SENSOR#temp001#BUCKET#2024-11-18-1430   SENSOR#temp001#BUCKET#2024-11-18-14
```

### Step 3: Guidelines for Bucket Size Selection

```
Original: 1-hour buckets (3,600 readings at 1/sec)
If readings increase to 10/sec: 36,000 readings/hour = ~5MB/bucket (too large!)

Solutions:
1. Switch to 10-minute buckets: 6,000 readings/bucket = ~800KB (acceptable)
2. Switch to 1-minute buckets: 600 readings/bucket = ~80KB (optimal)
3. Reduce reading granularity: sample every 10 seconds instead of every second
```

## Task 7: Cleanup

```sql
-- Clean up comparison table
DROP TABLE sensor_data_unbucketed PURGE;

-- Keep sensor_data for subsequent labs or clean up:
-- DROP TABLE sensor_data PURGE;
```

## Conclusion

In this lab, you learned how to implement the Bucketing Pattern for efficiently managing high-volume time-series data in Oracle JSON Collection Tables.

**Key Takeaways:**
- ✅ Bucketing reduces document count by 99%+ for time-series data
- ✅ Query performance improves significantly (scanning buckets vs individual readings)
- ✅ Use composite keys for time-based buckets (`SENSOR#id#BUCKET#YYYY-MM-DD-HH`)
- ✅ Choose bucket size to keep documents under 500KB (ideally under 200KB)
- ✅ Store pre-computed summary statistics per bucket for fast aggregations
- ✅ Monitor bucket sizes and split if they grow too large
- ✅ Use JSON_TRANSFORM APPEND for atomic array updates

**Bucket Sizing Guidelines:**
- 1 reading/sec → 1-hour buckets (~50-100KB)
- 10 readings/sec → 10-minute buckets (~80-150KB)
- 100 readings/sec → 1-minute buckets (~100-200KB)

**Next Steps:**
- Proceed to **Lab 6: Polymorphic Pattern** to learn how to store multiple entity types efficiently in a single collection

## Learn More

* [Oracle JSON Developer's Guide - Arrays and Nested Documents](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/)
* [MongoDB Bucket Pattern Documentation](https://www.mongodb.com/docs/manual/data-modeling/design-patterns/bucket-pattern/)
* [Time-Series Data Best Practices](https://www.mongodb.com/docs/manual/core/timeseries-collections/)

## Acknowledgments

* **Author** - Rick Houlihan
* **Last Updated By/Date** - November 2025
