// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../RedemptionVault.sol";
import "./TmxOsvMidasAccessControlRoles.sol";

/**
 * @title TmxOsvRedemptionVault
 * @notice Handles quoted USDC and USDT redemptions for tmxOSV
 * @author TermMax Labs
 */
contract TmxOsvRedemptionVault is RedemptionVault, TmxOsvMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for future updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return TMX_OSV_REDEMPTION_VAULT_ADMIN_ROLE;
    }
}
