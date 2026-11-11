# Ride-Hailing Trips — Reconciliation Notes

The Gold SQL creates `ride_hailing_trips.default.gold_reconciliation` to summarize row counts across the pipeline.

## Metrics reported

| Metric | Definition in current SQL |
|---|---|
| `bronze_rows` | Total rows in `bronze_sales` |
| `clean_rows` | Total rows in `silver_trips_clean` |
| `rejected_rows` | Total rows in `silver_trips_rejected` |
| `duplicates_removed` | Bronze row count minus distinct Bronze `trip_id` count |
| `reconciliation_ok` | Boolean comparison between Bronze count and clean + rejected + duplicate-ID count |

## Important interpretation

The current `reconciliation_ok` expression is a high-level count check, not a guaranteed row-by-row reconciliation:

1. The clean view uses `SELECT DISTINCT`, so it may collapse identical rows.
2. The rejected view reads directly from Bronze and can include repeated trip IDs.
3. The duplicate metric counts repeated `trip_id` values, not necessarily exact duplicate records.
4. A record can have more than one invalid field, while the rejected view counts the record once.
5. A row that is both duplicated and invalid can make the categories overlap.

Therefore, the sum of clean, rejected, and duplicate counts may not represent mutually exclusive record groups. Treat the Boolean as a diagnostic indicator and inspect the underlying counts when it is false or unexpected.

## Recommended stronger reconciliation

For a rigorous reconciliation, define the record grain first (for example, one unique `trip_id` per trip), then classify each source record into mutually exclusive groups:

- accepted unique trips;
- rejected unique trips;
- duplicate trip records.

Use a stable source-row identifier or ingestion metadata if repeated trip IDs must be distinguished from repeated physical rows. Then verify that the mutually exclusive categories sum to the source row count.

Also compare key business totals (such as fare, discount, driver payout, and net revenue) between the appropriate layers, accounting for the records intentionally excluded from Silver.
