SELECT *
FROM (
  WITH all_dates AS (
    SELECT
      DISTINCT date
    FROM {{ ref('permits_by_date_and_work_type') }}
  )
  , all_work_types AS (
    SELECT
      DISTINCT work_type
    FROM {{ ref('permits_by_date_and_work_type') }}
  )
  SELECT
      ad.date
      , awt.work_type AS type
      , AVG(COALESCE(pbdawt.total_sqft_issued_amt,0)) OVER (PARTITION BY awt.work_type ORDER BY ad.date DESC ROWS BETWEEN CURRENT ROW AND 365 FOLLOWING) AS value
  FROM all_dates AS ad
  CROSS JOIN all_work_types AS awt
  LEFT JOIN {{ ref('permits_by_date_and_work_type') }} AS pbdawt
    ON ad.date = pbdawt.date
      AND awt.work_type = pbdawt.work_type
  WHERE ad.date > '2010-01-01'
    AND awt.work_type IS NOT NULL
)
WHERE date > '2011-01-01'
ORDER BY
  type ASC
  , date ASC
