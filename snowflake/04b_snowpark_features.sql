USE WAREHOUSE VERICARGO_WH;
USE DATABASE VERICARGO_ONETRUTH;

-- A Snowpark Python transform keeps Python in the governed data path rather than using it
-- only for local fixture generation and the UI. It joins structured shipment state with
-- document outcomes and materializes one auditable risk-feature row per shipment.
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
from snowflake.snowpark.functions import (
    coalesce,
    col,
    current_timestamp,
    datediff,
    lit,
    max as max_,
    when,
)
from snowflake.snowpark.types import DecimalType


def run(session: Session) -> str:
    shipments = session.table("VERICARGO_ONETRUTH.CURATED.SHIPMENT_METRICS")
    documents = session.table(
        "VERICARGO_ONETRUTH.CURATED.DOCUMENT_COMPARISON_SUMMARY"
    ).select(
        col("SHIPMENT_ID"),
        col("OUTCOME").alias("DOCUMENT_OUTCOME"),
        col("MIN_CONFIDENCE").alias("DOCUMENT_MIN_CONFIDENCE"),
    )
    anchor = session.table("VERICARGO_ONETRUTH.RAW.INVENTORY_SNAPSHOTS").agg(
        max_(col("SNAPSHOT_DATE")).alias("AS_OF_DATE")
    )

    joined = shipments.join(documents, "SHIPMENT_ID", "left").cross_join(anchor)
    delivery_days_late = when(
        col("ACTUAL_DELIVERY_DATE").is_not_null(),
        datediff("day", col("PROMISED_DELIVERY_DATE"), col("ACTUAL_DELIVERY_DATE")),
    ).otherwise(datediff("day", col("PROMISED_DELIVERY_DATE"), col("AS_OF_DATE")))

    document_risk = (
        when(col("DOCUMENT_OUTCOME").isin("UNREADABLE", "AMBIGUOUS"), lit(60))
        .when(col("DOCUMENT_OUTCOME") == lit("MISSING_DOCUMENT"), lit(50))
        .when(col("DOCUMENT_OUTCOME") == lit("MISMATCH"), lit(40))
        .when(col("DOCUMENT_OUTCOME") == lit("NEEDS_REVIEW"), lit(30))
        .otherwise(lit(0))
    )
    delivery_risk = when(delivery_days_late > lit(0), lit(30)).otherwise(lit(0))

    features = joined.select(
        col("SHIPMENT_ID"),
        coalesce(col("DOCUMENT_OUTCOME"), lit("NOT_PROCESSED")).alias(
            "DOCUMENT_OUTCOME"
        ),
        col("DOCUMENT_MIN_CONFIDENCE").cast(DecimalType(5, 4)).alias(
            "DOCUMENT_MIN_CONFIDENCE"
        ),
        delivery_days_late.alias("DELIVERY_DAYS_LATE"),
        (document_risk + delivery_risk).alias("EXCEPTION_RISK_SCORE"),
        current_timestamp().alias("FEATURE_REFRESHED_AT"),
    )

    target = "VERICARGO_ONETRUTH.CURATED.SHIPMENT_RISK_FEATURES"
    features.write.mode("overwrite").save_as_table(target)
    row_count = session.table(target).count()
    return f"Materialized {row_count} shipment risk feature row(s)."
$$;

CALL CURATED.REFRESH_SHIPMENT_RISK_FEATURES();
