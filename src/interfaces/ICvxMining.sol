// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

interface ICvxMining {
    function ConvertCrvToCvx(uint256 _amount) external view returns(uint256);
}