WITH user_cohorts AS (
  -- 1. Identify the exact month of a user's first-ever purchase (Cohort Month)
  SELECT 
    user_id,
    DATE_TRUNC(MIN(DATE(created_at)), MONTH) AS cohort_month
  FROM `bigquery-public-data.thelook_ecommerce.orders`
  WHERE status NOT IN ('Cancelled', 'Returned')
  GROUP BY user_id
),
user_activities AS (
  -- 2. Identify every active month for every user
  SELECT DISTINCT
    user_id,
    DATE_TRUNC(DATE(created_at), MONTH) AS activity_month
  FROM `bigquery-public-data.thelook_ecommerce.orders`
  WHERE status NOT IN ('Cancelled', 'Returned')
),
cohort_indexes AS (
  -- 3. Calculate the relative month index (0 = first month, 1 = second month, etc.)
  SELECT 
    c.user_id,
    c.cohort_month,
    a.activity_month,
    DATE_DIFF(a.activity_month, c.cohort_month, MONTH) AS month_index
  FROM user_cohorts c
  JOIN user_activities a ON c.user_id = a.user_id
),
cohort_sizes AS (
  -- 4. Count the total number of unique users in each initial cohort
  SELECT 
    cohort_month,
    COUNT(DISTINCT user_id) AS initial_users
  FROM cohort_indexes
  WHERE month_index = 0
  GROUP BY cohort_month
),
retention_counts AS (
  -- 5. Count how many users returned in each subsequent month index
  SELECT 
    cohort_month,
    month_index,
    COUNT(DISTINCT user_id) AS retained_users
  FROM cohort_indexes
  GROUP BY cohort_month, month_index
)
-- 6. Join the base size with the retained count to calculate the percentage
SELECT 
  r.cohort_month,
  s.initial_users,
  r.month_index,
  r.retained_users,
  ROUND((r.retained_users / s.initial_users) * 100, 2) AS retention_rate_pct
FROM retention_counts r
JOIN cohort_sizes s ON r.cohort_month = s.cohort_month
ORDER BY r.cohort_month, r.month_index;