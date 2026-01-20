// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/DataFeed.sol";
import "./PUSDCMidasAccessControlRoles.sol";

/**
 * @title PUSDCDataFeed
 * @notice DataFeed for pUSDC product
 * @author TermMax Labs
 */
contract PUSDCDataFeed is DataFeed, PUSDCMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc DataFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return P_USDC_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
