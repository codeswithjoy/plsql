DECLARE
    v_account_id       NUMBER := :account_id;
    v_transfer_amount  NUMBER := :amount;
    v_src_balance      NUMBER;
    v_dest_balance     NUMBER;
    v_daily_limit      NUMBER;
    v_err_msg          VARCHAR2(4000);

    -- Cursor to fetch KYC + block status
    CURSOR c_acct_info IS
        SELECT kyc_flag, block_flag
        FROM customer_profile
        WHERE account_id = v_account_id;

    v_kyc     CHAR(1);
    v_blocked CHAR(1);

    -- Autonomous transaction procedure for audit logs
    PROCEDURE log_audit(p_status VARCHAR2, p_message VARCHAR2) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO audit_transaction_log
            (txn_timestamp, account_id, status, message)
        VALUES
            (SYSTIMESTAMP, v_account_id, p_status, p_message);
        COMMIT;
    END log_audit;

BEGIN
    -- 1. Security Pre-Validation
    OPEN c_acct_info;
    FETCH c_acct_info INTO v_kyc, v_blocked;
    CLOSE c_acct_info;

    IF v_kyc = 'N' THEN
        RAISE_APPLICATION_ERROR(-20001, 'KYC pending — transaction blocked.');
    END IF;

    IF v_blocked = 'Y' THEN
        RAISE_APPLICATION_ERROR(-20002, 'Account blocked — fraud suspected.');
    END IF;

    -- 2. Fetch current balances & daily limit
    SELECT balance, daily_txn_limit
    INTO v_src_balance, v_daily_limit
    FROM account_master
    WHERE account_id = v_account_id FOR UPDATE;

    -- 3. Daily limit check
    IF v_transfer_amount > v_daily_limit THEN
        RAISE_APPLICATION_ERROR(-20003, 'Transfer exceeds daily limit.');
    END IF;

    -- 4. Check sufficient funds
    IF v_src_balance < v_transfer_amount THEN
        RAISE_APPLICATION_ERROR(-20004, 'Insufficient balance.');
    END IF;

    -- 5. Debit sender
    UPDATE account_master
    SET balance = balance - v_transfer_amount
    WHERE account_id = v_account_id;

    -- 6. Credit settlement pool (internal system account)
    UPDATE bank_settlement_pool
    SET pool_balance = pool_balance + v_transfer_amount
    WHERE pool_id = 101;

    -- 7. Insert transaction record
    INSERT INTO txn_ledger
        (txn_id, account_id, txn_type, amount, txn_time)
    VALUES
        (txn_seq.NEXTVAL, v_account_id, 'DEBIT', v_transfer_amount, SYSTIMESTAMP);

    -- 8. Commit atomic transaction
    COMMIT;

    log_audit('SUCCESS', 'Transfer completed successfully.');

EXCEPTION
    WHEN OTHERS THEN
        v_err_msg := SQLERRM;
        ROLLBACK;
        log_audit('FAILED', v_err_msg);
        RAISE;
END;
/
