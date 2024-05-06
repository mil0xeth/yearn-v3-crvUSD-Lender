// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

interface IPoolUtilities {
    function rewardRates(uint256 _PID) external view returns (address[] memory tokens, uint256[] memory rates);
    function apr(uint256 _rate, uint256 _priceOfReward, uint256 _priceOfDeposit) external view returns (uint256);
}