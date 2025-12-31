/* ============================================================
   PACKAGE: CAR_PROCESSING_PKG
   PURPOSE:
     Enterprise-grade PL/SQL package operating on SINGLE table CAR
     Demonstrates complex logic for PL/SQL → Java conversion
   TABLE:
     car(car_id, brand, model)
   ============================================================ */

CREATE OR REPLACE PACKAGE car_processing_pkg AS

  -- Custom exceptions
  ex_invalid_brand        EXCEPTION;
  ex_no_data_found_custom EXCEPTION;
  ex_bulk_failure         EXCEPTION;

  -- Public procedures
  PROCEDURE process_all_cars(p_commit BOOLEAN DEFAULT TRUE);
  PROCEDURE bulk_update_models(p_brand_filter VARCHAR2);
  FUNCTION  calculate_priority(p_brand VARCHAR2) RETURN NUMBER;

END car_processing_pkg;
/
----------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY car_processing_pkg AS

  ----------------------------------------------------------------
  -- Cursor for controlled row processing
  ----------------------------------------------------------------
  CURSOR car_cur IS
    SELECT car_id, brand, model
    FROM car
    FOR UPDATE;

  ----------------------------------------------------------------
  -- RECORD & TABLE types for BULK processing
  ----------------------------------------------------------------
  TYPE car_rec IS RECORD (
    car_id car.car_id%TYPE,
    brand  car.brand%TYPE,
    model  car.model%TYPE
  );

  TYPE car_tab IS TABLE OF car_rec INDEX BY PLS_INTEGER;

  ----------------------------------------------------------------
  -- PRIVATE helper: priority logic
  ----------------------------------------------------------------
  FUNCTION calculate_priority(p_brand VARCHAR2) RETURN NUMBER IS
  BEGIN
    IF p_brand = 'FORD' THEN
      RETURN 1;
    ELSIF p_brand = 'TOYOTA' THEN
      RETURN 2;
    ELSIF p_brand = 'TATA' THEN
      RETURN 3;
    ELSE
      RETURN 99;
    END IF;
  END calculate_priority;

  ----------------------------------------------------------------
  -- MAIN PROCEDURE: Row-by-row + business logic + transaction mgmt
  ----------------------------------------------------------------
  PROCEDURE process_all_cars(p_commit BOOLEAN DEFAULT TRUE) IS

    v_priority NUMBER;
    v_sql      VARCHAR2(1000);

  BEGIN
    SAVEPOINT start_processing;

    FOR rec IN car_cur LOOP

      -- Business validation
      IF rec.brand IS NULL THEN
        RAISE ex_invalid_brand;
      END IF;

      v_priority := calculate_priority(rec.brand);

      -- Dynamic SQL to simulate runtime decision
      v_sql :=
        'UPDATE car SET model = model || ''-P'' || :1 WHERE car_id = :2';

      EXECUTE IMMEDIATE v_sql USING v_priority, rec.car_id;

      -- Simulated conditional failure
      IF v_priority = 99 THEN
        RAISE ex_no_data_found_custom;
      END IF;

    END LOOP;

    IF p_commit THEN
      COMMIT;
    END IF;

  EXCEPTION
    WHEN ex_invalid_brand THEN
      ROLLBACK TO start_processing;
      DBMS_OUTPUT.PUT_LINE('Invalid brand detected');

    WHEN ex_no_data_found_custom THEN
      ROLLBACK;
      DBMS_OUTPUT.PUT_LINE('Unknown brand encountered');

    WHEN OTHERS THEN
      ROLLBACK;
      DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
      RAISE;
  END process_all_cars;

  ----------------------------------------------------------------
  -- BULK PROCESSING: BULK COLLECT + FORALL
  ----------------------------------------------------------------
  PROCEDURE bulk_update_models(p_brand_filter VARCHAR2) IS

    v_cars car_tab;

  BEGIN
    SAVEPOINT bulk_start;

    SELECT car_id, brand, model
    BULK COLLECT INTO v_cars
    FROM car
    WHERE brand = p_brand_filter;

    IF v_cars.COUNT = 0 THEN
      RAISE ex_no_data_found_custom;
    END IF;

    FORALL i IN v_cars.FIRST .. v_cars.LAST SAVE EXCEPTIONS
      UPDATE car
         SET model = model || '-BULK'
       WHERE car_id = v_cars(i).car_id;

    COMMIT;

  EXCEPTION
    WHEN ex_no_data_found_custom THEN
      ROLLBACK TO bulk_start;
      DBMS_OUTPUT.PUT_LINE('No cars found for brand: ' || p_brand_filter);

    WHEN OTHERS THEN
      ROLLBACK;
      DBMS_OUTPUT.PUT_LINE('Bulk failure: ' || SQLERRM);
      RAISE ex_bulk_failure;
  END bulk_update_models;

END car_processing_pkg;
/
