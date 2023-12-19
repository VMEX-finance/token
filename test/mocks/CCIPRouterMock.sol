// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IRouterClient} from "ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from "ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract CCIPRouterMock is IRouterClient {
    using SafeTransferLib for ERC20;

    address[] public supportedTokens;
    mapping(uint64 => bool) public supportedChains;
    uint256 public fee;
    bytes32 public messageId;
    ERC20 public link;

    error Bad();

    constructor(address _link) {
        link = ERC20(_link);
    }

    function setFee(uint256 newFee) external {
        fee = newFee;
    }

    function setSupportedChain(uint64 chain, bool supported) external {
        supportedChains[chain] = supported;
    }

    function isChainSupported(uint64 chainSelector) external view returns (bool supported) {
        return supportedChains[chainSelector];
    }

    function getSupportedTokens(uint64) external view returns (address[] memory tokens) {
        return supportedTokens;
    }

    function getFee(uint64, Client.EVM2AnyMessage memory) external view returns (uint256) {
        return fee;
    }

    function setMessageId(bytes32 newMessageId) external {
        messageId = newMessageId;
    }

    function ccipSend(uint64, Client.EVM2AnyMessage calldata message) external payable returns (bytes32) {
        if (message.feeToken == address(link)) {
            link.safeTransferFrom(msg.sender, address(this), fee);
        } else if (message.feeToken == address(0)) {
            require(msg.value == fee);
        } else {
            revert Bad();
        }

        return messageId;
    }

    function ccipReceive(address receiver, Client.Any2EVMMessage calldata message) external {
        IAny2EVMMessageReceiver(receiver).ccipReceive(message);
    }
}
