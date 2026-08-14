/*
    Challenge: Implement a Secure Fund Transfer Function

    In this challenge, you will implement a PostgreSQL stored function to simulate transferring funds 
    between two accounts in a banking system. The function must follow proper validation, ensure data 
    integrity, and log transactions with a shared reference.

    Your function should be named:
    banking.transfer_funds(from_id INT, to_id INT, amount NUMERIC)

    The function must:

    - Prevent transfers to the same account
    - Ensure the transfer amount is greater than zero
    - Validate that both sender and recipient accounts exist
    - Prevent transfers if either account is marked as "frozen"
    - Ensure the sender has sufficient funds
    - Debit the sender and credit the recipient atomically
    - Log two transactions: a withdrawal and a deposit, both linked by the same UUID reference
    - Raise meaningful exceptions for all validation failures

    The function should perform all operations within a safe transactional context, maintaining 
    database consistency even in the event of failure.

    Notes:
    - In order to test you can mock some additional data in the tables that participates in this challenge.
    - Make sure of raising errors when they're present

    ERD:
    +---------------------+            +--------------------------+
    |     accounts        |            |      transactions        |
    +---------------------+            +--------------------------+
    | account_id (PK)     |<-----------| transaction_id (PK)      |
    | balance             |            | account_id (FK)          |
    | status              |            | amount                   |
    +---------------------+            | transaction_type         |
                                       | reference                |
                                       | transaction_date         |
                                       +--------------------------+
*/


-- your solution here
DROP FUNCTION IF EXISTS banking.transfer_funds(INT, INT, NUMERIC);

CREATE FUNCTION banking.transfer_funds(
    from_id INT,
    to_id INT,
    amount NUMERIC
) RETURNS VOID AS $$
DECLARE
    v_sender_balance NUMERIC;
    v_sender_status TEXT;
    v_recipient_status TEXT;
    v_reference UUID;
BEGIN
    IF from_id IS NULL OR to_id IS NULL OR amount IS NULL THEN
        RAISE EXCEPTION 'Sender, recipient and amount are required (got from=%, to=%, amount=%).',
            from_id, to_id, amount;
    END IF;

    IF from_id = to_id THEN
        RAISE EXCEPTION 'Cannot transfer to the same account.';
    END IF;

    IF amount <= 0 THEN
        RAISE EXCEPTION 'Transfer amount must be greater than zero.';
    END IF;

    IF round(amount, 2) <> amount THEN
        RAISE EXCEPTION 'Transfer amount % cannot be finer than one cent.', amount;
    END IF;

    PERFORM 1
    FROM banking.accounts
    WHERE account_id IN (from_id, to_id)
    ORDER BY account_id
    FOR UPDATE;

    SELECT balance, status INTO v_sender_balance, v_sender_status
    FROM banking.accounts
    WHERE account_id = from_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sender account ID % does not exist.', from_id;
    END IF;

    SELECT status INTO v_recipient_status
    FROM banking.accounts
    WHERE account_id = to_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Recipient account ID % does not exist.', to_id;
    END IF;

    IF v_sender_status = 'frozen' THEN
        RAISE EXCEPTION 'Sender account is frozen. Transfer aborted.';
    END IF;

    IF v_recipient_status = 'frozen' THEN
        RAISE EXCEPTION 'Recipient account is frozen. Transfer aborted.';
    END IF;

    IF v_sender_balance < amount THEN
        RAISE EXCEPTION 'Insufficient funds in sender account.';
    END IF;

    UPDATE banking.accounts
    SET balance = balance - amount
    WHERE account_id = from_id;

    UPDATE banking.accounts
    SET balance = balance + amount
    WHERE account_id = to_id;

    v_reference := uuid_generate_v4();

    INSERT INTO banking.transactions (account_id, amount, transaction_type, reference)
    VALUES
        (from_id, amount, 'withdrawal', v_reference::text),
        (to_id, amount, 'deposit', v_reference::text);

END;
$$ LANGUAGE plpgsql;