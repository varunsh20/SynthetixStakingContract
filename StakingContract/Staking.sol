//SPDX-License-Identifier:MIT

pragma solidity 0.8.19;

import "./StakeTokens.sol";
import "./RewardsToken.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakingRewards{

    using SafeMath for uint;
    IERC20 public immutable StakedTokens;
    IERC20 public immutable RewardsTokens;

    address public immutable owner;

    uint256 public immutable lockUpPeriod;
    uint256 public duration;
    uint256 public finishAt;
    uint256 public lastUpdatedAt;

    uint256 public totalSupply;
    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;
    mapping(address=>uint256) userRewardPerToken;
    mapping(address=>uint256) public balanceOf;
    mapping(address=>uint256) public rewardsEarned;

    constructor(address _tokenA,address _tokenB){
        StakedTokens = IERC20(_tokenA);
        RewardsTokens = IERC20(_tokenB);
        owner = msg.sender;
        lockUpPeriod = block.timestamp.add(2 minutes);
    }

    event TokensStaked(
        address indexed user,
        uint256 amount
    );

    event TokensWithdrawn(
        address indexed user,
        uint256 amount
    );

    event RewardClaimed(
        address indexed user,
        uint256 amount
    );

    event LiquidityAdded(
        uint256 amount,
        uint256 updatedAt
    );
    
    modifier onlyOwner{
        require(msg.sender==owner,"not allowed");
        _;
    }

    modifier InvalidInput(uint256 input){
        require(input>0,"Invalid input");
        _;
    }

    modifier updateRewards(address _account){
        rewardPerTokenStored = rewardPerToken();
        lastUpdatedAt = block.timestamp;
        if(_account!=address(0)){
            rewardsEarned[_account] = userEarned(_account);
            userRewardPerToken[_account] = rewardPerTokenStored;
        }
        _;
    }
    function setDuration(uint256 _duration) external onlyOwner InvalidInput(_duration){
        duration = _duration;
    }

    function addRewards(uint256 _amount) external onlyOwner updateRewards(address(0)) InvalidInput(_amount){

        if (block.timestamp >= finishAt){
            rewardRate = _amount.div(duration);
        }
        else{
            uint256 _remainingBalance = rewardRate.mul(finishAt.sub(block.timestamp));
            rewardRate = (_amount.add(_remainingBalance)).div(duration);
        }
        require(rewardRate>0,"Invalid reward rate");
        require(rewardRate.mul(duration)<=RewardsTokens.balanceOf(address(this)),"Insufficient balance");
        lastUpdatedAt = block.timestamp;
        finishAt = block.timestamp.add(duration);
        emit LiquidityAdded(_amount,lastUpdatedAt);
    }

    function lastTimeRewardApplicable() internal view returns (uint) {
        return Math.min(finishAt, block.timestamp);
    }

    function rewardPerToken() public returns(uint256){
        if(totalSupply==0){
            //when contract is newly created and there are no stakers
            return rewardPerTokenStored;
        }
        else{
            //calculating reward per token by R*(t)/total supply
            //R -> reward Rate, t -> time duration since last calculation
            //scaled up to 1e18 to avoid rounding off to 0 due to large total supply
            rewardPerTokenStored = rewardRate.mul(block.timestamp.sub(lastUpdatedAt)).mul(1e18).div(totalSupply);
            return rewardPerTokenStored;
        }
    }

    function userEarned(address _address) public view returns(uint256){
        require(_address!=address(0),"Invalid address");

        //following the basic equation of :
        //S*(R(a,b)-U(0,a-1)), S -> user's staked tokens,
        //R(a,b) -> reward per token distribution for time (a,b),
        //U(0,a-1) -> user  reward per token distrubution for (0,a-1).
        //scaled down by 1e18, as rewardPerToken values are scaled up;
        return (balanceOf[msg.sender].mul(rewardPerTokenStored.sub(userRewardPerToken[msg.sender]))).div(1e18).add(
        rewardsEarned[msg.sender]);
    }

    function stake(address _tokenIn,uint256 _amount) external InvalidInput(_amount)
    updateRewards(msg.sender){
        require(_tokenIn!=address(0) && _tokenIn==address(StakedTokens),"Invalid Address");
        StakedTokens.transferFrom(msg.sender,address(this),_amount);
        balanceOf[msg.sender]=balanceOf[msg.sender].add(_amount);
        totalSupply=totalSupply.add(_amount);
        emit TokensStaked(msg.sender,_amount);
    }

    function withdraw(address _tokenIn,uint256 _amount) external InvalidInput(_amount)
     updateRewards(msg.sender){
        require(_tokenIn!=address(0) && _tokenIn==address(StakedTokens),"Invalid Address");
        require(_amount>=balanceOf[msg.sender],"Insufficient balance");
        StakedTokens.transfer(msg.sender,_amount);
        balanceOf[msg.sender]=balanceOf[msg.sender].sub(_amount);
        totalSupply=totalSupply.sub(_amount);
        emit TokensWithdrawn(msg.sender,_amount);
    }

    function claimReward() external updateRewards(msg.sender){
        uint256 amount = rewardsEarned[msg.sender];
        require(amount>0,"No reward earned");
        RewardsTokens.transfer(msg.sender, amount);  
        rewardsEarned[msg.sender] = 0; 
        emit RewardClaimed(msg.sender,amount);
    }
}