// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../RedemptionVault.sol";
import "./LeveragedQQQonMidasAccessControlRoles.sol";

/**
 * @title LeveragedQQQonRedemptionVault
 * @notice Smart contract that handles leveragedQQQon redemptions
 * @author TermMax Labs
 */
contract LeveragedQQQonRedemptionVault is
    RedemptionVault,
    LeveragedQQQonMidasAccessControlRoles
{
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return LEVERAGED_QQQON_REDEMPTION_VAULT_ADMIN_ROLE;
    }
}
