-- Xóa thủ tục cũ nếu đã tồn tại
DROP PROCEDURE IF EXISTS ProcessPrescription;

DELIMITER //

-- Khởi tạo Procedure với các tham số IN và OUT chuẩn coder
CREATE PROCEDURE ProcessPrescription(
    IN p_patient_id INT,
    IN p_medicine_id INT,
    IN p_quantity INT,
    OUT p_status_message VARCHAR(255)
)
BEGIN
    -- Khai báo các biến cục bộ để lưu trữ tạm thời thông tin thuốc
    DECLARE v_current_stock INT;
    DECLARE v_unit_price DECIMAL(18,2);

    -- Khai báo khối xử lý ngoại lệ (Exception Handler) cho các lỗi hệ thống chung
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status_message = 'Lỗi: Hệ thống gặp sự cố, giao dịch đã bị hủy bỏ.';
    END;

    -- Bắt đầu khối giao dịch
    START TRANSACTION;

        -- Lấy số lượng tồn kho và đơn giá hiện tại của thuốc
        SELECT stock_quantity, unit_price 
        INTO v_current_stock, v_unit_price
        FROM Medicines
        WHERE medicine_id = p_medicine_id
        FOR UPDATE;

        -- Kiểm tra logic nghiệp vụ
        IF p_quantity > v_current_stock THEN
            -- Hủy bỏ giao dịch và trả về thông báo lỗi
            SET p_status_message = 'Lỗi: Số lượng tồn kho không đủ';
            ROLLBACK;
        ELSE
            -- Thao tác 1: Trừ số lượng cấp phát trong kho thuốc
            UPDATE Medicines
            SET stock_quantity = stock_quantity - p_quantity
            WHERE medicine_id = p_medicine_id;

            -- Thao tác 2: Cộng dồn công nợ cho bệnh nhân
            UPDATE Patient_Invoices
            SET total_due = total_due + (p_quantity * v_unit_price)
            WHERE patient_id = p_patient_id;

            -- Xác nhận giao dịch thành công
            SET p_status_message = 'Đã cấp phát thành công';
            COMMIT;
        END IF;

END //

DELIMITER ;

-- TRƯỜNG HỢP 1: Cấp phát hợp lệ (Số lượng yêu cầu <= Tồn kho)
CALL ProcessPrescription(1, 101, 2, @status_success);
SELECT @status_success AS Result_Message; 
-- TRƯỜNG HỢP 2: Chặn và báo lỗi (Số lượng yêu cầu > Tồn kho)
CALL ProcessPrescription(2, 105, 100, @status_error);
SELECT @status_error AS Result_Message;