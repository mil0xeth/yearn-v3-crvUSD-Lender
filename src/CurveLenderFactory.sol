// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.18;

import {CurveLender} from "./CurveLender.sol";
import {IStrategyInterface} from "./interfaces/IStrategyInterface.sol";

contract CurveLenderFactory {
    event NewCurveLender(address indexed strategy, address indexed asset);

    address public management;
    address public performanceFeeRecipient;
    address public keeper;

    address public immutable emergencyAdmin;
    address internal immutable GOV;

    mapping(uint256 => address) public PIDtoStrategy;

    constructor(
        address _management,
        address _peformanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin,
        address _GOV
    ) {
        management = _management;
        performanceFeeRecipient = _peformanceFeeRecipient;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;
        require(_GOV != address(0));
        GOV = _GOV;
    }

    modifier onlyManagement() {
        require(msg.sender == management, "!management");
        _;
    }

    /**
     * @notice Deploy a new Curve Lender Strategy.
     * @dev This will set the msg.sender to all of the permissioned roles.
     * @param _asset The underlying asset for the lender to use.
     * @param _name The name for the lender to use.
     * @return . The address of the new lender.
     */
    function newCurveLender(
        address _asset,
        string memory _name,
        address _vault,
        uint256 _PID
    ) external onlyManagement returns (address) {
        // We need to use the custom interface with the
        // tokenized strategies available setters.
        IStrategyInterface newStrategy = IStrategyInterface(
            address(new CurveLender(_asset, _name, _vault, _PID, GOV))
        );
        newStrategy.setPerformanceFeeRecipient(performanceFeeRecipient);

        newStrategy.setKeeper(keeper);

        newStrategy.setPendingManagement(management);

        newStrategy.setEmergencyAdmin(emergencyAdmin);

        emit NewCurveLender(address(newStrategy), _asset);

        PIDtoStrategy[_PID] = address(newStrategy);

        return address(newStrategy);
    }

    /**
     * @notice Retrieve the address of a strategy by the market vault
     * @param _PID pool ID
     * @return strategy address
     */
    function getStrategyByPID(uint256 _PID) external view returns (address) {
        return PIDtoStrategy[_PID];
    }

    /**
     * @notice Check if a strategy has been deployed by this Factory
     * @param _strategy strategy address
     */
    function isDeployedStrategy(
        address _strategy
    ) external view returns (bool) {
        uint256 _PID = IStrategyInterface(_strategy).PID();
        return PIDtoStrategy[_PID] == _strategy;
    }

    function setStrategyByPID(
        uint256 _PID,
        address _strategy
    ) external onlyManagement {
        PIDtoStrategy[_PID] = _strategy;
    }

    /**
     * @notice Set the management address.
     * @dev This is the address that can call the management functions.
     * @param _management The address to set as the management address.
     */
    function setManagement(address _management) external onlyManagement {
        require(_management != address(0), "ZERO_ADDRESS");
        management = _management;
    }

    /**
     * @notice Set the performance fee recipient address.
     * @dev This is the address that will receive the performance fee.
     * @param _performanceFeeRecipient The address to set as the performance fee recipient address.
     */
    function setPerformanceFeeRecipient(
        address _performanceFeeRecipient
    ) external onlyManagement {
        require(_performanceFeeRecipient != address(0), "ZERO_ADDRESS");
        performanceFeeRecipient = _performanceFeeRecipient;
    }

    /**
     * @notice Set the keeper address.
     * @dev This is the address that will be able to call the keeper functions.
     * @param _keeper The address to set as the keeper address.
     */
    function setKeeper(address _keeper) external onlyManagement {
        keeper = _keeper;
    }
}
