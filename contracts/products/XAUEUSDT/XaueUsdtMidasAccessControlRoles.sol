// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title XaueUsdtMidasAccessControlRoles
 * @notice Base contract that stores all roles descriptors for XAUEUSDT contracts
 * @author TermMax Labs
 */
abstract contract XaueUsdtMidasAccessControlRoles {
    /**
     * @notice actor that can manage XaueUsdtDepositVault
     */
    bytes32 public constant XAUE_USDT_DEPOSIT_VAULT_ADMIN_ROLE = keccak256("XAUE_USDT_DEPOSIT_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage XaueUsdtRedemptionVault
     */
    bytes32 public constant XAUE_USDT_REDEMPTION_VAULT_ADMIN_ROLE = keccak256("XAUE_USDT_REDEMPTION_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage XaueUsdtCustomAggregatorFeed and XaueUsdtDataFeed
     */
    bytes32 public constant XAUE_USDT_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE =
        keccak256("XAUE_USDT_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE");
}
