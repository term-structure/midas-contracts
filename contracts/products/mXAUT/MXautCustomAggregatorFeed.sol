// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/CustomAggregatorV3CompatibleFeed.sol";
import "./MXautMidasAccessControlRoles.sol";

/**
 * @title MXautCustomAggregatorFeed
 * @notice AggregatorV3 compatible feed for mXAUT,
 * where price is submitted manually by feed admins
 * @author TermMax Labs
 */
contract MXautCustomAggregatorFeed is
    CustomAggregatorV3CompatibleFeed,
    MXautMidasAccessControlRoles
{
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc CustomAggregatorV3CompatibleFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return M_XAUT_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
