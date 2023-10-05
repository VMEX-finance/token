// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol"; 
import { IERC20 } from "forge-std/interfaces/IERC20.sol"; 

contract VMEXToken is ERC20, CCIPReceiver {

	IRouterClient internal router; 

	//temp -- need to get msig address and put here
	address owner; 

	uint256 public constant MAX_TOTAL_SUPPLY = 100_000_000 * 1e18; //100 million max
	address internal constant LINK = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6; 
	
	//owner will be changed to msig later
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

	//assuming we're only going to pay with LINK for 10% discount
	function _ccipSend(
		uint64 destinationChainSelector,
		address receiver, 
		string memory text
	) external onlyCCIPRouterOrMsig returns (bytes32 messageId) {
		Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
			receiver: abi.encode(receiver), 
			data: abi.encode(text),
			tokenAmounts: new Client.EVMTokenAmount[](0),
			extraArgs: "",
			feeToken: LINK
		}); 

		uint256 fee = IRouterClient(router).getFee(
			destinationChainSelector,
			message
		); 
		
		IERC20(LINK).approve(address(router), fee);  
		messageId = IRouterClient(router).ccipSend(
			destinationChainSelector, 
			message
		); 

	}	


}
