// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IRouterClient} from "ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Test, console2} from "forge-std/Test.sol";

contract VMEXToken is ERC20, CCIPReceiver, Owned, Test {
    using SafeTransferLib for ERC20;

    //set chain to allowed as both source, and destination
    mapping(uint64 chain => address vmexToken) public allowlistedChains;

    uint256 public constant MAX_TOTAL_SUPPLY = 100_000_000 * 1e18; //100 million max
    address internal immutable LINK;
    bool public isOpen = true;

    error DestinationChainNotAllowed(uint64 chain);
    error SourceChainNotAllowed(uint64 chain);
    error NotEnoughEthForFee();
    error SenderNotVmexToken();

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
    function allowlistChain(uint64 destinationChainSelector, address vmexToken) external onlyOwner {
        allowlistedChains[destinationChainSelector] = vmexToken;
    }

    function withdrawGasTokens(uint256 amount) external onlyOwner {
        ERC20(LINK).safeTransfer(owner, amount);
    }

    function withdraw(address beneficiary) external onlyOwner {
        uint256 amount = address(this).balance;
        (bool sent,) = beneficiary.call{value: amount}("");
        if (!sent) revert("failed to withdraw eth");
    }

    function toggleOpenStatus() external onlyOwner {
        if (isOpen == true) {
            isOpen = false;
        } else {
            isOpen = true;
        }
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
        address receiverUserAddress,
        uint256 amount,
        bool payFeesNative
    ) public payable returns (bytes32 messageId) {
        address destinationVmexToken = allowlistedChains[destinationChainSelector];
        if (destinationVmexToken == address(0)) {
            revert DestinationChainNotAllowed(destinationChainSelector);
        }

        _burn(msg.sender, amount);

        //if we're burning on the destination chain, this chain needs to do the opposite
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(destinationVmexToken),
            data: abi.encode(receiverUserAddress, amount),
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
        address sourceChainVmexToken = allowlistedChains[message.sourceChainSelector];
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
