DECLARE
    v_count NUMBER;
BEGIN
    UPDATE employees
    SET salary = salary * 1.10;

    v_count := SQL%ROWCOUNT;

    DBMS_OUTPUT.PUT_LINE(v_count || ' employees got a 10% salary hike.');
END;
/
