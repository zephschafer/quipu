# quipu-data-generator

An example [pvc](https://github.com/zephschafer/pvc) project demonstrating two common ingestion patterns:

| Pipeline | Source | Pattern |
|---|---|---|
| `portland_permits` | PortlandMaps REST API | Date-range iteration, staging + merge dedup |
| `craigslist_apts` | Craigslist (HTML scraping) | Categorical iteration, snapshot append |

This repo plays the same role as [jaffle-shop](https://github.com/dbt-labs/jaffle-shop) for dbt: a concrete, runnable reference project you can clone, explore, and use as a starting point.

---

## Requirements

- Python 3.12+
- [uv](https://docs.astral.sh/uv/)
- Java (required by PySpark / Iceberg)

---

## Setup

```bash
git clone https://github.com/Data-Dispatch/quipu-data-generator
cd quipu-data-generator
uv sync
uv run pvc init    # creates project.yml — prompts for API key and catalog type
```

`project.yml` is gitignored. Leave `portlandmaps_api_key` blank to use the built-in default key.

---

## Running pipelines

```bash
# Validate all pipelines (no data fetched)
uv run pvc validate all

# Portland building permits — backfill a month
uv run pvc run portland_permits --start 2024-01-01 --end 2024-01-31

# Craigslist apartments — full run across all Oregon cities
uv run pvc run craigslist_apts

# Test with one iteration and a small record cap
uv run pvc run craigslist_apts --limit 1 --param max_records=10
```

---

## Pipelines

### `portland_permits`

Fetches building permits from the [PortlandMaps API](https://www.portlandmaps.com/api/). The API partitions permit data by date type (`review`, `issued`, `final`) — a permit may appear under `review` before it has an `issued` date. pvc writes each date type to a separate staging table then merges them into a single deduplicated `permits_loader` table using a latest-non-null window across all three date columns.

**Demonstrates:** `type: http`, date_range × categorical iteration, `staging` + `merge` with `latest_non_null` dedup.

```bash
uv run pvc run portland_permits --start 2024-01-01 --end 2024-12-31
```

**Output table:** `local.portland_permits.permits_loader`

Columns: `ivr_number`, `application_number`, `address`, `neighborhood`, `neighborhood_district`, `business_association`, `description`, `work`, `submitted_valuation`, `final_valuation`, `total_sqft`, `stories`, `new_units`, `under_review`, `issued`, `final`, `lon`, `lat`

### `craigslist_apts`

Scrapes apartment rental listings from Craigslist for five Oregon cities: Portland, Eugene, Salem, Bend, Corvallis. Craigslist's static-render fallback returns all listings in a single page request — no pagination needed. Detail pages are fetched per listing for bedrooms, sqft, coordinates, and description.

Each run snapshots current listings (`strategy: append`). Run on a schedule to build a time series of rental prices.

**Demonstrates:** `type: python`, categorical iteration over regions, `append` strategy, custom HTML scraper in `connectors/`.

```bash
uv run pvc run craigslist_apts
```

**Output table:** `local.craigslist_apts.craigslist_apts`

Columns: `region`, `url`, `posted`, `price`, `bedrooms`, `sqft`, `neighborhood`, `title`, `address`, `post_description`, `latitude`, `longitude`

---

## Exploring the data

Query the warehouse instantly via DuckDB — no Spark startup required:

```python
import duckdb
conn = duckdb.connect()

# Portland permits by neighborhood
conn.execute("""
    SELECT neighborhood, COUNT(*) as permits, AVG(CAST(submitted_valuation AS DOUBLE)) as avg_valuation
    FROM read_parquet('warehouse/portland_permits/permits_loader/data/*.parquet')
    WHERE submitted_valuation != 'nan'
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT 20
""").fetchdf()

# Craigslist median rent by city
conn.execute("""
    SELECT region, COUNT(*) as listings, 
           MEDIAN(CAST(price AS DOUBLE)) as median_rent,
           MEDIAN(CAST(sqft AS DOUBLE)) as median_sqft
    FROM read_parquet('warehouse/craigslist_apts/craigslist_apts/data/*.parquet')
    WHERE price != 'nan'
    GROUP BY 1
    ORDER BY 3 DESC
""").fetchdf()
```

Or with Spark (full Iceberg catalog access):

```python
from pvc.spark_session import get_spark
spark = get_spark()

spark.table("local.portland_permits.permits_loader").show()
spark.sql("""
    SELECT neighborhood, COUNT(*) as permits
    FROM local.portland_permits.permits_loader
    WHERE issued != 'nan'
    GROUP BY 1 ORDER BY 2 DESC
""").show()
```

**Note:** All warehouse columns are stored as strings. Cast to numeric types as needed: `CAST(price AS DOUBLE)`. Null numeric values appear as the string `'nan'`.

---

## Claude integration (MCP + skills)

This project includes Claude skills in [`.claude/commands/`](.claude/commands/):

- `/new-pipeline` — guides Claude through building a new pipeline end-to-end
- `/explore-warehouse` — guides Claude through querying warehouse data

To connect Claude Desktop to this project's pvc MCP server:

```bash
# Run once from this directory
uv run pvc mcp setup-desktop
```

Then restart Claude Desktop. Claude can then call `list_pipelines`, `run_pipeline`, `query_warehouse`, and the other pvc tools directly.

---

## Project structure

```
pipelines/                Pipeline YAML definitions
  portland_permits.yml    REST API → date-range × categorical iteration
  craigslist_apts.yml     Python scraper → categorical iteration
connectors/
  craigslist_apts.py      HTML scraper for Craigslist listings
transform/                dbt models for downstream analysis (optional)
warehouse/                Iceberg data lake — written by pvc (gitignored)
project.yml               Local config: API keys, catalog type (gitignored)
pyproject.toml            Depends on pvc; lists scraper dependencies
.claude/commands/         Claude slash commands for vibe-coding new pipelines
```

---

## Creating your own pvc project

See the [pvc README](https://github.com/zephschafer/pvc) for full documentation:
pipeline YAML reference, all CLI flags, build strategies, and how to set up a new project from scratch.
