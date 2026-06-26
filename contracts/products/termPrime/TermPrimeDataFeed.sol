// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/DataFeed.sol";
import "./TermPrimeMidasAccessControlRoles.sol";

/**
 * @title TermPrimeDataFeed
 * @notice DataFeed for termPrime product
 * @author TermMax Labs
 */
contract TermPrimeDataFeed is DataFeed, TermPrimeMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc DataFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return TERM_PRIME_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
