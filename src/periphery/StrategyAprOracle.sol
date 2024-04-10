// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;
import "forge-std/console.sol";
import {AprOracleBase} from "@periphery/AprOracle/AprOracleBase.sol";

interface IStrategy {
    function curveLendVault() external view returns (address);
    function PID() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function stakedBalance() external view returns (uint256);
}

interface ICurveVault {
    function controller() external view returns (address);
    function totalAssets() external view returns (uint256);
    function pricePerShare() external view returns(uint256);
}

interface IChainlink {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

interface IPoolUtilities {
    function rewardRates(uint256 _PID) external view returns (address[] memory tokens, uint256[] memory rates);
    function apr(uint256 _rate, uint256 _priceOfReward, uint256 _priceOfDeposit) external view returns (uint256);
}

contract StrategyAprOracle is AprOracleBase {
    address public constant poolUtilities = 0x5Fba69a794F395184b5760DAf1134028608e5Cd1; //Mainnet
    address internal constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52; // hardcoded for now
    address internal constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B; // hardcoded for now
    address public constant chainlinkCVXvsUSD = 0xd962fC30A72A84cE50161031391756Bf2876Af5D;
    address public immutable chainlinkCRVUSDvsUSD;
    address public immutable chainlinkCRVvsUSD;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant secondsInOneYear = 60 * 60 * 24 * 365;

    constructor(address _chainlinkCRVUSDvsUSD, address _chainlinkCRVvsUSD) AprOracleBase("Strategy Apr Oracle Example", msg.sender) {
        chainlinkCRVUSDvsUSD = _chainlinkCRVUSDvsUSD;
        chainlinkCRVvsUSD = _chainlinkCRVvsUSD;
    }

    function aprAfterDebtChange(
        address _strategy,
        int256 _delta
    ) external view override returns (uint256) {
        IStrategy strategy = IStrategy(_strategy);
        (address[] memory tokens, uint256[] memory rates) = IPoolUtilities(poolUtilities).rewardRates(strategy.PID());
        uint256 length = tokens.length;
        require(length == rates.length, "length mismatch");

        address curveLendVault = strategy.curveLendVault();
        uint256 totalApr;
        address currentReward;
        int256 priceReward;
        int256 priceCRVUSD;
        uint256 apr;
        uint256 depositAmount = 1e18;
        for (uint256 i; i < length; ++i) {
            currentReward = tokens[i];
            if (currentReward == CRV) {
                (, priceReward, , , ) = IChainlink(chainlinkCRVvsUSD).latestRoundData();
                console.log("priceReward CRV: ", uint256(priceReward));
                (, priceCRVUSD, , , ) = IChainlink(chainlinkCRVUSDvsUSD).latestRoundData();
                console.log("priceCRVUSD: ", uint256(priceCRVUSD));
                console.log("rate: ", rates[i]);
                apr = IPoolUtilities(poolUtilities).apr(rates[i], uint256(priceReward) * 1e10, ICurveVault(curveLendVault).pricePerShare());
                console.log("apr: ", apr);
                totalApr += apr;
            } else if (currentReward == CVX) {
                (, priceReward, , , ) = IChainlink(chainlinkCVXvsUSD).latestRoundData();
                console.log("priceReward CVX: ", uint256(priceReward));
                (, priceCRVUSD, , , ) = IChainlink(chainlinkCRVUSDvsUSD).latestRoundData();
                console.log("priceCRVUSD: ", uint256(priceCRVUSD));
                console.log("rate: ", rates[i]);
                apr = IPoolUtilities(poolUtilities).apr(rates[i], uint256(priceReward) * 1e10, ICurveVault(curveLendVault).pricePerShare());
                console.log("apr: ", apr);
                totalApr += apr;
            } else {
                console.log("OTHER REWARD!");
            }
        }
        console.log("totalApr", totalApr);
        return totalApr;
    }
}