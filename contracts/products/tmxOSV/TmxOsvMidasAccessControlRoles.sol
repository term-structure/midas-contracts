// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title TmxOsvMidasAccessControlRoles
 * @notice Stores role descriptors for the TermMax Option Strategy Vault contracts
 * @author TermMax Labs
 */
abstract contract TmxOsvMidasAccessControlRoles {
    /**
     * @notice actor that can manage TmxOsvDepositVault
     */
    bytes32 public constant TMX_OSV_DEPOSIT_VAULT_ADMIN_ROLE = keccak256("TMX_OSV_DEPOSIT_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage TmxOsvRedemptionVault
     */
    bytes32 public constant TMX_OSV_REDEMPTION_VAULT_ADMIN_ROLE = keccak256("TMX_OSV_REDEMPTION_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage TmxOsvCustomAggregatorFeed and TmxOsvDataFeed
     */
    bytes32 public constant TMX_OSV_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE =
        keccak256("TMX_OSV_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE");
}
