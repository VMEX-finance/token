// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IRouterClient} from "ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract VMEXToken is ERC20, CCIPReceiver, Owned {
    using SafeTransferLib for ERC20;

    uint256 public constant MAX_TOTAL_SUPPLY = 100_000_000 * 1e18; //100 million max
	address internal currentRouter; 
	bytes internal extraArgs; 
    ERC20 internal immutable LINK;

    //set chain to allowed as both source, and destination
    mapping(uint64 chain => address vmexToken) public vmexTokenByChain;

    error DestinationChainNotAllowed(uint64 chain);
    error SourceChainNotAllowed(uint64 chain);
    error NotEnoughEthForFee();
    error SenderNotVmexToken();
    error VmexTokenAlreadyAddedOnChain();

    event ChainAdded(uint64 indexed chain, address vmexToken);
    event IsOpenChanged(bool isOpen);

    constructor(address _router, address link, bool hubChain, address newOwner, bytes memory _extraArgs)
        ERC20("VMEX Token", "VMEX", 18)
        CCIPReceiver(_router)
        Owned(newOwner)
    {
		currentRouter = _router; 
		extraArgs = _extraArgs; 	

        LINK = ERC20(link);
        LINK.safeApprove(address(_router), type(uint256).max);

        if (hubChain) {
            _mint(newOwner, MAX_TOTAL_SUPPLY);
        }
    }

    //to receive eth to pay for ccip
    //router accepts ETH and WETH as payment
    receive() external payable {}

    ////////////////// Helpers \\\\\\\\\\\\\\\\\\
    function addVmexTokenOnChain(uint64 chain, address vmexToken) external onlyOwner {
        if (vmexTokenByChain[chain] != address(0)) revert VmexTokenAlreadyAddedOnChain();

        vmexTokenByChain[chain] = vmexToken;

        emit ChainAdded(chain, vmexToken);
    }

    function withdrawToken(address token, uint256 amount) external onlyOwner {
        ERC20(token).safeTransfer(owner, amount);
    }

    function withdrawNative(uint256 amount) external onlyOwner {
        SafeTransferLib.safeTransferETH(owner, amount);
    }

    //@dev used for when users are paying for bridging themselves and already have vmex tokens on the source chain
    //@param destinationChainSelecter -- the chain we are bridging to
    //@param receiver -- the corresponding token address on another chain
    //@param receiver -- the user recieving the tokens on the receiving chain
    //@param amount -- the amount we burning or minting
    //@param payFeesNative -- flag indicating whether ccip fees are paid in native token or in link
    function bridge(uint64 destinationChainSelector, address receiver, uint256 amount, bool payFeesNative)
        external
        payable
        returns (bytes32)
    {
        address destinationVmexToken = vmexTokenByChain[destinationChainSelector];
        if (destinationVmexToken == address(0)) {
            revert DestinationChainNotAllowed(destinationChainSelector);
        }

        _burn(msg.sender, amount);

        //if we're burning on the destination chain, this chain needs to do the opposite
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(destinationVmexToken),
            data: abi.encode(receiver, amount),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: extraArgs,
            feeToken: payFeesNative ? address(0) : address(LINK)
        });

        uint256 fee = IRouterClient(currentRouter).getFee(destinationChainSelector, message);

        if (payFeesNative) {
            //if we're not paying, user will have to make sure they're sending eth with their tx
            if (msg.value < fee) {
                revert NotEnoughEthForFee();
            }

            return IRouterClient(currentRouter).ccipSend{value: fee}(destinationChainSelector, message);
        }

        LINK.safeTransferFrom(msg.sender, address(this), fee);
        return IRouterClient(currentRouter).ccipSend(destinationChainSelector, message);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        uint64 sourceChain = message.sourceChainSelector;
        address sourceChainVmexToken = vmexTokenByChain[sourceChain];
        if (sourceChainVmexToken == address(0)) {
            revert SourceChainNotAllowed(sourceChain);
        }

        address messageSender = abi.decode(message.sender, (address));
        if (sourceChainVmexToken != messageSender) {
            revert SenderNotVmexToken();
        }

        (address receiver, uint256 amount) = abi.decode(message.data, (address, uint256));
        _mint(receiver, amount);
    }

	///////////////// Helpers ///////////////// 
	function setRouter(address newRouter) external onlyOwner {
		currentRouter = newRouter; 						
	}

	function setExtraArgs(bytes memory newExtraArgs) external onlyOwner {
		extraArgs = newExtraArgs; 
	}	
}
