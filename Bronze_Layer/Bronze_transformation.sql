-- Bronze Layer :- Raw data Ingestion
create or refresh streaming table ride_hailing_trips.default.bronze_sales
(
   constraint trip_id_loaded expect (trip_id is not null),
   constraint customer_id_loaded expect (customer_id is not null),
   constraint driver_id_loaded expect (driver_id is not null)
)
comment 'Bronze layer: Ride Hailing Trip Data Ingestion'
as
select *,
        _metadata.file_path as file_path,
        current_timestamp() as ingested_at
from stream read_files(
  "/Volumes/ride_hailing_trips/default/trips_data",
  format => 'CSV',
  header => true
)
