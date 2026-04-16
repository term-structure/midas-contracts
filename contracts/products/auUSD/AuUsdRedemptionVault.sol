// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../RedemptionVault.sol";
import "./AuUsdMidasAccessControlRoles.sol";

/**
 * @title AuUsdRedemptionVault
 * @notice Smart contract that handles auUSD redemptions
 * @author TermMax Labs
 */
contract AuUsdRedemptionVault is
    RedemptionVault,
    AuUsdMidasAccessControlRoles
{
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return AU_USD_REDEMPTION_VAULT_ADMIN_ROLE;
    }
}
