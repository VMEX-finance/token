// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../src/VmexToken.sol"; 
import {IVMEXToken} from "../src/IVmexToken.sol"; 
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";


contract TokenTest is Test {
	
	//IVMEXToken internal vmexToken; 
	address internal LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789; 
	address internal vmexTokenArb = 0x55d89cF26Df0fD27E9B84C48C3350C91e1016daA; 
	VMEXToken internal vmexToken; 

	uint64 arbSelection = 6101244977088475029; 


	function setUp() public {
		address router = 0xD0daae2231E9CB96b94C8512223533293C3693Bf; 
		vmexToken = new VMEXToken(router, true); 
		vmexToken.allowlistDestinationChain(arbSelection, true); 
		
		deal(LINK, address(vmexToken), 100e18); 
		deal(address(vmexToken), 10e18); 
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
		vmexToken.allowlistDestinationChain(arbSelection, true); 
		VMEXToken.BurnOrMint mint = VMEXToken.BurnOrMint.MINT; 
		VMEXToken.PayFeesIn payLink = VMEXToken.PayFeesIn.LINK; 
		vmexToken.bridgeWithFeePaidByProtocol(arbSelection, vmexTokenArb, mint, 100e18, payLink); 
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
