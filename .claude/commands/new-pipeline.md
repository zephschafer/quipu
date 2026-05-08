You are helping the user create a new pvc pipeline. pvc is a YAML-driven data ingestion framework that writes to a local Apache Iceberg warehouse.

Follow these steps in order:

## 1. Understand the data source

Ask the user (or use context already provided):
- What data are they trying to ingest?
- What is the source? (REST API, website to scrape, database, file, etc.)
- Do they have API docs or a sample URL/response?

## 2. Reference existing pipelines

Use `list_pipelines` to see what already exists. Use `get_pipeline` on the most relevant one as a structural reference for the YAML you're about to write.

## 3. Determine source type

- **`type: http`** — for REST APIs with JSON or CSV responses (like Portland permits)
- **`type: python`** — for anything that needs custom logic: HTML scraping, pagination that depends on response content, multi-step auth, etc. (like Craigslist)

## 4. Design the YAML

Key YAML sections:
- `source` — where data comes from and how to authenticate
- `iterate` — what axes to loop over (date ranges, categorical values like regions)
- `schema.columns` — exactly which fields to keep; everything else is dropped
- `build` — how to write to the warehouse:
  - `incremental` + `primary_key` — upsert by key (good for records that update over time)
  - `append` — snapshot each run (good for listings, prices, events)
  - `full_refresh` — replace the whole table each run

For `type: python`, also design the scraper function signature:
```python
def fetch_data(dynamic_params: dict) -> list[dict]:
    ...
```
The function receives the current iteration's param values and returns raw records.

## 5. Write and validate

1. Use `write_pipeline` to save the YAML
2. Immediately run `validate_pipeline` — fix any errors before proceeding

## 6. Test with a small run

Use `run_pipeline` with `limit=1` and small `params` (e.g. `max_records=3`) to verify end-to-end without a full run. Watch for:
- Fetch errors (auth, URL, response format)
- Schema projection errors (wrong column paths)
- Write errors (type mismatches)

## 7. Verify the data

Use `query_warehouse` to inspect what landed:
```sql
SELECT * FROM namespace.table LIMIT 10
```
Check that types look right, values are sensible, and the row count matches expectations.

## 8. Done

Report: pipeline name, table location in warehouse, column count, rows written in the test run.
