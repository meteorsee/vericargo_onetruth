USE WAREHOUSE VERICARGO_WH;
USE DATABASE VERICARGO_ONETRUTH;

-- Mutating acceptance test over synthetic data. It leaves a RESOLVED case and audit trail.
EXECUTE IMMEDIATE $$
DECLARE
  created VARIANT;
  duplicate_attempt VARIANT;
  started VARIANT;
  resolved VARIANT;
  smoke_case_id VARCHAR;
  link_count INTEGER;
  audit_count INTEGER;
  existing_active_count INTEGER;
  existing_case_id VARCHAR;
  existing_status VARCHAR;
BEGIN
  -- Finish an interrupted earlier smoke attempt before creating the fresh test case.
  SELECT COUNT(*) INTO :existing_active_count FROM APP.REVIEW_CASES
    WHERE shipment_id = 'SHP-1002' AND status IN ('PENDING', 'IN_REVIEW');
  IF (existing_active_count > 0) THEN
    SELECT case_id, status INTO :existing_case_id, :existing_status FROM APP.REVIEW_CASES
      WHERE shipment_id = 'SHP-1002' AND status IN ('PENDING', 'IN_REVIEW')
      ORDER BY created_at LIMIT 1;
    IF (existing_status = 'PENDING') THEN
      CALL APP.UPDATE_REVIEW_CASE(:existing_case_id, 'IN_REVIEW',
        'workflow-smoke-reviewer', NULL) INTO :started;
    END IF;
    CALL APP.UPDATE_REVIEW_CASE(:existing_case_id, 'RESOLVED',
      'workflow-smoke-reviewer', 'Recovered and verified after an interrupted smoke run.')
      INTO :resolved;
  END IF;

  CALL APP.CREATE_REVIEW_CASE(
    'SHP-1002', ARRAY_CONSTRUCT('DOC-SHP-1002', 'DELIVERY-SHP-1002'),
    'Workflow smoke test for the delivery and document exceptions.',
    'HIGH', TRUE, 'Run the guarded SHP-1002 workflow smoke test.'
  ) INTO :created;
  IF (created:status::STRING <> 'CREATED') THEN RETURN created; END IF;
  smoke_case_id := created:case_id::STRING;

  CALL APP.CREATE_REVIEW_CASE(
    'SHP-1002', ARRAY_CONSTRUCT('DOC-SHP-1002'),
    'This duplicate active case must be rejected.',
    'HIGH', TRUE, 'Verify active-case duplicate protection.'
  ) INTO :duplicate_attempt;
  IF (duplicate_attempt:status::STRING <> 'DUPLICATE') THEN
    RETURN OBJECT_CONSTRUCT('status', 'FAIL', 'step', 'duplicate_detection');
  END IF;

  CALL APP.UPDATE_REVIEW_CASE(:smoke_case_id, 'IN_REVIEW', 'workflow-smoke-reviewer', NULL)
    INTO :started;
  CALL APP.UPDATE_REVIEW_CASE(:smoke_case_id, 'RESOLVED', 'workflow-smoke-reviewer',
    'Verified both source documents; correction requested from the carrier.') INTO :resolved;

  SELECT COUNT(*) INTO :link_count FROM APP.REVIEW_CASE_EXCEPTIONS
    WHERE case_id = :smoke_case_id;
  SELECT COUNT(*) INTO :audit_count FROM APP.REVIEW_AUDIT_EVENTS
    WHERE case_id = :smoke_case_id;
  RETURN OBJECT_CONSTRUCT(
    'status', IFF(resolved:status::STRING = 'UPDATED' AND link_count = 2 AND audit_count = 3,
                  'PASS', 'FAIL'),
    'case_id', smoke_case_id, 'linked_exceptions', link_count,
    'audit_events', audit_count, 'final_status', resolved:new_status::STRING
  );
END;
$$;
