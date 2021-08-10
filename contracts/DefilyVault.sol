// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./helpers/ERC20.sol";

import "./libraries/Address.sol";

import "./libraries/SafeERC20.sol";

import "./libraries/EnumerableSet.sol";

import "./helpers/Ownable.sol";

import "./helpers/ReentrancyGuard.sol";

// For interacting with our own strategy
interface IStrategy {
    // Total want tokens managed by stratfegy
    function wantLockedTotal() external view returns (uint256);

    // Sum of all shares of users to wantLockedTotal
    function sharesTotal() external view returns (uint256);

    // All fees 
    function buyBackRate() external view returns (uint256);

    function controllerFee() external view returns (uint256);

    function entranceFeeFactor() external view returns (uint256);
    function entranceFeeFactorMax() external view returns (uint256);

    function withdrawFeeFactor() external view returns (uint256);
    function withdrawFeeFactorMax() external view returns (uint256);

    // Main want token compounding function
    function earn() external;

    // Transfer want tokens vault -> strategy
    function deposit(address _userAddress, uint256 _wantAmt)
        external
        returns (uint256);

    // Transfer want tokens strategy -> vault
    function withdraw(address _userAddress, uint256 _wantAmt)
        external
        returns (uint256);

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) external;
}

contract DefilyVault is Ownable, ReentrancyGuard, ERC20("Dungeons Token","DDT") {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 shares; // How many LP tokens the user has provided.
    }

    struct StrategyInfo {
        IERC20 want; // Address of the want token.
        // uint256 allocPoint; // How many allocation points assigned to this pool. AUTO to distribute per block.
        // uint256 lastRewardBlock; // Last block number that AUTO distribution occurs.
        // uint256 accAUTOPerShare; // Accumulated AUTO per share, times 1e12. See below.
        address strat; // Strategy address that will auto compound want tokens
    }

    StrategyInfo public strategyInfo; // Info of each pool.
    mapping(address => UserInfo) public userInfo; // Info of each user that stakes LP tokens.
    //uint256 public totalAllocPoint = 1; // Total allocation points. Must be the sum of all allocation points in all pools.

    // event Add(
    //     uint256 _allocPoint,
    //     IERC20 _want,
    //     bool _withUpdate,
    //     address _strat
    // );
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    // function poolLength() external view returns (uint256) {
    //     return poolInfo.length;
    // }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do. (Only if want tokens are stored here.)

    function defineStrategy(
        // uint256 _allocPoint,
        IERC20 _want,
        //bool _withUpdate,
        address _strat
    ) public onlyOwner {
        // totalAllocPoint = totalAllocPoint.add(_allocPoint);
        // poolInfo.push(
        //     PoolInfo({
        //         want: _want,
        //         allocPoint: _allocPoint,
        //         lastRewardBlock: 0,
        //         accAUTOPerShare: 0,
        //         strat: _strat
        //     })
        // );

        //emit Add(_allocPoint, _want, _withUpdate, _strat);

        strategyInfo = StrategyInfo({
            want: _want,
            strat: _strat
        });
    }

    // View function to see staked Want tokens on frontend.
    function stakedWantTokens(address _user)
        external
        view
        returns (uint256)
    {
        //PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_user];

        uint256 sharesTotal = IStrategy(strategyInfo.strat).sharesTotal();
        uint256 wantLockedTotal =
            IStrategy(strategyInfo.strat).wantLockedTotal();
        if (sharesTotal == 0) {
            return 0;
        }
        return user.shares.mul(wantLockedTotal).div(sharesTotal);
    }

    // View functions for Fees and Total Staked LP
    function totalStakedWantTokens() external view returns(uint256){
        return IStrategy(strategyInfo.strat).wantLockedTotal();
    }

    function totalShares() external view returns(uint256){
        return IStrategy(strategyInfo.strat).sharesTotal();
    }

    function getBuyBackRate() external view returns(uint256){
        return IStrategy(strategyInfo.strat).buyBackRate();
    }

    function getEntranceFee() external view returns(uint256){
        uint256 entranceFeeFactor = IStrategy(strategyInfo.strat).entranceFeeFactor();
        uint256 entranceFeeFactorMax = IStrategy(strategyInfo.strat).entranceFeeFactorMax();
        return entranceFeeFactorMax.sub(entranceFeeFactor);
    }

    function getWithdrawFee() external view returns(uint256){
        uint256 withdrawFeeFactor = IStrategy(strategyInfo.strat).withdrawFeeFactor();
        uint256 withdrawFeeFactorMax = IStrategy(strategyInfo.strat).withdrawFeeFactorMax();
        return withdrawFeeFactorMax.sub(withdrawFeeFactor);
    }

    function getPerformanceFee() external view returns(uint256){
        return IStrategy(strategyInfo.strat).controllerFee();
    }

    // Want tokens moved from user -> Defily vault -> Strat (compounding)
    function deposit(uint256 _wantAmt) public nonReentrant {
        //PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[msg.sender];

        if (_wantAmt > 0) {
            strategyInfo.want.safeTransferFrom(
                address(msg.sender),
                address(this),
                _wantAmt
            );

            strategyInfo.want.safeIncreaseAllowance(strategyInfo.strat, _wantAmt);
            uint256 sharesAdded =
                IStrategy(strategyInfo.strat).deposit(msg.sender, _wantAmt);

            user.shares = user.shares.add(sharesAdded);
            _mint(address(msg.sender),sharesAdded);
        }

        emit Deposit(msg.sender, _wantAmt);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _wantAmt) public nonReentrant {
        //PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[msg.sender];

        uint256 wantLockedTotal =
            IStrategy(strategyInfo.strat).wantLockedTotal();
        uint256 sharesTotal = IStrategy(strategyInfo.strat).sharesTotal();

        require(user.shares > 0, "user.shares is 0");
        require(sharesTotal > 0, "sharesTotal is 0");

        // Withdraw want tokens
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);
        if (_wantAmt > amount) {
            _wantAmt = amount;
        }
        if (_wantAmt > 0) {
            uint256 sharesRemoved =
                IStrategy(strategyInfo.strat).withdraw(msg.sender, _wantAmt);

            if (sharesRemoved > user.shares) {
                user.shares = 0;
            } else {
                user.shares = user.shares.sub(sharesRemoved);
            }

            uint256 wantBal = IERC20(strategyInfo.want).balanceOf(address(this));
            if (wantBal < _wantAmt) {
                _wantAmt = wantBal;
            }
            strategyInfo.want.safeTransfer(address(msg.sender), _wantAmt);
            _burn(address(msg.sender),sharesRemoved);
        }
        emit Withdraw(msg.sender, _wantAmt);
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount)
        public
        onlyOwner
    {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function executeStrategy() public {
        IStrategy(strategyInfo.strat).earn();
    }

    //*Override transfer functions, allowing receipts to be transferable */

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        UserInfo storage _sender = userInfo[_msgSender()];
        UserInfo storage _receiver = userInfo[recipient];

        _transfer(_msgSender(), recipient, amount);

        _sender.shares = _sender.shares.sub(amount);
        _receiver.shares = _receiver.shares.add(amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        UserInfo storage _sender = userInfo[sender];
        UserInfo storage _receiver = userInfo[recipient];

        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender,_msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));

        _sender.shares = _sender.shares.sub(amount);
        _receiver.shares = _receiver.shares.add(amount);
        return true;
    }
}
