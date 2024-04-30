// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {Base4626Compounder, ERC20, SafeERC20, Math, IStrategy} from "@periphery/Bases/4626Compounder/Base4626Compounder.sol";
import {TradeFactorySwapper} from "@periphery/swappers/TradeFactorySwapper.sol";
import {IConvexDeposit, IConvexRewards} from "./interfaces/ConvexInterfaces.sol";

contract CurveLender is Base4626Compounder, TradeFactorySwapper {
    using SafeERC20 for ERC20;

    IConvexDeposit public constant booster =
        IConvexDeposit(0xF403C135812408BFbE8713b5A23a04b3D48AAE31); // convex deposit contract
    IConvexRewards public immutable convexRewardsContract; // Convex rewards contract specific to this asset
    address public immutable gauge; // use to check free liquidity in lending pool
    uint256 public immutable PID; // pool ID, specific to each convex pool
    address public immutable GOV; //yearn governance

    /**
     * @dev Vault must match lp_token() for the staking pool.
     * @param _asset Underlying asset to use for this strategy.
     * @param _name Name to use for this strategy.
     * @param _vault Vault token for our asset.
     */
    constructor(
        address _asset,
        string memory _name,
        address _vault,
        uint256 _PID,
        address _GOV
    ) Base4626Compounder(_asset, _name, _vault) {
        (
            address _curveVault,
            ,
            address _gauge,
            address _convexRewardsContract,
            ,

        ) = booster.poolInfo(_PID);
        require(_asset == IStrategy(_curveVault).asset(), "wrong PID");
        gauge = _gauge;
        convexRewardsContract = IConvexRewards(_convexRewardsContract);

        PID = _PID;
        GOV = _GOV;
        ERC20(_vault).safeApprove(address(booster), type(uint256).max);
    }

    function claimableBalance() external view returns (uint256) {
        return convexRewardsContract.earned(address(this));
    }

    /* ========== BASE4626 FUNCTIONS ========== */

    /**
     * @notice Balance of vault tokens staked in the staking contract
     */
    function balanceOfStake() public view virtual override returns (uint256) {
        return convexRewardsContract.balanceOf(address(this));
    }

    function _stake() internal override {
        booster.deposit(PID, balanceOfVault(), true);
    }

    function _unStake(uint256 _amount) internal virtual override {
        convexRewardsContract.withdrawAndUnwrap(_amount, true);
    }

    function vaultsMaxWithdraw()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return
            Math.min(
                vault.convertToAssets(vault.maxRedeem(gauge)),
                vault.totalAssets()
            );
    }

    function availableDepositLimit(
        address /*_owner*/
    ) public view virtual override returns (uint256) {
        return vault.maxDeposit(address(this));
    }

    /* ========== TRADE FACTORY FUNCTIONS ========== */

    function _claimRewards() internal override {
        convexRewardsContract.getReward(address(this), true);
    }

    /**
     * @notice Use to add tokens to our rewardTokens array. Also enables token on trade factory if one is set.
     * @dev Can only be called by management.
     * @param _token Address of token to add.
     */
    function addToken(address _token) external onlyManagement {
        _checkIfProtected(_token);
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

    /**
     * @notice Check for tokens that shouldn't be moved (swept or swapped).
     * @dev Use this for all tokens/tokenized positions this contract
     * manages on a *persistent* basis (e.g. not just for swapping back to
     * asset ephemerally).
     */
    function protectedTokens() public view returns (address[] memory) {
        address[] memory protected = new address[](3);
        protected[0] = address(convexRewardsContract);
        protected[1] = address(vault);
        protected[2] = address(asset);
        return protected;
    }

    // checks if a given token is on our protectedTokens list
    function _checkIfProtected(address _token) internal view {
        address[] memory _protectedTokens = protectedTokens();
        for (uint256 i; i < _protectedTokens.length; ++i) {
            require(_token != _protectedTokens[i], "!protected");
        }
    }

    /* ========== GOV-ONLY FUNCTIONS ========== */

    /**
     * @dev Require that the call is coming from governance.
     */
    modifier onlyGovernance() {
        require(msg.sender == GOV, "!gov");
        _;
    }

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
        _checkIfProtected(_token);
        ERC20(_token).safeTransfer(GOV, ERC20(_token).balanceOf(address(this)));
    }
}
