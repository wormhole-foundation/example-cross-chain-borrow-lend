// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Hub} from "../src/Hub.sol";
import {Spoke} from "../src/Spoke.sol";

import "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract ExampleCrossChainBorrowLendTest is WormholeRelayerTest {
    
    // Hub chain is Celo Testnet
    uint16 constant hubChain = 14;

    // Spoke chains are BSC, Polygon, and Avalanche Testnets
    uint16[] spokeChains = [4, 5, 6];

    Hub public hub;
    mapping(uint16 => Spoke) spokes;

    mapping(uint16 => ERC20Mock) public tokens;

    constructor() WormholeRelayerTest() {
        ChainInfo[] memory chains = new ChainInfo[](spokeChains.length + 1);

        chains[0] = chainInfosTestnet[hubChain];

        for(uint256 i=0; i<spokeChains.length; i++) {
            chains[i+1] = chainInfosTestnet[spokeChains[i]];
        }

        setActiveForks(chains);
    }

    function selectChain(uint16 chain) public {
        vm.selectFork(activeForks[chain].fork);
    }

    function setUpFork(ActiveFork memory fork) public override {

    }

    function setUpGeneral() public override {
        selectChain(hubChain);
        hub = new Hub(
            address(activeForks[hubChain].relayer),
            address(activeForks[hubChain].tokenBridge),
            address(activeForks[hubChain].wormhole)
        );

        for(uint256 i=0; i<spokeChains.length; i++) {
            ActiveFork memory fork = activeForks[spokeChains[i]];
            vm.selectFork(fork.fork);
            spokes[fork.chainId] = new Spoke(hubChain, address(hub), address(fork.relayer), address(fork.tokenBridge), address(fork.wormhole));
            tokens[fork.chainId] = createAndAttestToken(fork.chainId);
        }

        selectChain(hubChain);
        for(uint256 i=0; i<spokeChains.length; i++) {
            hub.setRegisteredSender(spokeChains[i], toWormholeFormat(address(spokes[spokeChains[i]])));
        }

        for(uint256 i=0; i<spokeChains.length; i++) {
            selectChain(spokeChains[i]);
            spokes[spokeChains[i]].setRegisteredSender(hubChain, toWormholeFormat(address(hub)));
        }
    }

    function deposit(uint16 chain, uint256 amount) internal {
        vm.recordLogs();
        selectChain(chain);

        Spoke spoke = spokes[chain];
        ERC20Mock token = tokens[chain];

        token.mint(address(this), amount);

        uint256 currentBalance = token.balanceOf(address(this));

        token.approve(address(spoke), amount);

        uint256 cost = spoke.quoteDeposit();
        vm.deal(address(this), cost);
        spoke.deposit{value: cost}(address(token), amount);
        performDelivery();

        assertEq(token.balanceOf(address(this)), currentBalance - amount, "Tokens not sent for deposit");
    }

    function withdraw(uint16 chain, uint256 amount) internal {
        vm.recordLogs();
        selectChain(chain);

        Spoke spoke = spokes[chain];
        ERC20Mock token = tokens[chain];

        uint256 currentBalance = token.balanceOf(address(this));
        
        uint256 cost = spoke.quoteWithdraw();
        vm.deal(address(this), cost);
        spoke.withdraw{value: cost}(address(token), amount);
        performDelivery();

        selectChain(hubChain);
        performDelivery();

        selectChain(chain);
        assertEq(token.balanceOf(address(this)), currentBalance + amount, "Tokens not received for withdraw");
    }


    function testDeposit() public {
        // We use multiples of 10**10 because TokenBridge can only send up to 8 decimal places
        deposit(6, 1 * 10**10);
    }

    function testDepositWithdraw() public {
        // We use multiples of 10**10 because TokenBridge can only send up to 8 decimal places
        deposit(6, 1 * 10**10);
        withdraw(6, 1 * 10**10);
    }

    function testMultipleDepositWithdraw() public {
        deposit(6, 1 * 10**10);
        deposit(6, 2 * 10**10);
        deposit(6, 5 * 10**10);
        deposit(6, 7 * 10**10);
        withdraw(6, 6 * 10**10);
        withdraw(6, 9 * 10**10);
    }

    function testDepositWithdrawMultipleChains() public {

        deposit(6, 10 * 10**10);
        deposit(4, 9 * 10**10);
        withdraw(4, 9 * 10**10);
        withdraw(6, 10 * 10**10);
    }
}
