// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-relayer-solidity-sdk/WormholeRelayerSDK.sol";

contract Spoke is TokenSender, TokenReceiver {
    uint256 constant GAS_LIMIT = 250_000;
    uint256 constant GAS_LIMIT_FOR_WITHDRAWS_AND_BORROWS = 1_500_000; // to get your tokens from Hub! A safe upper bound for both actions on Hub chain and back on Spoke chain
    // Requires Hub to be the cheapest chain gas-wise

    enum Action {DEPOSIT, WITHDRAW, BORROW, REPAY}

    uint16 hubChain;
    address hubAddress;

    constructor(uint16 _hubChain, address _hubAddress, address _wormholeRelayer, address _tokenBridge, address _wormhole)
        TokenBase(_wormholeRelayer, _tokenBridge, _wormhole)
    {
        hubChain = _hubChain;
        hubAddress = _hubAddress;
    }

    function quoteDeposit() public view returns (uint256 cost) {
        (cost,) = wormholeRelayer.quoteEVMDeliveryPrice(hubChain, 0, GAS_LIMIT);
    }

    function quoteBorrow() public view returns (uint256 cost) {
        (cost,) = wormholeRelayer.quoteEVMDeliveryPrice(hubChain, 0, GAS_LIMIT_FOR_WITHDRAWS_AND_BORROWS);
    }

    function quoteRepay() public view returns (uint256 cost) {
        (cost,) = wormholeRelayer.quoteEVMDeliveryPrice(hubChain, 0, GAS_LIMIT);
    }

    function quoteWithdraw() public view returns (uint256 cost) {
        (cost,) = wormholeRelayer.quoteEVMDeliveryPrice(hubChain, 0, GAS_LIMIT_FOR_WITHDRAWS_AND_BORROWS);
    }

    function deposit(address tokenAddress, uint256 amount) public payable {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        sendTokenWithPayloadToEvm(hubChain, hubAddress, abi.encode(Action.DEPOSIT, msg.sender), 0, GAS_LIMIT, msg.value, tokenAddress, amount);
    }

    function withdraw(address tokenAddress, uint256 amount) public payable {
        wormholeRelayer.sendPayloadToEvm{value: msg.value}(hubChain, hubAddress, abi.encode(Action.WITHDRAW, msg.sender, tokenAddress, amount), 0, GAS_LIMIT_FOR_WITHDRAWS_AND_BORROWS);
    }

    function borrow(address tokenAddress, uint256 amount) public payable {
        wormholeRelayer.sendPayloadToEvm{value: msg.value}(hubChain, hubAddress, abi.encode(Action.BORROW, msg.sender, tokenAddress, amount), 0, GAS_LIMIT_FOR_WITHDRAWS_AND_BORROWS);
    }

    function repay(address tokenAddress, uint256 amount) public payable {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        sendTokenWithPayloadToEvm(hubChain, hubAddress, abi.encode(Action.REPAY, msg.sender), 0, GAS_LIMIT, msg.value, tokenAddress, amount);
   }

    function receiveTokensWithPayloads(
        ITokenBridge.TransferWithPayload[] memory transfers,
        bytes32 sourceAddress, 
        uint16 sourceChain,
        bytes32 deliveryHash
    ) internal override onlyWormholeRelayer isRegisteredSender(sourceChain, sourceAddress) replayProtect(deliveryHash) {
        require(transfers.length == 1, "Expecting one transfer");
        ITokenBridge.TransferWithPayload memory transfer = transfers[0];
            
        (address user) = abi.decode(transfer.payload, (address));
        address wrappedTokenAddress = transfer.tokenChain == wormhole.chainId() ? fromWormholeFormat(transfer.tokenAddress) : tokenBridge.wrappedAsset(transfer.tokenChain, transfer.tokenAddress);

        uint256 denormalizedAmount = transfer.amount;
        uint8 decimals = getDecimals(wrappedTokenAddress);
        if(decimals > 8) denormalizedAmount *= 10 ** (decimals - 8);
        IERC20(wrappedTokenAddress).transfer(user, denormalizedAmount);

        // send any refund back to the user
        user.call{value: msg.value}("");
    }

    function getDecimals(address tokenAddress) internal view returns (uint8 decimals) {
        (, bytes memory queriedDecimals) = tokenAddress.staticcall(abi.encodeWithSignature("decimals()"));
        decimals = abi.decode(queriedDecimals, (uint8));
    }
}
