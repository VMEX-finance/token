// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IRouterClient} from "ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol"; 
import { ERC20 } from "solmate/tokens/ERC20.sol"; 
import { IERC20 } from "forge-std/interfaces/IERC20.sol"; 


import {Test, console2} from "forge-std/Test.sol";

contract VMEXToken is ERC20, CCIPReceiver, Ownable, Test {

	IRouterClient internal router; 

	enum PayFeesIn {
		LINK,
		NATIVE
	}

	enum BurnOrMint {
		BURN,
		MINT
	}
	
	//set chain to allowed as both source, and destination
	mapping(uint64 => bool) public allowlistedChains; 

	uint256 public constant MAX_TOTAL_SUPPLY = 100_000_000 * 1e18; //100 million max
	address internal constant LINK = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6; 
	bool public isOpen = true;  

	//TODO: set msig address here
	constructor(address _router, bool hubChain) ERC20("VMEX Token", "VMEX", 18) CCIPReceiver(_router) Ownable(0x4CF908f6f1EAF51d143823Ce3A5Dd0Eb8373f23c) {
		router = IRouterClient(_router); 	
		if (hubChain == true) {
			_mint(owner(), MAX_TOTAL_SUPPLY);  
		}
	}
	
	//@dev mint tokens on the dest chain to the user who bridged
	//is this vulnerable to people using low level calls to mint/burn?
	//doesn't seem to work in tests, but could be skill issue
	//can someone double check this pls and thanks
	function mint(address user, uint256 amount) public {
		require(amount + totalSupply <= MAX_TOTAL_SUPPLY, "Cannot mint more than max total supply");
		require(msg.sender == address(this) || msg.sender == owner()); //this will be changed to modifier eventually, after review
		_mint(user, amount); 	
	}
	
	function burn(address user, uint256 amount) public {
		require(msg.sender == address(this) || msg.sender == owner()); //also will be changed to modifer after review
		_burn(user, amount); 
	}

	function _ccipReceive(
		Client.Any2EVMMessage memory message
	) internal override {
		//receive ccip message from router
		(bool success, ) = address(this).call(message.data);
        require(success, "mint or burn failed");
	}
	
	//@dev used for when users are paying for bridging themselves and already have vmex tokens on the source chain
	//@param destinationChainSelecter -- the chain we are bridging to
	//@param receiver -- the corresponding token address on another chain
	//@param burnOrMint -- an enum selection specifying to a burn or mint of the token on the receiving chain
	//@param receiverUserAddress -- the user recieving the tokens on the receiving chain
	//@param amount -- the amount we burning or minting
	//@param payFeesIn -- an enum specifying the token we are using to pay ccip fees 
	function bridge(
		uint64 destinationChainSelector,
		address receiverTokenAddress, 
		address receiverUserAddress,
		uint256 amount,
		BurnOrMint burnOrMint,
		PayFeesIn payFeesIn
	) public payable returns (bytes32 messageId) {
		require(IERC20(address(this)).balanceOf(msg.sender) >= amount, "balance too low on source chain"); 
		require(allowlistedChains[destinationChainSelector] = true, "chain not allowed"); 
		
		//if we're burning on the destination chain, this chain needs to do the opposite
		bytes memory functionCallDestChain; 
		if (burnOrMint == BurnOrMint.BURN) {
			mint(receiverUserAddress, amount); 
			functionCallDestChain = abi.encodeWithSignature("burn(address,uint256)", receiverUserAddress, amount); 
		} else {
			burn(receiverUserAddress, amount); 	
			functionCallDestChain = abi.encodeWithSignature("mint(address,uint256)", receiverUserAddress, amount); 
		}
		
		Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
			receiver: abi.encode(receiverTokenAddress), 
			data: functionCallDestChain,
			tokenAmounts: new Client.EVMTokenAmount[](0),
			extraArgs: "",
			feeToken: payFeesIn == PayFeesIn.LINK ? LINK : address(0)
		}); 
		
		uint256 fee = IRouterClient(router).getFee(
						destinationChainSelector,
						message
					); 

		
		if (payFeesIn == PayFeesIn.LINK) {
			//if we are not paying for bridge fees, we transfer some link from sender to pay
			if (isOpen == false) {
				IERC20(LINK).transferFrom(msg.sender, address(this), fee); 
				IERC20(LINK).approve(address(router), fee);  
			}

			messageId = IRouterClient(router).ccipSend(
				destinationChainSelector, 
				message
			); 

		} else {
			//if we're not paying, user will have to make sure they're sending eth with their txn
			if (isOpen == false) {
				require(msg.value >= fee, "not enough eth for fee"); 
			}	

			messageId = IRouterClient(router).ccipSend{value: fee}(
				destinationChainSelector, 
				message
			); 
		}	

		return messageId; 

	}	


	////////////////// Helpers \\\\\\\\\\\\\\\\\\
	function allowlistDestinationChain(uint64 _destinationChainSelector, bool allowed) external onlyOwner {
		allowlistedChains[_destinationChainSelector] = allowed;
    }
	
	function withdrawGasTokens(uint256 amount) external onlyOwner {
		IERC20(LINK).transfer(owner(), amount); 	
	}
	
	//TODO: test only remove later
	function withdraw(address beneficiary) external onlyOwner {
		uint256 amount = address(this).balance;
        (bool sent, ) = beneficiary.call{value: amount}("");
        if (!sent) revert ("failed to withdraw eth");
	}

	function toggleOpenStatus() external {
		if (isOpen == true) {
			isOpen = false; 
		} else {
			isOpen = true; 
		}
	}
	
	//to receive eth to pay for ccip
	//router accepts ETH and WETH as payment
	receive() payable external {}



}
