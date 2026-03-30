// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../DepositVault.sol";
import "./LeveragedQQQonMidasAccessControlRoles.sol";

/**
 * @title LeveragedQQQonDepositVault
 * @notice Smart contract that handles leveragedQQQon minting
 * @author TermMax Labs
 */
contract LeveragedQQQonDepositVault is DepositVault, LeveragedQQQonMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return LEVERAGED_QQQON_DEPOSIT_VAULT_ADMIN_ROLE;
    }
}
