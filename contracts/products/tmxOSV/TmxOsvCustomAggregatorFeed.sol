// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/CustomAggregatorV3CompatibleFeed.sol";
import "./TmxOsvMidasAccessControlRoles.sol";

/**
 * @title TmxOsvCustomAggregatorFeed
 * @notice AggregatorV3-compatible tmxOSV NAV feed updated by the backend
 * @author TermMax Labs
 */
contract TmxOsvCustomAggregatorFeed is CustomAggregatorV3CompatibleFeed, TmxOsvMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for future updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc CustomAggregatorV3CompatibleFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return TMX_OSV_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
