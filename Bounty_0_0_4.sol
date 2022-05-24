// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// This contract takes a bet on if the timestamp will be odd or even at a future block
// Next version: Store all bets in an array; create a function that is external view to check what bets an address has open?
// Ideas: (1) emergency withdraw activation (2) allow multiple addresses to bet? (3) add oracles
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/IERC20.sol";

contract SimpleBet {
    // struct to store each address's total deposited token balance and # tokens in a bet
    struct Ledger {
        uint depositedBalance;
        uint escrowedBalance;
    }
    // Mapping of mapping to track balances for each token by owner address
    mapping(address => mapping(address => Ledger)) public balances;

    // Mapping to track all of a user's bets;
    // Risks creating an unbounded array that consumes too much gas!!!!!!!!!!!!!!!
    mapping(address => uint256[]) public UserBets;

    uint256 BetNumber;
    
    // this struct stores bets which will be assigned a BetNumber to be mapped to
    struct Bets {
        address Maker; 
        address Taker;
        address SkinToken;
        uint BetAmount;
        uint EndTime;
        bytes32 Status;
        uint8 MakerSide;
        bool MakerCancel;
        bool TakerCancel;
    }
    // Mapping of all open bets 
    mapping(uint256 => Bets) public AllBets;

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
    function betNewDeposit(address _takerAddress, address _tokenAddress, uint _amount, uint32 _time) public {
        require(_amount > 0);
        // should BetNumber be incremented here or later? This logic results in BetNumber[0] having no initialization
        BetNumber++;

        AllBets[BetNumber].Maker = msg.sender;
        AllBets[BetNumber].Taker = _takerAddress;
        AllBets[BetNumber].SkinToken = _tokenAddress;
        AllBets[BetNumber].BetAmount = _amount;
        AllBets[BetNumber].EndTime = block.timestamp + _time;
        AllBets[BetNumber].Status = "WAITING";
        AllBets[BetNumber].MakerSide = 1;
        AllBets[BetNumber].MakerCancel= false; 
        AllBets[BetNumber].TakerCancel = false;
        UserBets[msg.sender].push(BetNumber);
        balances[msg.sender][_tokenAddress].depositedBalance += _amount;
        balances[msg.sender][_tokenAddress].escrowedBalance += _amount;
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
    }

    function betWithDeposits(address _takerAddress, address _tokenAddress, uint _amount, uint32 _time) public {
        //Check that Maker has required amount of tokens for bet
        require(balances[msg.sender][_tokenAddress].depositedBalance - balances[msg.sender][_tokenAddress].escrowedBalance >= _amount);
        BetNumber++;

        AllBets[BetNumber].Maker = msg.sender;
        AllBets[BetNumber].Taker = _takerAddress;
        AllBets[BetNumber].SkinToken = _tokenAddress;
        AllBets[BetNumber].BetAmount = _amount;
        AllBets[BetNumber].EndTime = block.timestamp + _time;
        AllBets[BetNumber].Status = "WAITING";
        AllBets[BetNumber].MakerSide = 1;
        AllBets[BetNumber].MakerCancel= false; 
        AllBets[BetNumber].TakerCancel = false;
        UserBets[msg.sender].push(BetNumber);
        balances[msg.sender][_tokenAddress].escrowedBalance += _amount;
    } 

    function CancelBet(uint _betNumber) public {
        address _tokenAddress = AllBets[_betNumber].SkinToken;
        // Check that request was sent by bet Maker
        require(msg.sender == AllBets[_betNumber].Maker);
        // check that bet is not taken
        require(AllBets[_betNumber].Status == "WAITING");
        // check that the amount they want to withdraw is allowed
        require(AllBets[_betNumber].BetAmount <= balances[msg.sender][_tokenAddress].escrowedBalance);
        // subtract the bet amount from escrowedBalance
        balances[msg.sender][_tokenAddress].escrowedBalance -= AllBets[_betNumber].BetAmount;
        // subtract bet amount from depositedBalance
        balances[msg.sender][_tokenAddress].depositedBalance -= AllBets[_betNumber].BetAmount;
        // Change status to "KILLED"
        AllBets[_betNumber].Status = "KILLED";
        // withdraw funds
        IERC20(_tokenAddress).transfer(msg.sender, AllBets[_betNumber].BetAmount);
    }

    function AcceptBet(uint _betNumber, uint _amount) public {
        // require that the bet is not taken, killed, or completed
        require(AllBets[_betNumber].Status == "WAITING");
        // require bet time not passed
        require(AllBets[_betNumber].EndTime > block.timestamp);
        // check the token being deposited as SkinToken is correct
        address _tokenAddress = AllBets[_betNumber].SkinToken;
        require(_tokenAddress == AllBets[_betNumber].SkinToken);
        // check the same amount is uesd
        require(_amount == AllBets[_betNumber].BetAmount);
        
        AllBets[_betNumber].Status = "IN_PROCESS";
        UserBets[msg.sender].push(BetNumber);
        balances[msg.sender][_tokenAddress].depositedBalance += _amount;
        balances[msg.sender][_tokenAddress].escrowedBalance += _amount;
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
    }

    function AcceptBetWithDeposit(uint _betNumber, uint _amount) public {
        // require that the bet is not taken, killed, or completed
        require(AllBets[_betNumber].Status == "WAITING");
        // require bet time not passed
        require(AllBets[_betNumber].EndTime > block.timestamp);
        // check that Taker has required amount of tokens
        require(balances[msg.sender][AllBets[_betNumber].SkinToken].depositedBalance  
            - balances[msg.sender][AllBets[_betNumber].SkinToken].escrowedBalance 
            >= _amount);
        AllBets[_betNumber].Status = "IN_PROCESS";
        UserBets[msg.sender].push(BetNumber);
        balances[msg.sender][AllBets[_betNumber].SkinToken].escrowedBalance += _amount;
    }

    function CloseBet(uint _betNumber) public {
        // check bet status
        require(AllBets[_betNumber].Status == "IN_PROCESS");
        // check correct time has passed
        require(block.timestamp >= AllBets[_betNumber].EndTime);
        // check winner
        uint amount = AllBets[_betNumber].BetAmount;
        bool makerWins;

        if(block.timestamp % 2 == AllBets[_betNumber].MakerSide){
            makerWins = true;
        }else{makerWins = false;}

        // make the below into a function like: SendSettledBet(_winningAddress, _losingAddress, token, amount)
        if(makerWins){
            AllBets[_betNumber].Status = "SETTLED";
            balances[AllBets[_betNumber].Maker][AllBets[_betNumber].SkinToken].depositedBalance += amount;
            balances[AllBets[_betNumber].Maker][AllBets[_betNumber].SkinToken].escrowedBalance -= amount;
            balances[AllBets[_betNumber].Taker][AllBets[_betNumber].SkinToken].depositedBalance -= amount;
            balances[AllBets[_betNumber].Taker][AllBets[_betNumber].SkinToken].escrowedBalance -= amount;
        }else {
            AllBets[_betNumber].Status = "SETTLED";
            balances[AllBets[_betNumber].Maker][AllBets[_betNumber].SkinToken].depositedBalance -= amount;
            balances[AllBets[_betNumber].Maker][AllBets[_betNumber].SkinToken].escrowedBalance -= amount;
            balances[AllBets[_betNumber].Taker][AllBets[_betNumber].SkinToken].depositedBalance += amount;
            balances[AllBets[_betNumber].Taker][AllBets[_betNumber].SkinToken].escrowedBalance -= amount;
        }
    }

    function RequestBetCancel(uint _betNumber) public {
        // Require that request was sent by Maker or Taker
        require(msg.sender == AllBets[_betNumber].Maker || msg.sender == AllBets[_betNumber].Taker);
        // Require that bet is in a cancellable state ("IN_PROCESS")
        require(AllBets[_betNumber].Status == "IN_PROCESS");

        if(msg.sender == AllBets[_betNumber].Maker) {
            AllBets[_betNumber].MakerCancel = true;
        }else if(msg.sender == AllBets[_betNumber].Taker) {
            AllBets[_betNumber].TakerCancel = true;
        }

        //If Maker and Taker agree to cancel then refund each their tokens
        //If future versions have deposited LINK into an LINK oracle then this may need to be refunded
        if(AllBets[_betNumber].MakerCancel == true && AllBets[_betNumber].TakerCancel == true){
            AllBets[_betNumber].Status = "CANCELLED";
            balances[AllBets[_betNumber].Maker][AllBets[_betNumber].SkinToken].escrowedBalance -= AllBets[_betNumber].BetAmount;
            balances[AllBets[_betNumber].Taker][AllBets[_betNumber].SkinToken].escrowedBalance -= AllBets[_betNumber].BetAmount;
        }
    }

    fallback() external {
        
    }
}
