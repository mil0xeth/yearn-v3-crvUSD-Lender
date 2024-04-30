// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IConvexDeposit {
    function poolInfo(
        uint256 _PID
    ) external view returns (address, address, address, address, address, bool);
    function deposit(uint256 _PID, uint256 _amount, bool _stake) external;
    function withdraw(uint256 _PID, uint256 _amount) external;
}

interface IConvexRewards is IERC20 {
    function earned(address) external view returns (uint256);
    function getReward(address, bool) external;
    function withdrawAndUnwrap(uint256, bool) external;
}
