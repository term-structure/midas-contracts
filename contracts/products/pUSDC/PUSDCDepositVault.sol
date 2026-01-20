// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../DepositVault.sol";
import "./PUSDCMidasAccessControlRoles.sol";

/**
 * @title PUSDCDepositVault
 * @notice Smart contract that handles pUSDC minting
 * @author TermMax Labs
 */
contract PUSDCDepositVault is DepositVault, PUSDCMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return P_USDC_DEPOSIT_VAULT_ADMIN_ROLE;
    }
}
