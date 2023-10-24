// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {Helper} from "./Helper.sol"; 

import {VMEXToken} from "../src/VmexToken.sol"; 

contract TokenScript is Script, Helper {
	
	//@param source -- enum 
	function run(Helper.SupportedNetworks source) public {
		uint256 privateKey = vm.envUint("PRIVATE_KEY"); 
		vm.startBroadcast(privateKey);

		VMEXToken vmexToken; 
		(address router, , ,) = Helper.getConfigFromNetwork(source); 
		if (source == Helper.SupportedNetworks.ETHEREUM_SEPOLIA) {
			vmexToken = new VMEXToken(router, true); 
		} else {
			vmexToken = new VMEXToken(router, false); 
		}

		console2.log(
			"VMEX Token deployed on:",
			Helper.networks[source],
			"at address:",
			address(vmexToken)
		); 	

		vm.stopBroadcast(); 
    }
}

contract BridgeToken is Script, Helper {
	function run(
		address payable _vmexToken, //source
	    SupportedNetworks destination,
	    address receiver,
		VMEXToken.BurnOrMint burnOrMint,
	    VMEXToken.PayFeesIn payFeesIn
	) external {
		VMEXToken vmexToken = VMEXToken(_vmexToken); 

	    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
	    vm.startBroadcast(deployerPrivateKey);
	
	    (, address link, , uint64 destinationChainId) = Helper.getConfigFromNetwork(destination);
		console2.log(destinationChainId); 
			
	    bytes32 messageId = vmexToken.bridgeWithFeePaidByProtocol(
	        destinationChainId,
	        receiver,
			burnOrMint,
	        payFeesIn,
			link
	    );
	
	    console2.log(
	        "You can now monitor the status of your Chainlink CCIP Message via https://ccip.chain.link using CCIP Message ID: "
	    );
	    console2.logBytes32(messageId);
	
	    vm.stopBroadcast();
	}
}
