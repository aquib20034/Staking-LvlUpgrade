// contracts/CHIPS.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "erc721a-upgradeable/contracts/IERC721AUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract Staking is Ownable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20Upgradeable;

    uint256 public totalStaked;
    
    // Interfaces for ERC20 and ERC721
    IERC20Upgradeable public immutable rewardsToken;
    IERC721AUpgradeable public immutable nftCollection;
    
    enum TimeFrame{ ONE_DAY,TWO_WEEKS, FOUR_WEEKS, EIGHT_WEEKS, TWELVE_WEEKS }

    // struct to store a stake's token, owner, and earning values
    struct Stake {
        uint24 tokenId;
        uint48 timeOfLastUpdate;
        address owner;
        // timeFrame 
        TimeFrame timeFrame;
    }

   

    // Rewards per hour per token deposited in wei.
    // Rewards are cumulated/ collected once every hour.
    uint256 private rewardsPerTm = 4 * 10 ** 18;  // 4 * 10**decimals()

    // 3600 = 1 hour = 60 * 60 
    // 86400 = 1 day = 60 * 60 * 24
    uint256 private rewardsTm = 60;  // 1 minutes

 

    // maps tokenId to stake
    mapping(uint256 => Stake) public vault;

    event NFTStaked(address owner, uint256 tokenId, uint256 value);
    event NFTUnstaked(address owner, uint256 tokenId, uint256 value);
    event Claimed(address owner, uint256 amount);

    // Constructor function
    constructor(IERC721AUpgradeable _nftCollection, IERC20Upgradeable _rewardsToken) {
        nftCollection = _nftCollection;
        rewardsToken = _rewardsToken;
    }

    //to check balance of receiveAbleTokens 
    function checkReceivedTokensBalance() external view returns(uint balance){
        return rewardsToken.balanceOf(address(this));
    }

    function stake(uint256[] calldata tokenIds, TimeFrame _timeFrame) external {
        uint256 tokenId;
        totalStaked += tokenIds.length;
        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            
            // checking ownership of NFT
            require(
                nftCollection.ownerOf(tokenId) == msg.sender,
                "Can't stake tokens you don't own!"
            );


            // checking is token staked
            require(
                vault[tokenId].tokenId == 0, 
                'already staked'
            );

            nftCollection.transferFrom(msg.sender, address(this), tokenId);
            emit NFTStaked(msg.sender, tokenId, block.timestamp);

            vault[tokenId] = Stake({
                owner: msg.sender,
                tokenId: uint24(tokenId),
                timeOfLastUpdate: uint48(block.timestamp),
                timeFrame: _timeFrame
            });
        }
    }
    
 

    function _claim(address account, uint256[] calldata tokenIds, bool _unstake) internal {
        uint256 tokenId;
        uint256 earned = 0;

        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            Stake memory staked = vault[tokenId];
            
            require(
                staked.owner == account,
                "not an owner"
            );

            uint256 cal_tm       = (block.timestamp - staked.timeOfLastUpdate);
            uint256 cus_tm       = getTimeFrame(staked.timeFrame);        
            require(
                cal_tm >= cus_tm,
                "Please wait, lock period is not completed"
            );

            earned +=  calculateLockRewards(staked.timeFrame, cal_tm);
            
            vault[tokenId] = Stake({
                owner: account,
                tokenId: uint24(tokenId),
                timeOfLastUpdate: uint48(block.timestamp),
                timeFrame: staked.timeFrame
            });

        }
        if (earned > 0) {
            // sending reward token 
            require(
                rewardsToken.balanceOf(address(this)) >= earned,
                "Contract does not have Token to transfer reward"
            );

            rewardsToken.transfer(msg.sender, earned);
            
        }
        if (_unstake) {
            _unstakeMany(account, tokenIds);
        }
        emit Claimed(account, earned);
    }

    function unstake(uint256[] calldata tokenIds) external {
        _claim(msg.sender, tokenIds, true);
    }

    function _unstakeMany(address account, uint256[] calldata tokenIds) internal {
        uint256 tokenId;
        totalStaked -= tokenIds.length;
        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            Stake memory staked = vault[tokenId];
            require(staked.owner == msg.sender, "not an owner");

            delete vault[tokenId];
            emit NFTUnstaked(account, tokenId, block.timestamp);
            nftCollection.transferFrom(address(this), account, tokenId);
        }
    }

    // should never be used inside of transaction because of gas fee
    function balanceOf(address account) public view returns (uint256) {
        uint256 balance = 0;
        uint256 supply  = nftCollection.totalSupply();
        for(uint i = 1; i <= supply; i++) {
            if (vault[i].owner == account) {
                balance += 1;
            }
        }
        return balance;
    }

     // should never be used inside of transaction because of gas fee
    function tokensOfOwner(address account) public view returns (uint256[] memory ownerTokens) {

        uint256 supply          = nftCollection.totalSupply();
        uint256[] memory tmp    = new uint256[](supply);

        uint256 index       = 0;
        for(uint tokenId    = 1; tokenId <= supply; tokenId++) {
            if (vault[tokenId].owner == account) {
                tmp[index] = vault[tokenId].tokenId;
                index +=1;
            }
        }

        uint256[] memory tokens = new uint256[](index);
        for(uint i = 0; i < index; i++) {
            tokens[i] = tmp[i];
        }

        return tokens;
    }
    

    function getTimeFrame(TimeFrame _timeFrame) internal pure returns (uint256) {

        uint256 tmp;
        if(_timeFrame == TimeFrame.ONE_DAY){
            tmp = 1 minutes;    // 1 days
        }else if(_timeFrame == TimeFrame.TWO_WEEKS){
            tmp = 2 minutes;    // 2 weeks
        }else if(_timeFrame == TimeFrame.FOUR_WEEKS){
            tmp = 4 minutes;    // 4 weeks
        }else if(_timeFrame == TimeFrame.EIGHT_WEEKS){
            tmp = 8 minutes;    // 8 weeks
        }else if(_timeFrame == TimeFrame.TWELVE_WEEKS){
            tmp = 12 minutes;   // 12 weeks
        }

        return tmp;

    }

  
    function calculateLockRewards(TimeFrame _timeFrame, uint256 tm) internal pure returns (uint256)
    {
        // uint256 tm      = (block.timestamp - lockers[_locker].timeOfLastUpdate);
        uint256 reward  = 0;

        if((_timeFrame == TimeFrame.ONE_DAY) &&  (tm >= (1 minutes )) ){
            
            reward  = 4000000000000000000 * 1;   // 1-2 weeks  // 4

        }else if((_timeFrame == TimeFrame.TWO_WEEKS) &&  (tm >= (2 minutes )) ){
            reward  = 4000000000000000000 * 14;   // 1-2 weeks  // 4

        }else if((_timeFrame == TimeFrame.FOUR_WEEKS) && (tm >= (4 minutes )) ){
            reward  = 4000000000000000000 * 14;   // 1-2 weeks  // 4
            reward += 8000000000000000000 * 14;   // 2-4 weeks  // 8

        }else if((_timeFrame == TimeFrame.EIGHT_WEEKS) && (tm >= (8 minutes )) ){
            reward  = 4000000000000000000 * 14;   // 1-2 weeks  // 4
            reward += 8000000000000000000 * 14;   // 2-4 weeks  // 8
            reward += 12500000000000000000 * 28;  // 4-8 weeks  // 12.5 

        }else if((_timeFrame == TimeFrame.TWELVE_WEEKS) && (tm >= (12 minutes )) ){
            reward  = 4000000000000000000 * 14;   // 1-2 weeks  // 4
            reward += 8000000000000000000 * 14;   // 2-4 weeks  // 8
            reward += 12500000000000000000 * 28;  // 4-8 weeks  // 12.5 
            reward += 20000000000000000000 * 28;  //8-12 weeks  // 20
        }

        return reward;  
    }

    function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}