// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/DataFeed.sol";
import "./TmxOsvMidasAccessControlRoles.sol";

/**
 * @title TmxOsvDataFeed
 * @notice Data feed wrapper for the tmxOSV NAV
 * @author TermMax Labs
 */
contract TmxOsvDataFeed is DataFeed, TmxOsvMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for future updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc DataFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return TMX_OSV_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
