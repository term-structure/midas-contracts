// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../DepositVault.sol";
import "./XaueUsdtMidasAccessControlRoles.sol";

/**
 * @title XaueUsdtDepositVault
 * @notice Smart contract that handles XAUEUSDT minting
 * @author TermMax Labs
 */
contract XaueUsdtDepositVault is DepositVault, XaueUsdtMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return XAUE_USDT_DEPOSIT_VAULT_ADMIN_ROLE;
    }
}
