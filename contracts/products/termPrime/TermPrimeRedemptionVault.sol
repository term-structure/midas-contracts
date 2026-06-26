// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../RedemptionVault.sol";
import "./TermPrimeMidasAccessControlRoles.sol";

/**
 * @title TermPrimeRedemptionVault
 * @notice Smart contract that handles termPrime redemptions
 * @author TermMax Labs
 */
contract TermPrimeRedemptionVault is
    RedemptionVault,
    TermPrimeMidasAccessControlRoles
{
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return TERM_PRIME_REDEMPTION_VAULT_ADMIN_ROLE;
    }
}
