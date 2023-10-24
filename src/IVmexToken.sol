// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;


interface IVMEXToken {


	enum PayFeesIn {
		LINK,
		NATIVE
	}

	enum BurnOrMint {
		BURN,
		MINT
	}

	function totalSupply() external view returns (uint256); 
	function name() external view returns (string memory); 
	function mint(uint256 amount) external; 
	function burn(uint256 amount) external; 

	function bridge(
		uint64 destinationChainSelector,
		address receiver, 
		BurnOrMint burnOrMint,
		uint256 amount,
		PayFeesIn payFeesIn		
	) external returns (bytes32 messageId); 

}
