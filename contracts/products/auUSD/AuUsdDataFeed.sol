// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/DataFeed.sol";
import "./AuUsdMidasAccessControlRoles.sol";

/**
 * @title AuUsdDataFeed
 * @notice DataFeed for auUSD product
 * @author TermMax Labs
 */
contract AuUsdDataFeed is DataFeed, AuUsdMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc DataFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return AU_USD_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
