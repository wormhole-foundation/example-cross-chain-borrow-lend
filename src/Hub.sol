// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-solidity-sdk/WormholeRelayerSDK.sol";

contract Hub is TokenSender, TokenReceiver {
    uint256 constant GAS_LIMIT = 250_000;

    enum Action {DEPOSIT, WITHDRAW}

    // user => wrapped token address => amount 
    mapping(address => mapping(address => uint256)) public vaultDeposits;

    constructor(address _wormholeRelayer, address _tokenBridge, address _wormhole)
        TokenBase(_wormholeRelayer, _tokenBridge, _wormhole)
    {}

    function receivePayloadAndTokens(
        bytes memory payload,
        TokenReceived[] memory receivedTokens,
        bytes32 sourceAddress, 
        uint16 sourceChain,
        bytes32 deliveryHash
    ) internal override onlyWormholeRelayer isRegisteredSender(sourceChain, sourceAddress) replayProtect(deliveryHash) {
        if(receivedTokens.length == 0) {
            (Action action, address user, address tokenHomeAddress, uint256 amount) = abi.decode(payload, (Action, address, address, uint256));
            
            address tokenAddressOnThisChain = getTokenAddressOnThisChain(sourceChain, toWormholeFormat(tokenHomeAddress));

            if(action == Action.WITHDRAW) {
                if(updateHubState(action, user, tokenAddressOnThisChain, amount)) {
                    sendTokenToUser(user, sourceChain, sourceAddress, tokenAddressOnThisChain, amount);
                }
            }
        } else if(receivedTokens.length == 1) {
            TokenReceived memory receivedToken = receivedTokens[0];

            (Action action, address user) = abi.decode(payload, (Action, address));

            if(action == Action.DEPOSIT) {
                updateHubState(action, user, receivedToken.tokenAddress, receivedToken.amount);
            }
        }
    }

    function updateHubState(Action action, address user, address wrappedTokenAddress, uint256 amount) internal returns (bool success) {
        uint256 currentHubBalance = IERC20(wrappedTokenAddress).balanceOf(address(this));
        if(action == Action.DEPOSIT) {
            vaultDeposits[user][wrappedTokenAddress] += amount;
        } else if(action == Action.WITHDRAW) {
            if(vaultDeposits[user][wrappedTokenAddress] < amount) return false;
            if(currentHubBalance < amount) return false;
            vaultDeposits[user][wrappedTokenAddress] -= amount;
        }
        return true;
    }

    function sendTokenToUser(address user, uint16 sourceChain, bytes32 sourceAddress, address wrappedTokenAddress, uint256 amount) internal {
        forwardTokenWithPayloadToEvm(sourceChain, fromWormholeFormat(sourceAddress), abi.encode(user), 0, GAS_LIMIT, msg.value, wrappedTokenAddress, amount);
    }
}