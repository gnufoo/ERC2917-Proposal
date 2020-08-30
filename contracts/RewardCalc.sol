//SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import './interface/RewardCalc-Token-Interface.sol';
import './libraries/Upgradable.sol';
import './libraries/SafeMath.sol';

/*
    The Objective of RewardCalc Demo is to implement a decentralized staking mechanism, which calculates users' share
    by accumulating productiviy * time. And calculates users revenue from anytime t0 to t1 by the formula below:

        user_accumulated_productivity(time1) - user_accumulated_productivity(time0)
       _____________________________________________________________________________  * (gross_product(t1) - gross_product(t0))
       total_accumulated_productivity(time1) - total_accumulated_productivity(time0)

*/
contract RewardCalcImpl is IRewardCalc, UpgradableProduct, UpgradableGovernance {
    using SafeMath for uint;

    uint public mintCumulation;

    struct Production {
        uint amount;            // how many tokens could be produced on block basis
        uint total;             // total produced tokens
        uint block;             // last updated block number
    }

    Production internal grossProduct = Production(0, 0, 0);

    struct Productivity {
        uint product;           // user's productivity
        uint total;             // total productivity
        uint block;             // record's block number
        uint accProduct;              // accumulated products
        uint global;            // global accumulated products
        uint gross;             // global gross products
    }

    Productivity public global;
    mapping(address => Productivity) public users;

    uint private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, 'Locked');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // implementation of ERC20 interfaces.
    string override public name;
    string override public symbol;
    uint8 override public decimals = 18;
    uint override public totalSupply;
    mapping(address => uint) override public balanceOf;
    mapping(address => mapping(address => uint)) override public allowance;

    function _transfer(address from, address to, uint value) private {
        require(balanceOf[from] >= value, 'ERC20Token: INSUFFICIENT_BALANCE');
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        if (to == address(0)) { // burn
            totalSupply = totalSupply.sub(value);
        }
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external override returns (bool) {
        require(allowance[from][msg.sender] >= value, 'ERC20Token: INSUFFICIENT_ALLOWANCE');
        allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        _transfer(from, to, value);
        return true;
    }

    // end of implementation of ERC20

    // creation of the interests token.
    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint8 _interestsRate) UpgradableProduct() UpgradableGovernance() public {
        name        = _name;
        symbol      = _symbol;
        decimals    = _decimals;
        grossProduct.amount = _interestsRate * (uint(10) ** _decimals);
        grossProduct.block  = block.number;
    }

    // When calling _computeBlockProduct() it calculates the area of productivity * time since last time and accumulate it.
    function _computeBlockProduct() private view returns (uint) {
        uint elapsed = block.number.sub(grossProduct.block);
        return grossProduct.amount.mul(elapsed);
    }

    // compute productivity returns total productivity of a user.
    function _computeProductivity(Productivity memory user) private view returns (uint) {
        uint blocks = block.number.sub(user.block);
        return user.total.mul(blocks);
    }

    // update users' productivity by value with boolean value indicating increase  or decrease.
    function _updateProductivity(Productivity storage user, uint value, bool increase) private {
        user.product      = user.product.add(_computeProductivity(user));
        global.product    = global.product.add(_computeProductivity(global));

        require(global.product <= uint(-1), 'GLOBAL_PRODUCT_OVERFLOW');

        user.block      = block.number;
        global.block    = block.number;
        if(increase) {
            user.total   = user.total.add(value);
            global.total = global.total.add(value);
        }
        else {
            user.total   = user.total.sub(value);
            global.total = global.total.sub(value);
        }
    }

    // External function call
    // This function adjust how many token will be produced by each block, eg:
    // changeAmountPerBlock(100)
    // will set the produce rate to 100/block.
    function changeInterestRatePerBlock(uint value) external override requireGovernor returns (bool) {
        uint old = grossProduct.amount;
        require(value != old, 'AMOUNT_PER_BLOCK_NO_CHANGE');

        uint product                = _computeBlockProduct();
        grossProduct.total          = grossProduct.total.add(product);
        grossProduct.block          = block.number;
        grossProduct.amount         = value;
        require(grossProduct.total <= uint(-1), 'BLOCK_PRODUCT_OVERFLOW');

        emit InterestRatePerBlockChanged(old, value);
        return true;
    }

    // External function call
    // This function increase user's productivity and updates the global productivity.
    // the users' actual share percentage will calculated by:
    // Formula:     user_productivity / global_productivity
    function increaseProductivity(address user, uint value) external override requireImpl returns (bool) {
        require(value > 0, 'PRODUCTIVITY_VALUE_MUST_BE_GREATER_THAN_ZERO');
        Productivity storage product        = users[user];

        if (product.block == 0) {
            product.gross = grossProduct.total.add(_computeBlockProduct());
            product.global = global.product.add(_computeProductivity(global));
        }
        
        _updateProductivity(product, value, true);
        emit ProductivityIncreased(user, value);
        return true;
    }

    // External function call 
    // This function will decreases user's productivity by value, and updates the global productivity
    // it will record which block this is happenning and accumulates the area of (productivity * time)
    function decreaseProductivity(address user, uint value) external override requireImpl returns (bool) {
        Productivity storage product = users[user];

        require(value > 0 && product.total >= value, 'INSUFFICIENT_PRODUCTIVITY');
        
        _updateProductivity(product, value, false);
        emit ProductivityDecreased(user, value);
        return true;
    }


    // External function call
    // When user calls this function, it will calculate how many token will mint to user from his productivity * time
    // Also it calculates global token supply from last time the user mint to this time.
    function mint() external override lock returns (uint) {
        (uint gp, uint userProduct, uint globalProduct, uint amount) = _computeUserProduct();
        require(amount > 0, 'NO_PRODUCTIVITY');
        Productivity storage product = users[msg.sender];
        product.gross   = gp;
        product.accProduct    = userProduct;
        product.global  = globalProduct;

        balanceOf[msg.sender]   = balanceOf[msg.sender].add(amount);
        totalSupply             = totalSupply.add(amount);
        mintCumulation          = mintCumulation.add(amount);

        emit Transfer(address(0), msg.sender, amount);
        return amount;
    }

    // Returns how many token he will be able to mint.
    function _computeUserProduct() private view returns (uint gp, uint userProduct, uint globalProduct, uint amount) {
        Productivity memory product    = users[msg.sender];

        gp              = grossProduct.total.add(_computeBlockProduct());
        userProduct     = product.product.add(_computeProductivity(product));
        globalProduct   = global.product.add(_computeProductivity(global));

        uint deltaBlockProduct  = gp.sub(product.gross);
        uint numerator          = userProduct.sub(product.accProduct);
        uint denominator        = globalProduct.sub(product.global);

        if (denominator > 0) {
            amount = deltaBlockProduct.mul(numerator).div(denominator);
        }
    }

    // Returns how many productivity a user has and global has.
    function getProductivity(address user) external override view returns (uint, uint) {
        return (users[user].total, global.total);
    }

    // Returns the current gorss product rate.
    function interestsPerBlock() external override view returns (uint) {
        return grossProduct.amount;
    }

    // Returns how much a user could earn.
    function take() external override view returns (uint) {
        (, , , uint amount) = _computeUserProduct();
        return amount;
    }

    // Returns how much a user could earn plus the giving block number.
    function takeWithBlock() external override view returns (uint, uint) {
        (, , , uint amount) = _computeUserProduct();
        return (amount, block.number);
    }
}
