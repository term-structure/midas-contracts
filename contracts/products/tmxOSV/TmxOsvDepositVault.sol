// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../DepositVault.sol";
import "./TmxOsvMidasAccessControlRoles.sol";

/**
 * @title TmxOsvDepositVault
 * @notice Handles quoted USDC and USDT deposits for tmxOSV
 * @author TermMax Labs
 */
contract TmxOsvDepositVault is DepositVault, TmxOsvMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for future updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return TMX_OSV_DEPOSIT_VAULT_ADMIN_ROLE;
    }
}
