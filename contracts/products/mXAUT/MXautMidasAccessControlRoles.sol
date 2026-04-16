// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title MXautMidasAccessControlRoles
 * @notice Base contract that stores all roles descriptors for mXAUT contracts
 * @author RedDuck Software
 */
abstract contract MXautMidasAccessControlRoles {
    /**
     * @notice actor that can manage MXautDepositVault
     */
    bytes32 public constant M_XAUT_DEPOSIT_VAULT_ADMIN_ROLE =
        keccak256("M_XAUT_DEPOSIT_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage MXautRedemptionVault
     */
    bytes32 public constant M_XAUT_REDEMPTION_VAULT_ADMIN_ROLE =
        keccak256("M_XAUT_REDEMPTION_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage MXautCustomAggregatorFeed and MXautDataFeed
     */
    bytes32 public constant M_XAUT_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE =
        keccak256("M_XAUT_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE");
}
