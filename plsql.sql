CREATE OR REPLACE PROCEDURE proc_update_salary_hike (
    p_department_id   IN  NUMBER,
    p_hike_percentage IN  NUMBER
)
IS
    CURSOR emp_cur IS
        SELECT employee_id, salary
        FROM employees
        WHERE department_id = p_department_id
          AND status = 'ACTIVE';

    v_emp_id    employees.employee_id%TYPE;
    v_salary    employees.salary%TYPE;
    v_new_sal   employees.salary%TYPE;
    v_updated   NUMBER := 0;

BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting salary hike process...');

    FOR emp_rec IN emp_cur LOOP
        v_emp_id  := emp_rec.employee_id;
        v_salary  := emp_rec.salary;
        v_new_sal := v_salary + (v_salary * (p_hike_percentage / 100));

        -- Update employee salary
        UPDATE employees
        SET salary = v_new_sal,
            last_updated = SYSDATE
        WHERE employee_id = v_emp_id;

        v_updated := v_updated + 1;

        -- Log salary change
        INSERT INTO salary_audit_log (employee_id, old_salary, new_salary, updated_on)
        VALUES (v_emp_id, v_salary, v_new_sal, SYSDATE);
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE(v_updated || ' employees received a ' || p_hike_percentage || '% hike.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        INSERT INTO error_log (error_message, log_time)
        VALUES (SQLERRM, SYSDATE);
        DBMS_OUTPUT.PUT_LINE('Error occurred: ' || SQLERRM);
END;
/
