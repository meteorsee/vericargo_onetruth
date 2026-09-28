USE WAREHOUSE VERICARGO_WH;
USE DATABASE VERICARGO_ONETRUTH;

CREATE OR REPLACE SEMANTIC VIEW ANALYTICS.SUPPLY_CHAIN_SEMANTIC_VIEW
  TABLES (
    suppliers AS RAW.SUPPLIERS
      PRIMARY KEY (supplier_id)
      WITH SYNONYMS = ('vendors', 'sources')
      COMMENT = 'Suppliers of parts and shipments',
    parts AS RAW.PARTS
      PRIMARY KEY (part_id)
      WITH SYNONYMS = ('materials', 'items', 'SKUs')
      COMMENT = 'Parts sourced from suppliers',
    plants AS RAW.PLANTS
      PRIMARY KEY (plant_id)
      WITH SYNONYMS = ('factories', 'sites')
      COMMENT = 'Manufacturing and fulfilment plants',
    customers AS RAW.CUSTOMERS
      PRIMARY KEY (customer_id)
      WITH SYNONYMS = ('buyers', 'consignees')
      COMMENT = 'Customers receiving orders',
    ports AS RAW.PORTS
      PRIMARY KEY (port_code)
      WITH SYNONYMS = ('seaports', 'terminals')
      COMMENT = 'Canonical UN/LOCODE-style port records',
    orders AS RAW.ORDERS
      PRIMARY KEY (order_id)
      COMMENT = 'Customer orders',
    order_lines AS CURATED.ORDER_LINE_METRICS
      PRIMARY KEY (order_id, line_number)
      WITH SYNONYMS = ('fulfilment lines', 'order items')
      COMMENT = 'Order-line grain used for governed fill rate',
    shipments AS CURATED.SHIPMENT_METRICS
      PRIMARY KEY (shipment_id)
      WITH SYNONYMS = ('loads', 'consignments')
      COMMENT = 'Shipment grain used for delivery and landed-cost metrics',
    shipment_risk AS CURATED.SHIPMENT_RISK_FEATURES
      PRIMARY KEY (shipment_id)
      WITH SYNONYMS = ('shipment exceptions', 'risk features')
      COMMENT = 'Snowpark-generated delivery and document exception features',
    exceptions AS ANALYTICS.SHIPMENT_EXCEPTIONS
      PRIMARY KEY (exception_id)
      WITH SYNONYMS = ('findings', 'issues', 'alerts')
      COMMENT = 'Governed operational and document exceptions',
    inventory AS CURATED.INVENTORY_METRICS
      PRIMARY KEY (plant_id, part_id)
      WITH SYNONYMS = ('stock', 'inventory snapshots')
      COMMENT = 'Latest plant-part inventory with trailing 30-day demand'
  )
  RELATIONSHIPS (
    parts_to_supplier AS parts (supplier_id) REFERENCES suppliers,
    orders_to_customer AS orders (customer_id) REFERENCES customers,
    orders_to_plant AS orders (plant_id) REFERENCES plants,
    lines_to_order AS order_lines (order_id) REFERENCES orders,
    lines_to_part AS order_lines (part_id) REFERENCES parts,
    shipments_to_order AS shipments (order_id) REFERENCES orders,
    shipments_to_supplier AS shipments (supplier_id) REFERENCES suppliers,
    shipments_to_origin AS shipments (origin_port_code) REFERENCES ports,
    shipments_to_destination AS shipments (destination_port_code) REFERENCES ports,
    risk_to_shipment AS shipment_risk (shipment_id) REFERENCES shipments,
    exceptions_to_shipment AS exceptions (shipment_id) REFERENCES shipments,
    inventory_to_plant AS inventory (plant_id) REFERENCES plants,
    inventory_to_part AS inventory (part_id) REFERENCES parts
  )
  FACTS (
    shipments.delivered_shipments AS shipments.delivered_flag
      COMMENT = 'One when the shipment is delivered, otherwise zero',
    shipments.on_time_delivered_shipments AS shipments.on_time_delivered_flag
      COMMENT = 'One when delivered on or before promise date, otherwise zero',
    shipments.landed_cost_amount_usd AS shipments.landed_cost_usd
      COMMENT = 'Product plus freight, duty, insurance, and handling in USD',
    shipment_risk.delivery_days_late AS shipment_risk.delivery_days_late,
    shipment_risk.overall_risk_score AS shipment_risk.overall_risk_score,
    shipment_risk.delivery_risk_score AS shipment_risk.delivery_risk_score,
    shipment_risk.document_risk_score AS shipment_risk.document_risk_score,
    shipment_risk.inventory_risk_score AS shipment_risk.inventory_risk_score,
    shipment_risk.cost_risk_score AS shipment_risk.cost_risk_score,
    shipment_risk.data_quality_risk_score AS shipment_risk.data_quality_risk_score,
    shipment_risk.document_min_confidence AS shipment_risk.document_min_confidence,
    order_lines.ordered_quantity AS order_lines.ordered_qty,
    order_lines.shipped_quantity AS order_lines.shipped_qty,
    order_lines.capped_shipped_quantity AS order_lines.capped_shipped_qty
      COMMENT = 'Shipped quantity capped at ordered quantity',
    inventory.on_hand_quantity AS inventory.on_hand_qty,
    inventory.trailing_30_day_shipped_quantity AS inventory.trailing_30_day_shipped_qty
  )
  DIMENSIONS (
    suppliers.supplier_id AS suppliers.supplier_id,
    suppliers.supplier_name AS suppliers.supplier_name,
    suppliers.risk_tier AS suppliers.risk_tier,
    parts.part_id AS parts.part_id,
    parts.part_name AS parts.part_name,
    plants.plant_id AS plants.plant_id,
    plants.plant_name AS plants.plant_name,
    customers.customer_id AS customers.customer_id,
    customers.customer_name AS customers.customer_name,
    ports.port_code AS ports.port_code,
    ports.port_name AS ports.port_name,
    orders.order_id AS orders.order_id,
    orders.order_date AS orders.order_date,
    orders.promised_delivery_date AS orders.promised_delivery_date,
    order_lines.line_number AS order_lines.line_number,
    order_lines.ship_date AS order_lines.ship_date,
    shipments.shipment_id AS shipments.shipment_id,
    shipments.container_id AS shipments.container_id,
    shipments.ship_date AS shipments.ship_date,
    shipments.promised_delivery_date AS shipments.promised_delivery_date,
    shipments.actual_delivery_date AS shipments.actual_delivery_date,
    shipments.status AS shipments.status,
    shipment_risk.document_outcome AS shipment_risk.document_outcome,
    shipment_risk.document_outcome_reason AS shipment_risk.document_outcome_reason,
    shipment_risk.risk_severity AS shipment_risk.risk_severity,
    shipment_risk.feature_refreshed_at AS shipment_risk.feature_refreshed_at,
    exceptions.exception_id AS exceptions.exception_id,
    exceptions.exception_category AS exceptions.exception_category,
    exceptions.exception_type AS exceptions.exception_type,
    exceptions.severity AS exceptions.severity,
    exceptions.status AS exceptions.status,
    exceptions.reason AS exceptions.reason,
    inventory.snapshot_date AS inventory.snapshot_date
  )
  METRICS (
    shipments.on_time_delivery_rate
      AS SUM(shipments.on_time_delivered_shipments)
         / NULLIF(SUM(shipments.delivered_shipments), 0)
      WITH SYNONYMS = ('OTD', 'on-time rate', 'delivery reliability')
      COMMENT = 'Delivered shipments on or before promised date divided by delivered shipments',
    shipments.landed_cost
      AS SUM(shipments.landed_cost_amount_usd)
      WITH SYNONYMS = ('total landed cost', 'delivered cost')
      COMMENT = 'Product cost plus freight, duty, insurance, and handling; all fixture values are USD',
    shipments.shipment_count
      AS COUNT(shipments.shipment_id)
      WITH SYNONYMS = ('number of shipments', 'loads count')
      COMMENT = 'Count of shipments at shipment grain',
    shipments.delayed_shipment_count
      AS COUNT_IF(shipments.actual_delivery_date > shipments.promised_delivery_date)
      WITH SYNONYMS = ('late shipments', 'delayed loads')
      COMMENT = 'Count of shipments later than their promised date',
    exceptions.exception_count
      AS COUNT(exceptions.exception_id)
      WITH SYNONYMS = ('issue count', 'open findings')
      COMMENT = 'Count of governed operational and document exceptions',
    order_lines.fill_rate
      AS SUM(order_lines.capped_shipped_quantity)
         / NULLIF(SUM(order_lines.ordered_quantity), 0)
      WITH SYNONYMS = ('order fill', 'fulfilment rate')
      COMMENT = 'Sum of min(shipped quantity, ordered quantity) divided by total ordered quantity',
    inventory.days_of_inventory
      AS SUM(inventory.on_hand_quantity)
         / NULLIF(SUM(inventory.trailing_30_day_shipped_quantity) / 30.0, 0)
      WITH SYNONYMS = ('DOI', 'days on hand', 'inventory coverage')
      COMMENT = 'Current on-hand quantity divided by trailing-30-day average daily shipped quantity; null when demand is zero'
  )
  COMMENT = 'Governed supply-chain ontology for VeriCargo OneTruth'
  AI_SQL_GENERATION 'Use only the four governed metric definitions in this semantic view. State the grain, filters, date window, and USD currency assumptions. Never infer document facts that are absent or failed extraction.'
  AI_QUESTION_CATEGORIZATION 'Use this semantic view for supply-chain KPI, supplier, plant, order, shipment, part, inventory, customer, and port questions. Route document-content questions to the document search tool.'
  AI_VERIFIED_QUERIES (
    operations_otd AS (
      QUESTION 'Operations: what is our on-time delivery rate?'
      VERIFIED_AT 1790467200
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = VERICARGO_TEAM)'
      SQL 'SELECT SUM(__shipments.on_time_delivered_shipments) / NULLIF(SUM(__shipments.delivered_shipments), 0) AS on_time_delivery_rate FROM __shipments'
    ),
    procurement_otd AS (
      QUESTION 'Procurement: what percentage of delivered supplier shipments met promise?'
      VERIFIED_AT 1790467200
      VERIFIED_BY '(STEWARD = VERICARGO_TEAM)'
      SQL 'SELECT SUM(__shipments.on_time_delivered_shipments) / NULLIF(SUM(__shipments.delivered_shipments), 0) AS on_time_delivery_rate FROM __shipments'
    ),
    planning_otd AS (
      QUESTION 'Planning: show delivery reliability against promised dates.'
      VERIFIED_AT 1790467200
      VERIFIED_BY '(STEWARD = VERICARGO_TEAM)'
      SQL 'SELECT SUM(__shipments.on_time_delivered_shipments) / NULLIF(SUM(__shipments.delivered_shipments), 0) AS on_time_delivery_rate FROM __shipments'
    ),
    governed_fill_rate AS (
      QUESTION 'What is the governed order fill rate?'
      VERIFIED_AT 1790467200
      ONBOARDING_QUESTION TRUE
      VERIFIED_BY '(STEWARD = VERICARGO_TEAM)'
      SQL 'SELECT SUM(__order_lines.capped_shipped_quantity) / NULLIF(SUM(__order_lines.ordered_quantity), 0) AS fill_rate FROM __order_lines'
    ),
    governed_inventory_days AS (
      QUESTION 'How many days of inventory do we hold?'
      VERIFIED_AT 1790467200
      VERIFIED_BY '(STEWARD = VERICARGO_TEAM)'
      SQL 'SELECT SUM(__inventory.on_hand_quantity) / NULLIF(SUM(__inventory.trailing_30_day_shipped_quantity) / 30.0, 0) AS days_of_inventory FROM __inventory'
    ),
    governed_landed_cost AS (
      QUESTION 'What is total landed cost in USD?'
      VERIFIED_AT 1790467200
      VERIFIED_BY '(STEWARD = VERICARGO_TEAM)'
      SQL 'SELECT SUM(__shipments.landed_cost_amount_usd) AS landed_cost_usd FROM __shipments'
    ),
    shipment_exception_counts AS (
      QUESTION 'How many shipments, delays, and governed exceptions are there?'
      VERIFIED_AT 1790467200
      VERIFIED_BY '(STEWARD = VERICARGO_TEAM)'
      SQL 'SELECT COUNT(__shipments.shipment_id) AS shipment_count, COUNT_IF(__shipments.actual_delivery_date > __shipments.promised_delivery_date) AS delayed_shipment_count FROM __shipments'
    )
  );
