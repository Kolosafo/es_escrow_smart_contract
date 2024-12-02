// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum TaskStatus {
    Complete,
    Pending,
    Cancelled,
    NotStarted
}

interface IESCROW {
    struct EscrowData {
        string id;
        address payable seller;
        address payable buyer;
        string baseCurrency; // seller currency
        uint256 cryptoFunds;
        uint256 fiatFunds;
        uint256 sellerRate;
        string exchangeCurrency; //buyer currency
        bool buyerHasSentFunds;
        bool sellerHasReceivedFunds;
        uint256 transactionFee;
        TaskStatus transactionStatus;
    }

    function getEscrow(
        string memory id
    ) external view returns (EscrowData memory);
}

contract Escrow {
    bool public locked;
    mapping(string => IESCROW.EscrowData) public transactions;

    constructor(
        string memory _id,
        address payable _seller,
        address payable _buyer,
        string memory _baseCurrency,
        uint256 _sellerRate,
        string memory _exchangeCurrency
    ) payable {
        IESCROW.EscrowData memory initialEscrowData = IESCROW.EscrowData({
            id: _id,
            cryptoFunds: msg.value,
            seller: _seller,
            buyer: _buyer,
            baseCurrency: _baseCurrency,
            sellerRate: _sellerRate,
            exchangeCurrency: _exchangeCurrency,
            buyerHasSentFunds: false,
            sellerHasReceivedFunds: false,
            transactionFee: 0,
            fiatFunds: 0,
            transactionStatus: TaskStatus.Pending
        });
        transactions[_id] = initialEscrowData;
    }

    modifier onlySeller(string memory id, address seller) {
        require(
            transactions[id].seller == seller,
            "Only seller can trigger this event"
        );
        _;
    }

    modifier onlyBuyer(string memory id, address buyer) {
        require(
            transactions[id].buyer == buyer,
            "Only buyer can trigger this event"
        );
        _;
    }

    function getTransactionObject(
        string memory id
    ) public view returns (IESCROW.EscrowData memory) {
        IESCROW.EscrowData storage getTransObj = transactions[id];
        return getTransObj;
    }

    function buyerSentFunds(
        string memory id,
        address buyer
    ) public view onlyBuyer(id, buyer) returns (IESCROW.EscrowData memory) {
        IESCROW.EscrowData memory findTransaction = transactions[id];
        findTransaction.buyerHasSentFunds = true;
        return findTransaction;
    }

    function sellerHasRecievedFunds(
        string memory id,
        address seller,
        uint256 amountBuyerDeposited
    )
        public
        payable
        onlySeller(id, seller)
        returns (IESCROW.EscrowData memory)
    {
        require(!locked, "Reentrancy Guard");
        locked = true;
        IESCROW.EscrowData memory findTransaction = transactions[id];
        require(
            findTransaction.transactionStatus == TaskStatus.Pending,
            "This transaction has either been completed or cancelled"
        );
        findTransaction.fiatFunds = amountBuyerDeposited;
        findTransaction.sellerHasReceivedFunds = true;
        findTransaction.buyer.transfer(findTransaction.cryptoFunds);
        findTransaction.transactionStatus = TaskStatus.Complete;
        locked = false;
        return findTransaction;
    }

    function cancelTransaction(
        string memory id,
        address cancelledBy
    ) public view returns (IESCROW.EscrowData memory) {
        IESCROW.EscrowData memory findTransaction = transactions[id];
        require(
            findTransaction.transactionStatus == TaskStatus.Pending,
            "This transaction has either been completed or cancelled"
        );
        if (
            findTransaction.seller != cancelledBy &&
            findTransaction.buyer != cancelledBy
        ) {
            revert("Only the buyer or seller can trigger this event");
        } else {
            findTransaction.transactionStatus = TaskStatus.Cancelled;
        }
        return findTransaction;
    }
}
