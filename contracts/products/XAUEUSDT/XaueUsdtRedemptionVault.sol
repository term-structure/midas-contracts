// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../RedemptionVault.sol";
import "./XaueUsdtMidasAccessControlRoles.sol";

/**
 * @title XaueUsdtRedemptionVault
 * @notice Smart contract that handles XAUEUSDT redemptions
 * @author TermMax Labs
 */
contract XaueUsdtRedemptionVault is RedemptionVault, XaueUsdtMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return XAUE_USDT_REDEMPTION_VAULT_ADMIN_ROLE;
    }
}
