// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../feeds/CustomAggregatorV3CompatibleFeed.sol";
import "./PUSDCMidasAccessControlRoles.sol";

/**
 * @title PUSDCCustomAggregatorFeed
 * @notice AggregatorV3 compatible feed for pUSDC,
 * where price is submitted manually by feed admins
 * @author TermMax Labs
 */
contract PUSDCCustomAggregatorFeed is
    CustomAggregatorV3CompatibleFeed,
    PUSDCMidasAccessControlRoles
{
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc CustomAggregatorV3CompatibleFeed
     */
    function feedAdminRole() public pure override returns (bytes32) {
        return P_USDC_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE;
    }
}
