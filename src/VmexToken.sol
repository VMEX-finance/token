// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol"; 

contract VMEXToken is ERC20, CCIPReceiver {

	IRouterClient internal router; 

	//temp -- need to get msig address and put here
	address owner; 

	uint256 public constant MAX_TOTAL_SUPPLY = 100_000_000 * 1e18; //100 million max
	
	//owner will be changed to msig later
	//TODO: add modifier for ccip router only to burn/mint
	modifier onlyCCIPRouterOrMsig() {
		require(msg.sender == address(router) || msg.sender == owner); 
		_; 
	}

	event MessageReceived(
		bytes32 latestMessageId,
        uint64 latestSourceChainSelector,
        address latestSender,
        string latestMessage
	);


	constructor(address _router) ERC20("VMEX Token", "VMEX", 18) CCIPReceiver(_router) {
		router = IRouterClient(_router); 	
		owner = msg.sender; 
		_mint(owner, MAX_TOTAL_SUPPLY);  
	}
	
	//should these be public?
	//TODO: send minted tokens to team msig
	function mint(uint256 amount) internal onlyCCIPRouterOrMsig {
		require(amount + totalSupply <= MAX_TOTAL_SUPPLY, "Cannot mint more than max total supply");  
		_mint(address(this), amount); 	
	}
	
	//TODO: burn minted tokens from msig
	function burn(uint256 amount) internal onlyCCIPRouterOrMsig {
		//can build 
		_burn(address(this), amount); 
	}

	function _ccipReceive(
		Client.Any2EVMMessage memory message
	) internal override {
		//receive ccip message from router
		//determine if we should burn or mint based on the message	
		bytes32 latestMessageId = message.messageId;
        uint64 latestSourceChainSelector = message.sourceChainSelector;
        address latestSender = abi.decode(message.sender, (address));
        string memory latestMessage = abi.decode(message.data, (string));

		//assuming that we're only ever using this for our token, 
		//we can hardcode this as [0]
		uint256 amount = message.destTokenAmounts[0].amount; 
		
		//check if we need to burn or mint from the received message
		if (keccak256(abi.encodePacked(latestMessage)) == 
			keccak256(abi.encodePacked("burn"))) {
				burn(amount); 
		} else if (keccak256(abi.encodePacked(latestMessage)) == 
			keccak256(abi.encodePacked("mint"))) {
				mint(amount); 
		}

        emit MessageReceived(
            latestMessageId,
            latestSourceChainSelector,
            latestSender,
            latestMessage
        );

	}



}
