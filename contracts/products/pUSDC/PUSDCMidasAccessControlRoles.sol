// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title PUSDCMidasAccessControlRoles
 * @notice Base contract that stores all roles descriptors for tUSDe contracts
 * @author RedDuck Software
 */
abstract contract PUSDCMidasAccessControlRoles {
    /**
     * @notice actor that can manage PUSDCDepositVault
     */
    bytes32 public constant P_USDC_DEPOSIT_VAULT_ADMIN_ROLE =
        keccak256("P_USDC_DEPOSIT_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage TUsdeRedemptionVault
     */
    bytes32 public constant P_USDC_REDEMPTION_VAULT_ADMIN_ROLE =
        keccak256("P_USDC_REDEMPTION_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage TUsdeCustomAggregatorFeed and TUsdeDataFeed
     */
    bytes32 public constant P_USDC_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE =
        keccak256("P_USDC_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE");
}
