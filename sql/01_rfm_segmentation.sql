WITH base_metrics AS(
  SELECT 
    user_id,
    MAX(DATE(created_at)) AS last_purchase_date,
    COUNT(DISTINCT order_id) AS frequency,
    ROUND(SUM(sale_price), 2) AS monetary
  FROM bigquery-public-data.thelook_ecommerce.order_items
  WHERE status = 'Complete'
  GROUP BY user_id
),
scoring AS (
  SELECT
    user_id,
    frequency,
    monetary,
    DATE_DIFF(
      (SELECT MAX(DATE(created_at)) FROM bigquery-public-data.thelook_ecommerce.order_items), 
      last_purchase_date, 
      DAY
    ) AS recency_days,
    -- NTILE(5) assigns a score of 1 to 5. 
    -- Ordering by last_purchase_date ASC means older dates get 1, newer dates get 5.
    NTILE(5) OVER (ORDER BY last_purchase_date ASC) AS r_score,
    NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
    NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
  FROM base_metrics
)

SELECT
  user_id,
  recency_days,
  frequency,
  monetary,
  CASE
    WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
    WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
    WHEN r_score >= 4 AND f_score = 1 THEN 'New Customers'
    WHEN r_score <= 2 AND f_score = 1 THEN 'Lost'
    ELSE 'Average Regulars'
  END AS customer_segment
FROM scoring
ORDER BY monetary DESC;
