// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../DepositVault.sol";
import "./MXautMidasAccessControlRoles.sol";

/**
 * @title MXautDepositVault
 * @notice Smart contract that handles mXAUT minting
 * @author TermMax Labs
 */
contract MXautDepositVault is DepositVault, MXautMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return M_XAUT_DEPOSIT_VAULT_ADMIN_ROLE;
    }
}
