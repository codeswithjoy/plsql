DELIMITER $$

CREATE PROCEDURE get_car_by_id(
    IN p_car_id INT
)
BEGIN
    SELECT * 
    FROM car
    WHERE car_id = p_car_id;
END$$

DELIMITER ;
