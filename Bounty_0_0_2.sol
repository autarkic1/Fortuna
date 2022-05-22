pragma solidity ^0.4.22;

// Create a contract that receives ETH and only allows the address that deposited it *OR* a specified address to withdraw the ETH
// This contract only allows ETH deposits and withdrawals
// This contract only allows for one address to be set as "permitted" and able to withdraw another user's ETH

contract simpleBounty {
    // Track address balances
    mapping(address => uint) public balances;
    // Trace allowed withdraw addresses and amounts   ***in v3 try making permittedAddresses an array of addresses, will need to change
    // line 25 require statement
    struct permit_data {address permittedAddress; uint max_amount;}
    mapping(address => permit_data) public permissioned;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint withdraw_amount) public {
        require(balances[msg.sender] >= withdraw_amount);
        balances[msg.sender] -= withdraw_amount;
        msg.sender.transfer(withdraw_amount);
    }

    function setPermissions(address permitted_address, uint permitted_amount) public {
        require(permitted_amount <= balances[msg.sender]);
        require(permissioned[msg.sender].permittedAddress == 0);

        permissioned[msg.sender].permittedAddress = permitted_address;
        permissioned[msg.sender].max_amount = permitted_amount;
    }

    function permittedWithdrawal(address target_address, uint amount) public {
        // check that msg.sender is permitted to withdraw funds
        require(msg.sender == permissioned[target_address].permittedAddress);
        // check that the amount they want to withdraw is allowed
        require(amount <= permissioned[target_address].max_amount);
        // subtract the amount they want to withdraw from max_amount to avoid reentrancy
        permissioned[target_address].max_amount -= amount;
        // if all of the ETH allowed to be withdrawn is taken then reset permitted address to 0
        if(permissioned[target_address].max_amount == 0) {
            permissioned[target_address].permittedAddress = 0;
        }
        // withdraw funds
        msg.sender.transfer(amount);
    }

    function () public payable {
        balances[msg.sender] += msg.value;
    }
}
