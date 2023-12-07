// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract MultisigWallet {
  // events
    event SubmitTx(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 amount,
        string reason
    );

    event ConfirmTx(address indexed owner, uint indexed txIndex);

    event ExecuteTx(address indexed owner, uint indexed txIndex);

    struct Transaction {
        uint256 txIndex;
        address to;
        uint256 amount;
        string reason;
        bool executed;
        uint256 confirmations;
    }
    // only access via contract
    Transaction[] private s_transactions;
    // mapping tx index to the tx's data
    mapping(uint256 => Transaction) private s_transaction;
    // record the existance of a tx
    mapping(uint256 => bool) private txExits;
    // record which user has confirmed the tx
    mapping(uint256 => mapping(address => bool)) s_userHasConfimed;
    // get all owners / addresses in the wallet
    address[] private s_owners;

    uint256 private s_balance;

    //Check if an address is the owner of the wallet.
    mapping(address => bool) private isOwner;

    //specifies the number of confirmations required for a transaction to be executed.
    uint256 private s_numOfConfirmationsRequired;

    error MultisigWallet__UserAlreadyFound();
    error MultisigWallet__NotAnOwner();
    error MultisigWallet__TransactionDoesNotExist();
    error MultisigWallet__TransactionAlreadyExecuted();
    error MultisigWallet__UserAlreadyConfirmedTransaction();
    error MultisigWallet__TransactionNeedsApproval();
    error MultisigWallet__TransactionExecutionFailed();

    constructor(address[] memory _owners) payable {
        s_numOfConfirmationsRequired = _owners.length;

        // Loop through the entered array and add all the addresses to the s_owners group
        for (uint i = 0; i < _owners.length; i++) {
            // Extract out the looped address
            address user = _owners[i];

            if (isOwner[user] == true) {
                revert MultisigWallet__UserAlreadyFound();
            }

            // Add it to the isOwner mapping to make sure it is part of the owners of the wallet
            isOwner[user] = true;
            s_owners.push(user);
        }

        s_balance = msg.value;
    }

    function submitTransaction(
        address receiver,
        uint256 _amount,
        string memory _reason
    ) public {
        if (isOwner[msg.sender] != true) {
            revert MultisigWallet__NotAnOwner();
        }

        // Get the tx length
        uint256 txNum = s_transactions.length;

        s_transactions.push(
            Transaction({
                txIndex: txNum,
                to: receiver,
                amount: _amount,
                reason: _reason,
                executed: false,
                confirmations: 0
            })
        );

        txExits[txNum] = true;

        emit SubmitTx(msg.sender, txNum, receiver, _amount, _reason);
    }

    function confirmTransaction(uint256 _txIndex) public {
        // Verify that the user trying to confirm the transaction is a verified owner
        if (isOwner[msg.sender] != true) {
            revert MultisigWallet__NotAnOwner();
        }

        // Verify that the transaction exists
        if (txExits[_txIndex] != true) {
            revert MultisigWallet__TransactionDoesNotExist();
        }

        // Verify that the transaction is not yet executed
        if (s_transactions[_txIndex].executed == true) {
            revert MultisigWallet__TransactionAlreadyExecuted();
        }

        // Verify that the user has not already confirmed the transaction
        if (s_userHasConfimed[_txIndex][msg.sender] == true) {
            revert MultisigWallet__UserAlreadyConfirmedTransaction();
        }

        // Extract out the wanted transaction
        Transaction storage transaction = s_transactions[_txIndex];

        // Update the number of confirmations
        transaction.confirmations += 1;

        // Update user confirmation status
        s_userHasConfimed[_txIndex][msg.sender] = true;

        // Emit the confirmation event
        emit ConfirmTx(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex) public {
        // Verify that the user trying to confirm the transaction is a verified owner
        if (isOwner[msg.sender] != true) {
            revert MultisigWallet__NotAnOwner();
        }

        // Verify that the transaction exists
        if (txExits[_txIndex] != true) {
            revert MultisigWallet__TransactionDoesNotExist();
        }

        // Verify that the transaction is not yet executed
        if (s_transactions[_txIndex].executed == true) {
            revert MultisigWallet__TransactionAlreadyExecuted();
        }

        Transaction storage transaction = s_transactions[_txIndex];

        // Verify that the wanted transaction to be executed has the required number of confirmations to continue
        if (transaction.confirmations < s_numOfConfirmationsRequired) {
            revert MultisigWallet__TransactionNeedsApproval();
        }

        // set the transaction to be executed
        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.amount}('');

        if (!success) {
            revert MultisigWallet__TransactionExecutionFailed();
        }

        s_balance -= transaction.amount;

        emit ExecuteTx(msg.sender, _txIndex);
    }

    // Pure / View
    function getOwners() public view returns (address[] memory) {
        return s_owners;
    }

    function getNumberOfConfimationsRequired() public view returns (uint256) {
        return s_numOfConfirmationsRequired;
    }

    function getTransactions() public view returns (Transaction[] memory) {
        return s_transactions;
    }

    function getTransaction(
        uint256 _txIndex
    ) public view returns (Transaction memory) {
        return s_transaction[_txIndex];
    }

    function getBalance() public view returns (uint256) {
        return s_balance;
    }
}