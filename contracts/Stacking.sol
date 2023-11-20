//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "./Token.sol";

contract NFTVERSE_STAKING{

    uint256 public totalStacked = 0; 

    //  Stake Duration:
    //     1 for Quaterly
    //     2 for semiYearly
    //     3 for Yearly
    uint256 private quaterlyReward = 4;
    uint256 private semiYearlyReward = 7;
    uint256 private yearlyReward = 10;
   
    Token public token;

    struct Stacking{
        uint256 stakeTime;
        uint256 stakeDuration; 
        uint256 tokenAmount;
        uint256 lastRewardTime;
        uint8 stakeType;
    }

    mapping(address => mapping(uint256 => Stacking)) private stakingDetails;
    mapping(address => mapping(uint256 => uint256)) private rewardClaimed;
    mapping(address => uint256) private totalWalletStacked;
    mapping(address => uint256) private currentWalletStacked;

    modifier onlyOwner{
        require(msg.sender == token.owner(), "invalid owner address");
        _;
    }

    modifier stakeType(uint8 _stakeType){
        require(_stakeType >= 1 && _stakeType <= 3, "invalid stacking type");
        _;
    }

    event StackingEvent(string message, address indexed buyer, uint256 amount, uint8 stakeType);

    constructor(address _token){
        token = Token(_token);
        require(msg.sender == token.owner(), "Deployer wallet must be Token Owner");
    }

    receive() external payable{}

    function setRewardPercent(uint8 _stakeType, uint8 rewardPercent) external onlyOwner stakeType(_stakeType){
        if(_stakeType == 1){
            quaterlyReward = rewardPercent;
        }
        else if(_stakeType == 2){
            semiYearlyReward = rewardPercent;
        }
        else{
            yearlyReward = rewardPercent;
        }
    }

    function getRewardPercent(uint8 _stakeType) public view stakeType(_stakeType) returns(uint256){
        if(_stakeType == 1){
            return quaterlyReward;
        }
        else if(_stakeType == 2){
            return semiYearlyReward;
        }
        else{
            return yearlyReward;
        }
    }

    function stakeTokens(uint256 tokenAmount, uint8 _stakeType) external stakeType(_stakeType){
        require(token.balanceOf(msg.sender) >= tokenAmount, "not enough Tokens for Stacking");
        uint256 _walletStacked = getTotalWalletStackedCount(msg.sender);
        _walletStacked += 1;
        uint256 currentTime = block.timestamp;
        if(_stakeType == 1){
            stakingDetails[msg.sender][_walletStacked] = Stacking(currentTime, currentTime + 13 weeks, tokenAmount, currentTime, _stakeType);
        }
        else if(_stakeType == 2){
            stakingDetails[msg.sender][_walletStacked] = Stacking(currentTime, currentTime + 26 weeks, tokenAmount, currentTime, _stakeType);
        }
        else{
            stakingDetails[msg.sender][_walletStacked] = Stacking(currentTime, currentTime + 365 days, tokenAmount, currentTime, _stakeType);
        }
        totalWalletStacked[msg.sender] = _walletStacked;
        currentWalletStacked[msg.sender] += 1;
        token.transferFrom(msg.sender,address(this), tokenAmount);
        totalStacked += 1;
        emit StackingEvent("Token Stacked", msg.sender, tokenAmount, _stakeType);
    }

    function unStakeTokens(uint256 index) external {
        Stacking memory _stakingDetais = getWalletSkacking(msg.sender, index);
        require(_stakingDetais.tokenAmount > 0, "tokens is not Skacked");
        require(block.timestamp >= _stakingDetais.stakeDuration,  "stacking time is not complete");
        
        uint256 remainingReward = calculateReward(msg.sender, index);
        if(remainingReward > 0){
             token.transferFrom(token.owner(), msg.sender, remainingReward);
            _unStakeTokens(index, _stakingDetais.tokenAmount);
            emit StackingEvent("Token UnStacked and Claimed Reward", msg.sender, _stakingDetais.tokenAmount + remainingReward, _stakingDetais.stakeType);
        }
        else{
            _unStakeTokens(index, _stakingDetais.tokenAmount);
            emit StackingEvent("Token UnStacked", msg.sender, _stakingDetais.tokenAmount, _stakingDetais.stakeType);
        }
    }

    function _unStakeTokens(uint256 index, uint256 tokenAmount) internal {
        token.transfer(msg.sender, tokenAmount);
        delete stakingDetails[msg.sender][index];
        delete rewardClaimed[msg.sender][index];
        currentWalletStacked[msg.sender] -= 1;
        totalStacked -= 1;
    }

    function claimReward(uint256 index) public{
        uint256 getReward = calculateReward(msg.sender, index);
        Stacking memory _stakingDetais = getWalletSkacking(msg.sender, index);
        
        require(_stakingDetais.tokenAmount > 0, "tokens is not stacked");
        require(getReward > 0, "not enough reward to claim");
        
        token.transferFrom(token.owner(), msg.sender, getReward);
        stakingDetails[msg.sender][index].lastRewardTime = block.timestamp;
        rewardClaimed[msg.sender][index] += getReward;
        
        emit StackingEvent("Token Reward Claimed", msg.sender, getReward, _stakingDetais.stakeType);
    }

    function getWalletSkacking(address _address, uint256 index) public view returns(Stacking memory){
        return stakingDetails[_address][index];
    }

    function getAllWalletSkacking(address _address) public view returns(Stacking[] memory){
        uint256 _walletStacked = getTotalWalletStackedCount(msg.sender);
        uint256 _currentwalletStacked = getCurrentWalletStackedCount(msg.sender);
        Stacking[] memory stacking = new Stacking[](_currentwalletStacked);
        for(uint i=0; i<_walletStacked; i++){
            if(getWalletSkacking(_address, i+1).tokenAmount > 0){
                stacking[i] = getWalletSkacking(_address, i+1);
            }
        }   
        return stacking;
    }

    function getCurrentWalletStackedCount(address _address) public view returns(uint256){
        return currentWalletStacked[_address];
    }

    function getTotalWalletStackedCount(address _address) private view returns(uint256){
        return totalWalletStacked[_address];
    }

    function getRewardClaimed(address _address, uint256 index) public view returns(uint256){
        return rewardClaimed[_address][index];
    }

    function calculateReward(address _address, uint256 index) public view returns(uint256){
        Stacking memory _stakingDetais = getWalletSkacking(_address, index);
        uint256 duration = _stakingDetais.stakeDuration;
        uint256 lastRewardTime = _stakingDetais.lastRewardTime;
       
        uint256 currentTime = block.timestamp;
        if(currentTime >= duration){
            currentTime = duration;    
        }    
        
        uint256 totalDaysInSeconds = currentTime - lastRewardTime;
        uint256 secondsInOneDay = 86400;
        uint256 stakeDays =  totalDaysInSeconds / secondsInOneDay;

        if(_stakingDetais.stakeType == 1){
            uint256 totalReward = (_stakingDetais.tokenAmount * quaterlyReward) / 100;
            uint256 reward = (totalReward * stakeDays) / 92;
            return reward; 
        }
        else if(_stakingDetais.stakeType == 2){
            uint256 totalReward = (_stakingDetais.tokenAmount * semiYearlyReward) / 100;
            uint256 reward = (totalReward * stakeDays) / 183;
            return reward; 
        }
        else{
            uint256 totalReward = (_stakingDetais.tokenAmount * yearlyReward) / 100;
            uint256 reward = (totalReward * stakeDays) / 365;
            return reward; 
        }
    }

}