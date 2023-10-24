const ethers = require('ethers'); 
const providerSepolia = new ethers.AlchemyProvider("sepolia", "5CDHPv0KHMxfd3f6zue0vESYQdR4UwqO"); 
const providerArbitrumGoerli = new ethers.AlchemyProvider("arbitrum-goerli", "VwSs_drvpNLT7ZZss2oNYVrtGLfSltlG"); 

const vmexTokenAddressSepolia = "0x55d89cF26Df0fD27E9B84C48C3350C91e1016daA"; 
const vmexTokenAbi = require("../out/VmexToken.sol/VMEXToken.json").abi; 

const vmexTokenAddressArbitrumGoerli = "0x55d89cF26Df0fD27E9B84C48C3350C91e1016daA"; 

const signerSepolia = new ethers.Wallet(
	"b3e8bababde3083daeca3e2666427d225ea28c795a0c5d19f48afb5c26280768", 
	providerSepolia
); 

const signerArbitrumGoerli = new ethers.Wallet(
	"b3e8bababde3083daeca3e2666427d225ea28c795a0c5d19f48afb5c26280768", 
	providerArbitrumGoerli	
); 

//sepolia contract
const vmexTokenSepolia = new ethers.Contract(
	vmexTokenAddressSepolia,
	vmexTokenAbi,
	signerSepolia
); 

const vmexTokenArbitrumGoerli = new ethers.Contract(
	vmexTokenAddressArbitrumGoerli,
	vmexTokenAbi,
	signerArbitrumGoerli
);

const arbitrumGoerliSelector = "6101244977088475029"; 
const sepoliaSelector = "16015286601757825753"; 

async function main() {
	const owner = await vmexTokenSepolia.owner(); 
	console.log("owner is: ", owner); //testing account


	let totalSupply = await vmexTokenSepolia.totalSupply(); 
	console.log("initial total supply:", totalSupply); 


	let totalSupplyGoerli = await vmexTokenArbitrumGoerli.totalSupply(); 
	console.log("initial total supply:", totalSupplyGoerli); 
	
	//await vmexTokenSepolia.allowlistDestinationChain(arbitrumGoerliSelector, true); 
	//await vmexTokenArbitrumGoerli.allowlistDestinationChain(sepoliaSelector, true); 
	console.log("chains approved!"); 
	
	const amountToMintOnArbitrum = BigInt(100 * 1e18); 
	const options = {value: ethers.parseEther("0.05")}	
	await vmexTokenSepolia.bridge(
		arbitrumGoerliSelector,
		vmexTokenAddressArbitrumGoerli,
		"burn"
	); 

	totalSupply = await vmexTokenSepolia.totalSupply(); 
	console.log("total supply after transfer:", totalSupply); 

	totalSupplyGoerli = await vmexTokenArbitrumGoerli.totalSupply(); 
	console.log("total supply after transfer:", totalSupplyGoerli); 

}

main(); 
