SELECT *
FROM (
  WITH all_dates AS (
    SELECT
      DISTINCT date
    FROM {{ ref('permits_by_date_and_structure_type') }}
  )
  , all_structure_types AS (
    SELECT
      DISTINCT structure_type
    FROM {{ ref('permits_by_date_and_structure_type') }}
  )
  SELECT
      ad.date
      , ast.structure_type AS type
      , AVG(COALESCE(pbdast.total_sqft_issued_amt,0)) OVER (PARTITION BY ast.structure_type ORDER BY ad.date DESC ROWS BETWEEN CURRENT ROW AND 365 FOLLOWING) AS value
  FROM all_dates AS ad
  CROSS JOIN all_structure_types AS ast
  LEFT JOIN {{ ref('permits_by_date_and_structure_type') }} AS pbdast
    ON ad.date = pbdast.date
      AND ast.structure_type = pbdast.structure_type
  WHERE ad.date > '2010-01-01'
    AND ast.structure_type IS NOT NULL
)
WHERE date > '2011-01-01'
ORDER BY
  type ASC
  , date ASC
