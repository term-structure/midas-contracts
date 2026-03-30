// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/DataFeed.sol";
import "./LeveragedQQQonMidasAccessControlRoles.sol";

/**
 * @title LeveragedQQQonDataFeed
 * @notice DataFeed for leveragedQQQon product
 * @author TermMax Labs
 */
contract LeveragedQQQonDataFeed is DataFeed, LeveragedQQQonMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc DataFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return LEVERAGED_QQQON_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
