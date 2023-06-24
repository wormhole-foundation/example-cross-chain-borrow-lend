// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Hub} from "../src/Hub.sol";
import {Spoke} from "../src/Spoke.sol";

import "wormhole-relayer-solidity-sdk/testing/WormholeRelayerTest.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract HelloTokensTest is WormholeRelayerTest {
    Hub public hub;

    Spoke public spoke;

    ERC20Mock public token;

    function setUpSource() public override {
        hub = new Hub(
            address(relayerSource),
            address(tokenBridgeSource),
            address(wormholeSource)
        );
    }

    function setUpTarget() public override {
        token = createAndAttestToken(targetFork);
        spoke = new Spoke(
            sourceChain, // hub chain id
            address(hub), // hub address
            address(relayerTarget),
            address(tokenBridgeTarget),
            address(wormholeTarget)
        );
        spoke.setRegisteredSender(sourceChain, toWormholeFormat(address(hub)));

        bytes32 spokeAddress = toWormholeFormat(address(spoke));
        vm.selectFork(sourceFork);
        hub.setRegisteredSender(targetChain, spokeAddress);
    }

    function deposit(uint256 amount) internal {
        vm.recordLogs();
        vm.selectFork(targetFork);

        token.mint(address(this), amount);

        uint256 currentBalance = token.balanceOf(address(this));

        token.approve(address(spoke), amount);

        uint256 cost = spoke.quoteDeposit();
        vm.deal(address(this), cost);
        spoke.deposit{value: cost}(address(token), amount);
        performDelivery();

        assertEq(token.balanceOf(address(this)), currentBalance - amount, "Tokens not sent for deposit");
    }

    function withdraw(uint256 amount) internal {
        vm.recordLogs();
        vm.selectFork(targetFork);

        uint256 currentBalance = token.balanceOf(address(this));

        uint256 cost = spoke.quoteWithdraw();
        vm.deal(address(this), cost);
        spoke.withdraw{value: cost}(address(token), amount);
        performDelivery();

        vm.selectFork(sourceFork);
        performDelivery();

        vm.selectFork(targetFork);
        assertEq(token.balanceOf(address(this)), currentBalance + amount, "Tokens not received for withdraw");
    }

    function borrow(uint256 amount) internal {
        vm.recordLogs();
        vm.selectFork(targetFork);

        uint256 currentBalance = token.balanceOf(address(this));

        uint256 cost = spoke.quoteBorrow();
        vm.deal(address(this), cost);
        spoke.borrow{value: cost}(address(token), amount);
        performDelivery();

        vm.selectFork(sourceFork);
        performDelivery();

        vm.selectFork(targetFork);
        assertEq(token.balanceOf(address(this)), currentBalance + amount, "Tokens not received for borrow");
    }

    function repay(uint256 amount) internal {
        vm.recordLogs();
        vm.selectFork(targetFork);

        token.mint(address(this), amount);

        uint256 currentBalance = token.balanceOf(address(this));

        token.approve(address(spoke), amount);

        uint256 cost = spoke.quoteRepay();
        vm.deal(address(this), cost);
        spoke.repay{value: cost}(address(token), amount);
        performDelivery();

        assertEq(token.balanceOf(address(this)), currentBalance - amount, "Tokens not sent for repay");
    }

    function testDeposit() public {
        // We use multiples of 10**10 because TokenBridge can only send up to 8 decimal places
        deposit(1 * 10**10);
    }

    function testWithdraw() public {
        // We use multiples of 10**10 because TokenBridge can only send up to 8 decimal places
        deposit(1 * 10**10);
        withdraw(1 * 10**10);
    }

    function testDepositAndWithdraw() public {
        deposit(1 * 10**10);
        deposit(2 * 10**10);
        deposit(5 * 10**10);
        deposit(7 * 10**10);
        withdraw(6 * 10**10);
        withdraw(9 * 10**10);
    }
}
