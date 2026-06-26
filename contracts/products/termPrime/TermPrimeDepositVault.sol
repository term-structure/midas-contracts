// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../DepositVault.sol";
import "./TermPrimeMidasAccessControlRoles.sol";

/**
 * @title TermPrimeDepositVault
 * @notice Smart contract that handles termPrime minting
 * @author TermMax Labs
 */
contract TermPrimeDepositVault is DepositVault, TermPrimeMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return TERM_PRIME_DEPOSIT_VAULT_ADMIN_ROLE;
    }
}
