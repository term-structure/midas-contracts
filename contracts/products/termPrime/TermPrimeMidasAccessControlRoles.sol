// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title TermPrimeMidasAccessControlRoles
 * @notice Base contract that stores all roles descriptors for termPrime contracts
 * @author TermMax Labs
 */
abstract contract TermPrimeMidasAccessControlRoles {
    /**
     * @notice actor that can manage TermPrimeDepositVault
     */
    bytes32 public constant TERM_PRIME_DEPOSIT_VAULT_ADMIN_ROLE =
        keccak256("TERM_PRIME_DEPOSIT_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage TermPrimeRedemptionVault
     */
    bytes32 public constant TERM_PRIME_REDEMPTION_VAULT_ADMIN_ROLE =
        keccak256("TERM_PRIME_REDEMPTION_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage TermPrimeCustomAggregatorFeed and TermPrimeDataFeed
     */
    bytes32 public constant TERM_PRIME_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE =
        keccak256("TERM_PRIME_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE");
}
