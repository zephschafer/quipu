WITH issues_by_day AS (
  SELECT
    d.date
    , SUM(p_issued.total_sqft_amt) AS total_sqft_issued_amt
    , SUM(p_issued.new_units_amt) AS total_new_units_issued_amt
    , COALESCE(COUNT(p_issued.ivr_number),0) AS count_permits_issued
    , COALESCE(COUNT(p_issued.total_sqft_amt),0) AS count_permits_issued_w_sqft
    , COALESCE(COUNT(p_issued.value),0) AS final_valuation_issued_amount
    , AVG(p_issued.days_to_issue) AS avg_days_to_issue
    , COALESCE(SUM(p_issued.days_to_issue),0) AS sum_days_to_issue
    , COALESCE(SUM(CASE WHEN p_issued.new_units_amt > 0 THEN p_issued.days_to_issue END),0) AS sum_days_to_issue_w_new_units
  FROM {{ ref('dates') }} AS d
  LEFT JOIN {{ ref('permits_cleaned') }} AS p_issued
      ON d.date = p_issued.issued_at::DATE
  GROUP BY 1
)
, reviews_by_day AS (
  SELECT
    d.date
    , COALESCE(SUM(p_review.total_sqft_amt),0) AS total_sqft_review_amt
    , COALESCE(SUM(p_review.new_units_amt),0) AS total_new_units_review_amt
    , SUM(
        CASE
          WHEN d.date BETWEEN p_review.set_up_at::DATE AND (COALESCE(p_review.issued_at::DATE, CURRENT_DATE) - 1)
            AND p_review.status NOT IN ('Expired', 'Abandoned')
          THEN p_review.total_sqft_amt
        END
    ) AS total_sqft_waiting_approval
    , SUM(
        CASE
          WHEN d.date BETWEEN p_review.set_up_at::DATE AND (COALESCE(p_review.issued_at::DATE, CURRENT_DATE) - 1)
            AND p_review.status NOT IN ('Expired', 'Abandoned')
          THEN p_review.new_units_amt
        END
    ) AS total_new_units_waiting_approval
    , COALESCE(SUM(p_review.new_units_amt),0) AS total_new_units_amt
    , COALESCE(COUNT(p_review.ivr_number),0) AS count_permits_review
    , COALESCE(COUNT(p_review.total_sqft_amt),0) AS count_permits_review_w_sqft
    , COALESCE(COUNT(p_review.value),0) AS final_valuation_review_amount
  FROM {{ ref('dates') }} AS d
  LEFT JOIN {{ ref('permits_cleaned') }} AS p_review
    ON d.date = p_review.under_review_at::DATE
  GROUP BY 1
)
, finals_by_day AS (
  SELECT
    d.date
    , COALESCE(SUM(p_final.total_sqft_amt),0) AS total_sqft_final_amt
    , COALESCE(SUM(p_final.new_units_amt),0) AS total_new_units_final_amt
    , COALESCE(SUM(p_final.new_units_amt),0) AS total_new_units_amt
    , COALESCE(COUNT(p_final.ivr_number),0) AS count_permits_final
    , COALESCE(COUNT(p_final.total_sqft_amt),0) AS count_permits_final_w_sqft
    , COALESCE(COUNT(p_final.value),0) AS final_valuation_amount
  FROM {{ ref('dates') }} AS d
  LEFT JOIN {{ ref('permits_cleaned') }} AS p_final
    ON d.date = p_final.final_at::DATE
  GROUP BY 1
)
SELECT
  d.date
  , ibd.total_sqft_issued_amt
  , ibd.total_new_units_issued_amt
  , ibd.count_permits_issued
  , ibd.count_permits_issued_w_sqft
  , ibd.final_valuation_issued_amount
  , ibd.avg_days_to_issue
  , (ibd.sum_days_to_issue/NULLIF(ibd.total_sqft_issued_amt,0)) AS days_to_issue_sqft
  , (ibd.sum_days_to_issue_w_new_units/NULLIF(ibd.total_new_units_issued_amt,0)) AS days_to_issue_new_units
  , rbd.total_sqft_review_amt
  , rbd.total_new_units_review_amt
  , rbd.total_sqft_waiting_approval
  , rbd.total_new_units_waiting_approval
  , rbd.count_permits_review
  , rbd.count_permits_review_w_sqft
  , rbd.final_valuation_review_amount
  , fbd.total_sqft_final_amt
  , fbd.total_new_units_final_amt
  , fbd.total_new_units_amt
  , fbd.count_permits_final
  , fbd.count_permits_final_w_sqft
  , fbd.final_valuation_amount
FROM {{ ref('dates') }} AS d
LEFT JOIN issues_by_day AS ibd ON d.date = ibd.date
LEFT JOIN reviews_by_day AS rbd ON d.date = rbd.date
LEFT JOIN finals_by_day AS fbd ON d.date = fbd.date
