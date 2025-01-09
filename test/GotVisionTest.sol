// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GotVision} from "../src/GotVision.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract GotVisionTest is Test {
    GotVision public gotVision;
    MockERC20 public wldToken;
    
    address public admin = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant DEPOSIT_AMOUNT = 100 ether;

    event Deposited(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount, uint256 timestamp);

    function setUp() public {
        // Deploy mock WLD token
        wldToken = new MockERC20("Worldcoin", "WLD", 18);
        
        // Deploy GotVision
        gotVision = new GotVision(address(wldToken));
        
        // Setup test users with initial balances
        wldToken.mint(user1, INITIAL_BALANCE);
        wldToken.mint(user2, INITIAL_BALANCE);
    }

    function test_Constructor() public {
        assertEq(address(gotVision.wldToken()), address(wldToken));
        assertEq(gotVision.owner(), admin);
    }

    function testRevert_Constructor_ZeroAddress() public {
        vm.expectRevert("Invalid token address");
        new GotVision(address(0));
    }

    function test_Deposit() public {
        // Setup
        vm.startPrank(user1);
        wldToken.approve(address(gotVision), DEPOSIT_AMOUNT);
        
        // Expect Deposit event
        vm.expectEmit(true, false, false, true);
        emit Deposited(user1, DEPOSIT_AMOUNT, block.timestamp);
        
        // Deposit tokens
        gotVision.deposit(DEPOSIT_AMOUNT);
        
        // Verify balances
        assertEq(wldToken.balanceOf(address(gotVision)), DEPOSIT_AMOUNT);
        assertEq(wldToken.balanceOf(user1), INITIAL_BALANCE - DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }

    function testRevert_Deposit_ZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("Amount must be greater than 0");
        gotVision.deposit(0);
        vm.stopPrank();
    }

    function testRevert_Deposit_InsufficientBalance() public {
        vm.startPrank(user1);
        wldToken.approve(address(gotVision), INITIAL_BALANCE * 2);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        gotVision.deposit(INITIAL_BALANCE + 1);
        vm.stopPrank();
    }

    function test_AdminWithdraw() public {
        // Setup - deposit first
        vm.startPrank(user1);
        wldToken.approve(address(gotVision), DEPOSIT_AMOUNT);
        gotVision.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Admin withdrawal
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(user2, DEPOSIT_AMOUNT, block.timestamp);
        
        gotVision.adminWithdraw(user2, DEPOSIT_AMOUNT);
        
        // Verify balances
        assertEq(wldToken.balanceOf(address(gotVision)), 0);
        assertEq(wldToken.balanceOf(user2), INITIAL_BALANCE + DEPOSIT_AMOUNT);
    }

    function testRevert_AdminWithdraw_NotOwner() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        gotVision.adminWithdraw(user2, DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testRevert_AdminWithdraw_ZeroAddress() public {
        vm.expectRevert("Invalid address");
        gotVision.adminWithdraw(address(0), DEPOSIT_AMOUNT);
    }

    function testRevert_AdminWithdraw_ZeroAmount() public {
        vm.expectRevert("Amount must be greater than 0");
        gotVision.adminWithdraw(user2, 0);
    }

    function testRevert_AdminWithdraw_InsufficientBalance() public {
        vm.expectRevert("Insufficient contract balance");
        gotVision.adminWithdraw(user2, DEPOSIT_AMOUNT);
    }

    function test_Pause() public {
        gotVision.pause();
        assertTrue(gotVision.paused());
        
        // Verify deposits are blocked when paused
        vm.startPrank(user1);
        wldToken.approve(address(gotVision), DEPOSIT_AMOUNT);
        vm.expectRevert("Pausable: paused");
        gotVision.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function test_Unpause() public {
        gotVision.pause();
        gotVision.unpause();
        assertFalse(gotVision.paused());
        
        // Verify deposits work after unpause
        vm.startPrank(user1);
        wldToken.approve(address(gotVision), DEPOSIT_AMOUNT);
        gotVision.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        assertEq(wldToken.balanceOf(address(gotVision)), DEPOSIT_AMOUNT);
    }

    function test_GetContractBalance() public {
        vm.startPrank(user1);
        wldToken.approve(address(gotVision), DEPOSIT_AMOUNT);
        gotVision.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        assertEq(gotVision.getContractBalance(), DEPOSIT_AMOUNT);
    }

    function test_RecoverERC20() public {
        // Deploy another token and send it to the contract
        MockERC20 otherToken = new MockERC20("Other", "OTHER", 18);
        otherToken.mint(address(gotVision), DEPOSIT_AMOUNT);
        
        // Recover the other token
        gotVision.recoverERC20(address(otherToken));
        
        // Verify the token was recovered
        assertEq(otherToken.balanceOf(admin), DEPOSIT_AMOUNT);
    }

    function testRevert_RecoverERC20_GameToken() public {
        vm.expectRevert("Cannot recover game token");
        gotVision.recoverERC20(address(wldToken));
    }
}