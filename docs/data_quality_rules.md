# Ride-Hailing Trips — Data Quality Rules

This document describes the data-quality behavior implemented in the Bronze and Silver SQL scripts.

## Bronze layer

Source data is read from:

`/Volumes/ride_hailing_trips/default/trips_data`

The streaming table `ride_hailing_trips.default.bronze_sales` retains source columns and adds:

- `file_path`: source file path from Databricks file metadata.
- `ingested_at`: ingestion timestamp.

The Bronze expectations require `trip_id`, `customer_id`, and `driver_id` to be non-null. Review the pipeline expectation metrics to confirm how violations are handled by the configured pipeline.

## Silver clean layer

The `silver_trips_clean` materialized view selects distinct records and applies these rules:

| Field / rule | Implemented behavior |
|---|---|
| City, booking channel, pickup zone, region, vehicle type, trip type | Trim whitespace, title-case text, replace null with `Unknown` |
| Payment method | Replace null with `Unknown` |
| Fare amount | Use `fare_amount`; if null, derive `distance_km * rate_per_km` |
| Distance | Must be greater than zero; invalid rows are dropped from the clean view |
| Rate per km | Must be zero or greater; invalid rows are dropped from the clean view |
| Driver payout | Must be zero or greater; invalid rows are dropped from the clean view |
| Duplicate output rows | `SELECT DISTINCT` is applied |
| Net revenue | Fare less discount |
| Platform earnings | Fare less discount less driver payout |

The three Silver expectations use `ON VIOLATION DROP ROW`.

## Rejected-record layer

The `silver_trips_rejected` view selects Bronze records where:

- `distance_km` is null or less than/equal to zero;
- `rate_per_km` is null or negative; or
- `driver_payout` is null or negative.

It adds `reject_reason` to indicate the first matching condition in the CASE expression.

## Current implementation notes

- The clean view uses `SELECT DISTINCT`, which removes duplicate result rows but does not by itself define a business key for trips.
- The Gold duplicate metric is based on `COUNT(*) - COUNT(DISTINCT trip_id)`; this treats repeated trip IDs as duplicates even if their other columns differ.
- The rejected view reads directly from Bronze and does not use `DISTINCT`.
- The current Silver rules do not explicitly validate trip date, pickup hour, duration, rating range, discount, or payment status.
- A missing `fare_amount` can remain null if either distance or rate is null.
- The clean view replaces null payment method with `Unknown`, while Gold's missing-payment metric counts null payment methods in Bronze.

These notes document the SQL as it currently exists; they are not claims that every possible data-quality rule is already enforced.
