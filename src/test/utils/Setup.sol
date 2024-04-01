// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import "forge-std/console.sol";
import {ExtendedTest} from "./ExtendedTest.sol";

import {CurveLender, ERC20} from "../../CurveLender.sol";
import {CurveLenderFactory} from "../../CurveLenderFactory.sol";
import {IStrategyInterface} from "../../interfaces/IStrategyInterface.sol";
import {IStrategyFactoryInterface} from "../../interfaces/IStrategyFactoryInterface.sol";

// Inherit the events so they can be checked if desired.
import {IEvents} from "@tokenized-strategy/interfaces/IEvents.sol";

interface IFactory {
    function governance() external view returns (address);

    function set_protocol_fee_bps(uint16) external;

    function set_protocol_fee_recipient(address) external;
}

contract Setup is ExtendedTest, IEvents {
    // Contract instances that we will use repeatedly.
    ERC20 public asset;
    IStrategyInterface public strategy;
    IStrategyFactoryInterface public strategyFactory;
    address curveLendVault;
    address gauge;
    address emergencyAdmin;
    address GOV;

    mapping(string => address) public tokenAddrs;

    // Addresses for different roles we will use repeatedly.
    address public user = address(10);
    address public keeper = address(4);
    address public management = address(1);
    address public performanceFeeRecipient = address(3);

    // Address of the real deployed Factory
    address public factory;

    // Integer variables that will be used repeatedly.
    uint256 public decimals;
    uint256 public MAX_BPS = 10_000;

    // Fuzz from $0.01 of 1e6 stable coins up to 1 trillion of a 1e18 coin
    uint256 public maxFuzzAmount = 1e30;
    uint256 public minFuzzAmount = 1e15;

    // Default profit max unlock time is set for 10 days
    uint256 public profitMaxUnlockTime = 10 days;

    function setUp() public virtual {
        _setTokenAddrs();

        // Set asset
        asset = ERC20(tokenAddrs["CRVUSD"]);

        //https://etherscan.io/address/0xeA6876DDE9e3467564acBeE1Ed5bac88783205E0#readContract --> gauges -->

        //0
        curveLendVault = 0x8cf1DE26729cfB7137AF1A6B2a665e099EC319b5; //Mainnet wstETH/crvUSD
        gauge = 0x222D910ef37C06774E1eDB9DC9459664f73776f0; //Mainnet wstETH/crvUSD //0

        //1
        //curveLendVault = 0x5AE28c9197a4a6570216fC7e53E7e0221D7A0FEF;
        //gauge = 0x1Cfabd1937e75E40Fa06B650CB0C8CD233D65C20; //Mainnet WETH/crvUSD //1

        //2
        //curveLendVault = 0xb2b23C87a4B6d1b03Ba603F7C3EB9A81fDC0AAC9;
        //gauge = 0x41eBf0bEC45642A675e8b7536A2cE9c078A814B4; //Mainnet WBTCt/crvUSD //2

        //3
        //curveLendVault = 0xCeA18a8752bb7e7817F9AE7565328FE415C0f2cA; // Mainnet CRV/crvUSD
        //gauge = 0x49887dF6fE905663CDB46c616BfBfBB50e85a265;  //CRV/crvUSD



        GOV = management;
        emergencyAdmin = management;

        // Set decimals
        decimals = asset.decimals();

        strategyFactory = setUpStrategyFactory();

        // Deploy strategy and set variables
        vm.prank(management);
        strategy = IStrategyInterface(strategyFactory.newCurveLender(address(asset), "Strategy", curveLendVault, gauge));
        setUpStrategy();

        // Deploy strategy and set variables
        //strategy = IStrategyInterface(setUpStrategy());

        factory = strategy.FACTORY();

        // label all the used addresses for traces
        vm.label(keeper, "keeper");
        vm.label(factory, "factory");
        vm.label(address(asset), "asset");
        vm.label(management, "management");
        vm.label(address(strategy), "strategy");
        vm.label(performanceFeeRecipient, "performanceFeeRecipient");
    }

    function setUpStrategyFactory() public returns (IStrategyFactoryInterface) {
        vm.prank(management);
        IStrategyFactoryInterface _factory = IStrategyFactoryInterface(
            address(
                new CurveLenderFactory(
                    management,
                    performanceFeeRecipient,
                    keeper,
                    emergencyAdmin,
                    GOV
                )
            )
        );
        return _factory;
    }

    function setUpStrategy() public {
        vm.startPrank(management);
        strategy.acceptManagement();
        // set keeper
        strategy.setKeeper(keeper);
        // set treasury
        strategy.setPerformanceFeeRecipient(performanceFeeRecipient);
        strategy.setProfitLimitRatio(60_000);
        vm.stopPrank();
    }

    function depositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        vm.prank(_user);
        asset.approve(address(_strategy), _amount);

        vm.prank(_user);
        _strategy.deposit(_amount, _user);
    }

    function mintAndDepositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        airdrop(asset, _user, _amount);
        depositIntoStrategy(_strategy, _user, _amount);
    }

    // For checking the amounts in the strategy
    function checkStrategyTotals(
        IStrategyInterface _strategy,
        uint256 _totalAssets,
        uint256 _totalDebt,
        uint256 _totalIdle
    ) public view {
        uint256 _assets = _strategy.totalAssets();
        uint256 _balance = ERC20(_strategy.asset()).balanceOf(
            address(_strategy)
        );
        uint256 _idle = _balance > _assets ? _assets : _balance;
        uint256 _debt = _assets - _idle;
        assertEq(_assets, _totalAssets, "!totalAssets");
        assertEq(_debt, _totalDebt, "!totalDebt");
        assertEq(_idle, _totalIdle, "!totalIdle");
        assertEq(_totalAssets, _totalDebt + _totalIdle, "!Added");
    }

    function airdrop(ERC20 _asset, address _to, uint256 _amount) public {
        uint256 balanceBefore = _asset.balanceOf(_to);
        deal(address(_asset), _to, balanceBefore + _amount);
    }

    function setFees(uint16 _protocolFee, uint16 _performanceFee) public {
        address gov = IFactory(factory).governance();

        // Need to make sure there is a protocol fee recipient to set the fee.
        vm.prank(gov);
        IFactory(factory).set_protocol_fee_recipient(gov);

        vm.prank(gov);
        IFactory(factory).set_protocol_fee_bps(_protocolFee);

        vm.prank(management);
        strategy.setPerformanceFee(_performanceFee);
    }

    function _setTokenAddrs() internal {
        tokenAddrs["WBTC"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        tokenAddrs["YFI"] = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
        tokenAddrs["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokenAddrs["LINK"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        tokenAddrs["USDT"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        tokenAddrs["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        tokenAddrs["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokenAddrs["CRVUSD"] = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    }
}