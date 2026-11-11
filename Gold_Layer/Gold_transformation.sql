-- =====================================================================
-- GOLD LAYER — business-ready aggregates (BR-01 … BR-06)
-- Sources: silver_trips_clean / silver_trips_rejected (Silver_Layer pipeline)
--          bronze_sales (Bronze_Layer pipeline) — used for DQ + payment status
-- All views publish to ride_hailing_trips.default
-- =====================================================================

-- BR-01 Monthly trends: trips, total km, net revenue, driver payout,
-- platform earnings per month
CREATE OR REFRESH MATERIALIZED VIEW ride_hailing_trips.default.gold_monthly_trips AS
SELECT DATE_TRUNC('MONTH', trip_date) AS trip_month,
       COUNT(*)                       AS trips,
       SUM(distance_km)               AS total_km,
       SUM(net_revenue)               AS net_revenue,
       SUM(driver_payout)             AS driver_payout,
       SUM(platform_earnings)         AS platform_earnings
FROM ride_hailing_trips.default.silver_trips_clean
GROUP BY DATE_TRUNC('MONTH', trip_date);

-- BR-02 City performance: trips, net revenue and average fare per trip
-- by region and city
CREATE OR REFRESH MATERIALIZED VIEW ride_hailing_trips.default.gold_city_performance AS
SELECT region,
       city,
       COUNT(*)              AS trips,
       SUM(net_revenue)      AS net_revenue,
       AVG(fare_amount)      AS avg_fare_per_trip
FROM ride_hailing_trips.default.silver_trips_clean
GROUP BY ALL;

-- BR-03 Vehicle performance: trips, km, net revenue and average customer
-- rating by vehicle type
CREATE OR REFRESH MATERIALIZED VIEW ride_hailing_trips.default.gold_vehicle_performance AS
SELECT vehicle_type,
       COUNT(*)               AS trips,
       SUM(distance_km)       AS total_km,
       SUM(net_revenue)       AS net_revenue,
       AVG(customer_rating)   AS avg_customer_rating
FROM ride_hailing_trips.default.silver_trips_clean
GROUP BY vehicle_type;

-- BR-04 Payment analysis: trips, net revenue and pending amount by payment
-- method. silver_trips_clean does not yet carry payment_status, so the clean
-- rows are re-derived here from bronze_sales limited to trip_ids that
-- survived Silver (semi-join), deduplicated, with Silver's exact fare
-- fallback applied. Once payment_status is added to silver_trips_clean this
-- view can read it directly instead.
CREATE OR REFRESH MATERIALIZED VIEW ride_hailing_trips.default.gold_payment_analysis AS
WITH clean_payment_rows AS (
  SELECT DISTINCT
    trip_id,
    payment_method,
    payment_status,
    COALESCE(fare_amount, distance_km * rate_per_km) - discount_amount AS net_revenue
  FROM ride_hailing_trips.default.bronze_sales
  WHERE trip_id IN (SELECT trip_id FROM ride_hailing_trips.default.silver_trips_clean)
)
SELECT payment_method,
       COUNT(*)                                                    AS trips,
       SUM(net_revenue)                                            AS net_revenue,
       SUM(CASE WHEN payment_status = 'Pending' THEN net_revenue ELSE 0 END) AS pending_amount
FROM clean_payment_rows
GROUP BY payment_method;

-- BR-05 Data-quality visibility: how many bronze rows had each problem
-- (duplicates, bad distance, bad rate, bad payout, blanks)
CREATE OR REFRESH MATERIALIZED VIEW ride_hailing_trips.default.gold_data_quality AS
SELECT COUNT(*)                                                                          AS bronze_rows,
       COUNT(*) - COUNT(DISTINCT trip_id)                                                AS duplicate_rows,
       SUM(CASE WHEN distance_km IS NULL OR distance_km <= 0 THEN 1 ELSE 0 END)          AS invalid_distance_rows,
       SUM(CASE WHEN rate_per_km IS NULL OR rate_per_km < 0 THEN 1 ELSE 0 END)           AS bad_rate_rows,
       SUM(CASE WHEN driver_payout IS NULL OR driver_payout < 0 THEN 1 ELSE 0 END)       AS bad_payout_rows,
       SUM(CASE WHEN payment_method IS NULL THEN 1 ELSE 0 END)                           AS missing_payment_rows,
       SUM(CASE WHEN fare_amount IS NULL THEN 1 ELSE 0 END)                              AS missing_fare_rows,
       SUM(CASE WHEN customer_rating IS NULL THEN 1 ELSE 0 END)                          AS missing_rating_rows,
       SUM(CASE WHEN city IS NULL OR TRIM(city) = '' THEN 1 ELSE 0 END)                  AS missing_city_rows
FROM ride_hailing_trips.default.bronze_sales;

-- BR-06 Reconciliation: prove Bronze rows = clean + rejected + duplicates removed
CREATE OR REFRESH MATERIALIZED VIEW ride_hailing_trips.default.gold_reconciliation AS
SELECT (SELECT COUNT(*) FROM ride_hailing_trips.default.bronze_sales)                    AS bronze_rows,
       (SELECT COUNT(*) FROM ride_hailing_trips.default.silver_trips_clean)              AS clean_rows,
       (SELECT COUNT(*) FROM ride_hailing_trips.default.silver_trips_rejected)           AS rejected_rows,
       (SELECT COUNT(*) FROM ride_hailing_trips.default.bronze_sales)
         - (SELECT COUNT(DISTINCT trip_id) FROM ride_hailing_trips.default.bronze_sales) AS duplicates_removed,
       (SELECT COUNT(*) FROM ride_hailing_trips.default.silver_trips_clean)
         + (SELECT COUNT(*) FROM ride_hailing_trips.default.silver_trips_rejected)
         + ((SELECT COUNT(*) FROM ride_hailing_trips.default.bronze_sales)
              - (SELECT COUNT(DISTINCT trip_id) FROM ride_hailing_trips.default.bronze_sales))
         = (SELECT COUNT(*) FROM ride_hailing_trips.default.bronze_sales)                AS reconciliation_ok
FROM (SELECT 1);

