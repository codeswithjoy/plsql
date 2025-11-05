DECLARE
   v_total NUMBER;
BEGIN
   SELECT COUNT(*) INTO v_total FROM employees WHERE department_id = 10;
   DBMS_OUTPUT.PUT_LINE('Total employees in dept 10: ' || v_total);
END;
/
