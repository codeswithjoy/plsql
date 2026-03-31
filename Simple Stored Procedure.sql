CREATE OR REPLACE PROCEDURE tc1_update_salary (
    p_id NUMBER
) AS
BEGIN
    UPDATE employee SET salary = salary + 1000 WHERE id = p_id;
END;
/
