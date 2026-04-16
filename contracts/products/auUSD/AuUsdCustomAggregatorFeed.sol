// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/CustomAggregatorV3CompatibleFeed.sol";
import "./AuUsdMidasAccessControlRoles.sol";

/**
 * @title AuUsdCustomAggregatorFeed
 * @notice AggregatorV3 compatible feed for auUSD,
 * where price is submitted manually by feed admins
 * @author TermMax Labs
 */
contract AuUsdCustomAggregatorFeed is
    CustomAggregatorV3CompatibleFeed,
    AuUsdMidasAccessControlRoles
{
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc CustomAggregatorV3CompatibleFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return AU_USD_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
