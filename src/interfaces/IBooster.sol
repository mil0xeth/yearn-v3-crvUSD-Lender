// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import {IRewardStaking} from "./IRewardStaking.sol";

interface IBooster {
    function poolInfo(uint256 _pid) external view returns(address _lptoken, address _token, address _gauge, IRewardStaking _crvRewards, address _stash, bool _shutdown);
}