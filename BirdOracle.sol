// https://kovan.etherscan.io/address/0x8e19f3d69d340eecd596487b0deaffd13444bf7f#code

pragma solidity ^0.5.16;

// SPDX-License-Identifier: MIT

/**
Bird On-chain Oracle to confirm rating with 2+ consensus before update using the off-chain API https://www.bird.money/docs
*/

contract BirdOracle {
    BirdRequest[] public onChainRequests; //keep track of list of on-chain

    uint256 public minConsensus = 2; //minimum number of consensus before confirmation
    uint256 public birdNest = 3; // bird consensus count
    uint256 public trackId = 0;

    uint8 constant notTrusted = 0;
    uint8 constant trustedAndNotVoted = 1;
    uint8 constant trustedAndVoted = 2;

    /**
     * Bird Standard API Request
     * id: "1"
     * ethAddress: address(0xcF01971DB0CAB2CBeE4A8C21BB7638aC1FA1c38c)
     * key: "bird_rating"
     * value: 400000000000000000   // 4.0
     * resolved: true / false
     * response: response from off-chain oracles
     * nest: approved off-chain oracles nest/addresses and keep track of vote (1= trusted and not voted, 2=voted)
     */

    struct BirdRequest {
        uint256 id;
        address ethAddress;
        string key;
        uint256 value;
        bool resolved;
        mapping(uint256 => uint256) response; //specific answer => number of votes of that answer
        mapping(address => uint256) nest; //address => trusted or not, voted or not
    }

    mapping(address => uint256) public ratings; //saved ratings after consensus

    /**
     * Bird Standard API Request
     * Off-Chain-Request from outside the blockchain
     */
    event OffChainRequest(uint256 id, address ethAddress, string key);

    /**
     * To call when there is consensus on final result
     */
    event UpdatedRequest(
        uint256 id,
        address ethAddress,
        string key,
        uint256 value
    );

    function newChainRequest(address _ethAddress, string memory _key) public {
        uint256 length =
            onChainRequests.push(
                BirdRequest({
                    id: trackId,
                    ethAddress: _ethAddress,
                    key: _key,
                    value: 0, // if resolved is true then read value
                    resolved: false // if resolved is false then value do not matter
                })
            );

        BirdRequest storage r = onChainRequests[length - 1];

        /**
         * trusted oracles in bird nest
         */
        address bird1 = 0x35fA8692EB10F87D17Cd27fB5488598D33B023E5;
        address bird2 = 0x58Fd79D34Edc6362f92c6799eE46945113A6EA91;
        address bird3 = 0x0e4338DFEdA53Bc35467a09Da483410664d34e88;

        /**
         * track votes
         */
        r.nest[bird1] = trustedAndNotVoted;
        r.nest[bird2] = trustedAndNotVoted;
        r.nest[bird3] = trustedAndNotVoted;

        /**
         * Off-Chain event trigger
         */
        emit OffChainRequest(trackId, _ethAddress, _key);

        /**
         * update total number of requests
         */
        trackId++;
    }

    /**
     * called by the oracle to record its answer
     * Off-Chain oracle to update its consensus answer
     */
    function updateChainRequest(uint256 _id, uint256 _valueResponse) public {
        BirdRequest storage req = onChainRequests[_id];

        require(
            req.resolved == false,
            "Error: Consensus is complete so you can not vote."
        );
        require(
            req.nest[address(msg.sender)] == trustedAndNotVoted,
            "Error: You can not vote."
        );

        req.nest[msg.sender] = trustedAndVoted;
        if (minConsensus <= ++req.response[_valueResponse]) {
            req.resolved = true;
            req.value = _valueResponse;
            ratings[req.ethAddress] = _valueResponse;
            emit UpdatedRequest(req.id, req.ethAddress, req.key, req.value);
        }
    }

    function getRatingByAddress(address _addr) public view returns (uint256) {
        return ratings[_addr];
    }

    function getRating() public view returns (uint256) {
        return ratings[msg.sender];
    }
}
