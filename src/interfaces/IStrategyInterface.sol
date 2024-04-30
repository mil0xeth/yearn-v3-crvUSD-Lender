// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

interface IStrategyInterface is IStrategy {
    function setProfitLimitRatio(uint256) external;
    function PID() external view returns (uint256);
    function curveLendVault() external view returns (address);
}
