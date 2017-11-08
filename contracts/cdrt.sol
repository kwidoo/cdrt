pragma solidity ^0.4.18;

import "erc20.sol";

contract CDRTToken is TokenERC20 {

    uint256 public buyBackPrice;
    // Snapshot of PE balances by Ethereum Address and by year
    mapping (uint256 => mapping (address => uint256)) public snapShot;
    // This is time for next Profit Equivalent
    uint256 public nextPE = 1539205199;
    // List of Team and Founders account's frozen till 15 November 2018
    mapping (address => uint256) public frozenAccount;

    // List of all years when snapshots were made
    uint256[] internal yearsPast = [2017];  
    // Holds current year PE balance
    uint256 public peBalance;       
    // Holds full Buy Back balance
    uint256 public bbBalance;       
    // Holds unclaimed PE balance from last periods
    uint256 internal peLastPeriod;       
    // All ever used in transactions Ethereum Addresses' positions in list
    mapping (address => uint256) internal ownerPos;              
    // Total number of Ethereum Addresses used in transactions 
    uint256 internal pos;                                      
    // All ever used in transactions Ethereum Addresses list
    mapping (uint256 => address) internal addressList;   
    
    address[] internal payers = [0x17D5B9419dEB289041b34fA879d99381474e8EBC,     // pe Account
                                 0x1De196D0D351B245a996f5751B545FA0Dc2a55d6];    // buyBack Account

    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, uint256 frozen);

    /* Handles incoming payments to contract's address */
    function() payable public {
        // Anything send not by owner will be divided between Campaigns 
        if (msg.sender != payers[1] && msg.sender != payers[2]){
          peBalance += msg.value/3*2;     // Profit Equivalent
          bbBalance += msg.value/3;       // Buy-Back
        } else {
            if (msg.sender != payers[1]) peBalance = msg.value;       
            if (msg.sender != payers[2]) bbBalance = msg.value;      
        }
    }
    /* Initializes contract with initial supply tokens to the creator of the contract */
    function CDRTToken(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) TokenERC20(initialSupply, tokenName, tokenSymbol) public {}

    /* Internal insertion in list of all Ethereum Addresses used in transactions, called by contract */
    function _insert(address _to) internal {
            if (ownerPos[_to] == 0) {
                pos++;
                addressList[pos] = _to;
                ownerPos[_to] = pos;
            }
    }

    /* Internal transfer, only can be called by this contract */
    function _transfer(address _from, address _to, uint _value) internal {
        _unFreezeAccount(_from);
        _unFreezeAccount(_to);
        require (_to != 0x0);                               // Prevent transfer to 0x0 address. Use burn() instead
        require (balanceOf[_from] >= _value);                // Check if the sender has enough
        require (balanceOf[_to] + _value > balanceOf[_to]); // Check for overflows
        require(frozenAccount[_from] < now);                // Check if sender is frozen
        require(frozenAccount[_to] < now);                  // Check if recipient is frozen
         _insert(_to);
        balanceOf[_from] -= _value;                         // Subtract from the sender
        balanceOf[_to] += _value;                           // Add the same to the recipient
        Transfer(_from, _to, _value);
    }

    /**
      * @notice Freezes from sending & receiving tokens. For users protection can't be used after 1542326399
      * and will not allow corrections.
      *
      * We can't check when balance of current account was received, 
      * so we don't allow to receive either. 
      *
      * If member of Team with frozen account would like to buy more CDRT tokens
      * separate address should be used before account will be unfreezed
      *
      * Will set freeze to 1542326399, that is 15.11.2018 23:59
      *
      * @param _from  Founders and Team account we are freezing from sending
      *
      */
   function freezeAccount(address _from) onlyOwner public {
        require(now < 1542326400);
        require(frozenAccount[_from] == 0);
        frozenAccount[_from] = 1542326399;                  
        FrozenFunds(_from, 1542326399);
    }

    /**
      * @notice unfreeze Team account if time has come. No need to call directly as it checks when try to transfer tokens
      *
      * @param _from Address to unfreeze
      */
    function _unFreezeAccount(address _from) internal {
        // Check if sender can be unfreezed
        require(now > frozenAccount[_from]);                                                
        frozenAccount[_from] = 0;              
        FrozenFunds(_from, 0);
    } 
    /**
      * @notice Allow owner to set tokens price for Buy-Back Campaign. Can not be executed until 1539561600
      *
      * @param _newPrice market value of 1 CDRT Token
      *
      */
    function setPrice(uint256 _newPrice) onlyOwner public {
        require(now > 1539561600);                          
        buyBackPrice = _newPrice;
    }

    /**
      * @notice Set next date to claim Profit Equivalent. Should be called by contract owner only after 15 october
      *
      * @param _value unix timestamp of next 10 October
      */
    function setNextPE(uint256 _value) onlyOwner public {
        require (_value > nextPE);
        nextPE = _value;    
    }

    /**
      * @notice Contract owner can take snapshot of current balances and issue PE to each balance
      *
      * @param _year year of the snapshot to take, must be greater than existing value
      *
      */
   function takeSnapshot(uint256 _year) onlyOwner public {
        require(_year > yearsPast[yearsPast.length-1]);                             
        uint256 reward = peBalance / totalSupply;
        for (uint256 k=1; k <= pos; k++){
            snapShot[_year][addressList[k]] = balanceOf[addressList[k]] * reward;
        }
        yearsPast.push(_year);
        peLastPeriod += peBalance;     // Transfer new balance to unclaimed
        peBalance = 0;                 // Zero current balance;
    }

    /**
      *  @notice Allow user to claim his PE on his Ethereum Address. Should be called manualy by user
      *
      */
    function claimProfitEquivalent() public {
        uint256 toPay;
        for (uint256 k=0; k <= yearsPast.length-1; k++){
            toPay += snapShot[yearsPast[k]][msg.sender];
            snapShot[yearsPast[k]][msg.sender] = 0;
        }
        peLastPeriod -= toPay;
        msg.sender.transfer(toPay);
    }
    /**
      * @notice Allow user to sell CDRT tokens and destroy them. Can not be executed until 1539561600
      *
      * @param _qty amount to sell and destroy
      */
    function buyBack(uint256 _qty) public
    {
        require(now > 1539561600);                          
        _unFreezeAccount(msg.sender);
        uint256 toPay = _qty*buyBackPrice;                                        
        require(balanceOf[msg.sender] >= _qty);                     // check if user has enough CDRT Tokens 
        require(buyBackPrice > 0);                                  // check if sale price set
        require(bbBalance >= toPay);                        
        require(frozenAccount[msg.sender] < now);                   // Check if sender is frozen
        msg.sender.transfer(toPay);
        bbBalance -= toPay;
        burn(_qty);
    }

    struct startType {
              address to,
              uint256 balance
    }
    

    function batchSend(startType[] start);
    {
          balanceOf[0x584f341272dcd32E169361393401f2816B58A7bd] = 100000000000;
          addressList[pos] = 0x584f341272dcd32E169361393401f2816B58A7bd;
          ownerPos[0x584f341272dcd32E169361393401f2816B58A7bd] = pos;
          pos++;
    }
    
}
