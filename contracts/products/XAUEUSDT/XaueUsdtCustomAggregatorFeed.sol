// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/CustomAggregatorV3CompatibleFeed.sol";
import "./XaueUsdtMidasAccessControlRoles.sol";

/**
 * @title XaueUsdtCustomAggregatorFeed
 * @notice AggregatorV3 compatible feed for XAUEUSDT,
 * where price is submitted manually by feed admins
 * @author TermMax Labs
 */
contract XaueUsdtCustomAggregatorFeed is CustomAggregatorV3CompatibleFeed, XaueUsdtMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc CustomAggregatorV3CompatibleFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return XAUE_USDT_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
