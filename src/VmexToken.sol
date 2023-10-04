// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol"; 

contract VMEXToken is ERC20, CCIPReceiver {

	IRouterClient internal router; 

	constructor(address _router) ERC20("VMEX Token", "VMEX", 18) CCIPReceiver(_router) {
		router = IRouterClient(_router); 	
	}


	function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {

	}


}
