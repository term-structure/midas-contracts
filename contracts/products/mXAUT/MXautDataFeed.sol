// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/DataFeed.sol";
import "./MXautMidasAccessControlRoles.sol";

/**
 * @title MXautDataFeed
 * @notice DataFeed for mXAUT product
 * @author TermMax Labs
 */
contract MXautDataFeed is DataFeed, MXautMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc DataFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return M_XAUT_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
