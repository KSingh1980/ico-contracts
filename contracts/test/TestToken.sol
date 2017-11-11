pragma solidity 0.4.15;

import '../Zeppelin/StandardToken.sol';


contract TestToken is StandardToken {

    ////////////////////////
    // Constructor
    ////////////////////////

    function TestToken(uint256 initialBalance)
        StandardToken()
        public
    {
        _balances[msg.sender] = initialBalance;
    }
}
