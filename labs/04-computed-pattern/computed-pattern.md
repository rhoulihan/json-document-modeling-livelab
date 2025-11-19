# Lab 4: Computed Pattern and Aggregations

## Introduction

The Computed Pattern involves pre-calculating and storing aggregate values, statistics, and derived data within documents to avoid expensive runtime calculations. This pattern is essential when you need to display metrics, dashboards, or summary statistics frequently without the overhead of real-time aggregation queries.

In this lab, you will learn how to implement the Computed Pattern within a Single Collection design, using composite keys to organize computed results alongside your operational data.

**Estimated Time:** 45 minutes

## Prerequisites

- Completed Lab 3: Single Collection/Table Design Pattern
- Understanding of composite keys and Single Collection design
- Familiarity with JSON aggregation operations

## Objectives

In this lab, you will:
- Understand when to use the Computed Pattern vs real-time aggregation
- Implement pre-computed metrics within a Single Collection
- Use composite keys to organize computed results (e.g., `CUSTOMER#456#STATS#2024-11`)
- Create update strategies for maintaining computed values
- Measure performance improvements from pre-computation
- Design appropriate triggers or batch jobs for computation updates

## Task 1: Understanding the Computed Pattern

### Step 1: The Problem with Real-Time Aggregation

Consider a social media application where you need to display engagement metrics for posts:

```sql
-- Real-time aggregation (SLOW for popular posts)
SELECT
  post_id,
  COUNT(CASE WHEN type = 'like' THEN 1 END) as like_count,
  COUNT(CASE WHEN type = 'comment' THEN 1 END) as comment_count,
  COUNT(CASE WHEN type = 'share' THEN 1 END) as share_count
FROM social_data
WHERE JSON_VALUE(json_document, '$.post_id') = 'POST-12345'
  AND JSON_VALUE(json_document, '$.type') IN ('like', 'comment', 'share')
GROUP BY post_id;

-- Problem: Scans thousands of engagement documents for popular posts
-- Latency: 100-500ms for popular posts with 10,000+ engagements
```

**Issues with real-time aggregation:**
- ❌ Expensive table scans or index scans across thousands of documents
- ❌ High latency (100-500ms) for frequently accessed metrics
- ❌ Increased database load during peak traffic
- ❌ Poor user experience (slow dashboard loads)

### Step 2: The Solution - Pre-Computed Metrics

Store computed metrics directly in the document:

```json
{
  "_id": "POST#12345",
  "type": "post",
  "user_id": "USER-789",
  "content": "Check out this amazing photo!",
  "created_at": "2024-11-18T10:30:00Z",

  // Pre-computed engagement metrics (updated incrementally)
  "engagement": {
    "like_count": 1247,
    "comment_count": 89,
    "share_count": 34,
    "view_count": 15420,
    "last_updated": "2024-11-19T14:22:00Z"
  }
}
```

**Benefits:**
- ✅ Single document read (2-5ms latency)
- ✅ No aggregation queries needed
- ✅ Scales to millions of engagements
- ✅ Simple increment operations

### Step 3: When to Use the Computed Pattern

**Use the Computed Pattern when:**
- ✅ Metrics are read far more often than written (read-heavy, 100:1 ratio or higher)
- ✅ Exact real-time accuracy is not required (eventual consistency acceptable)
- ✅ Aggregation queries are expensive (many documents to scan)
- ✅ Response time requirements are strict (< 10ms)

**Avoid the Computed Pattern when:**
- ❌ Exact real-time accuracy is critical (financial transactions, inventory)
- ❌ Write frequency is very high relative to reads (write-heavy)
- ❌ Aggregation is already fast (< 10ms)
- ❌ Storage cost is more important than query performance

## Task 2: Implementing Computed Metrics in Single Collection

### Step 1: Design the Data Model

Let's build a social media application with posts, likes, comments, and shares in a Single Collection:

```sql
-- Create the social media collection
CREATE TABLE social_data (
  id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
  json_document JSON,
  created_on TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Insert a post with initial computed metrics
INSERT INTO social_data (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'POST#12345',
    'type' VALUE 'post',
    'user_id' VALUE 'USER-789',
    'user_name' VALUE 'Alice Smith',
    'content' VALUE 'Check out this amazing photo!',
    'created_at' VALUE SYSTIMESTAMP,
    'engagement' VALUE JSON_OBJECT(
      'like_count' VALUE 0,
      'comment_count' VALUE 0,
      'share_count' VALUE 0,
      'view_count' VALUE 0,
      'last_updated' VALUE SYSTIMESTAMP
    )
  )
);

-- Insert engagement events (individual documents)
-- Note: We store these as separate documents but maintain computed totals in the post
INSERT INTO social_data (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'POST#12345#LIKE#USER-456',
    'type' VALUE 'like',
    'post_id' VALUE 'POST#12345',
    'user_id' VALUE 'USER-456',
    'user_name' VALUE 'Bob Johnson',
    'created_at' VALUE SYSTIMESTAMP
  )
);

-- Query the post (fast - single document read)
SELECT JSON_QUERY(json_document, '$' PRETTY)
FROM social_data
WHERE JSON_VALUE(json_document, '$._id') = 'POST#12345';

/*
Result (2-3ms):
{
  "_id": "POST#12345",
  "type": "post",
  "content": "Check out this amazing photo!",
  "engagement": {
    "like_count": 1247,
    "comment_count": 89,
    "share_count": 34
  }
}
*/
```

### Step 2: Update Strategies for Computed Metrics

**Strategy 1: Increment on Write (Immediate Consistency)**

```sql
-- Update the computed metric when a like is added
-- This ensures metrics are always current

-- 1. Insert the like event
INSERT INTO social_data (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'POST#12345#LIKE#USER-999',
    'type' VALUE 'like',
    'post_id' VALUE 'POST#12345',
    'user_id' VALUE 'USER-999',
    'created_at' VALUE SYSTIMESTAMP
  )
);

-- 2. Increment the like_count in the post document
UPDATE social_data
SET json_document = JSON_MERGEPATCH(
  json_document,
  JSON_OBJECT(
    'engagement' VALUE JSON_OBJECT(
      'like_count' VALUE (
        SELECT JSON_VALUE(json_document, '$.engagement.like_count') + 1
        FROM social_data
        WHERE JSON_VALUE(json_document, '$._id') = 'POST#12345'
      ),
      'last_updated' VALUE SYSTIMESTAMP
    )
  )
)
WHERE JSON_VALUE(json_document, '$._id') = 'POST#12345';

COMMIT;
```

**Strategy 2: Batch Update (Eventual Consistency)**

```sql
-- Update computed metrics in batches (every 5 minutes)
-- Better for high-velocity data

BEGIN
  -- Update engagement counts for all posts based on actual event counts
  FOR post_rec IN (
    SELECT DISTINCT JSON_VALUE(json_document, '$.post_id') AS post_id
    FROM social_data
    WHERE JSON_VALUE(json_document, '$.type') IN ('like', 'comment', 'share')
      AND JSON_VALUE(json_document, '$.created_at' RETURNING TIMESTAMP)
          > SYSTIMESTAMP - INTERVAL '5' MINUTE
  ) LOOP
    -- Count likes
    DECLARE
      v_like_count NUMBER;
      v_comment_count NUMBER;
      v_share_count NUMBER;
    BEGIN
      SELECT
        COUNT(CASE WHEN JSON_VALUE(json_document, '$.type') = 'like' THEN 1 END),
        COUNT(CASE WHEN JSON_VALUE(json_document, '$.type') = 'comment' THEN 1 END),
        COUNT(CASE WHEN JSON_VALUE(json_document, '$.type') = 'share' THEN 1 END)
      INTO v_like_count, v_comment_count, v_share_count
      FROM social_data
      WHERE JSON_VALUE(json_document, '$.post_id') = post_rec.post_id
        AND JSON_VALUE(json_document, '$.type') IN ('like', 'comment', 'share');

      -- Update post document
      UPDATE social_data
      SET json_document = JSON_MERGEPATCH(
        json_document,
        JSON_OBJECT(
          'engagement' VALUE JSON_OBJECT(
            'like_count' VALUE v_like_count,
            'comment_count' VALUE v_comment_count,
            'share_count' VALUE v_share_count,
            'last_updated' VALUE SYSTIMESTAMP
          )
        )
      )
      WHERE JSON_VALUE(json_document, '$._id') = 'POST#' || post_rec.post_id;
    END;
  END LOOP;

  COMMIT;
END;
/
```

### Step 3: Using Composite Keys for Time-Series Computed Data

Store monthly customer statistics using composite keys:

```sql
-- Insert customer document
INSERT INTO social_data (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'CUSTOMER#456',
    'type' VALUE 'customer',
    'name' VALUE 'John Doe',
    'email' VALUE 'john@example.com',
    'tier' VALUE 'gold',
    'joined_date' VALUE '2023-01-15'
  )
);

-- Insert monthly computed statistics (separate document)
INSERT INTO social_data (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'CUSTOMER#456#STATS#2024-11',
    'type' VALUE 'customer_monthly_stats',
    'customer_id' VALUE 'CUSTOMER#456',
    'month' VALUE '2024-11',
    'stats' VALUE JSON_OBJECT(
      'total_orders' VALUE 12,
      'total_spent' VALUE 1450.25,
      'avg_order_value' VALUE 120.85,
      'items_purchased' VALUE 47,
      'returns' VALUE 2
    ),
    'computed_at' VALUE SYSTIMESTAMP
  )
);

-- Query customer with recent monthly stats
SELECT JSON_QUERY(json_document, '$' PRETTY)
FROM social_data
WHERE JSON_VALUE(json_document, '$._id') IN (
  'CUSTOMER#456',
  'CUSTOMER#456#STATS#2024-11',
  'CUSTOMER#456#STATS#2024-10'
);

-- Query all stats for a customer (composite key prefix)
SELECT JSON_QUERY(json_document, '$' PRETTY)
FROM social_data
WHERE JSON_VALUE(json_document, '$._id') LIKE 'CUSTOMER#456#STATS#%'
ORDER BY JSON_VALUE(json_document, '$.month') DESC;
```

## Task 3: Advanced Computed Pattern - Cascading Aggregations

### Step 1: Multi-Level Aggregation Hierarchy

For complex analytics, you may need multiple levels of computed aggregations:

```sql
-- Level 1: Individual post metrics (updated on each engagement)
INSERT INTO social_data (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'POST#12345',
    'type' VALUE 'post',
    'user_id' VALUE 'USER-789',
    'engagement' VALUE JSON_OBJECT(
      'like_count' VALUE 1247,
      'comment_count' VALUE 89
    )
  )
);

-- Level 2: Daily user statistics (computed from posts)
INSERT INTO social_data (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'USER#789#STATS#2024-11-18',
    'type' VALUE 'user_daily_stats',
    'user_id' VALUE 'USER-789',
    'date' VALUE '2024-11-18',
    'stats' VALUE JSON_OBJECT(
      'posts_created' VALUE 5,
      'total_likes_received' VALUE 3421,
      'total_comments_received' VALUE 234,
      'engagement_rate' VALUE 0.082
    ),
    'computed_at' VALUE SYSTIMESTAMP
  )
);

-- Level 3: Monthly user statistics (computed from daily stats)
INSERT INTO social_data (json_document) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'USER#789#STATS#2024-11',
    'type' VALUE 'user_monthly_stats',
    'user_id' VALUE 'USER-789',
    'month' VALUE '2024-11',
    'stats' VALUE JSON_OBJECT(
      'posts_created' VALUE 87,
      'total_likes_received' VALUE 54230,
      'total_comments_received' VALUE 4521,
      'avg_engagement_rate' VALUE 0.078,
      'follower_growth' VALUE 423
    ),
    'computed_at' VALUE SYSTIMESTAMP
  )
);

-- Query user with monthly stats (single query)
SELECT JSON_QUERY(json_document, '$' PRETTY)
FROM social_data
WHERE JSON_VALUE(json_document, '$._id') IN ('USER#789', 'USER#789#STATS#2024-11');
```

### Step 2: Batch Computation Job for Cascading Aggregations

```sql
-- Daily batch job to compute user statistics from posts
DECLARE
  v_user_id VARCHAR2(100);
  v_date VARCHAR2(10) := TO_CHAR(SYSDATE, 'YYYY-MM-DD');
BEGIN
  -- Loop through active users
  FOR user_rec IN (
    SELECT DISTINCT JSON_VALUE(json_document, '$.user_id') AS user_id
    FROM social_data
    WHERE JSON_VALUE(json_document, '$.type') = 'post'
      AND JSON_VALUE(json_document, '$.created_at' RETURNING TIMESTAMP)
          >= TRUNC(SYSDATE)
  ) LOOP
    DECLARE
      v_posts_created NUMBER;
      v_total_likes NUMBER := 0;
      v_total_comments NUMBER := 0;
    BEGIN
      -- Count posts created today
      SELECT COUNT(*)
      INTO v_posts_created
      FROM social_data
      WHERE JSON_VALUE(json_document, '$.type') = 'post'
        AND JSON_VALUE(json_document, '$.user_id') = user_rec.user_id
        AND JSON_VALUE(json_document, '$.created_at' RETURNING TIMESTAMP) >= TRUNC(SYSDATE);

      -- Sum engagement metrics from posts
      SELECT
        SUM(JSON_VALUE(json_document, '$.engagement.like_count' RETURNING NUMBER)) AS total_likes,
        SUM(JSON_VALUE(json_document, '$.engagement.comment_count' RETURNING NUMBER)) AS total_comments
      INTO v_total_likes, v_total_comments
      FROM social_data
      WHERE JSON_VALUE(json_document, '$.type') = 'post'
        AND JSON_VALUE(json_document, '$.user_id') = user_rec.user_id
        AND JSON_VALUE(json_document, '$.created_at' RETURNING TIMESTAMP) >= TRUNC(SYSDATE);

      -- Insert or update daily stats document
      MERGE INTO social_data dst
      USING (
        SELECT 'USER#' || user_rec.user_id || '#STATS#' || v_date AS doc_id FROM DUAL
      ) src
      ON (JSON_VALUE(dst.json_document, '$._id') = src.doc_id)
      WHEN MATCHED THEN
        UPDATE SET dst.json_document = JSON_MERGEPATCH(
          dst.json_document,
          JSON_OBJECT(
            'stats' VALUE JSON_OBJECT(
              'posts_created' VALUE v_posts_created,
              'total_likes_received' VALUE v_total_likes,
              'total_comments_received' VALUE v_total_comments
            ),
            'computed_at' VALUE SYSTIMESTAMP
          )
        )
      WHEN NOT MATCHED THEN
        INSERT (json_document) VALUES (
          JSON_OBJECT(
            '_id' VALUE 'USER#' || user_rec.user_id || '#STATS#' || v_date,
            'type' VALUE 'user_daily_stats',
            'user_id' VALUE user_rec.user_id,
            'date' VALUE v_date,
            'stats' VALUE JSON_OBJECT(
              'posts_created' VALUE v_posts_created,
              'total_likes_received' VALUE v_total_likes,
              'total_comments_received' VALUE v_total_comments
            ),
            'computed_at' VALUE SYSTIMESTAMP
          )
        );
    END;
  END LOOP;

  COMMIT;
END;
/
```

## Task 4: Performance Comparison - Computed vs Real-Time

### Step 1: Load Test Data

```sql
-- Create sample posts with varying engagement levels
BEGIN
  -- Insert 100 posts
  FOR i IN 1..100 LOOP
    INSERT INTO social_data (json_document) VALUES (
      JSON_OBJECT(
        '_id' VALUE 'POST#' || LPAD(i, 5, '0'),
        'type' VALUE 'post',
        'user_id' VALUE 'USER-' || MOD(i, 10),
        'content' VALUE 'Sample post content ' || i,
        'created_at' VALUE SYSTIMESTAMP - INTERVAL '1' DAY * (100 - i),
        'engagement' VALUE JSON_OBJECT(
          'like_count' VALUE 0,
          'comment_count' VALUE 0,
          'share_count' VALUE 0,
          'last_updated' VALUE SYSTIMESTAMP
        )
      )
    );

    -- Insert likes for each post (varying count)
    FOR j IN 1..MOD(i, 50) + 10 LOOP
      INSERT INTO social_data (json_document) VALUES (
        JSON_OBJECT(
          '_id' VALUE 'POST#' || LPAD(i, 5, '0') || '#LIKE#USER-' || j,
          'type' VALUE 'like',
          'post_id' VALUE 'POST#' || LPAD(i, 5, '0'),
          'user_id' VALUE 'USER-' || j,
          'created_at' VALUE SYSTIMESTAMP - INTERVAL '1' HOUR * j
        )
      );
    END LOOP;
  END LOOP;

  COMMIT;
END;
/

-- Update computed metrics for all posts
BEGIN
  FOR post_rec IN (
    SELECT DISTINCT JSON_VALUE(json_document, '$._id') AS post_id
    FROM social_data
    WHERE JSON_VALUE(json_document, '$.type') = 'post'
  ) LOOP
    DECLARE
      v_like_count NUMBER;
    BEGIN
      SELECT COUNT(*)
      INTO v_like_count
      FROM social_data
      WHERE JSON_VALUE(json_document, '$.post_id') = post_rec.post_id
        AND JSON_VALUE(json_document, '$.type') = 'like';

      UPDATE social_data
      SET json_document = JSON_MERGEPATCH(
        json_document,
        JSON_OBJECT(
          'engagement' VALUE JSON_OBJECT(
            'like_count' VALUE v_like_count,
            'last_updated' VALUE SYSTIMESTAMP
          )
        )
      )
      WHERE JSON_VALUE(json_document, '$._id') = post_rec.post_id;
    END;
  END LOOP;

  COMMIT;
END;
/
```

### Step 2: Benchmark Real-Time Aggregation

```sql
-- Test 1: Real-time aggregation (NO computed pattern)
SET SERVEROUTPUT ON;

DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_duration NUMBER;
  v_like_count NUMBER;
  v_total_duration NUMBER := 0;
  v_iterations NUMBER := 100;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Real-Time Aggregation Benchmark ===');

  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;

    -- Real-time count query
    SELECT COUNT(*)
    INTO v_like_count
    FROM social_data
    WHERE JSON_VALUE(json_document, '$.post_id') = 'POST#00025'
      AND JSON_VALUE(json_document, '$.type') = 'like';

    v_end := SYSTIMESTAMP;
    v_duration := EXTRACT(DAY FROM (v_end - v_start)) * 86400000
                + EXTRACT(HOUR FROM (v_end - v_start)) * 3600000
                + EXTRACT(MINUTE FROM (v_end - v_start)) * 60000
                + EXTRACT(SECOND FROM (v_end - v_start)) * 1000;

    v_total_duration := v_total_duration + v_duration;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Average query time: ' || ROUND(v_total_duration / v_iterations, 2) || ' ms');
  DBMS_OUTPUT.PUT_LINE('Total time for ' || v_iterations || ' queries: ' || ROUND(v_total_duration, 2) || ' ms');
END;
/

/*
Expected Output:
=== Real-Time Aggregation Benchmark ===
Average query time: 8.45 ms
Total time for 100 queries: 845.20 ms
*/
```

### Step 3: Benchmark Computed Pattern

```sql
-- Test 2: Computed pattern (read pre-computed value)
SET SERVEROUTPUT ON;

DECLARE
  v_start TIMESTAMP;
  v_end TIMESTAMP;
  v_duration NUMBER;
  v_like_count NUMBER;
  v_total_duration NUMBER := 0;
  v_iterations NUMBER := 100;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== Computed Pattern Benchmark ===');

  FOR i IN 1..v_iterations LOOP
    v_start := SYSTIMESTAMP;

    -- Read pre-computed value from post document
    SELECT JSON_VALUE(json_document, '$.engagement.like_count' RETURNING NUMBER)
    INTO v_like_count
    FROM social_data
    WHERE JSON_VALUE(json_document, '$._id') = 'POST#00025';

    v_end := SYSTIMESTAMP;
    v_duration := EXTRACT(DAY FROM (v_end - v_start)) * 86400000
                + EXTRACT(HOUR FROM (v_end - v_start)) * 3600000
                + EXTRACT(MINUTE FROM (v_end - v_start)) * 60000
                + EXTRACT(SECOND FROM (v_end - v_start)) * 1000;

    v_total_duration := v_total_duration + v_duration;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Average query time: ' || ROUND(v_total_duration / v_iterations, 2) || ' ms');
  DBMS_OUTPUT.PUT_LINE('Total time for ' || v_iterations || ' queries: ' || ROUND(v_total_duration, 2) || ' ms');
END;
/

/*
Expected Output:
=== Computed Pattern Benchmark ===
Average query time: 1.85 ms
Total time for 100 queries: 185.40 ms
*/
```

### Step 4: Performance Comparison Summary

```sql
-- Summary comparison
SELECT
  'Real-Time Aggregation' AS method,
  '8.45 ms' AS avg_query_time,
  '845 ms' AS total_time_100_queries,
  'Baseline' AS improvement
FROM DUAL
UNION ALL
SELECT
  'Computed Pattern' AS method,
  '1.85 ms' AS avg_query_time,
  '185 ms' AS total_time_100_queries,
  '4.6x faster' AS improvement
FROM DUAL;

/*
Expected Results:

METHOD                    AVG_QUERY_TIME   TOTAL_TIME_100_QUERIES   IMPROVEMENT
------------------------  ---------------  -----------------------  ------------
Real-Time Aggregation     8.45 ms          845 ms                   Baseline
Computed Pattern          1.85 ms          185 ms                   4.6x faster

Key Insights:
- Computed pattern is 4-5x faster for read operations
- For high-traffic applications (1M reads/day), this saves significant database resources
- Trade-off: Slightly more complex write logic (increment operations)
- Best for: Dashboards, analytics, frequently accessed metrics
*/
```

## Task 5: Best Practices for the Computed Pattern

### Step 1: Design Checklist

When implementing the Computed Pattern, follow this checklist:

**Data Design:**
- [ ] Identify metrics that are read far more often than written (100:1 ratio or higher)
- [ ] Determine acceptable staleness for computed values (real-time, 5 min, hourly, daily?)
- [ ] Design composite keys for time-series computed data (`ENTITY#ID#STATS#YYYY-MM`)
- [ ] Store metadata about when values were last computed (`computed_at` timestamp)
- [ ] Keep computed documents small (< 10KB) to avoid LOB storage

**Update Strategy:**
- [ ] Choose update strategy: immediate (on write) or batch (scheduled job)
- [ ] Implement idempotent updates to handle retries safely
- [ ] Consider using atomic increment operations for counters
- [ ] Add validation to ensure computed values don't drift from source data
- [ ] Schedule periodic full reconciliation jobs to correct any drift

**Performance:**
- [ ] Index fields used to filter computed documents (`type`, `entity_id`, `month`)
- [ ] Monitor query performance to validate improvement from computed pattern
- [ ] Set alerts for staleness (e.g., computed values older than expected)

### Step 2: Common Pitfalls to Avoid

**❌ Anti-Pattern 1: Over-Computing**
```json
// DON'T compute values that are rarely accessed
{
  "_id": "USER#123",
  "stats": {
    "posts_on_tuesdays": 42,              // ❌ Too specific, rarely used
    "avg_word_count_in_comments": 15.7,   // ❌ Not valuable enough
    "third_quartile_engagement": 0.082    // ❌ Complex, rarely needed
  }
}

// DO compute frequently accessed, valuable metrics
{
  "_id": "USER#123",
  "stats": {
    "total_posts": 247,              // ✅ Frequently displayed
    "follower_count": 1420,          // ✅ Displayed on every profile view
    "engagement_rate": 0.078         // ✅ Used for ranking/recommendations
  }
}
```

**❌ Anti-Pattern 2: Stale Computed Values Without Metadata**
```json
// DON'T store computed values without tracking when they were computed
{
  "_id": "POST#12345",
  "like_count": 1247    // ❌ How old is this value? Is it current?
}

// DO include metadata about computation
{
  "_id": "POST#12345",
  "engagement": {
    "like_count": 1247,
    "last_updated": "2024-11-19T14:22:00Z",    // ✅ Know when computed
    "update_method": "realtime_increment"       // ✅ Understand accuracy
  }
}
```

**❌ Anti-Pattern 3: Ignoring Drift Between Computed and Source Data**
```sql
-- DON'T ignore discrepancies between computed and source data

-- DO implement periodic reconciliation
DECLARE
  v_computed_count NUMBER;
  v_actual_count NUMBER;
BEGIN
  FOR post_rec IN (
    SELECT JSON_VALUE(json_document, '$._id') AS post_id
    FROM social_data
    WHERE JSON_VALUE(json_document, '$.type') = 'post'
  ) LOOP
    -- Get computed count
    SELECT JSON_VALUE(json_document, '$.engagement.like_count' RETURNING NUMBER)
    INTO v_computed_count
    FROM social_data
    WHERE JSON_VALUE(json_document, '$._id') = post_rec.post_id;

    -- Get actual count
    SELECT COUNT(*)
    INTO v_actual_count
    FROM social_data
    WHERE JSON_VALUE(json_document, '$.post_id') = post_rec.post_id
      AND JSON_VALUE(json_document, '$.type') = 'like';

    -- Fix drift if found
    IF v_computed_count != v_actual_count THEN
      DBMS_OUTPUT.PUT_LINE('Drift detected for ' || post_rec.post_id ||
                          ': computed=' || v_computed_count ||
                          ', actual=' || v_actual_count);

      UPDATE social_data
      SET json_document = JSON_MERGEPATCH(
        json_document,
        JSON_OBJECT(
          'engagement' VALUE JSON_OBJECT(
            'like_count' VALUE v_actual_count,
            'last_reconciled' VALUE SYSTIMESTAMP
          )
        )
      )
      WHERE JSON_VALUE(json_document, '$._id') = post_rec.post_id;
    END IF;
  END LOOP;

  COMMIT;
END;
/
```

## Conclusion

In this lab, you learned how to implement the Computed Pattern for storing pre-calculated metrics and aggregations within a Single Collection design.

**Key Takeaways:**
- ✅ Computed Pattern improves read performance by 4-5x for frequently accessed metrics
- ✅ Use composite keys to organize time-series computed data (`ENTITY#ID#STATS#YYYY-MM`)
- ✅ Choose the right update strategy: immediate (on write) vs batch (scheduled)
- ✅ Store metadata about when values were computed for staleness tracking
- ✅ Implement periodic reconciliation to prevent drift between computed and source data
- ✅ Apply the pattern selectively to high-value, frequently read metrics

**When to Use the Computed Pattern:**
- Read:write ratio is 100:1 or higher
- Aggregation queries are expensive (over 50ms)
- Eventual consistency is acceptable
- Response time requirements are strict (under 10ms)

**Next Steps:**
- Proceed to **Lab 5: Bucketing Pattern for Time-Series** to learn how to handle high-volume time-series data efficiently

## Learn More

* [Oracle JSON Developer's Guide - JSON Collections](https://docs.oracle.com/en/database/oracle/oracle-database/23/adjsn/overview-of-storage-and-management-of-JSON-data.html)
* [MongoDB Computed Pattern Documentation](https://www.mongodb.com/docs/manual/data-modeling/design-patterns/computed-pattern/)
* [Rick Houlihan - DynamoDB Advanced Design Patterns](https://www.youtube.com/watch?v=6yqfmXiZTlM)

## Acknowledgments

* **Author** - Rick Houlihan, Principal Solutions Architect, Oracle Database
* **Last Updated By/Date** - November 2024
