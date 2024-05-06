// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {AprOracleBase} from "@periphery/AprOracle/AprOracleBase.sol";

import {AggregatorV3Interface} from "@chainlink/shared/interfaces/AggregatorV3Interface.sol";

import {IStrategyInterface} from "../interfaces/IStrategyInterface.sol";
import {IPoolUtilities} from "../interfaces/IPoolUtilities.sol";
import {IRewardStaking} from "../interfaces/IRewardStaking.sol";
import {ICurveVault} from "../interfaces/ICurveVault.sol";
import {ICvxMining} from "../interfaces/ICvxMining.sol";
import {IBooster} from "../interfaces/IBooster.sol";

import "forge-std/console.sol";

contract StrategyAprOracle is AprOracleBase {

    uint256 internal constant WAD = 1e18;
    uint256 internal constant CL_NORMALIZE = 1e10;
    uint256 internal constant secondsInOneYear = 60 * 60 * 24 * 365;

    address internal constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address internal constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;

    // Mainnet
    IPoolUtilities public constant poolUtilities = IPoolUtilities(0x5Fba69a794F395184b5760DAf1134028608e5Cd1);
    ICvxMining public constant cvxMining = ICvxMining(0x3c75BFe6FbfDa3A94E7E7E8c2216AFc684dE5343);
    IBooster public constant convexBooster = IBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);

    AggregatorV3Interface public constant chainlinkCVXvsUSD = AggregatorV3Interface(0xd962fC30A72A84cE50161031391756Bf2876Af5D);
    AggregatorV3Interface public constant chainlinkCRVvsUSD = AggregatorV3Interface(0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f);

    constructor() AprOracleBase("Strategy APR Oracle", msg.sender) {}

    function aprAfterDebtChange(
        address _strategy,
        int256 _delta
    ) external view override returns (uint256 _totalApr) {

        ICurveVault _curveLendVault = ICurveVault(IStrategyInterface(_strategy).curveLendVault());
        _totalApr += _lendAPR(_curveLendVault, _delta);
        console.log("lend apr: ", _totalApr);

        (uint256 _crvAPR, uint256 _cvxAPR) = _rewardAPR(_curveLendVault, IStrategyInterface(_strategy).PID(), _delta);
        console.log("crv apr: ", _crvAPR);
        console.log("cvx apr: ", _cvxAPR);

        _totalApr += _crvAPR + _cvxAPR;

        // _extraTokenAPR(); // todo

        console.log("totalApr", _totalApr);
    }

    function _lendAPR(ICurveVault _curveLendVault, int256 _delta) internal view returns (uint256) {
        if (_delta == 0) return _curveLendVault.lend_apr();

        int256 _totalAssets = int256(_curveLendVault.totalAssets());
        require(_delta < _totalAssets, "StrategyAprOracle: delta exceeds total assets");

        uint256 _totalAssetsAfterDelta = uint256(_totalAssets + _delta);
        uint256 _debt = _curveLendVault.controller().total_debt();
        require(_debt <= _totalAssetsAfterDelta, "StrategyAprOracle: debt exceeds total assets");

        return _debt == 0 ? 0 : _curveLendVault.amm().rate() * secondsInOneYear * _debt / _totalAssetsAfterDelta;
    }

    function _rewardAPR(
        ICurveVault _curveLendVault,
        uint256 _pid,
        int256 _delta
    ) internal view returns (uint256 _crvRate, uint256 _cvxRate) {

        (,,, IRewardStaking _crvRewards,,) = convexBooster.poolInfo(_pid);
        uint256 _stakedSupply = _crvRewards.totalSupply();
        if (block.timestamp < _crvRewards.periodFinish()){
            _crvRate = _crvRewards.rewardRate();
        } else {
            return (0, 0);
        }

        if (_delta != 0) {
            if (_delta > 0) {
                _stakedSupply += _curveLendVault.convertToShares(uint256(_delta));
            } else {
                require(_delta < int256(_curveLendVault.totalAssets()), "StrategyAprOracle: delta exceeds total assets");
                _stakedSupply -= _curveLendVault.convertToShares(uint256(-_delta));
            }
        }

        if (_stakedSupply > 0) {
            _crvRate = _crvRate * WAD / _stakedSupply;
            _cvxRate = cvxMining.ConvertCrvToCvx(_crvRate);

            uint256 _pps = _curveLendVault.pricePerShare();

            (, int256 _crvPrice,,,) = chainlinkCRVvsUSD.latestRoundData(); // todo - add sanity checks
            _crvRate = poolUtilities.apr(_crvRate, uint256(_crvPrice) * CL_NORMALIZE, _pps);

            (, int256 _cvxPrice,,,) = chainlinkCVXvsUSD.latestRoundData(); // todo - add sanity checks
            _cvxRate = poolUtilities.apr(_cvxRate, uint256(_cvxPrice) * CL_NORMALIZE, _pps);
        } else {
            return (0, 0);
        }
    }

    // function _rewardAPRInExtraTokens(address _token, int256 _delta) internal {
    //     // todo
    // }
}