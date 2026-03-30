// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/CustomAggregatorV3CompatibleFeed.sol";
import "./LeveragedQQQonMidasAccessControlRoles.sol";

/**
 * @title LeveragedQQQonCustomAggregatorFeed
 * @notice AggregatorV3 compatible feed for leveragedQQQon,
 * where price is submitted manually by feed admins
 * @author TermMax Labs
 */
contract LeveragedQQQonCustomAggregatorFeed is
    CustomAggregatorV3CompatibleFeed,
    LeveragedQQQonMidasAccessControlRoles
{
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc CustomAggregatorV3CompatibleFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return LEVERAGED_QQQON_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
