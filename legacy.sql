CREATE OR REPLACE PACKAGE car_extreme_processor AS

  PROCEDURE run_full_processing(
    p_brand_filter IN VARCHAR2 DEFAULT NULL,
    p_max_retries  IN NUMBER   DEFAULT 2
  );

END car_extreme_processor;
/
----------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY car_extreme_processor AS

  --------------------------------------------------------------------
  -- Custom error codes
  --------------------------------------------------------------------
  e_invalid_state      EXCEPTION;
  e_retry_exhausted    EXCEPTION;
  e_bulk_partial_fail  EXCEPTION;

  PRAGMA EXCEPTION_INIT(e_invalid_state, -20001);

  --------------------------------------------------------------------
  -- Cursor declarations
  --------------------------------------------------------------------
  CURSOR car_master_cur IS
    SELECT car_id, brand, model
    FROM car
    WHERE p_brand_filter IS NULL OR brand = p_brand_filter
    ORDER BY car_id
    FOR UPDATE;

  CURSOR car_check_cur(p_id NUMBER) IS
    SELECT brand, model
    FROM car
    WHERE car_id = p_id;

  --------------------------------------------------------------------
  -- Collection types
  --------------------------------------------------------------------
  TYPE num_tab  IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  TYPE varchar_tab IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;

  --------------------------------------------------------------------
  -- Deterministic business rule
  --------------------------------------------------------------------
  FUNCTION compute_score(p_brand VARCHAR2, p_model VARCHAR2)
    RETURN NUMBER DETERMINISTIC
  IS
  BEGIN
    IF p_brand = 'BMW' THEN
      RETURN 100;
    ELSIF p_brand = 'HYUNDAI' THEN
      RETURN 70;
    ELSIF p_brand = 'TATA' THEN
      RETURN 50;
    ELSE
      RETURN 10;
    END IF;
  END compute_score;

  --------------------------------------------------------------------
  -- MAIN PROCEDURE
  --------------------------------------------------------------------
  PROCEDURE run_full_processing(
    p_brand_filter IN VARCHAR2 DEFAULT NULL,
    p_max_retries  IN NUMBER   DEFAULT 2
  ) IS

    v_ids       num_tab;
    v_models    varchar_tab;
    v_retry     NUMBER := 0;
    v_sql       VARCHAR2(1000);
    v_score     NUMBER;

  BEGIN
    <<retry_block>>
    BEGIN
      SAVEPOINT start_cycle;

      ---------------------------------------------------------------
      -- BULK FETCH
      ---------------------------------------------------------------
      SELECT car_id, model
      BULK COLLECT INTO v_ids, v_models
      FROM car
      WHERE p_brand_filter IS NULL OR brand = p_brand_filter;

      IF v_ids.COUNT = 0 THEN
        RAISE e_invalid_state;
      END IF;

      ---------------------------------------------------------------
      -- BULK UPDATE WITH SAVE EXCEPTIONS
      ---------------------------------------------------------------
      FORALL i IN 1 .. v_ids.COUNT SAVE EXCEPTIONS
        UPDATE car
           SET model = model || '_PROC'
         WHERE car_id = v_ids(i);

      ---------------------------------------------------------------
      -- ROW LEVEL POST-VALIDATION (NESTED CURSOR)
      ---------------------------------------------------------------
      FOR i IN 1 .. v_ids.COUNT LOOP
        FOR chk IN car_check_cur(v_ids(i)) LOOP

          v_score := compute_score(chk.brand, chk.model);

          IF v_score < 40 THEN
            RAISE_APPLICATION_ERROR(
              -20001,
              'Low business score for CAR_ID=' || v_ids(i)
            );
          END IF;

          -----------------------------------------------------------
          -- Dynamic SQL mutation
          -----------------------------------------------------------
          v_sql :=
            'UPDATE car SET model = model || ''_S'' || :1 WHERE car_id = :2';

          EXECUTE IMMEDIATE v_sql USING v_score, v_ids(i);

        END LOOP;
      END LOOP;

      COMMIT;

    EXCEPTION
      ---------------------------------------------------------------
      -- PARTIAL BULK FAILURE HANDLING
      ---------------------------------------------------------------
      WHEN OTHERS THEN
        IF SQLCODE = -24381 THEN
          ROLLBACK TO start_cycle;
          RAISE e_bulk_partial_fail;
        ELSE
          ROLLBACK TO start_cycle;
          RAISE;
        END IF;
    END;

  EXCEPTION
    ---------------------------------------------------------------
    -- RETRY MECHANISM
    ---------------------------------------------------------------
    WHEN e_bulk_partial_fail OR e_invalid_state THEN
      v_retry := v_retry + 1;

      IF v_retry <= p_max_retries THEN
        DBMS_OUTPUT.PUT_LINE(
          'Retry attempt ' || v_retry || ' of ' || p_max_retries
        );
        GOTO retry_block;
      ELSE
        RAISE e_retry_exhausted;
      END IF;

    WHEN e_retry_exhausted THEN
      ROLLBACK;
      DBMS_OUTPUT.PUT_LINE('Retries exhausted. Manual intervention required.');

    WHEN OTHERS THEN
      ROLLBACK;
      DBMS_OUTPUT.PUT_LINE(
        'Fatal error [' || SQLCODE || ']: ' || SQLERRM
      );
      RAISE;

  END run_full_processing;

END car_extreme_processor;
/
