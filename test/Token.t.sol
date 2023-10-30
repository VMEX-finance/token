// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import "src/VmexToken.sol";
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

    function setUp() public {
        link = new MockERC20("LINK", "LINK", 18);
        router = new CCIPRouterMock();

        vmexToken = new VMEXToken(address(router), address(link), true, address(this));

        link.mint(address(vmexToken), 1e23);
    }

    function testTokenSupply() public {
        assertEq(vmexToken.totalSupply(), MAX_TOTAL_SUPPLY); 

        VMEXToken tokenNotOnHub = new VMEXToken(address(router), address(link), false, address(this));
        assertEq(tokenNotOnHub.totalSupply(), 0);
        
    }
    
    function testBridgeTo() public {
        vmexToken.allowlistChain(BASE_CHAIN_ID, address(0xbabe));

        vmexToken.bridge(BASE_CHAIN_ID, address(this), MAX_TOTAL_SUPPLY, false);

        assertEq(vmexToken.balanceOf(address(this)), 0);
    }
}
