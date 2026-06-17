// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/DataFeed.sol";
import "./XaueUsdtMidasAccessControlRoles.sol";

/**
 * @title XaueUsdtDataFeed
 * @notice DataFeed for XAUEUSDT product
 * @author TermMax Labs
 */
contract XaueUsdtDataFeed is DataFeed, XaueUsdtMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc DataFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return XAUE_USDT_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
