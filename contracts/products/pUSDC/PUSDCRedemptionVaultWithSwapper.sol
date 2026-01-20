// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../RedemptionVaultWithSwapper.sol";
import "./PUSDCMidasAccessControlRoles.sol";

/**
 * @title PUSDCRedemptionVaultWithSwapper
 * @notice Smart contract that handles pUSDC redemptions
 * @author TermMax Labs
 */
contract PUSDCRedemptionVaultWithSwapper is
    RedemptionVaultWithSwapper,
    PUSDCMidasAccessControlRoles
{
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return P_USDC_REDEMPTION_VAULT_ADMIN_ROLE;
    }
}
