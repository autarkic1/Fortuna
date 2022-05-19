//Version of Solidity compiler this program is written for
pragma solidity ^0.4.22;

// Create a contract that receives ETH and only allows the address that deposited it to withdraw
contract simpleBounty {
    // Track address balances
    mapping(address => uint) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint withdraw_amount) public {
        require(balances[msg.sender] >= withdraw_amount);
        balances[msg.sender] -= withdraw_amount;
        msg.sender.transfer(withdraw_amount);
    }

    function () public payable {
        // Should probably have this revert and NOT payable *************
        balances[msg.sender] += msg.value;
    }
}
