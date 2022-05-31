// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// This contract takes a bet on if the timestamp will be odd or even at a future block
// Next version: create a function that is external view to check what bets an address has open, improve function names
// Ideas: (1) take a fee on every bet (2) add oracles (3) Figure out tracking a user's bets
// (4) emergency withdraw activation (5) Add upgradeable proxy
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/IERC20.sol";

contract SimpleBet {
    // Protocol constants
    uint8 public PROTOCOL_FEE;
    address OWNER;
    enum Status {
        WAITING_TAKER,
        KILLED,
        IN_PROCESS,
        SETTLED,
        CANCELED
    }
    
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
        Status BetStatus;
        uint8 MakerSide;
        bool MakerCancel;
        bool TakerCancel;
    }
    // Mapping of all open bets 
    mapping(uint256 => Bets) public AllBets;

    fallback() payable external {
        
    }

    constructor(uint8 _protocolFee) {
        // Because Solidity can't perform decimal mult/div, multiply by PROTOCOL_FEE and divide by 10,000
        // PROTOCOL_FEE of 0001 equals 0.01% fee
        PROTOCOL_FEE = _protocolFee;
        OWNER = msg.sender;
    }

    receive() payable external {

    }

    function DepositTokens(address _tokenAddress, uint _amount) public {
        balances[msg.sender][_tokenAddress].depositedBalance += _amount;
        require(IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount), "Deposit Failed");
    }

    // Withdraws _amount of tokens if they are avaiable
    function WithdrawTokens(address _tokenAddress, uint _amount) public {
        uint tokensAvailable = balances[msg.sender][_tokenAddress].depositedBalance - balances[msg.sender][_tokenAddress].escrowedBalance;
        require(tokensAvailable >= _amount);
        balances[msg.sender][_tokenAddress].depositedBalance -= _amount;
        require(IERC20(_tokenAddress).transfer(msg.sender, _amount), "Withdraw Failed");
    }

    // Opens a new bet with freshly deposited tokens
    function DepositAndBet(address _takerAddress, address _tokenAddress, uint _amount, uint32 _time) public {
        require(_amount > 0);
        // should BetNumber be incremented here or later? This logic results in BetNumber[0] having no initialization
        BetNumber++;

        AllBets[BetNumber].Maker = msg.sender;
        AllBets[BetNumber].Taker = _takerAddress;
        AllBets[BetNumber].SkinToken = _tokenAddress;
        AllBets[BetNumber].BetAmount = _amount;
        AllBets[BetNumber].EndTime = block.timestamp + _time;
        AllBets[BetNumber].BetStatus = Status.WAITING_TAKER;
        AllBets[BetNumber].MakerSide = 1;
        AllBets[BetNumber].MakerCancel= false; 
        AllBets[BetNumber].TakerCancel = false;
        UserBets[msg.sender].push(BetNumber);
        balances[msg.sender][_tokenAddress].depositedBalance += _amount;
        balances[msg.sender][_tokenAddress].escrowedBalance += _amount;
        require(IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount), "Deposit Failed");
    }

    function BetWithUserBalance(address _takerAddress, address _tokenAddress, uint _amount, uint32 _time) public {
        //Check that Maker has required amount of tokens for bet
        require(balances[msg.sender][_tokenAddress].depositedBalance - balances[msg.sender][_tokenAddress].escrowedBalance >= _amount);
        BetNumber++;

        AllBets[BetNumber].Maker = msg.sender;
        AllBets[BetNumber].Taker = _takerAddress;
        AllBets[BetNumber].SkinToken = _tokenAddress;
        AllBets[BetNumber].BetAmount = _amount;
        AllBets[BetNumber].EndTime = block.timestamp + _time;
        AllBets[BetNumber].BetStatus = Status.WAITING_TAKER;
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
        require(AllBets[_betNumber].BetStatus == Status.WAITING_TAKER);
        // check that the amount they want to withdraw is allowed
        require(AllBets[_betNumber].BetAmount <= balances[msg.sender][_tokenAddress].escrowedBalance);
        // subtract the bet amount from escrowedBalance
        balances[msg.sender][_tokenAddress].escrowedBalance -= AllBets[_betNumber].BetAmount;
        // Change status to "KILLED"
        AllBets[_betNumber].BetStatus = Status.KILLED;
    }

    function DepositAndAcceptBet(uint _betNumber, uint _amount) public {
        // require that the bet is not taken, killed, or completed
        require(AllBets[_betNumber].BetStatus == Status.WAITING_TAKER);
        // require bet time not passed
        require(AllBets[_betNumber].EndTime > block.timestamp);
        // check the token being deposited as SkinToken is correct
        address _tokenAddress = AllBets[_betNumber].SkinToken;
        require(_tokenAddress == AllBets[_betNumber].SkinToken);
        // check the same amount is uesd
        require(_amount == AllBets[_betNumber].BetAmount);
        
        AllBets[_betNumber].BetStatus = Status.IN_PROCESS;
        UserBets[msg.sender].push(BetNumber);
        balances[msg.sender][_tokenAddress].depositedBalance += _amount;
        balances[msg.sender][_tokenAddress].escrowedBalance += _amount;
        require(IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount), "Deposit Failed");
    }

    function AcceptBetWithUserBalance(uint _betNumber, uint _amount) public {
        // require that the bet is not taken, killed, or completed
        require(AllBets[_betNumber].BetStatus == Status.WAITING_TAKER);
        // require bet time not passed
        require(AllBets[_betNumber].EndTime > block.timestamp);
        // check that Taker has required amount of tokens
        require(balances[msg.sender][AllBets[_betNumber].SkinToken].depositedBalance  
            - balances[msg.sender][AllBets[_betNumber].SkinToken].escrowedBalance 
            >= _amount);
        AllBets[_betNumber].BetStatus = Status.IN_PROCESS;
        UserBets[msg.sender].push(BetNumber);
        balances[msg.sender][AllBets[_betNumber].SkinToken].escrowedBalance += _amount;
    }

    function CloseBet(uint _betNumber) public {
        // check bet status
        require(AllBets[_betNumber].BetStatus == Status.IN_PROCESS);
        // check correct time has passed
        require(block.timestamp >= AllBets[_betNumber].EndTime);
        // check winner
        uint amount = AllBets[_betNumber].BetAmount;
        bool makerWins;

        if(block.timestamp % 2 == AllBets[_betNumber].MakerSide){
            makerWins = true;
        }else{makerWins = false;}

        if(makerWins){
            AllBets[_betNumber].BetStatus = Status.SETTLED;
            SettleBalances(AllBets[_betNumber].Maker, AllBets[_betNumber].Taker, AllBets[_betNumber].SkinToken, amount);
        }else {
            AllBets[_betNumber].BetStatus = Status.SETTLED;
            SettleBalances(AllBets[_betNumber].Taker, AllBets[_betNumber].Maker, AllBets[_betNumber].SkinToken, amount);
        }
    }

    function SettleBalances(address _winningAddress, address _losingAddress, address _skinToken, uint amount) internal {
        // This should use SafeMath!!!!!!!!!!!!!!
        balances[_winningAddress][_skinToken].depositedBalance += (amount*(10000-PROTOCOL_FEE))/10000;
        balances[_winningAddress][_skinToken].escrowedBalance -= amount;
        balances[_losingAddress][_skinToken].depositedBalance -= amount;
        balances[_losingAddress][_skinToken].escrowedBalance -= amount;
        balances[address(this)][_skinToken].depositedBalance += (amount*PROTOCOL_FEE)/10000;
    }

    function RequestBetCancel(uint _betNumber) public {
        // Require that request was sent by Maker or Taker
        require(msg.sender == AllBets[_betNumber].Maker || msg.sender == AllBets[_betNumber].Taker);
        // Require that bet is in a cancellable state ("IN_PROCESS")
        require(AllBets[_betNumber].BetStatus == Status.IN_PROCESS);

        if(msg.sender == AllBets[_betNumber].Maker) {
            AllBets[_betNumber].MakerCancel = true;
        }else if(msg.sender == AllBets[_betNumber].Taker) {
            AllBets[_betNumber].TakerCancel = true;
        }

        //If Maker and Taker agree to cancel then refund each their tokens
        //If future versions have deposited LINK into an LINK oracle then this may need to be refunded
        if(AllBets[_betNumber].MakerCancel == true && AllBets[_betNumber].TakerCancel == true){
            AllBets[_betNumber].BetStatus = Status.CANCELED;
            balances[AllBets[_betNumber].Maker][AllBets[_betNumber].SkinToken].escrowedBalance -= AllBets[_betNumber].BetAmount;
            balances[AllBets[_betNumber].Taker][AllBets[_betNumber].SkinToken].escrowedBalance -= AllBets[_betNumber].BetAmount;
        }
    }

    function TransferERC20(address _token, uint256 amount) external{
        require(msg.sender == OWNER, "Only owner can withdraw");
        require(amount <= balances[OWNER][_token].depositedBalance, "Insufficient Funds");
        balances[OWNER][_token].depositedBalance -= amount;
        require(IERC20(_token).transfer(OWNER, amount), "Withdraw Failed");
    }

    function WithdrawEther(uint256 amount) external{
        require(msg.sender == OWNER, "Only owner can withdraw");
        require(amount <= address(this).balance, "Insufficient Funds");
        payable(OWNER).transfer(amount);
    }

    function CheckClosable(uint _betNumber) external view returns(bool) {
        if(block.timestamp >= AllBets[_betNumber].EndTime && AllBets[_betNumber].BetStatus == Status.IN_PROCESS){return true;}
        else{return false;}
    }
}
