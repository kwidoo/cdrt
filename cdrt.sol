pragma solidity ^0.4.16;

contract owned {
    address public owner;

    function owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public; }

contract TokenERC20 {
    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 8;
    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;

    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function TokenERC20(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        totalSupply = initialSupply * 10 ** uint256(decimals);  									// Update total supply with the decimal amount
        balanceOf[msg.sender] = totalSupply;                										// Give the creator all initial tokens
        name = tokenName;                                   										// Set the name for display purposes
        symbol = tokenSymbol;                               										// Set the symbol for display purposes
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != 0x0);
        // Check if the sender has enough
        require(balanceOf[_from] >= _value);
        // Check for overflows
        require(balanceOf[_to] + _value > balanceOf[_to]);
        // Save this for an assertion in the future
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        // Subtract from the sender
        balanceOf[_from] -= _value;
        // Add the same to the recipient
        balanceOf[_to] += _value;
        Transfer(_from, _to, _value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` in behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);     // Check allowance
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public
        returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    /**
     * Set allowance for other address and notify
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
        public
        returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);   													// Check if the sender has enough
        balanceOf[msg.sender] -= _value;            													// Subtract from the sender
        totalSupply -= _value;                     														// Updates totalSupply
        Burn(msg.sender, _value);
        return true;
    }

}

/******************************************/
/*       ADVANCED TOKEN STARTS HERE       */
/******************************************/

contract CDRTToken is owned, TokenERC20 {

    mapping (address => uint256) public frozenAccount;
    mapping (address => uint256) public snapShot;
    
    uint256 public nextPE;

    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, uint256 frozen);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function CDRTToken(
        uint256 initialSupply, 
        string tokenName,
        string tokenSymbol
    ) TokenERC20(initialSupply, tokenName, tokenSymbol) public {
        /* insert starting balances here */
        balanceOf[0x14723a09acff6d2a60dcdf7aa4aff308fddc160c] = 1000;
        /* first profit equivalent payment date */
        nextPE = 1539205199;
    }


    /* Internal transfer, only can be called by this contract */
    function _transfer(address _from, address _to, uint _value) internal {
        _unFreezeAccount(_from);
        require (_to != 0x0);                              										 		// Prevent transfer to 0x0 address. Use burn() instead
        require (balanceOf[_from] >= _value);               											// Check if the sender has enough
        require (balanceOf[_to] + _value > balanceOf[_to]); 											// Check for overflows
        require(frozenAccount[_from] < now);                											// Check if sender is frozen as Team member till 01.11.2018 
        balanceOf[_from] -= _value;                         											// Subtract from the sender
        balanceOf[_to] += _value;                           											// Add the same to the recipient
        Transfer(_from, _to, _value);
    }


    /// @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
    /// @param target Address to be frozen
    function freezeAccount(address target) onlyOwner public {
        frozenAccount[target] = 1541030399;     // 31.10.2018 23:59
        FrozenFunds(target, 1541030399);
    }

    /// @notice unfreeze Team account if 01.11.2018
    /// @param target Address to unfreeze
    function _unFreezeAccount(address target) internal {
        require(now > frozenAccount[target]);     														// Check if sender is frozen
        frozenAccount[target] = 0;              
        FrozenFunds(target, 0);
    }  

    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) onlyOwner public returns (bool success) {
        require(balanceOf[_from] >= _value);                											// Check if the targeted balance is enough
        balanceOf[_from] -= _value;                         											// Subtract from the targeted balance
        totalSupply -= _value;                              											// Update totalSupply
        Burn(_from, _value);
        return true;
    }
    /**
	 * Set next date to claim Profit Equivalent
	 *
	 * @param _value unix timestamp of next 10 October
	 */
    function setNextPE(uint256 _value) onlyOwner public {
		nextPE = _value;    
    }
    /**
     * Set PE for 0.00000001 CDRT 
     * 
     * @param _value in Ethereum
     * 
     */
    function issuePE(uint256 _value) onlyOwner public {
        
        
    }
}


