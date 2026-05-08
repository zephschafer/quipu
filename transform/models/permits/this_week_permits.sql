SELECT
    structure_type AS Structure
    , under_review_at::DATE AS Submitted
    , issued_at::DATE AS Issued
    , work_type AS Type_of_Work
    , function_type AS Building_Function
    , total_sqft_amt AS New_Square_Feet
    , stories_amt AS Buildings_Stories
    , new_units_amt AS New_Residential_Units
    , value AS Construction_Value
    , description AS Description
FROM {{ ref('permits_cleaned') }}
WHERE issued_at::DATE BETWEEN CURRENT_DATE - 7 AND CURRENT_DATE
  AND total_sqft_amt > 0
ORDER BY
  issued_at::DATE DESC
  , CAST(total_sqft_amt AS INTEGER) DESC
