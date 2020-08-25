//SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;
import '../libraries/SafeMath.sol';
import '../interface/ERC3000-Token-Interface.sol';

contract ProveOfStake {
    using SafeMath for uint;

    address public interestsToken;
    uint public nounce;
    function incNounce() public 
    {
        nounce ++;
    }
    
    mapping(address => uint) public stakePool;
    
    constructor(address _interestsToken) public 
    {
        interestsToken = _interestsToken;
    }

    function stake() payable public returns(uint amount)
    {
        require(msg.value > 0, "INVALID AMOUNT.");

        stakePool[msg.sender] = stakePool[msg.sender].add(msg.value);
        IERC3000Token(interestsToken).increaseProductivity(msg.sender, msg.value);
        amount = msg.value;
    }

    function unstake(uint _amountOut) public returns(uint amount)
    {
        require(stakePool[msg.sender] >= _amountOut, "INSUFFICIENT AMOUNT.");
        require(_amountOut > 0, "INVALID AMOUNT.");

        IERC3000Token(interestsToken).decreaseProductivity(msg.sender, _amountOut);
        stakePool[msg.sender] = stakePool[msg.sender].sub(_amountOut);
        msg.sender.transfer(_amountOut);
        amount = _amountOut;
    }
}
