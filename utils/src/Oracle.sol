// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Oracle {
    address public owner;
    address[] public nodes;
    mapping(address => bool) public isNode;

    struct Round {
        uint256 id;
        uint256 totalSubmissionCount;
        uint256 lastUpdatedAt;
    }

    mapping(string => Round) public rounds;
    mapping(string => mapping(uint256 => mapping(address => uint256)))
        public nodePrices;
    mapping(string => mapping(uint256 => mapping(address => bool)))
        public hasSubmitted;
    mapping(string => uint256) public currentPrices;

    event PriceUpdated(string coin, uint256 price, uint256 roundId);

    constructor() {
        owner = msg.sender;
    }

    function getQuorum() public view returns (uint256) {
        if (nodes.length < 3) {
            return 3;
        }

        // ceil(nodes.length * 2 / 3)
        return (nodes.length * 2 + 2) / 3;
    }

    function addNode() public {
        if (!isNode[msg.sender]) {
            isNode[msg.sender] = true;
            nodes.push(msg.sender);
        }
    }

    function submitPrice(string memory coin, uint256 price) public {
        require(isNode[msg.sender], "Not a node");

        Round storage round = rounds[coin];
        require(
            !hasSubmitted[coin][round.id][msg.sender],
            "Already submitted for this round"
        );

        nodePrices[coin][round.id][msg.sender] = price;
        hasSubmitted[coin][round.id][msg.sender] = true;
        round.totalSubmissionCount++;

        if (round.totalSubmissionCount >= getQuorum()) {
            _finalizeRound(coin);
        }
    }

    function _finalizeRound(string memory coin) internal {
        Round storage round = rounds[coin];
        uint256 totalPrice = 0;
        uint256 count = 0;

        for (uint256 i = 0; i < nodes.length; i++) {
            address node = nodes[i];
            if (hasSubmitted[coin][round.id][node]) {
                totalPrice += nodePrices[coin][round.id][node];
                count++;
            }
        }

        uint256 avgPrice = 0;
        if (count > 0) {
            avgPrice = totalPrice / count;
            currentPrices[coin] = avgPrice;
        }

        emit PriceUpdated(coin, avgPrice, round.id);

        round.lastUpdatedAt = block.timestamp;
        round.id++;
        round.totalSubmissionCount = 0;
    }
}
