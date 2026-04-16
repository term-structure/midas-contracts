// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../RedemptionVault.sol";
import "./MXautMidasAccessControlRoles.sol";

/**
 * @title MXautRedemptionVault
 * @notice Smart contract that handles mXAUT redemptions
 * @author TermMax Labs
 */
contract MXautRedemptionVault is
    RedemptionVault,
    MXautMidasAccessControlRoles
{
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return M_XAUT_REDEMPTION_VAULT_ADMIN_ROLE;
    }
}
