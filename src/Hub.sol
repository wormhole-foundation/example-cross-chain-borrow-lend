// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-solidity-sdk/WormholeRelayerSDK.sol";

contract Hub is TokenSender, TokenReceiver {

    constructor(address _wormholeRelayer, address _tokenBridge, address _wormhole)
        TokenBase(_wormholeRelayer, _tokenBridge, _wormhole)
    {}

    /**
     * Should receive a payload (and optionally tokens) from a Spoke
     * 
     * The payload should indicate 
     *      - the user who performed the action
     *      - whether this is a deposit or a withdraw request
     *      - (if the action is withdraw) the token and amount that are wished to be withdrawn
     * 
     * If the request is deposit - then this action should be logged somehow in the Hub state
     * (in order to allow the user to request a withdraw in the future)
     * 
     * If the request is withdraw - then a delivery should be initiated to the Spoke with the requested tokens
     * *only if* the user had previously deposited at least that many of the token
     */
    function receivePayloadAndTokens(
        bytes memory payload,
        TokenReceived[] memory receivedTokens,
        bytes32 sourceAddress, 
        uint16 sourceChain,
        bytes32 deliveryHash
    ) internal override {

    }
}