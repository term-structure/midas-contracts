// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../DepositVault.sol";
import "./AuUsdMidasAccessControlRoles.sol";

/**
 * @title AuUsdDepositVault
 * @notice Smart contract that handles auUSD minting
 * @author TermMax Labs
 */
contract AuUsdDepositVault is DepositVault, AuUsdMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return AU_USD_DEPOSIT_VAULT_ADMIN_ROLE;
    }
}
