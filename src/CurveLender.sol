// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;
import "forge-std/console.sol";
import {BaseHealthCheck, ERC20} from "@periphery/Bases/HealthCheck/BaseHealthCheck.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TradeFactorySwapper} from "@periphery/swappers/TradeFactorySwapper.sol";

interface ICurveLend {
    function asset() external view returns (address);
    function deposit(uint256) external returns (uint256);
    function withdraw(uint256) external;
    function redeem(uint256) external;
    function maxDeposit(address) external view returns (uint256);
    function maxWithdraw(address) external view returns (uint256);
    function convertToShares(uint256) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    }

interface IConvexDeposit {
    function poolInfo(uint256 _PID) external view returns (address, address, address, address, address, bool);
    function deposit(uint256 _PID, uint256 _amount, bool _stake) external;
    function withdraw(uint256 _PID, uint256 _amount) external;
    }

interface IConvexRewards {
    function earned(address) external view returns (uint256);
    function getReward(address, bool) external;
    function withdrawAndUnwrap(uint256, bool) external;
    }

contract CurveLender is BaseHealthCheck, TradeFactorySwapper {
    using SafeERC20 for ERC20;

    address public immutable curveLendVault;
    address public immutable convexDepositContract;
    address public immutable convexRewardsContract;
    uint256 public immutable PID;
    address public immutable GOV;

    constructor(address _asset, string memory _name, address _convexDepositContract, uint256 _PID, address _GOV) BaseHealthCheck(_asset, _name) {
        convexDepositContract = _convexDepositContract;
        PID = _PID;
        (curveLendVault, , , convexRewardsContract, , ) = IConvexDeposit(_convexDepositContract).poolInfo(_PID);
        GOV = _GOV;

        asset.safeApprove(curveLendVault, type(uint256).max);
        ERC20(curveLendVault).safeApprove(_convexDepositContract, type(uint256).max);
    }

    function _deployFunds(uint256 _amount) internal override {
        console.log("_deployFunds");
        IConvexDeposit(convexDepositContract).deposit(PID, ICurveLend(curveLendVault).deposit(_amount), true); // deposit & stake
        console.log("_deployFunds done");
    }

    function _freeFunds(uint256 _amount) internal override {
        console.log("_freefunds _amount: ", _amount);
        console.log("asset.balanceOf(address(this): ", asset.balanceOf(address(this)));
        uint256 shares = ICurveLend(curveLendVault).convertToShares(_amount);
        console.log("shares: ", shares);
        IConvexRewards(convexRewardsContract).withdrawAndUnwrap(shares, true);
        console.log("asset.balanceOf(address(this): ", asset.balanceOf(address(this)));
        //IConvexDeposit(convexDepositContract).withdraw(PID, shares); // unstake
        ICurveLend(curveLendVault).redeem(shares); // redeem
        console.log("asset.balanceOf(address(this): ", asset.balanceOf(address(this)));
    }

    function _harvestAndReport()
        internal
        override
        returns (uint256 _totalAssets)
    {
        if (!TokenizedStrategy.isShutdown()) {
            uint256 assetBalance = asset.balanceOf(address(this));
            if (assetBalance > 0) {
                _deployFunds(assetBalance);
            }
        }
        console.log("stakedBalance", stakedBalance());
        console.log("ICurveLend(curveLendVault).convertToAssets(stakedBalance()", ICurveLend(curveLendVault).convertToAssets(stakedBalance()));
        _totalAssets = asset.balanceOf(address(this)) + ICurveLend(curveLendVault).convertToAssets(stakedBalance());
    }

    function availableDepositLimit(address /*_owner*/) public view virtual override returns (uint256) {
        return ICurveLend(curveLendVault).maxDeposit(address(this));
    }

    function stakedBalance() public view returns (uint256) {
        return ERC20(convexRewardsContract).balanceOf(address(this));
    }

    function claimableBalance() public view returns (uint256) {
        return IConvexRewards(convexRewardsContract).earned(address(this));
    }

    /* ========== TRADE FACTORY FUNCTIONS ========== */

    function _claimRewards() internal override {
        IConvexRewards(convexRewardsContract).getReward(address(this), true);
    }

    /**
     * @notice Use to add tokens to our rewardTokens array. Also enables token on trade factory if one is set.
     * @dev Can only be called by management.
     * @param _token Address of token to add.
     */
    function addToken(address _token) external onlyManagement {
        _addToken(_token, address(asset));
    }

    /**
     * @notice Use to remove tokens from our rewardTokens array. Also disables token on trade factory.
     * @dev Can only be called by management.
     * @param _token Address of token to remove.
     */
    function removeToken(address _token) external onlyManagement {
        _removeToken(_token, address(asset));
    }

    /*//////////////////////////////////////////////////////////////
                GOVERNANCE:
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Use to update our trade factory.
     * @dev Can only be called by governance.
     * @param _tradeFactory Address of new trade factory.
     */
    function setTradeFactory(address _tradeFactory) external onlyGovernance {
        _setTradeFactory(_tradeFactory, address(asset));
    }

    /// @notice Sweep of non-asset ERC20 tokens to governance (onlyGovernance)
    /// @param _token The ERC20 token to sweep
    function sweep(address _token) external onlyGovernance {
        require(_token != address(asset), "!asset");
        ERC20(_token).safeTransfer(GOV, ERC20(_token).balanceOf(address(this)));
    }

    modifier onlyGovernance() {
        require(msg.sender == GOV, "!gov");
        _;
    }
}