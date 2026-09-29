WITH date_bounds AS (
  -- 1. Dynamically find the exact start and end dates of the dataset
  SELECT 
    MIN(DATE(created_at)) AS min_date,
    MAX(DATE(created_at)) AS max_date
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
),
calendar_spine AS (
  -- 2. Generate a continuous array of dates between those dynamic bounds
  SELECT date
  FROM date_bounds,
  UNNEST(GENERATE_DATE_ARRAY(min_date, max_date, INTERVAL 1 DAY)) AS date
),
daily_sales AS (
  -- 3. Calculate raw daily revenue, excluding failed transactions
  SELECT 
    DATE(created_at) AS sale_date,
    ROUND(SUM(sale_price), 2) AS total_revenue
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  WHERE status NOT IN ('Cancelled', 'Returned')
  GROUP BY sale_date
),
spine_joined AS (
  -- 4. Left join to the spine. This forces days with zero sales to appear as NULL, which we convert to 0.
  SELECT 
    c.date AS calendar_date,
    COALESCE(d.total_revenue, 0) AS daily_revenue
  FROM calendar_spine c
  LEFT JOIN daily_sales d ON c.date = d.sale_date
)
-- 5. Apply the window function to calculate the moving average over the gapless spine
SELECT 
  calendar_date,
  daily_revenue,
  ROUND(
    AVG(daily_revenue) OVER(
      ORDER BY calendar_date 
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2
  ) AS rolling_7_day_avg
FROM spine_joined
ORDER BY calendar_date DESC;