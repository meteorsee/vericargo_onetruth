USE WAREHOUSE VERICARGO_WH;
USE DATABASE VERICARGO_ONETRUTH;

CREATE OR REPLACE DYNAMIC TABLE CURATED.SHIPMENT_METRICS
  TARGET_LAG = '1 minute'
  WAREHOUSE = VERICARGO_WH
AS
SELECT
  s.shipment_id,
  s.order_id,
  s.supplier_id,
  o.customer_id,
  o.plant_id,
  s.origin_port_code,
  s.destination_port_code,
  s.container_id,
  s.ship_date,
  s.promised_delivery_date,
  s.actual_delivery_date,
  s.status,
  IFF(s.status = 'DELIVERED', 1, 0) AS delivered_flag,
  IFF(
    s.status = 'DELIVERED'
    AND s.actual_delivery_date <= s.promised_delivery_date,
    1,
    0
  ) AS on_time_delivered_flag,
  lc.product_cost_usd,
  lc.freight_usd,
  lc.duty_usd,
  lc.insurance_usd,
  lc.handling_usd,
  lc.product_cost_usd + lc.freight_usd + lc.duty_usd
    + lc.insurance_usd + lc.handling_usd AS landed_cost_usd
FROM RAW.SHIPMENTS s
JOIN RAW.ORDERS o ON o.order_id = s.order_id
JOIN RAW.LANDED_COSTS lc ON lc.shipment_id = s.shipment_id;

CREATE OR REPLACE DYNAMIC TABLE CURATED.ORDER_LINE_METRICS
  TARGET_LAG = '1 minute'
  WAREHOUSE = VERICARGO_WH
AS
SELECT
  ol.order_id,
  ol.line_number,
  ol.part_id,
  o.customer_id,
  o.plant_id,
  s.shipment_id,
  s.ship_date,
  ol.ordered_qty,
  ol.shipped_qty,
  LEAST(ol.shipped_qty, ol.ordered_qty) AS capped_shipped_qty
FROM RAW.ORDER_LINES ol
JOIN RAW.ORDERS o ON o.order_id = ol.order_id
JOIN RAW.SHIPMENTS s ON s.order_id = ol.order_id;

CREATE OR REPLACE DYNAMIC TABLE CURATED.INVENTORY_METRICS
  TARGET_LAG = '1 minute'
  WAREHOUSE = VERICARGO_WH
AS
WITH anchors AS (
  SELECT MAX(snapshot_date) AS anchor_date
  FROM RAW.INVENTORY_SNAPSHOTS
),
latest_inventory AS (
  SELECT i.snapshot_date, i.plant_id, i.part_id, i.on_hand_qty
  FROM RAW.INVENTORY_SNAPSHOTS i
  JOIN anchors a ON i.snapshot_date = a.anchor_date
),
shipped_30d AS (
  SELECT
    olm.plant_id,
    olm.part_id,
    SUM(olm.shipped_qty) AS trailing_30_day_shipped_qty
  FROM CURATED.ORDER_LINE_METRICS olm
  CROSS JOIN anchors a
  WHERE olm.ship_date BETWEEN DATEADD(day, -29, a.anchor_date) AND a.anchor_date
  GROUP BY olm.plant_id, olm.part_id
)
SELECT
  i.snapshot_date,
  i.plant_id,
  i.part_id,
  i.on_hand_qty,
  COALESCE(s.trailing_30_day_shipped_qty, 0) AS trailing_30_day_shipped_qty,
  i.on_hand_qty
    / NULLIF(COALESCE(s.trailing_30_day_shipped_qty, 0) / 30.0, 0)
    AS days_of_inventory
FROM latest_inventory i
LEFT JOIN shipped_30d s
  ON s.plant_id = i.plant_id
 AND s.part_id = i.part_id;

CREATE OR REPLACE VIEW ANALYTICS.KPI_OVERVIEW AS
WITH delivery AS (
  SELECT
    SUM(on_time_delivered_flag) / NULLIF(SUM(delivered_flag), 0)::FLOAT
      AS on_time_delivery_rate,
    SUM(landed_cost_usd) AS landed_cost_usd
  FROM CURATED.SHIPMENT_METRICS
),
fulfilment AS (
  SELECT
    SUM(capped_shipped_qty) / NULLIF(SUM(ordered_qty), 0)::FLOAT AS fill_rate
  FROM CURATED.ORDER_LINE_METRICS
),
inventory AS (
  SELECT
    SUM(on_hand_qty)
      / NULLIF(SUM(trailing_30_day_shipped_qty) / 30.0, 0)
      AS days_of_inventory
  FROM CURATED.INVENTORY_METRICS
)
SELECT
  d.on_time_delivery_rate,
  f.fill_rate,
  i.days_of_inventory,
  d.landed_cost_usd,
  CURRENT_TIMESTAMP() AS measured_at
FROM delivery d
CROSS JOIN fulfilment f
CROSS JOIN inventory i;

CREATE OR REPLACE VIEW ANALYTICS.ENTITY_RELATIONSHIPS AS
SELECT 'SUPPLIER' AS source_type, supplier_id AS source_id,
       'PART' AS target_type, part_id AS target_id, 'SUPPLIES' AS relationship
FROM RAW.PARTS
UNION ALL
SELECT 'PLANT', plant_id, 'ORDER', order_id, 'FULFILLS'
FROM RAW.ORDERS
UNION ALL
SELECT 'CUSTOMER', customer_id, 'ORDER', order_id, 'PLACED'
FROM RAW.ORDERS
UNION ALL
SELECT 'ORDER', order_id, 'SHIPMENT', shipment_id, 'SHIPS_AS'
FROM RAW.SHIPMENTS
UNION ALL
SELECT 'SHIPMENT', shipment_id, 'CONTAINER', container_id, 'USES'
FROM RAW.SHIPMENTS
UNION ALL
SELECT 'SHIPMENT', shipment_id, 'PORT', origin_port_code, 'ORIGINATES_AT'
FROM RAW.SHIPMENTS
UNION ALL
SELECT 'SHIPMENT', shipment_id, 'PORT', destination_port_code, 'DESTINED_FOR'
FROM RAW.SHIPMENTS;
