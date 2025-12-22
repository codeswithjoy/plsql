------------------------------------------------------------
-- CLEANUP (safe to ignore errors)
------------------------------------------------------------
BEGIN
  EXECUTE IMMEDIATE 'DROP PACKAGE car_mgmt_pkg';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE car';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

------------------------------------------------------------
-- TABLE CREATION (single table)
------------------------------------------------------------
CREATE TABLE car (
    car_id NUMBER PRIMARY KEY,
    brand  VARCHAR2(50),
    model  VARCHAR2(50)
);
/

------------------------------------------------------------
-- PACKAGE SPECIFICATION
------------------------------------------------------------
CREATE OR REPLACE PACKAGE car_mgmt_pkg IS

    PROCEDURE add_car(
        p_car_id IN NUMBER,
        p_brand  IN VARCHAR2,
        p_model  IN VARCHAR2
    );

    PROCEDURE update_car(
        p_car_id IN NUMBER,
        p_brand  IN VARCHAR2 DEFAULT NULL,
        p_model  IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE delete_car(
        p_car_id IN NUMBER
    );

    PROCEDURE print_all_cars;

    PROCEDURE brand_statistics;

END car_mgmt_pkg;
/
------------------------------------------------------------
-- PACKAGE BODY
------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY car_mgmt_pkg IS

    --------------------------------------------------------
    -- PRIVATE LOGGER
    --------------------------------------------------------
    PROCEDURE log_msg(p_msg VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE(
            TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS')
            || ' | ' || p_msg
        );
    END;

    --------------------------------------------------------
    -- ADD CAR
    --------------------------------------------------------
    PROCEDURE add_car(
        p_car_id IN NUMBER,
        p_brand  IN VARCHAR2,
        p_model  IN VARCHAR2
    ) IS
        v_count NUMBER;
    BEGIN
        log_msg('ADD_CAR started');

        SELECT COUNT(*)
        INTO v_count
        FROM car
        WHERE car_id = p_car_id;

        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Car already exists');
        END IF;

        INSERT INTO car
        VALUES (
            p_car_id,
            UPPER(p_brand),
            INITCAP(p_model)
        );

        COMMIT;
        log_msg('ADD_CAR completed');

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            log_msg('ADD_CAR failed: ' || SQLERRM);
            RAISE;
    END add_car;

    --------------------------------------------------------
    -- UPDATE CAR (Dynamic SQL)
    --------------------------------------------------------
    PROCEDURE update_car(
        p_car_id IN NUMBER,
        p_brand  IN VARCHAR2 DEFAULT NULL,
        p_model  IN VARCHAR2 DEFAULT NULL
    ) IS
        v_sql  VARCHAR2(500);
        v_rows NUMBER;
    BEGIN
        log_msg('UPDATE_CAR started');

        v_sql := 'UPDATE car SET ';

        IF p_brand IS NOT NULL THEN
            v_sql := v_sql || 'brand = ''' || UPPER(p_brand) || '''';
        END IF;

        IF p_model IS NOT NULL THEN
            IF p_brand IS NOT NULL THEN
                v_sql := v_sql || ', ';
            END IF;
            v_sql := v_sql || 'model = ''' || INITCAP(p_model) || '''';
        END IF;

        v_sql := v_sql || ' WHERE car_id = ' || p_car_id;

        EXECUTE IMMEDIATE v_sql;
        v_rows := SQL%ROWCOUNT;

        IF v_rows = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Car not found');
        END IF;

        COMMIT;
        log_msg('UPDATE_CAR completed');

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            log_msg('UPDATE_CAR failed: ' || SQLERRM);
            RAISE;
    END update_car;

    --------------------------------------------------------
    -- DELETE CAR
    --------------------------------------------------------
    PROCEDURE delete_car(p_car_id IN NUMBER) IS
        v_rows NUMBER;
    BEGIN
        log_msg('DELETE_CAR started');

        DELETE FROM car WHERE car_id = p_car_id;
        v_rows := SQL%ROWCOUNT;

        IF v_rows = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Car not found');
        END IF;

        COMMIT;
        log_msg('DELETE_CAR completed');

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            log_msg('DELETE_CAR failed: ' || SQLERRM);
            RAISE;
    END delete_car;

    --------------------------------------------------------
    -- PRINT ALL CARS (Cursor)
    --------------------------------------------------------
    PROCEDURE print_all_cars IS
        CURSOR c_car IS
            SELECT car_id, brand, model FROM car ORDER BY car_id;
        v_rec c_car%ROWTYPE;
    BEGIN
        log_msg('PRINT_ALL_CARS started');

        OPEN c_car;
        LOOP
            FETCH c_car INTO v_rec;
            EXIT WHEN c_car%NOTFOUND;

            DBMS_OUTPUT.PUT_LINE(
                v_rec.car_id || ' | ' ||
                v_rec.brand  || ' | ' ||
                v_rec.model
            );
        END LOOP;
        CLOSE c_car;

        log_msg('PRINT_ALL_CARS completed');
    END print_all_cars;

    --------------------------------------------------------
    -- BRAND STATISTICS (Bulk Collect)
    --------------------------------------------------------
    PROCEDURE brand_statistics IS
        TYPE t_brand IS TABLE OF car.brand%TYPE;
        v_brands t_brand;
        v_total  NUMBER := 0;
    BEGIN
        log_msg('BRAND_STATISTICS started');

        SELECT brand
        BULK COLLECT INTO v_brands
        FROM car;

        FOR i IN 1 .. v_brands.COUNT LOOP
            v_total := v_total + 1;
            DBMS_OUTPUT.PUT_LINE(
                'Row ' || i || ' Brand = ' || v_brands(i)
            );
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('TOTAL CARS = ' || v_total);
        log_msg('BRAND_STATISTICS completed');
    END brand_statistics;

END car_mgmt_pkg;
/
------------------------------------------------------------
-- SAMPLE EXECUTION
------------------------------------------------------------
BEGIN
  car_mgmt_pkg.add_car(1, 'Toyota', 'Corolla');
  car_mgmt_pkg.add_car(2, 'Honda', 'Civic');
  car_mgmt_pkg.add_car(3, 'Hyundai', 'Creta');
END;
/

BEGIN
  car_mgmt_pkg.print_all_cars;
  car_mgmt_pkg.brand_statistics;
END;
/
