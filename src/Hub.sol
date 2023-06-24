// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-relayer-solidity-sdk/WormholeRelayerSDK.sol";

contract Hub is TokenSender, TokenReceiver {
    uint256 constant GAS_LIMIT = 250_000;

    enum Action {DEPOSIT, WITHDRAW, BORROW, REPAY}

    // user => wrapped token address => amount (in units of 10^-8)
    mapping(address => mapping(address => uint256)) public vaultDeposits;

    // user => wrapped token address => amount (in units of 10^-8)
    mapping(address => mapping(address => uint256)) public vaultBorrows;

    constructor(address _wormholeRelayer, address _tokenBridge, address _wormhole)
        TokenBase(_wormholeRelayer, _tokenBridge, _wormhole)
    {}

    function receiveTokensWithPayloads(
        ITokenBridge.TransferWithPayload[] memory transfers,
        bytes32 sourceAddress, 
        uint16 sourceChain,
        bytes32 deliveryHash
    ) internal override onlyWormholeRelayer isRegisteredSender(sourceChain, sourceAddress) replayProtect(deliveryHash) {
        require(transfers.length == 1, "Expecting one transfer");
        ITokenBridge.TransferWithPayload memory transfer = transfers[0];
        
        (Action action, address user) = abi.decode(transfer.payload, (Action, address));
        address wrappedTokenAddress = tokenBridge.wrappedAsset(transfer.tokenChain, transfer.tokenAddress);

        bool succeeded = false;
        if(action == Action.DEPOSIT || action == Action.REPAY) {
            succeeded = updateHubState(action, user, wrappedTokenAddress, transfer.amount); // amount given with 8 decimals (units of 10^-8)
        }

        if(!succeeded) {
            uint8 decimals = getDecimals(wrappedTokenAddress);

            uint256 denormalizedAmount = transfer.amount; // we store all decimals on the hub in normalized form (no more than 8 decimals)
            if(decimals > 8) denormalizedAmount *= uint256(10) ** (decimals - 8);
            sendTokenToUser(user, sourceChain, sourceAddress, wrappedTokenAddress, denormalizedAmount);
        }
    }

    function receivePayload(
        bytes memory payload,
        bytes32 sourceAddress, 
        uint16 sourceChain,
        bytes32 deliveryHash
    ) internal override onlyWormholeRelayer isRegisteredSender(sourceChain, sourceAddress) replayProtect(deliveryHash) {
        (Action action, address user, address tokenAddress, uint256 amount) = abi.decode(payload, (Action, address, address, uint256));
        address wrappedTokenAddress = tokenBridge.wrappedAsset(sourceChain, toWormholeFormat(tokenAddress));

        uint8 decimals = getDecimals(wrappedTokenAddress);

        uint256 normalizedAmount = amount; // we store all decimals on the hub in normalized form (no more than 8 decimals)
        if(decimals > 8) normalizedAmount /= uint256(10) ** (decimals - 8);
        
        bool succeeded = false;
        if(action == Action.BORROW || action == Action.WITHDRAW) {
            succeeded = updateHubState(action, user, wrappedTokenAddress, normalizedAmount); 
        }

        if(succeeded) {
            sendTokenToUser(user, sourceChain, sourceAddress, wrappedTokenAddress, amount);
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
        } else if(action == Action.BORROW) {
            if(currentHubBalance < amount) return false;
            vaultBorrows[user][wrappedTokenAddress] += amount;
        } else if(action == Action.REPAY) {
            if(vaultBorrows[user][wrappedTokenAddress] < amount) {
                vaultDeposits[user][wrappedTokenAddress] += amount - vaultBorrows[user][wrappedTokenAddress];
                vaultBorrows[user][wrappedTokenAddress] = 0;
            } else {
                vaultBorrows[user][wrappedTokenAddress] -= amount;
            }
        }
        return true;
    }

    function sendTokenToUser(address user, uint16 sourceChain, bytes32 sourceAddress, address wrappedTokenAddress, uint256 amount) internal {
        forwardTokenWithPayloadToEvm(sourceChain, fromWormholeFormat(sourceAddress), abi.encode(user), 0, GAS_LIMIT, msg.value, wrappedTokenAddress, amount);
    }

    function getDecimals(address tokenAddress) internal view returns (uint8 decimals) {
        (, bytes memory queriedDecimals) = tokenAddress.staticcall(abi.encodeWithSignature("decimals()"));
        decimals = abi.decode(queriedDecimals, (uint8));
    }
}