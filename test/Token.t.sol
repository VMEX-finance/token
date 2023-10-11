// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../src/VmexToken.sol"; 
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";


contract TokenTest is Test {
	
	VMEXToken internal vmexToken; 
	
	function setUp() public {
		address router = address(0x69); 
		vmexToken = new VMEXToken(router);
	}


	function testTokenSupply() public view {
		uint256 totalSupply = vmexToken.totalSupply(); 	
		console2.log(totalSupply); 
	}


	function testTokenName() public view {
		string memory name = vmexToken.name(); 
		console2.log(name); 
	}

	function testMint() public {
		uint256 mintAmount = 10e18; 
		vm.expectRevert(); 
		vmexToken.mint(mintAmount); 
		
	}

	function testBurn() public {
		uint256 burnAmount = 10_000_000e18; 
		vmexToken.burn(burnAmount); 

		uint256 totalSupply = vmexToken.totalSupply(); 
		console2.log(totalSupply); 
	}

	function testCCIPSend() public {
		//temp until I get the address for ccipRouter on OP
		VMEXToken.BurnOrMint burn = VMEXToken.BurnOrMint.BURN; 
		VMEXToken.PayFeesIn payLink = VMEXToken.PayFeesIn.LINK; 
		vm.expectRevert(); 
		vmexToken.bridge(0, address(this), burn, 100e18, payLink); 
	}

//	function testCCIPReceive() public {
//		Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1); 
//
//		tokenAmounts[0] = Client.EVMTokenAmount({
//				token: address(vmexToken),
//				amount: 100_000e18
//		}); 
//
//		Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
//			messageId: bytes32("bozo"),
//			sourceChainSelector: uint64(0),
//			sender: bytes("this"),
//			data: abi.encode("burn"),
//			destTokenAmounts: tokenAmounts
//		}); 
//
//		vmexToken.ccipReceiveTest(message); 
//
//		console2.log(vmexToken.totalSupply()); 
//	}

}
