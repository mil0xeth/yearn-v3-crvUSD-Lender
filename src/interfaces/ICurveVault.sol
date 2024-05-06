// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

interface ICurveVault {
    function controller() external view returns (IController);
    function amm() external view returns (IAMM);
    function totalAssets() external view returns (uint256);
    function pricePerShare() external view returns(uint256);
    function lend_apr() external view returns (uint256);
    function convertToShares(uint256 _assets) external view returns (uint256);
}

interface IController {
    function total_debt() external view returns (uint256);
}

interface IAMM {
    function rate() external view returns (uint256);
}