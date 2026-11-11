CREATE OR REFRESH MATERIALIZED VIEW ride_hailing_trips.default.silver_trips_clean (
  CONSTRAINT valid_distance EXPECT (distance_km > 0)  ON VIOLATION DROP ROW,
  CONSTRAINT valid_rate     EXPECT (rate_per_km >= 0) ON VIOLATION DROP ROW,
  CONSTRAINT valid_payout  EXPECT  (driver_payout >=0) ON VIOLATION DROP ROW
) AS
SELECT DISTINCT
  trip_id, customer_id, driver_id, trip_date,pickup_hour,
  COALESCE(INITCAP(TRIM(city)), 'Unknown')          AS city,
  coalesce(initcap(trim(booking_channel)),'Unknown') AS booking_channel,
  coalesce(initcap(trim(pickup_zone)),'Unknown') AS pickup_zone,
  coalesce(initcap(trim(region)),'Unknown') AS region,
  COALESCE(INITCAP(TRIM(vehicle_type)), 'Unknown')  AS vehicle_type,
  COALESCE(fare_amount, distance_km * rate_per_km)  AS fare_amount,
  COALESCE(payment_method, 'Unknown')               AS payment_method,
  driver_payout,
  customer_rating,
  COALESCE(INITCAP(TRIM(trip_type)), 'Unknown')     AS trip_type,
  duration_min,
  discount_amount,
  distance_km,
  rate_per_km,
  COALESCE(fare_amount, distance_km * rate_per_km) - discount_amount AS net_revenue,
  COALESCE(fare_amount, distance_km * rate_per_km) - discount_amount - driver_payout AS platform_earnings
FROM ride_hailing_trips.default.bronze_sales;
 
CREATE OR REFRESH MATERIALIZED VIEW ride_hailing_trips.default.silver_trips_rejected AS
SELECT *,
  CASE WHEN distance_km IS NULL OR distance_km <= 0 THEN 'Distance is zero, negative or missing'
       WHEN rate_per_km IS NULL OR rate_per_km < 0 THEN 'Rate per km is negative or missing'
       WHEN driver_payout IS NULL OR driver_payout < 0 THEN 'Driver payout is negative or missing'
  END AS reject_reason
FROM ride_hailing_trips.default.bronze_sales
WHERE distance_km IS NULL OR distance_km <= 0
   OR rate_per_km IS NULL OR rate_per_km < 0
   OR driver_payout IS NULL OR driver_payout < 0;
