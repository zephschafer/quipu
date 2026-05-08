SELECT *
FROM (
  SELECT
    date
    , AVG(total_sqft_issued_amt) OVER (ORDER BY date DESC ROWS BETWEEN CURRENT ROW AND 365 FOLLOWING) AS total_sqft_issued_amt
    , AVG(total_new_units_issued_amt) OVER (ORDER BY date DESC ROWS BETWEEN CURRENT ROW AND 365 FOLLOWING) AS total_new_units_issued_amt
    , AVG(count_permits_issued) OVER (ORDER BY date DESC ROWS BETWEEN CURRENT ROW AND 365 FOLLOWING) AS count_permits_issued
    , SUM(count_permits_issued) OVER (ORDER BY date DESC ROWS BETWEEN CURRENT ROW AND 365 FOLLOWING) AS count_total_permits_issued
  FROM {{ ref('permits_by_date') }}
  WHERE date > '2010-01-01'
)
WHERE date > '2011-01-01'
ORDER BY date ASC
