pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {Setup} from "./utils/Setup.sol";

import {StrategyAprOracle} from "../periphery/StrategyAprOracle.sol";

contract OracleTest is Setup {
    StrategyAprOracle public oracle;

    function setUp() public override {
        super.setUp();
        oracle = new StrategyAprOracle(0xEEf0C605546958c1f899b6fB336C20671f9cD49F, 0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f);
    }

    function checkOracle(address _strategy, uint256 /*_delta*/) public view {
        // Check set up
        // TODO: Add checks for the setup

        uint256 currentApr = oracle.aprAfterDebtChange(_strategy, 0);

        // Should be greater than 0 but likely less than 100%
        assertGt(currentApr, 0, "ZERO");
        assertLt(currentApr, 1e18, "+100%");

        // TODO: Uncomment to test the apr goes up and down based on debt changes
        /**
        uint256 negativeDebtChangeApr = oracle.aprAfterDebtChange(_strategy, -int256(_delta));

        // The apr should go up if deposits go down
        assertLt(currentApr, negativeDebtChangeApr, "negative change");

        uint256 positiveDebtChangeApr = oracle.aprAfterDebtChange(_strategy, int256(_delta));

        assertGt(currentApr, positiveDebtChangeApr, "positive change");
        */

        // TODO: Uncomment if there are setter functions to test.
        /**
        vm.expectRevert("!governance");
        vm.prank(user);
        oracle.setterFunction(setterVariable);

        vm.prank(management);
        oracle.setterFunction(setterVariable);

        assertEq(oracle.setterVariable(), setterVariable);
        */
    }

    function test_oracle(uint256 _amount, uint16 _percentChange) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _percentChange = uint16(bound(uint256(_percentChange), 10, MAX_BPS));

        mintAndDepositIntoStrategy(strategy, user, _amount);

        uint256 _delta = (_amount * _percentChange) / MAX_BPS;

        checkOracle(address(strategy), _delta);
    }

    function test_displayAPR() public {
        uint256 apr = oracle.aprAfterDebtChange(address(strategy), 0);
        console.log("------- TOTAL APR: ", apr);
    }
}