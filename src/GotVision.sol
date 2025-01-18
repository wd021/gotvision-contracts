// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IPermit2 {
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

/*
 #####                  #     #                         
#     #  ####  #####    #     # #  ####  #  ####  #    #
#       #    #   #      #     # # #      # #    # ##   #
#  #### #    #   #      #     # #  ####  # #    # # #  #
#     # #    #   #       #   #  #      # # #    # #  # #
#     # #    #   #        # #   # #    # # #    # #   ##
 #####   ####    #         #    #  ####  #  ####  #    #
*/

contract GotVision is Ownable, ReentrancyGuard, Pausable {
    IERC20 public wldToken;

    // Add Permit2 constant and interface
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    IPermit2 public immutable permit2;

    // Events with timestamps
    event Deposited(address indexed user, uint256 amount, string userId, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount, uint256 timestamp);
    
    // Constructor sets the WLD token address and owner
    constructor(address _wldToken) Ownable(msg.sender) {
        require(_wldToken != address(0), "Invalid token address");
        wldToken = IERC20(_wldToken);
        permit2 = IPermit2(PERMIT2_ADDRESS);
    }

    /**
     * @notice Allows users to deposit WLD tokens using Permit2
     * @param amount The amount of WLD tokens to deposit
     * @param permit The Permit2 permission structure
     * @param signature The signature for the Permit2 transfer
     * @param userId The user's identification string
     */
    function deposit(
        uint256 amount,
        IPermit2.PermitTransferFrom calldata permit,
        bytes calldata signature,
        string calldata userId
    ) external whenNotPaused nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(permit.permitted.amount >= amount, "Insufficient permit amount");
        
        // Execute the Permit2 transfer
        permit2.permitTransferFrom(
            permit,
            IPermit2.SignatureTransferDetails({
                to: address(this),
                requestedAmount: amount
            }),
            msg.sender,
            signature
        );
        
        // Emit deposit event with userId and current timestamp
        emit Deposited(msg.sender, amount, userId, block.timestamp);
    }
    
    /**
     * @notice Allows admin to withdraw tokens to a user's address
     * @param user The address to send tokens to
     * @param amount The amount of WLD tokens to withdraw
     */
    function adminWithdraw(address user, uint256 amount) 
        external 
        onlyOwner 
        nonReentrant 
    {
        require(user != address(0), "Invalid address");
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= wldToken.balanceOf(address(this)), 
                "Insufficient contract balance");
        
        // Transfer tokens from contract to user
        require(wldToken.transfer(user, amount), "Transfer failed");
        
        // Emit withdrawal event with current timestamp
        emit Withdrawn(user, amount, block.timestamp);
    }
    
    /**
     * @notice Emergency function to pause deposits
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Unpause deposits
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @notice View function to get contract's WLD balance
     */
    function getContractBalance() external view returns (uint256) {
        return wldToken.balanceOf(address(this));
    }
    
    /**
     * @notice Emergency function to recover stuck tokens
     * @param token The token address to recover
     */
    function recoverERC20(address token) external onlyOwner {
        require(token != address(wldToken), "Cannot recover game token");
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        require(balance > 0, "No tokens to recover");
        require(tokenContract.transfer(owner(), balance), "Recovery failed");
    }
}