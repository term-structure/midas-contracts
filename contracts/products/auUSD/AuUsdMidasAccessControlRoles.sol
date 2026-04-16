// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title AuUsdMidasAccessControlRoles
 * @notice Base contract that stores all roles descriptors for auUSD contracts
 * @author RedDuck Software
 */
abstract contract AuUsdMidasAccessControlRoles {
    /**
     * @notice actor that can manage AuUsdDepositVault
     */
    bytes32 public constant AU_USD_DEPOSIT_VAULT_ADMIN_ROLE =
        keccak256("AU_USD_DEPOSIT_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage AuUsdRedemptionVault
     */
    bytes32 public constant AU_USD_REDEMPTION_VAULT_ADMIN_ROLE =
        keccak256("AU_USD_REDEMPTION_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage AuUsdCustomAggregatorFeed and AuUsdDataFeed
     */
    bytes32 public constant AU_USD_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE =
        keccak256("AU_USD_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE");
}
