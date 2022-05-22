// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/IERC20.sol";

contract TokenBank{
    // Mapping of mapping to track balances for each token deposited by owner address
    mapping(address => mapping(address => uint256)) public balances;

    function depositTokens(address _tokenAddress, uint _amount) public {
        balances[msg.sender][_tokenAddress] += _amount;
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawTokens(address _tokenAddress, uint _amount) public {
        require(balances[msg.sender][_tokenAddress] >= _amount);
        balances[msg.sender][_tokenAddress] -= _amount;
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
    }

    fallback() external {

    }
}
