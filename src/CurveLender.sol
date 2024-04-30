// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {Base4626Compounder, ERC20, SafeERC20} from "@periphery/Bases/4626Compounder/Base4626Compounder.sol";
import {TradeFactorySwapper} from "@periphery/swappers/TradeFactorySwapper.sol";
import {IStaking} from "./interfaces/CurveInterfaces.sol";

contract CurveLender is Base4626Compounder, TradeFactorySwapper {
    using SafeERC20 for ERC20;

    IStaking public immutable staking; // address of the Curve gauge
    address public immutable GOV; //yearn governance

    /**
     * @dev Vault must match lp_token() for the staking pool.
     * @param _asset Underlying asset to use for this strategy.
     * @param _name Name to use for this strategy.
     * @param _vault ERC4626 vault token to use.
     * @param _staking Staking pool to use.
     */
    constructor(
        address _asset,
        string memory _name,
        address _vault,
        address _staking,
        address _GOV
    ) Base4626Compounder(_asset, _name, _vault) {
        staking = IStaking(_staking);
        require(_vault == staking.lp_token(), "token mismatch");
        GOV = _GOV;

        ERC20(_vault).safeApprove(_staking, type(uint256).max);
    }

    /* ========== BASE4626 FUNCTIONS ========== */

    /**
     * @notice Balance of vault tokens staked in the staking contract
     */
    function balanceOfStake() public view override returns (uint256) {
        return staking.balanceOf(address(this));
    }

    function _stake() internal override {
        staking.deposit(balanceOfVault());
    }

    function _unStake(uint256 _amount) internal override {
        staking.withdraw(_amount);
    }

    function vaultsMaxWithdraw() public view override returns (uint256) {
        return vault.convertToAssets(vault.maxRedeem(address(staking)));
    }

    /* ========== TRADE FACTORY FUNCTIONS ========== */

    function _claimRewards() internal override {
        staking.claim_rewards();
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
        protected[0] = address(staking); // gauge
        protected[1] = address(vault); // curve lend token
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
