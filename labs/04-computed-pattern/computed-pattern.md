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
WHERE JSON_VALUE(data, '$.post_id') = 'POST-12345'
  AND JSON_VALUE(data, '$.type') IN ('like', 'comment', 'share')
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

### Step 1: Create the Social Media Collection

Let's build a social media application with posts, likes, comments, and shares in a Single Collection:

```sql
-- Create the social media collection
CREATE JSON COLLECTION TABLE social_data;

-- Create index on _id
CREATE INDEX idx_social_id ON social_data (JSON_VALUE(data, '$._id'));

-- Create index on type
CREATE INDEX idx_social_type ON social_data (JSON_VALUE(data, '$.type'));

-- Create index on post_id for finding engagements
CREATE INDEX idx_social_postid ON social_data (JSON_VALUE(data, '$.post_id'));
```

### Step 2: Insert a Post with Pre-Computed Metrics

```sql
-- Insert a post with initial computed metrics
INSERT INTO social_data (data) VALUES (
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

COMMIT;
```

Expected output:
```
1 row created.

Commit complete.
```

**MongoDB API Approach:**

```javascript
// Connect to Oracle using MongoDB API
// mongosh "mongodb://jsonuser:WelcomeJson%23123@localhost:27017/jsonuser?authMechanism=PLAIN&authSource=$external&tls=false"

use jsonuser

// Insert post with pre-computed engagement metrics
db.social_data.insertOne({
  _id: "POST#12345",
  type: "post",
  user_id: "USER-789",
  user_name: "Alice Smith",
  content: "Check out this amazing photo!",
  created_at: new Date(),
  engagement: {
    like_count: 0,
    comment_count: 0,
    share_count: 0,
    view_count: 0,
    last_updated: new Date()
  }
})
```

> **MongoDB API**: Pre-computed metrics are a standard MongoDB pattern. Initialize counters at 0, then increment atomically using `$inc` operator.

### Step 3: Insert Engagement Events

```sql
-- Insert engagement events (individual documents)
-- We store these as separate documents but maintain computed totals in the post

-- Insert a like
INSERT INTO social_data (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'POST#12345#LIKE#USER-456',
    'type' VALUE 'like',
    'post_id' VALUE 'POST#12345',
    'user_id' VALUE 'USER-456',
    'user_name' VALUE 'Bob Johnson',
    'created_at' VALUE SYSTIMESTAMP
  )
);

-- Insert a comment
INSERT INTO social_data (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'POST#12345#COMMENT#USER-789',
    'type' VALUE 'comment',
    'post_id' VALUE 'POST#12345',
    'user_id' VALUE 'USER-789',
    'content' VALUE 'Great photo!',
    'created_at' VALUE SYSTIMESTAMP
  )
);

COMMIT;
```

### Step 4: Query the Post (Fast - Single Document Read)

```sql
-- Query the post (2-3ms response time)
SELECT JSON_SERIALIZE(data PRETTY)
FROM social_data
WHERE JSON_VALUE(data, '$._id') = 'POST#12345';
```

## Task 3: Update Strategies for Computed Metrics

### Step 1: Increment on Write (Immediate Consistency)

```sql
-- When a like is added, increment the like_count

-- 1. Insert the like event
INSERT INTO social_data (data) VALUES (
  JSON_OBJECT(
    '_id' VALUE 'POST#12345#LIKE#USER-999',
    'type' VALUE 'like',
    'post_id' VALUE 'POST#12345',
    'user_id' VALUE 'USER-999',
    'created_at' VALUE SYSTIMESTAMP
  )
);

-- 2. Increment the like_count using JSON_TRANSFORM
UPDATE social_data
SET data = JSON_TRANSFORM(
  data,
  SET '$.engagement.like_count' = (
    JSON_VALUE(data, '$.engagement.like_count' RETURNING NUMBER) + 1
  ),
  SET '$.engagement.last_updated' = SYSTIMESTAMP
)
WHERE JSON_VALUE(data, '$._id') = 'POST#12345';

COMMIT;
```

Expected output:
```
1 row created.

1 row updated.

Commit complete.
```

### Step 2: Verify the Update

```sql
-- Check the updated like_count
SELECT
  JSON_VALUE(data, '$._id') AS post_id,
  JSON_VALUE(data, '$.engagement.like_count') AS like_count,
  JSON_VALUE(data, '$.engagement.last_updated') AS last_updated
FROM social_data
WHERE JSON_VALUE(data, '$._id') = 'POST#12345';
```

### Step 3: Using Composite Keys for Time-Series Computed Data

Store monthly customer statistics using composite keys:

```sql
-- Insert customer document
INSERT INTO social_data (data) VALUES (
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
INSERT INTO social_data (data) VALUES (
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

COMMIT;
```

```sql
-- Query all stats for a customer (composite key prefix)
SELECT JSON_SERIALIZE(data PRETTY)
FROM social_data
WHERE JSON_VALUE(data, '$._id') LIKE 'CUSTOMER#456#STATS#%'
ORDER BY JSON_VALUE(data, '$.month') DESC;
```

## Task 4: Multi-Level Aggregation Hierarchy

For complex analytics, you may need multiple levels of computed aggregations:

### Step 1: Create User Statistics at Multiple Levels

```sql
-- Level 1: Individual post metrics (updated on each engagement)
-- Already created above with POST#12345

-- Level 2: Daily user statistics (computed from posts)
INSERT INTO social_data (data) VALUES (
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
INSERT INTO social_data (data) VALUES (
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

COMMIT;
```

### Step 2: Query User with Monthly Stats

```sql
-- Query user with monthly stats (single query)
SELECT JSON_SERIALIZE(data PRETTY)
FROM social_data
WHERE JSON_VALUE(data, '$._id') IN ('USER#789', 'USER#789#STATS#2024-11');
```

## Task 5: Performance Comparison - Computed vs Real-Time

### Step 1: Load Test Data

```sql
-- Create sample posts with varying engagement levels
BEGIN
  -- Insert 100 posts
  FOR i IN 1..100 LOOP
    INSERT INTO social_data (data) VALUES (
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
      INSERT INTO social_data (data) VALUES (
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
```

### Step 2: Update Computed Metrics for All Posts

```sql
-- Update computed metrics for all posts
BEGIN
  FOR post_rec IN (
    SELECT DISTINCT JSON_VALUE(data, '$._id') AS post_id
    FROM social_data
    WHERE JSON_VALUE(data, '$.type') = 'post'
  ) LOOP
    DECLARE
      v_like_count NUMBER;
    BEGIN
      SELECT COUNT(*)
      INTO v_like_count
      FROM social_data
      WHERE JSON_VALUE(data, '$.post_id') = post_rec.post_id
        AND JSON_VALUE(data, '$.type') = 'like';

      UPDATE social_data
      SET data = JSON_TRANSFORM(
        data,
        SET '$.engagement.like_count' = v_like_count,
        SET '$.engagement.last_updated' = SYSTIMESTAMP
      )
      WHERE JSON_VALUE(data, '$._id') = post_rec.post_id;
    END;
  END LOOP;

  COMMIT;
END;
/
```

### Step 3: Benchmark Real-Time Aggregation

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
    WHERE JSON_VALUE(data, '$.post_id') = 'POST#00025'
      AND JSON_VALUE(data, '$.type') = 'like';

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

**MongoDB Aggregation Pipeline (Real-Time Computation):**

```javascript
// Real-time aggregation using MongoDB aggregation pipeline
// Oracle supports MongoDB aggregation operators!

// Example 1: Count likes for a specific post
db.social_data.aggregate([
  {
    $match: {
      post_id: "POST#00025",
      type: "like"
    }
  },
  {
    $group: {
      _id: "$post_id",
      like_count: { $sum: 1 }
    }
  }
])

// Example 2: Aggregate engagement metrics across all posts
db.social_data.aggregate([
  {
    $match: { type: "like" }
  },
  {
    $group: {
      _id: "$post_id",
      like_count: { $sum: 1 }
    }
  },
  {
    $sort: { like_count: -1 }
  },
  {
    $limit: 10
  }
])
```

> **MongoDB API**: Oracle supports MongoDB aggregation operators including `$match`, `$group`, `$sum`, `$sort`, and `$limit`. Use aggregation pipelines for real-time computation when exact real-time accuracy is required.

### Step 4: Benchmark Computed Pattern

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
    SELECT JSON_VALUE(data, '$.engagement.like_count' RETURNING NUMBER)
    INTO v_like_count
    FROM social_data
    WHERE JSON_VALUE(data, '$._id') = 'POST#00025';

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

### Step 5: Performance Comparison Summary

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

## Task 6: Best Practices for the Computed Pattern

### Step 1: Design Checklist

When implementing the Computed Pattern, follow this checklist:

**Data Design:**
- [ ] Identify metrics that are read far more often than written (100:1 ratio or higher)
- [ ] Determine acceptable staleness for computed values (real-time, 5 min, hourly, daily?)
- [ ] Design composite keys for time-series computed data (`ENTITY#ID#STATS#YYYY-MM`)
- [ ] Store metadata about when values were last computed (`computed_at` timestamp)
- [ ] Keep computed documents small (< 7,950 bytes) to stay in inline storage

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
-- DO implement periodic reconciliation
DECLARE
  v_computed_count NUMBER;
  v_actual_count NUMBER;
BEGIN
  FOR post_rec IN (
    SELECT JSON_VALUE(data, '$._id') AS post_id
    FROM social_data
    WHERE JSON_VALUE(data, '$.type') = 'post'
    AND ROWNUM <= 100  -- Limit for demo
  ) LOOP
    -- Get computed count
    SELECT JSON_VALUE(data, '$.engagement.like_count' RETURNING NUMBER)
    INTO v_computed_count
    FROM social_data
    WHERE JSON_VALUE(data, '$._id') = post_rec.post_id;

    -- Get actual count
    SELECT COUNT(*)
    INTO v_actual_count
    FROM social_data
    WHERE JSON_VALUE(data, '$.post_id') = post_rec.post_id
      AND JSON_VALUE(data, '$.type') = 'like';

    -- Fix drift if found
    IF NVL(v_computed_count, 0) != v_actual_count THEN
      DBMS_OUTPUT.PUT_LINE('Drift detected for ' || post_rec.post_id ||
                          ': computed=' || NVL(v_computed_count, 0) ||
                          ', actual=' || v_actual_count);

      UPDATE social_data
      SET data = JSON_TRANSFORM(
        data,
        SET '$.engagement.like_count' = v_actual_count,
        SET '$.engagement.last_reconciled' = SYSTIMESTAMP
      )
      WHERE JSON_VALUE(data, '$._id') = post_rec.post_id;
    END IF;
  END LOOP;

  COMMIT;
END;
/
```

## Summary

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

* [Oracle AI Database 26ai JSON Developer's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/26/adjsn/)
* [MongoDB Computed Pattern Documentation](https://www.mongodb.com/docs/manual/data-modeling/design-patterns/computed-pattern/)
* [AWS DynamoDB Advanced Design Patterns](https://aws.amazon.com/dynamodb/resources/)

## Acknowledgements

* **Author** - Rick Houlihan
* **Contributors** - Oracle JSON Development Team, Oracle LiveLabs Team
* **Last Updated By/Date** - Rick Houlihan, November 2025
