USE WAREHOUSE VERICARGO_WH;
USE DATABASE VERICARGO_ONETRUTH;

CREATE TABLE IF NOT EXISTS CURATED.RISK_POLICY (
  POLICY_NAME VARCHAR PRIMARY KEY,
  DELIVERY_LATE_SCORE NUMBER,
  DELIVERY_VERY_LATE_DAYS NUMBER,
  DELIVERY_VERY_LATE_SCORE NUMBER,
  DOCUMENT_MISMATCH_SCORE NUMBER,
  DOCUMENT_MISSING_SCORE NUMBER,
  DOCUMENT_UNRESOLVED_SCORE NUMBER,
  INVENTORY_LOW_DAYS NUMBER,
  INVENTORY_LOW_SCORE NUMBER,
  INVENTORY_WARNING_DAYS NUMBER,
  INVENTORY_WARNING_SCORE NUMBER,
  COST_HIGH_RATIO FLOAT,
  COST_HIGH_SCORE NUMBER,
  COST_WARNING_RATIO FLOAT,
  COST_WARNING_SCORE NUMBER,
  DATA_QUALITY_SCORE NUMBER,
  UPDATED_AT TIMESTAMP_LTZ
);

MERGE INTO CURATED.RISK_POLICY target
USING (SELECT 'MVP_V1' AS policy_name) source
ON target.policy_name = source.policy_name
WHEN NOT MATCHED THEN INSERT VALUES (
  'MVP_V1', 15, 3, 30, 30, 25, 20, 15, 15, 30, 8,
  1.20, 15, 1.10, 8, 10, CURRENT_TIMESTAMP()
);

CREATE OR REPLACE PROCEDURE CURATED.REFRESH_SHIPMENT_RISK_FEATURES()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
EXECUTE AS OWNER
AS
$$
from snowflake.snowpark import Session


def run(session: Session) -> str:
    session.sql("""
      CREATE OR REPLACE TABLE CURATED.SHIPMENT_RISK_FEATURES AS
      WITH anchor AS (
        SELECT MAX(snapshot_date) AS as_of_date FROM RAW.INVENTORY_SNAPSHOTS
      ), inventory_by_shipment AS (
        SELECT s.shipment_id, MIN(i.days_of_inventory) AS days_of_inventory
        FROM RAW.SHIPMENTS s
        JOIN RAW.ORDERS o ON o.order_id = s.order_id
        JOIN RAW.ORDER_LINES ol ON ol.order_id = o.order_id
        LEFT JOIN CURATED.INVENTORY_METRICS i
          ON i.plant_id = o.plant_id AND i.part_id = ol.part_id
        GROUP BY s.shipment_id
      ), prepared AS (
        SELECT sm.*, d.outcome AS document_outcome,
          d.outcome_reason AS document_outcome_reason,
          d.min_confidence AS document_min_confidence,
          i.days_of_inventory,
          DATEDIFF('day', sm.promised_delivery_date,
            COALESCE(sm.actual_delivery_date, a.as_of_date)) AS delivery_days_late,
          AVG(sm.landed_cost_usd) OVER (
            PARTITION BY sm.origin_port_code, sm.destination_port_code
          ) AS route_average_landed_cost,
          p.*
        FROM CURATED.SHIPMENT_METRICS sm
        LEFT JOIN CURATED.DOCUMENT_COMPARISON_SUMMARY d USING (shipment_id)
        LEFT JOIN inventory_by_shipment i USING (shipment_id)
        CROSS JOIN anchor a
        CROSS JOIN CURATED.RISK_POLICY p
        WHERE p.policy_name = 'MVP_V1'
      ), scored AS (
        SELECT *,
          CASE WHEN delivery_days_late > delivery_very_late_days THEN delivery_very_late_score
            WHEN delivery_days_late > 0 THEN delivery_late_score ELSE 0 END AS delivery_risk_score,
          CASE document_outcome WHEN 'MISMATCH' THEN document_mismatch_score
            WHEN 'MISSING' THEN document_missing_score
            WHEN 'UNRESOLVED' THEN document_unresolved_score ELSE 0 END AS document_risk_score,
          CASE WHEN days_of_inventory < inventory_low_days THEN inventory_low_score
            WHEN days_of_inventory < inventory_warning_days THEN inventory_warning_score ELSE 0 END AS inventory_risk_score,
          CASE WHEN landed_cost_usd > route_average_landed_cost * cost_high_ratio THEN cost_high_score
            WHEN landed_cost_usd > route_average_landed_cost * cost_warning_ratio THEN cost_warning_score ELSE 0 END AS cost_risk_score,
          IFF(document_outcome_reason IN ('PARSE_FAILURE', 'LOW_CONFIDENCE', 'AMBIGUOUS_PAIR'),
            data_quality_score, 0) AS data_quality_risk_score
        FROM prepared
      ), totals AS (
        SELECT *, LEAST(100, delivery_risk_score + document_risk_score
          + inventory_risk_score + cost_risk_score + data_quality_risk_score) AS overall_risk_score
        FROM scored
      )
      SELECT shipment_id, document_outcome, document_outcome_reason,
        document_min_confidence::NUMBER(5,4) AS document_min_confidence,
        delivery_days_late, days_of_inventory,
        delivery_risk_score, document_risk_score, inventory_risk_score,
        cost_risk_score, data_quality_risk_score, overall_risk_score,
        CASE WHEN overall_risk_score >= 75 THEN 'CRITICAL'
          WHEN overall_risk_score >= 50 THEN 'HIGH'
          WHEN overall_risk_score >= 25 THEN 'MEDIUM' ELSE 'LOW' END AS risk_severity,
        CONCAT_WS('; ',
          IFF(delivery_risk_score > 0, 'Delivery risk ' || delivery_risk_score, NULL),
          IFF(document_risk_score > 0, 'Document risk ' || document_risk_score, NULL),
          IFF(inventory_risk_score > 0, 'Inventory risk ' || inventory_risk_score, NULL),
          IFF(cost_risk_score > 0, 'Cost risk ' || cost_risk_score, NULL),
          IFF(data_quality_risk_score > 0, 'Data-quality risk ' || data_quality_risk_score, NULL)
        ) AS risk_contributors,
        CURRENT_TIMESTAMP() AS feature_refreshed_at
      FROM totals
    """).collect()
    count = session.table("CURATED.SHIPMENT_RISK_FEATURES").count()
    return f"Materialized {count} shipment risk feature row(s)."
$$;

CALL CURATED.REFRESH_SHIPMENT_RISK_FEATURES();
