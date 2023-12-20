// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {Helper} from "./Helper.sol";

import {VMEXToken} from "../src/VmexToken.sol";


contract TokenScript is Script, Helper {


	function run(address VMEX_DEPLOYER) external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

		address OP_CCIP_ROUTER = 0x261c05167db67B2b619f9d312e0753f3721ad6E8; 
		address OP_LINK = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6; 

		VMEXToken vmexToken = new VMEXToken(
			OP_CCIP_ROUTER, 
			OP_LINK,
			true, //hub chain == mint all tokens 
			VMEX_DEPLOYER
		); 

		console2.log(address(vmexToken)); 
        vm.stopBroadcast();
	}


}
