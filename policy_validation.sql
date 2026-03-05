
-- Simple Scenario: Basic Policy Validation
CREATE OR REPLACE PROCEDURE validate_policy_eligibility (
    p_policy_id IN NUMBER,
    p_customer_age IN NUMBER,
    p_policy_type IN VARCHAR2,
    p_is_eligible OUT BOOLEAN
) AS
    v_min_age NUMBER;
    v_max_age NUMBER;
BEGIN
    -- Basic age validation for different policy types
    CASE p_policy_type
        WHEN 'LIFE' THEN 
            v_min_age := 18;
            v_max_age := 65;
        WHEN 'HEALTH' THEN 
            v_min_age := 1;
            v_max_age := 75;
        WHEN 'VEHICLE' THEN 
            v_min_age := 18;
            v_max_age := 80;
    END CASE;

    -- Check eligibility
    IF p_customer_age BETWEEN v_min_age AND v_max_age THEN
        p_is_eligible := TRUE;
    ELSE
        p_is_eligible := FALSE;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_is_eligible := FALSE;
        RAISE_APPLICATION_ERROR(-20001, 'Error validating policy eligibility');
END validate_policy_eligibility;
