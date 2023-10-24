// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol"; 
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol"; 
import { IERC20 } from "forge-std/interfaces/IERC20.sol"; 


import {Test, console2} from "forge-std/Test.sol";

contract VMEXToken is ERC20, CCIPReceiver, Ownable, Test {

	IRouterClient internal router; 
	
	//temp -- need to get msig address and put here

	enum PayFeesIn {
		LINK,
		NATIVE
	}

	enum BurnOrMint {
		BURN,
		MINT
	}

	 error DestinationChainNotAllowlisted(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner()

	//chains we are launched on and are accepting bridged tokens
    mapping(uint64 => bool) public allowlistedChains;

	uint256 public constant MAX_TOTAL_SUPPLY = 100_000_000 * 1e18; //100 million max
	address internal constant LINK = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6; 
	bool public isOpenToPublic = true;  
	
	//owner() will be changed to msig later
	modifier onlyCCIPRouterOrMsig() {
		require(msg.sender == address(router) || msg.sender == owner()); 
		_; 
	}

	modifier MsigOnly {
		require (msg.sender == owner()); 
		_;  
	}

	modifier onlyAllowlistedChain(uint64 _destinationChainSelector) {
		if (!allowlistedChains[_destinationChainSelector])
        revert DestinationChainNotAllowlisted(_destinationChainSelector);
        _;
    }

	event MessageReceived(
		bytes32 latestMessageId,
		uint64 latestSourceChainSelector,
    	address latestSender,
    	string latestMessage
	);

	//TODO: set msig address here
	constructor(address _router, bool hubChain) ERC20("VMEX Token", "VMEX", 18) CCIPReceiver(_router) Ownable(msg.sender) {
		router = IRouterClient(_router); 	
		if (hubChain == true) {
			_mint(owner(), MAX_TOTAL_SUPPLY);  
		}
	}

	//these have to be public for the router to access, and for this contract to access based on messages received
	//TODO: send minted tokens to team msig
	function mint(uint256 amount) public onlyCCIPRouterOrMsig {
		require(amount + totalSupply <= MAX_TOTAL_SUPPLY, "Cannot mint more than max total supply");  
		_mint(owner(), amount); 	
	}
	
	function burn(uint256 amount) public onlyCCIPRouterOrMsig {
		_burn(owner(), amount); 
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
		//uint256 amount = message.destTokenAmounts[0].amount; 

		//check if we need to burn or mint from the received message
		//this is only for this chain -- the receiving chain
		if (keccak256(abi.encodePacked(latestMessage)) == 
			keccak256(abi.encodePacked("burn"))) {
				burn(100e18); 
		} else if (keccak256(abi.encodePacked(latestMessage)) == 
			keccak256(abi.encodePacked("mint"))) {
				mint(100e18); 
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
	) external onlyAllowlistedChain(destinationChainSelector) returns (bytes32 messageId) {
		require(isOpenToPublic == true || msg.sender == owner()); 

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
			tokenAmounts: new Client.EVMTokenAmount[](0),
			extraArgs: Client._argsToBytes(
				Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false})
			),
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

		messageId = IRouterClient(router).ccipSend{value: fee}(
			destinationChainSelector, 
			message
		); 

		return messageId; 

	}	
	

	////////////////// Helpers \\\\\\\\\\\\\\\\\\
	function allowlistDestinationChain(uint64 _destinationChainSelector, bool allowed) external onlyOwner {
		allowlistedChains[_destinationChainSelector] = allowed;
    }

	function withdrawGasTokens(uint256 amount, IERC20 token) external MsigOnly {
		token.transfer(owner(), amount); 	
	}

	function toggleOpenStatus() external MsigOnly {
		if (isOpenToPublic == true) {
			isOpenToPublic = false; 
		} else {
			isOpenToPublic = true; 
		}
	}
	
	//to receive eth to pay for ccip
	//router accepts ETH and WETH as payment
	receive() payable external {}



}
