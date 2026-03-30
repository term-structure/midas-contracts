// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title LeveragedQQQonMidasAccessControlRoles
 * @notice Base contract that stores all roles descriptors for leveragedQQQon contracts
 * @author RedDuck Software
 */
abstract contract LeveragedQQQonMidasAccessControlRoles {
    /**
     * @notice actor that can manage LeveragedQQQonDepositVault
     */
    bytes32 public constant LEVERAGED_QQQON_DEPOSIT_VAULT_ADMIN_ROLE =
        keccak256("LEVERAGED_QQQON_DEPOSIT_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage LeveragedQQQonRedemptionVault
     */
    bytes32 public constant LEVERAGED_QQQON_REDEMPTION_VAULT_ADMIN_ROLE =
        keccak256("LEVERAGED_QQQON_REDEMPTION_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage LeveragedQQQonCustomAggregatorFeed and LeveragedQQQonDataFeed
     */
    bytes32 public constant LEVERAGED_QQQON_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE =
        keccak256("LEVERAGED_QQQON_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE");
}
