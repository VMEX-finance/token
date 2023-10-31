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
    address internal immutable LINK;

    //set chain to allowed as both source, and destination
    mapping(uint64 chain => address vmexToken) public vmexTokenByChain;
    bool public isOpen = true;

    error DestinationChainNotAllowed(uint64 chain);
    error SourceChainNotAllowed(uint64 chain);
    error NotEnoughEthForFee();
    error SenderNotVmexToken();
    error VmexTokenAlreadyAddedOnChain();

    event BridgeTo(uint64 indexed chain, address indexed sender, address indexed receiver, uint256 amount);
    event BridgeFrom(uint64 indexed chain, address indexed sender, address indexed receiver, uint256 amount);
    event ChainAdded(uint64 indexed chain, address vmexToken);
    event IsOpenChanged(bool isOpen);

    constructor(address _router, address _link, bool hubChain, address newOwner)
        ERC20("VMEX Token", "VMEX", 18)
        CCIPReceiver(_router)
        Owned(newOwner)
    {
        LINK = _link;
        ERC20(_link).safeApprove(address(i_router), type(uint256).max);

        if (hubChain == true) {
            _mint(newOwner, MAX_TOTAL_SUPPLY);
        }
    }

    //to receive eth to pay for ccip
    //i_router accepts ETH and WETH as payment
    receive() external payable {}

    ////////////////// Helpers \\\\\\\\\\\\\\\\\\
    function addVmexTokenOnChain(uint64 chain, address vmexToken) external onlyOwner {
        if (vmexTokenByChain[chain] != address(0)) revert VmexTokenAlreadyAddedOnChain();

        vmexTokenByChain[chain] = vmexToken;

        emit ChainAdded(chain, vmexToken);
    }

    function withdrawGasTokens(uint256 amount) external onlyOwner {
        ERC20(LINK).safeTransfer(owner, amount);
    }

    function withdraw(address beneficiary) external onlyOwner {
        SafeTransferLib.safeTransferETH(beneficiary, address(this).balance);
    }

    function setIsOpen(bool newIsOpen) external onlyOwner {
        isOpen = newIsOpen;

        emit IsOpenChanged(newIsOpen);
    }

    //@dev used for when users are paying for bridging themselves and already have vmex tokens on the source chain
    //@param destinationChainSelecter -- the chain we are bridging to
    //@param receiver -- the corresponding token address on another chain
    //@param burnOrMint -- an enum selection specifying to a burn or mint of the token on the receiving chain
    //@param receiver -- the user recieving the tokens on the receiving chain
    //@param amount -- the amount we burning or minting
    //@param payFeesIn -- an enum specifying the token we are using to pay ccip fees
    function bridge(
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount,
        bool payFeesNative
    ) public payable returns (bytes32 messageId) {
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
            extraArgs: "",
            feeToken: payFeesNative ? address(0) : LINK
        });

        uint256 fee = IRouterClient(i_router).getFee(destinationChainSelector, message);

        if (payFeesNative == false) {
            //if we are not paying for bridge fees, we transfer some link from sender to pay
            if (isOpen == false) {
                ERC20(LINK).safeTransferFrom(msg.sender, address(this), fee);
            }

            return IRouterClient(i_router).ccipSend(destinationChainSelector, message);
        }

        //if we're not paying, user will have to make sure they're sending eth with their tx
        if (isOpen == false && msg.value < fee) {
            revert NotEnoughEthForFee();
        }

        return IRouterClient(i_router).ccipSend{value: fee}(destinationChainSelector, message);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        address sourceChainVmexToken = vmexTokenByChain[message.sourceChainSelector];
        if (sourceChainVmexToken == address(0)) {
            revert SourceChainNotAllowed(message.sourceChainSelector);
        }

        if (sourceChainVmexToken != abi.decode(message.sender, (address))) {
            revert SenderNotVmexToken();
        }

        (address receiver, uint256 amount) = abi.decode(message.data, (address, uint256));
        _mint(receiver, amount);
    }
}
