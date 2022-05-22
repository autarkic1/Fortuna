// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// This contract takes a bet on if the timestamp will be odd or even at a future block
// This code has numerous vulnerabilities and acts only as a proof of concept
// Ideas: (1) emergency withdraw activation (2) allow multiple permittedAddresses to withdraw? (3) add an oracle variable to the permit_data struct?
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/IERC20.sol";

contract SimpleBet {
    // struct to store each address's total deposited token balance and # tokens in a bet
    struct Ledger {
        uint depositedBalance;
        uint escrowedBalance;
    }
    // Mapping of mapping to track balances for each token by owner address
    mapping(address => mapping(address => Ledger)) public balances;
    
    // this struct stores bets by address, in this iteration it will only allow one bet at a time
    struct OpenBets {
        address opponent; 
        address token;
        uint bet_amount;
        uint end_time;
        bytes32 status;
        uint8 side;
    }
    // Mapping of all open bets by address (can only store one bet at a time, will overwrite 1st bet if a 2nd bet is made)
    mapping(address => OpenBets) public openBets;

    function depositTokens(address _tokenAddress, uint _amount) public {
        balances[msg.sender][_tokenAddress].depositedBalance += _amount;
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
    }

    // Withdraws _amount of tokens if they are avaiable
    function withdrawTokens(address _tokenAddress, uint _amount) public {
        uint tokensAvailable = balances[msg.sender][_tokenAddress].depositedBalance - balances[msg.sender][_tokenAddress].escrowedBalance;
        require(tokensAvailable >= _amount);
        balances[msg.sender][_tokenAddress].depositedBalance -= _amount;
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
    }

    // Opens a new bet with freshly deposited tokens
    function betNewDeposit(address _opponentAddress, address _tokenAddress, uint _amount, uint32 _time) public {
        require(_amount > 0);

        openBets[msg.sender].opponent = _opponentAddress;
        openBets[msg.sender].token = _tokenAddress;
        openBets[msg.sender].bet_amount = _amount;
        openBets[msg.sender].end_time = block.timestamp + _time;
        openBets[msg.sender].status = "WAITING";
        openBets[msg.sender].side = 1;
        balances[msg.sender][_tokenAddress].depositedBalance += _amount;
        balances[msg.sender][_tokenAddress].escrowedBalance += _amount;
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
    }

    function CancelBet(address _tokenAddress) public {
        // check that bet is not taken
        require(openBets[msg.sender].status == "WAITING" && openBets[msg.sender].token == _tokenAddress);
        // check that the amount they want to withdraw is allowed
        // *******This logic will need to be changed if we allow for multiple bets with the same token from the same address*******
        require(openBets[msg.sender].bet_amount <= balances[msg.sender][_tokenAddress].escrowedBalance);
        // subtract the bet amount from escrowedBalance
        balances[msg.sender][_tokenAddress].escrowedBalance -= openBets[msg.sender].bet_amount;
        // subtract bet amount from depositedBalance
        balances[msg.sender][_tokenAddress].depositedBalance -= openBets[msg.sender].bet_amount;
        // Change status to "KILLED"
        openBets[msg.sender].status = "KILLED";
        // withdraw funds
        IERC20(_tokenAddress).transfer(msg.sender, openBets[msg.sender].bet_amount);
    }

    function AcceptBet(address _proposerAddress, address _tokenAddress, uint _amount) public {
        // require that the bet is not taken, killed, or completed
        require(openBets[_proposerAddress].status == "WAITING");
        // require bet time not passed
        require(openBets[_proposerAddress].end_time > block.timestamp);
        // check token address
        require(_tokenAddress == openBets[_proposerAddress].token);
        openBets[msg.sender].opponent = _proposerAddress;
        openBets[msg.sender].token = _tokenAddress;
        openBets[msg.sender].bet_amount = _amount;
        openBets[msg.sender].end_time = openBets[_proposerAddress].end_time;
        openBets[msg.sender].status = "IN_PROCESS";
        openBets[msg.sender].side = 0;
        openBets[_proposerAddress].status = "IN_PROCESS";
        balances[msg.sender][_tokenAddress].depositedBalance += _amount;
        balances[msg.sender][_tokenAddress].escrowedBalance += _amount;
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
    }

    function CloseBet(address _opponentAddress, address _tokenAddress) public {
        // check bet exists
        require(openBets[msg.sender].opponent == _opponentAddress && openBets[msg.sender].token == _tokenAddress);
        // check bet status
        require(openBets[msg.sender].status == "IN_PROCESS");
        // check correct time has passed
        require(block.timestamp >= openBets[msg.sender].end_time);
        // check winner
        uint amount = openBets[msg.sender].bet_amount;
        bool proposerWins;
        bool senderWins;

        if(block.timestamp % 2 == 1){
            proposerWins = true;
        }else{proposerWins = false;}

        if(proposerWins && openBets[msg.sender].side == 1){
            senderWins = true;
        }else if(proposerWins && openBets[msg.sender].side == 0){
            senderWins = false;
        }else if(!proposerWins && openBets[msg.sender].side == 1) {
            senderWins = false;
        }else{senderWins = true;}

        if(senderWins){
            openBets[msg.sender].status = "SETTLED";
            openBets[_opponentAddress].status = "SETTLED";
            balances[msg.sender][_tokenAddress].depositedBalance += amount;
            balances[msg.sender][_tokenAddress].escrowedBalance -= amount;
            balances[_opponentAddress][_tokenAddress].depositedBalance -= amount;
            balances[_opponentAddress][_tokenAddress].escrowedBalance -= amount;
        }else{
            openBets[msg.sender].status = "SETTLED";
            openBets[_opponentAddress].status = "SETTLED";
            balances[msg.sender][_tokenAddress].depositedBalance -= amount;
            balances[msg.sender][_tokenAddress].escrowedBalance -= amount;
            balances[_opponentAddress][_tokenAddress].depositedBalance += amount;
            balances[_opponentAddress][_tokenAddress].escrowedBalance -= amount;
        }

    }

    fallback() external {
        
    }
}
