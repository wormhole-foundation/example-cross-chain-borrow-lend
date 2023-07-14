// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-solidity-sdk/WormholeRelayerSDK.sol";

contract Spoke is TokenSender, TokenReceiver {

    uint16 hubChain;
    address hubAddress;

    constructor(uint16 _hubChain, address _hubAddress, address _wormholeRelayer, address _tokenBridge, address _wormhole)
        TokenBase(_wormholeRelayer, _tokenBridge, _wormhole)
    {
        hubChain = _hubChain;
        hubAddress = _hubAddress;
    }

    /**
     * Returns the msg.value needed to call 'deposit'
     */
    function quoteDeposit() public view returns (uint256 cost) {
        // Implement this!
        return 0;
    }

    /**
     * Returns the msg.value needed to call 'withdraw'
     */
    function quoteWithdraw() public view returns (uint256 cost) {
        // Implement this!
        return 0;
    }

    /**
     * Deposits, through Token Bridge, 
     * 'amount' of the IERC20 token 'tokenAddress'
     * into the protocol (i.e. to the Hub)
     *  
     * Assumes that 'amount' of 'tokenAddress' was approved to be transferred
     * from msg.sender to this contract
     */
    function deposit(address tokenAddress, uint256 amount) public payable {
        require(msg.value == quoteDeposit());
        // Implement this!

    }

    /**
     * Initiates a request to withdraw, through Token Bridge, 
     * 'amount' of the IERC20 token 'tokenAddress'
     * from the protocol (i.e. from the Hub)
     * 
     * Should cause (not atomically but after a delivery to Hub and then back to Spoke)
     * receivePayloadAndTokens to be called with 'amount' of the token 'tokenAddress'
     * as well as a payload of abi.encode(msg.sender)
     */
    function withdraw(address tokenAddress, uint256 amount) public payable {
        require(msg.value == quoteWithdraw());
        // Implement this!
    }

    /**
     * When 'withdraw' is called (with msg.sender being recipient), 
     * then the Hub will request delivery of tokens with destination this Spoke and payload 'abi.encode(recipient)'
     * and the job of this function is to receive that delivery
     * and transfer the received tokens to the recipient address
     * 
     * You will need to
     * 1) obtain the intended recipient address from the payload
     * 2) transfer the correct amount of the correct token to that address
     * 
     * Only 'wormholeRelayer' should be allowed to call this method
     * 
     * 
     * @param payload This will be 'abi.encode(recipient)'
     * @param receivedTokens This will be an array of length 1
     * describing the amount and address of the token received
     * (the 'amount' field indicates the amount,
     * and the 'tokenAddress' field indicates the address of the IERC20 token
     * that was received, which will be a wormhole-wrapped version of the sent token)
     */
    function receivePayloadAndTokens(
        bytes memory payload,
        TokenReceived[] memory receivedTokens,
        bytes32 sourceAddress, 
        uint16 sourceChain,
        bytes32 deliveryHash
    ) internal override {
        // Implement this!
        
    }
}
