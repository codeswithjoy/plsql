CREATE OR REPLACE PROCEDURE add_employee (
    p_name   IN  VARCHAR2,
    p_salary IN  NUMBER,
    p_dept   IN  NUMBER
) AS
BEGIN
    INSERT INTO employee (emp_name, salary, dept_id)
    VALUES (p_name, p_salary, p_dept);

    COMMIT; -- small procedures sometimes commit; prefer controlling transactions at higher level
END add_employee;
/
