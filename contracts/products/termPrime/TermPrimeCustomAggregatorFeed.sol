// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/CustomAggregatorV3CompatibleFeed.sol";
import "./TermPrimeMidasAccessControlRoles.sol";

/**
 * @title TermPrimeCustomAggregatorFeed
 * @notice AggregatorV3 compatible feed for termPrime,
 * where price is submitted manually by feed admins
 * @author TermMax Labs
 */
contract TermPrimeCustomAggregatorFeed is
    CustomAggregatorV3CompatibleFeed,
    TermPrimeMidasAccessControlRoles
{
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc CustomAggregatorV3CompatibleFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return TERM_PRIME_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
