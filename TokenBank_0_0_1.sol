// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/IERC20.sol";

contract TokenBank{
    // Struct for tracking user's deposited balance of each token where tokenAddress is the erc20 contract address
    // !!!!!!!Next version needs to be a mapping of a mapping otherwise it only allows for one token type to be assigned per address!!!!!!!
    struct tokenBalances {
        address tokenAddress; 
        uint userBalance;
    }
    // Track address balances for each token deposited
    mapping(address => tokenBalances) public balances;

    function depositTokens(address _tokenAddress, uint _amount) public {
        balances[msg.sender].tokenAddress = _tokenAddress;
        balances[msg.sender].userBalance += _amount;
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawTokens(address _tokenAddress, uint _amount) public {
        require(balances[msg.sender].tokenAddress == _tokenAddress && balances[msg.sender].userBalance >= _amount);
        balances[msg.sender].userBalance -= _amount;
        IERC20(_tokenAddress).transferFrom(address(this), msg.sender, _amount);
    }

    fallback() external {

    }
}
