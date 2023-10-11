	//assuming we're only going to accept pay with LINK for 10% discount
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol"; 
import { IERC20 } from "forge-std/interfaces/IERC20.sol"; 

import {Test, console2} from "forge-std/Test.sol"; 

contract VMEXToken is ERC20, CCIPReceiver, Test {

	IRouterClient internal router; 

	//temp -- need to get msig address and put here
	address owner; 

	enum PayFeesIn {
		LINK,
		NATIVE
	}

	enum BurnOrMint {
		BURN,
		MINT
	}

	uint256 public constant MAX_TOTAL_SUPPLY = 100_000_000 * 1e18; //100 million max
	address internal constant LINK = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6; 
	bool public isOpenToPublic = true;  
	
	//owner will be changed to msig later
	modifier onlyCCIPRouterOrMsig() {
		require(msg.sender == address(router) || msg.sender == owner); 
		_; 
	}

	modifier MsigOnly {
		require (msg.sender == owner); 
		_;  
	}

	//this can be changed to just a require statement, but I thought this was cleaner
	//not sure if modifiers cost more gas or not
	modifier Open {
		require (isOpenToPublic == true); 
		_; 
	}

	event MessageReceived(
		bytes32 latestMessageId,
    uint64 latestSourceChainSelector,
    address latestSender,
    string latestMessage
	);

	//TODO: set msig address here
	constructor(address _router) ERC20("VMEX Token", "VMEX", 18) CCIPReceiver(_router) {
		router = IRouterClient(_router); 	
		owner = msg.sender; 
		_mint(owner, MAX_TOTAL_SUPPLY);  
	}

	//these have to be public for the router to access, and for this contract to access based on messages received
	//TODO: send minted tokens to team msig
	function mint(uint256 amount) public onlyCCIPRouterOrMsig {
		require(amount + totalSupply <= MAX_TOTAL_SUPPLY, "Cannot mint more than max total supply");  
		_mint(owner, amount); 	
	}
	
	function burn(uint256 amount) public onlyCCIPRouterOrMsig {
		_burn(owner, amount); 
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

		console2.log("latest message", latestMessage); 
		
		//check if we need to burn or mint from the received message
		//this is only for this chain -- the receiving chain
		if (keccak256(abi.encodePacked(latestMessage)) == 
			keccak256(abi.encodePacked("burn"))) {
				burn(amount); 
		} else if (keccak256(abi.encodePacked(latestMessage)) == 
			keccak256(abi.encodePacked("mint"))) {
				mint(amount); 
		}
		
		//emit the event message data 
		emit MessageReceived(
			latestMessageId,
			latestSourceChainSelector,
			latestSender,
			latestMessage
		); 

	}
	
	//@dev used for when protocol is paying for fees only
	function bridgeWithFeePaidByProtocol(
		uint64 destinationChainSelector,
		address receiver, 
		BurnOrMint burnOrMint,
		uint256 amount,
		PayFeesIn payFeesIn
	) external returns (bytes32 messageId) {
		require(isOpenToPublic == true || msg.sender == owner); 

		messageId = bridge(
			destinationChainSelector, 
			receiver,
			burnOrMint,
			amount,
			payFeesIn
		); 

		return messageId; 

	}
	
	//@dev used for when users are paying for bridging themselves
	//@param destinationChainSelecter -- the chain we are bridging to
	//@param receiver -- the address receiving the tokens
	//@param burnOrMint -- an enum selection specifying to a burn or mint of the token on the receiving chain
	//@param amount -- the amount we burning or minting
	//@param payFeesIn -- an enum specifying the token we are using to pay ccip fees 
	function bridge(
		uint64 destinationChainSelector,
		address receiver, 
		BurnOrMint burnOrMint,
		uint256 amount,
		PayFeesIn payFeesIn
	) public returns (bytes32 messageId) {
		Client.EVMTokenAmount[] memory tokenAmount = new Client.EVMTokenAmount[](1); 
		tokenAmount[0] = Client.EVMTokenAmount({
			token: address(this),
			amount: amount
		}); 
		
		//if we're burning on the destination chain, this chain needs to do the opposite	
		string memory text; 
		if (burnOrMint == BurnOrMint.BURN) {
			mint(amount); 
			text = "burn"; 
		} else {
			burn(amount); 	
			text = "mint"; 
		}

		Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
			receiver: abi.encode(receiver), 
			data: abi.encode(text),
			tokenAmounts: tokenAmount,
			extraArgs: "",
			feeToken: payFeesIn == PayFeesIn.LINK ? LINK : address(0)
		}); 
		
		uint256 fee = IRouterClient(router).getFee(
			destinationChainSelector,
			message
		); 
		
		if (payFeesIn == PayFeesIn.LINK) {
			IERC20(LINK).transferFrom(msg.sender, address(this), fee); 
			IERC20(LINK).approve(address(router), fee);  
			messageId = IRouterClient(router).ccipSend(
				destinationChainSelector, 
				message
			); 
		} else {
			messageId = IRouterClient(router).ccipSend{value: fee}(
				destinationChainSelector, 
				message
			); 
		}

		return messageId; 

	}	
	

	//Helpers//

	function _withdrawGasTokens(uint256 amount, IERC20 token) external MsigOnly {
		token.transfer(owner, amount); 	
	}

	function toggleOpenStatus() external MsigOnly {
		if (isOpenToPublic == true) {
			isOpenToPublic = false; 
		} else {
			isOpenToPublic = true; 
		}
	}
	
	//to receive eth (for gas)
	receive() payable external {}



}
