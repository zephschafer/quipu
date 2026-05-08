SELECT
  ivr_number
  , application_number
  , status
  , type
  , description
  , CASE WHEN work IN ('Addition','Alteration') THEN 'Addition/Alteration' ELSE work END AS work_type
  , address
  , set_up_at
  , under_review_at
  , issued_at
  , final_at
  , NULLIF(
      GREATEST(
        COALESCE(set_up_at, TIMESTAMP '1700-01-01')
        , COALESCE(under_review_at, TIMESTAMP '1700-01-01')
        , COALESCE(issued_at, TIMESTAMP '1700-01-01')
        , COALESCE(final_at, TIMESTAMP '1700-01-01')
      )
    , TIMESTAMP '1700-01-01'
  ) AS last_status_update_at
  , datediff('day', set_up_at, issued_at) AS days_to_issue
  , datediff('day', issued_at, final_at) AS days_to_final
  , neighborhood
  , neighborhood_coalition
  , business_association
  , occupancy_group
  , construction_type
  , COALESCE(final_valuation_amt, submitted_valuation_amt) AS value
  , COALESCE(final_valuation_amt, submitted_valuation_amt)/NULLIF(total_sqft_amt,0) AS dollars_per_sf
  , total_sqft_amt/NULLIF(stories_amt, 0) AS sf_per_story
  , new_units_amt
  , total_sqft_amt
  , has_square_footage
  , stories_amt
  , customer
  , longitude
  , latitude
  , ST_Point(longitude, latitude) AS location
  , CASE
      WHEN type = 'Townhouse (3 or more units)'
        OR type = 'Townhouse (2 Units)'
        OR type = 'Duplex'
        OR type = 'Rowhouse (2 units)'
        OR type = 'Rowhouse (3 or more units)'
          THEN 'Rowhouse, Townhouse, Duplex'
      WHEN type = 'Apartments/Condos (3 or more units)'
          THEN 'Apartments'
      WHEN type = 'Single Family Dwelling'
        OR type = 'Floating Home'
          THEN 'Single Family Detached'
      WHEN type = 'Accessory Structure'
        OR type = 'Decks, Fences, Retaining Walls'
        OR type = 'Garage/Carport'
          THEN 'Accessory Structures'
      ELSE type
      END AS structure_type
  , CASE
      WHEN SUBSTR(occupancy_group, 1, 1) IN ('A','M','R-1')
        OR type IN ('Assembly','Hotel/Motel')
          THEN 'Commercial'
      WHEN SUBSTR(occupancy_group, 1, 1) = 'B'
        OR type IN ('Business','Building')
          THEN 'Office'
      WHEN SUBSTR(occupancy_group, 1, 1) = 'E'
        OR type IN ('Educational','School')
          THEN 'School'
      WHEN SUBSTR(occupancy_group, 1, 1) IN ('F','H')
        OR type IN ('Factory/Industrial','Hazardous')
          THEN 'Industrial'
      WHEN SUBSTR(occupancy_group, 1, 1) = 'I'
          THEN 'Healthcare'
      WHEN SUBSTR(occupancy_group, 1, 1) = 'R'
          OR type IN (
            'Garage/Carport','Accessory Structure','Townhouse (3 or more units)'
            ,'Accessory Dwelling Unit','Duplex','Decks, Fences, Retaining Walls','Townhouse (2 Units)'
            ,'Floating Home','Single Family Dwelling','Rowhouse (2 units)','Rowhouse (3 or more units)'
          )
          OR SUBSTR(type,1,10) = 'Apartments'
            THEN 'Residential'
      WHEN SUBSTR(occupancy_group, 1, 2) IN ('U','S-','SR')
        OR type IN ('Mechanical','Utility','Storage')
          THEN 'Utility, Storage, Parking, Special'
      ELSE type
      END
      AS function_type
  , quipu_updated_at
FROM {{ ref('permits') }}
WHERE SUBSTRING(APPLICATION_NUMBER,12,5) = '-000-'
QUALIFY ROW_NUMBER() OVER (PARTITION BY IVR_NUMBER ORDER BY GREATEST(issued_at, under_review_at)) = 1
