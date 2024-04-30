// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;
import "forge-std/console.sol";
import {AprOracleBase} from "@periphery/AprOracle/AprOracleBase.sol";

interface IStrategy {
    function vault() external view returns (address);
    function staking() external view returns (address);
}

interface ICurveVault {
    function controller() external view returns (address);
    function totalAssets() external view returns (uint256);
}

interface IController {
    function monetary_policy() external view returns (address);
    function total_debt() external view returns (uint256);
}

interface IMonetaryPolicy {
    function future_rate(
        address,
        int256,
        int256
    ) external view returns (uint256);
}

interface ILiquidityGauge {
    function reward_data(
        address
    )
        external
        view
        returns (
            address token,
            address distributor,
            uint256 period_finish,
            uint256 rate,
            uint256 last_update,
            uint256 integral
        );
    function totalSupply() external view returns (uint256);
}

interface IChainlink {
    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80);
}

contract StrategyAprOracle is AprOracleBase {
    address internal constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52; // hardcoded for now
    address public immutable chainlinkCRVUSDvsUSD;
    address public immutable chainlinkCRVvsUSD;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant secondsInOneYear = 60 * 60 * 24 * 365;

    constructor(
        address _chainlinkCRVUSDvsUSD,
        address _chainlinkCRVvsUSD
    ) AprOracleBase("Strategy Apr Oracle Example", msg.sender) {
        chainlinkCRVUSDvsUSD = _chainlinkCRVUSDvsUSD;
        chainlinkCRVvsUSD = _chainlinkCRVvsUSD;
    }

    function aprAfterDebtChange(
        address _strategy,
        int256 _delta
    ) external view override returns (uint256 apr) {
        IStrategy strategy = IStrategy(_strategy);
        ICurveVault curveVault = ICurveVault(strategy.vault());
        IController controller = IController(curveVault.controller());
        IMonetaryPolicy monetaryPolicy = IMonetaryPolicy(
            controller.monetary_policy()
        );

        // native supply yield
        uint256 futureRate = monetaryPolicy.future_rate(
            address(controller),
            _delta,
            0
        );
        console.log("futureRate: ", futureRate);
        uint256 lendingAPR = (futureRate *
            secondsInOneYear *
            controller.total_debt()) / curveVault.totalAssets();

        // gauge rewards (crv)
        address liquidityGauge = strategy.staking();
        (, , , uint256 rate, , ) = ILiquidityGauge(liquidityGauge).reward_data(
            CRV
        );
        console.log("rate: ", rate);

        uint256 rewardYield;
        uint256 totalSupply = ILiquidityGauge(liquidityGauge).totalSupply();
        if (_delta >= 0) {
            rewardYield =
                (secondsInOneYear * rate * WAD) /
                (totalSupply + uint256(_delta));
            console.log("rewardYield: ", rewardYield);
        } else if (uint256(_delta) < totalSupply) {
            rewardYield =
                (secondsInOneYear * rate * WAD) /
                (totalSupply - uint256(_delta));
        } else {
            rewardYield = 0; // @todo: check
        }

        // pricing: reward to CRVUSD
        (, int256 price, , , ) = IChainlink(chainlinkCRVvsUSD)
            .latestRoundData();
        console.log("price: ", uint256(price));
        uint256 USDyield = (rewardYield * uint256(price)) / 1e8; // convert reward to USD
        console.log("USDyield: ", USDyield);
        (, price, , , ) = IChainlink(chainlinkCRVUSDvsUSD).latestRoundData();
        console.log("price: ", uint256(price));
        uint256 gaugeAPR = (USDyield * WAD) / (uint256(price) * 1e10); // convert USD to CRVUSD

        console.log("lendingAPR: ", lendingAPR);
        console.log("gaugeAPR: ", gaugeAPR);
        // return total of lending yields + gauge rewards
        return lendingAPR + gaugeAPR;
    }
}
