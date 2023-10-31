// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {VMEXToken} from "src/VmexToken.sol";
import {IRouterClient} from "ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {CCIPRouterMock} from "./mocks/CCIPRouterMock.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract TokenTest is Test {
    VMEXToken internal vmexToken;
    MockERC20 internal link;
    CCIPRouterMock internal router;
    uint256 public constant MAX_TOTAL_SUPPLY = 100_000_000 * 1e18; //100 million max

    uint64 internal constant BASE_CHAIN_ID = 8453;

    address internal constant VMEX_ON_BASE = address(0xbabe);
    address internal constant RECEIVER = address(0x1234);

    bytes32 internal constant MESSAGE_ID = 0x1230000000000000000000000000000000000000000000000000000000000000;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event ChainAdded(uint64 indexed chain, address vmexToken);

    receive() external payable {}

    function setUp() public {
        link = new MockERC20("LINK", "LINK", 18);
        router = new CCIPRouterMock(address(link));
        router.setFee(0.1 ether);
        router.setMessageId(MESSAGE_ID);

        vmexToken = new VMEXToken(address(router), address(link), true, address(this));

        vm.label(address(vmexToken), "VMEX");
        vm.label(address(router), "ROUTER");
        vm.label(address(link), "LINK");
        vm.label(address(this), "TESTER");
        vm.label(RECEIVER, "RECEIVER");
    }

    function testTokenSupply() public {
        assertEq(vmexToken.totalSupply(), MAX_TOTAL_SUPPLY);

        VMEXToken tokenNotOnHub = new VMEXToken(address(router), address(link), false, address(this));
        assertEq(tokenNotOnHub.totalSupply(), 0);
    }

    function testLinkBridgeTo() public {
        vmexToken.addVmexTokenOnChain(BASE_CHAIN_ID, VMEX_ON_BASE);
        uint256 fee = router.fee();

        link.mint(address(this), fee);
        link.approve(address(vmexToken), fee);

        vm.expectEmit(true, true, false, true, address(vmexToken));
        emit Transfer(address(this), address(0), MAX_TOTAL_SUPPLY);
        vm.expectEmit(true, true, false, true, address(link));
        emit Transfer(address(this), address(vmexToken), fee);
        vm.expectEmit(true, true, false, true, address(link));
        emit Transfer(address(vmexToken), address(router), fee);

        vmexToken.bridge(BASE_CHAIN_ID, RECEIVER, MAX_TOTAL_SUPPLY, false);

        assertEq(vmexToken.balanceOf(address(this)), 0);
        assertEq(link.balanceOf(address(vmexToken)), 0);
        assertEq(link.balanceOf(address(router)), fee);
        assertEq(link.balanceOf(address(this)), 0);
    }

    function testNativeBridgeTo() public {
        uint256 nativeBalanceBefore = address(router).balance;

        vmexToken.addVmexTokenOnChain(BASE_CHAIN_ID, VMEX_ON_BASE);
        uint256 fee = router.fee();

        vm.deal(address(this), fee);

        vm.expectEmit(true, true, false, true, address(vmexToken));
        emit Transfer(address(this), address(0), MAX_TOTAL_SUPPLY);

        vmexToken.bridge{value: fee}(BASE_CHAIN_ID, RECEIVER, MAX_TOTAL_SUPPLY, true);

        assertEq(vmexToken.balanceOf(address(this)), 0);
        assertEq(address(router).balance, nativeBalanceBefore + fee);
        assertEq(address(vmexToken).balance, 0);
    }

    function testBridgeToUnallowedChain() public {
        vm.expectRevert(abi.encodeWithSelector(VMEXToken.DestinationChainNotAllowed.selector, BASE_CHAIN_ID));
        vmexToken.bridge(BASE_CHAIN_ID, address(this), MAX_TOTAL_SUPPLY, false);
    }

    function testNativeBridgeToNotEnoughFee() public {
        vmexToken.addVmexTokenOnChain(BASE_CHAIN_ID, VMEX_ON_BASE);
        uint256 fee = router.fee();

        vm.deal(address(this), fee);

        vm.expectRevert(VMEXToken.NotEnoughEthForFee.selector);
        vmexToken.bridge{value: fee - 1}(BASE_CHAIN_ID, RECEIVER, MAX_TOTAL_SUPPLY, true);
    }

    function testBridgeFrom() public {
        uint256 totalSupplyBefore = vmexToken.totalSupply();
        uint256 recieverBalanceBefore = vmexToken.balanceOf(RECEIVER);

        vmexToken.addVmexTokenOnChain(BASE_CHAIN_ID, VMEX_ON_BASE);

        uint256 amount = 1e20;

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: MESSAGE_ID,
            sourceChainSelector: BASE_CHAIN_ID,
            sender: abi.encode(VMEX_ON_BASE),
            data: abi.encode(RECEIVER, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.expectEmit(true, true, false, true, address(vmexToken));
        emit Transfer(address(0), RECEIVER, amount);
        router.ccipReceive(address(vmexToken), message);

        assertEq(totalSupplyBefore + amount, vmexToken.totalSupply());
        assertEq(recieverBalanceBefore + amount, vmexToken.balanceOf(RECEIVER));
    }

    function testBridgeFromSourceChainNotAllowed() public {
        uint256 amount = 1e20;

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: MESSAGE_ID,
            sourceChainSelector: BASE_CHAIN_ID,
            sender: abi.encode(VMEX_ON_BASE),
            data: abi.encode(RECEIVER, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });
        vm.expectRevert(abi.encodeWithSelector(VMEXToken.SourceChainNotAllowed.selector, BASE_CHAIN_ID));
        router.ccipReceive(address(vmexToken), message);
    }

    function testBridgeFromSenderNotVmexToken() public {
        vmexToken.addVmexTokenOnChain(BASE_CHAIN_ID, VMEX_ON_BASE);

        uint256 amount = 1e20;
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: MESSAGE_ID,
            sourceChainSelector: BASE_CHAIN_ID,
            sender: abi.encode(address(0xc0de)),
            data: abi.encode(RECEIVER, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });
        vm.expectRevert(VMEXToken.SenderNotVmexToken.selector);
        router.ccipReceive(address(vmexToken), message);
    }

    function testWithdrawToken() public {
        uint256 amount = 1e23;
        link.mint(address(vmexToken), amount);

        vm.expectEmit(true, true, false, true, address(link));
        emit Transfer(address(vmexToken), address(this), amount);
        vmexToken.withdrawToken(address(link), amount);
    }

    function testWithdrawNative() public {
        uint256 amount = 1e23;

        vm.deal(address(vmexToken), amount);

        uint256 vmexBalanceBefore = address(vmexToken).balance;
        uint256 thisBalanceBefore = address(this).balance;

        vmexToken.withdrawNative(amount - 1);

        assertEq(thisBalanceBefore + amount - 1, address(this).balance);
        assertEq(vmexBalanceBefore - amount + 1, address(vmexToken).balance);
    }

    function testAddVmexTokenOnChain() public {
        vm.expectEmit(true, false, false, true, address(vmexToken));
        emit ChainAdded(BASE_CHAIN_ID, VMEX_ON_BASE);
        vmexToken.addVmexTokenOnChain(BASE_CHAIN_ID, VMEX_ON_BASE);
    }

    function testAddVmexTokenOnChainVmexTokenAlreadyAddedOnChain() public {
        vmexToken.addVmexTokenOnChain(BASE_CHAIN_ID, VMEX_ON_BASE);

        vm.expectRevert(VMEXToken.VmexTokenAlreadyAddedOnChain.selector);
        vmexToken.addVmexTokenOnChain(BASE_CHAIN_ID, VMEX_ON_BASE);
    }
}
