// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IRouterClient} from "ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from "ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";

contract CCIPRouterMock is IRouterClient {
    address[] supportedTokens;
    mapping(uint64 => bool) supportedChains;
    uint256 fee;
    bytes32 messageId;

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

    function getFee(uint64, Client.EVM2AnyMessage memory)
        external
        view
        returns (uint256)
    {
        return fee;
    }

    function setMessageId(bytes32 newMessageId) external {
        messageId = newMessageId;
    }

    function ccipSend(uint64, Client.EVM2AnyMessage calldata)
        external
        payable
        returns (bytes32) {
            return messageId;
        }

    function ccipReceive(address receiver, Client.Any2EVMMessage calldata message) external {
        IAny2EVMMessageReceiver(receiver).ccipReceive(message);
    }
}
