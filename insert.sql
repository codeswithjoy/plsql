DELIMITER $$

CREATE PROCEDURE insert_car(
    IN p_car_id INT,
    IN p_brand VARCHAR(50),
    IN p_model VARCHAR(50)
)
BEGIN
    INSERT INTO car (car_id, brand, model)
    VALUES (p_car_id, p_brand, p_model);
END$$

DELIMITER ;
