// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

interface IRewardStaking {
    function rewardRate() external view returns(uint256);
    function totalSupply() external view returns(uint256);
    function periodFinish() external view returns(uint256);
}