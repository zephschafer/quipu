SELECT range::DATE AS date
FROM generate_series(
  DATE '2009-01-01',
  (CURRENT_DATE + INTERVAL '1 year')::DATE,
  INTERVAL '1 day'
) t(range)
