SELECT *
FROM (
  WITH all_dates AS (
    SELECT
      DISTINCT date
    FROM {{ ref('permits_by_date_and_function_type') }}
  )
  , all_function_types AS (
    SELECT
      DISTINCT function_type
    FROM {{ ref('permits_by_date_and_function_type') }}
  )
  SELECT
      ad.date
      , aft.function_type AS type
      , AVG(COALESCE(pbdaft.total_sqft_issued_amt,0)) OVER (PARTITION BY aft.function_type ORDER BY ad.date DESC ROWS BETWEEN CURRENT ROW AND 365 FOLLOWING) AS value
  FROM all_dates AS ad
  CROSS JOIN all_function_types AS aft
  LEFT JOIN {{ ref('permits_by_date_and_function_type') }} AS pbdaft
    ON ad.date = pbdaft.date
      AND aft.function_type = pbdaft.function_type
  WHERE ad.date > '2010-01-01'
    AND aft.function_type IS NOT NULL
)
WHERE date > '2011-01-01'
ORDER BY
  type ASC
  , date ASC
