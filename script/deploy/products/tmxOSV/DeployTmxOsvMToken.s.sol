// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "forge-std/console.sol";

import {BaseProductDeployment} from "script/deploy/common/BaseProductDeployment.s.sol";
import {DataFeed} from "contracts/feeds/DataFeed.sol";
import {tmxOSV} from "contracts/products/tmxOSV/tmxOSV.sol";
import {TmxOsvCustomAggregatorFeed} from "contracts/products/tmxOSV/TmxOsvCustomAggregatorFeed.sol";
import {TmxOsvDataFeed} from "contracts/products/tmxOSV/TmxOsvDataFeed.sol";

/**
 * @title DeployTmxOsvMToken
 * @notice Deploys tmxOSV and its backend-updated NAV feed on BNB Chain.
 *
 * Output: deployment/<network>/tmxOSV-mtoken.json
 */
contract DeployTmxOsvMToken is BaseProductDeployment {
    string internal constant ARTIFACT_NAME = "tmxOSV-mtoken";

    uint256 internal constant BNB_CHAIN_ID = 56;
    address internal constant DEFAULT_ADMIN = 0x3171358cB9f27E6f5e4346Ab995675De4fCc407a;
    address internal constant BNB_USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address internal constant BNB_USDT = 0x55d398326f99059fF775485246999027B3197955;

    IERC20Metadata internal usdc;
    IERC20Metadata internal usdt;
    address internal usdcPriceFeed;
    address internal usdtPriceFeed;
    address internal productAdmin;

    tmxOSV internal token;
    TmxOsvCustomAggregatorFeed internal priceFeed;
    TmxOsvDataFeed internal mTokenDataFeed;
    DataFeed internal usdcDataFeed;
    DataFeed internal usdtDataFeed;

    address internal mTokenImpl;
    address internal customAggregatorFeedImpl;
    address internal dataFeedImpl;
    address internal paymentTokenDataFeedImpl;

    int192 internal mTokenMinPrice = 0.1e8;
    int192 internal mTokenMaxPrice = 20e8;
    uint256 internal mTokenMaxDeviation = 30e8;
    uint256 internal mTokenHealthyDiff = 9 days;
    int192 internal mTokenInitialPrice = 1e8;

    int192 internal stablecoinMinPrice = 99_700_000;
    int192 internal stablecoinMaxPrice = 100_300_000;
    uint256 internal stablecoinHealthyDiff = 1 days;

    function setUp() public {
        _setUpBase();
        require(block.chainid == BNB_CHAIN_ID, "tmxOSV: BNB Chain only");

        usdc = IERC20Metadata(_envAddressOr("TMX_OSV_USDC_ADDRESS", BNB_USDC));
        usdt = IERC20Metadata(_envAddressOr("TMX_OSV_USDT_ADDRESS", BNB_USDT));
        usdcPriceFeed = vm.envAddress("BNB_MAINNET_USDC_PRICE_FEED_ADDRESS");
        usdtPriceFeed = vm.envAddress("BNB_MAINNET_USDT_PRICE_FEED_ADDRESS");
        productAdmin = _envAddressOr("TMX_OSV_ADMIN_ADDRESS", DEFAULT_ADMIN);

        console.log("USDC:", address(usdc));
        console.log("USDT:", address(usdt));
        console.log("USDC/USD feed:", usdcPriceFeed);
        console.log("USDT/USD feed:", usdtPriceFeed);
        console.log("Product admin:", productAdmin);
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        _deployMToken();
        _deployFeeds();
        _setInitialPrice();
        _grantRoles();
        _saveDeployment();

        vm.stopBroadcast();
    }

    function _envAddressOr(string memory suffix, address defaultValue) internal view returns (address) {
        (address configured, bool exists) = _optionalEnvAddress(suffix);
        return exists ? configured : defaultValue;
    }

    function _deployMToken() internal {
        mTokenImpl =
            _resolveImpl(address(new tmxOSV()), "TMX_OSV_MTOKEN_IMPL_ADDRESS", "tmxOSVMTokenImpl", "tmxOSV mToken");

        token = tmxOSV(
            address(
                new ERC1967Proxy(
                    mTokenImpl, abi.encodeWithSignature("initialize(address)", address(midasAccessControl))
                )
            )
        );
        console.log("tmxOSV proxy:", address(token));
    }

    function _deployFeeds() internal {
        customAggregatorFeedImpl = _resolveImpl(
            address(new TmxOsvCustomAggregatorFeed()),
            "TMX_OSV_CUSTOM_AGGREGATOR_FEED_IMPL_ADDRESS",
            "tmxOSVCustomAggregatorFeedImpl",
            "tmxOSV custom aggregator feed"
        );

        priceFeed = TmxOsvCustomAggregatorFeed(
            address(
                new ERC1967Proxy(
                    customAggregatorFeedImpl,
                    abi.encodeWithSignature(
                        "initialize(address,int192,int192,uint256,string)",
                        address(midasAccessControl),
                        mTokenMinPrice,
                        mTokenMaxPrice,
                        mTokenMaxDeviation,
                        "tmxOSV/USD NAV Feed"
                    )
                )
            )
        );
        console.log("tmxOSV price feed proxy:", address(priceFeed));

        dataFeedImpl = _resolveImpl(
            address(new TmxOsvDataFeed()), "TMX_OSV_DATA_FEED_IMPL_ADDRESS", "tmxOSVDataFeedImpl", "tmxOSV data feed"
        );

        mTokenDataFeed = TmxOsvDataFeed(
            address(
                new ERC1967Proxy(
                    dataFeedImpl,
                    abi.encodeWithSignature(
                        "initialize(address,address,uint256,int256,int256)",
                        address(midasAccessControl),
                        address(priceFeed),
                        mTokenHealthyDiff,
                        mTokenMinPrice,
                        mTokenMaxPrice
                    )
                )
            )
        );
        console.log("tmxOSV data feed proxy:", address(mTokenDataFeed));

        paymentTokenDataFeedImpl = _resolveImpl(
            address(new DataFeed()),
            "TMX_OSV_PAYMENT_TOKEN_DATA_FEED_IMPL_ADDRESS",
            "genericDataFeedImpl",
            "Generic payment token data feed"
        );

        usdcDataFeed = _resolvePaymentTokenDataFeed(usdc, usdcPriceFeed, "TMX_OSV_USDC_DATA_FEED_ADDRESS");
        usdtDataFeed = _resolvePaymentTokenDataFeed(usdt, usdtPriceFeed, "TMX_OSV_USDT_DATA_FEED_ADDRESS");
    }

    function _resolvePaymentTokenDataFeed(IERC20Metadata paymentToken, address aggregator, string memory envSuffix)
        internal
        returns (DataFeed result)
    {
        string memory symbol = paymentToken.symbol();
        (address envDataFeed, bool envExists) = _optionalEnvAddress(envSuffix);

        if (envExists) {
            result = DataFeed(envDataFeed);
            console.log("Reusing payment token data feed (env):", envDataFeed);
            _saveTokenDataFeed(symbol, address(result), paymentTokenDataFeedImpl, aggregator);
            return result;
        }

        (address savedProxy, bool savedExists) = _loadTokenDataFeed(symbol);
        if (savedExists) {
            console.log("Reusing payment token data feed (saved):", savedProxy);
            return DataFeed(savedProxy);
        }

        result = DataFeed(
            address(
                new ERC1967Proxy(
                    paymentTokenDataFeedImpl,
                    abi.encodeWithSignature(
                        "initialize(address,address,uint256,int256,int256)",
                        address(midasAccessControl),
                        aggregator,
                        stablecoinHealthyDiff,
                        stablecoinMinPrice,
                        stablecoinMaxPrice
                    )
                )
            )
        );
        console.log("Payment token data feed proxy:", address(result));
        _saveTokenDataFeed(symbol, address(result), paymentTokenDataFeedImpl, aggregator);
    }

    function _setInitialPrice() internal {
        midasAccessControl.grantRole(priceFeed.feedAdminRole(), deployerAddr);
        priceFeed.setRoundData(mTokenInitialPrice);

        if (deployerAddr != productAdmin) {
            midasAccessControl.revokeRole(priceFeed.feedAdminRole(), deployerAddr);
        }
    }

    function _grantRoles() internal {
        midasAccessControl.grantRole(token.TMX_OSV_PAUSE_OPERATOR_ROLE(), productAdmin);
        midasAccessControl.grantRole(priceFeed.feedAdminRole(), productAdmin);
    }

    function _saveDeployment() internal {
        string memory objectKey = ARTIFACT_NAME;

        vm.serializeAddress(objectKey, "mTokenImpl", mTokenImpl);
        vm.serializeAddress(objectKey, "mTokenProxy", address(token));
        vm.serializeAddress(objectKey, "priceFeedImpl", customAggregatorFeedImpl);
        vm.serializeAddress(objectKey, "priceFeedProxy", address(priceFeed));
        vm.serializeAddress(objectKey, "dataFeedImpl", dataFeedImpl);
        vm.serializeAddress(objectKey, "paymentTokenDataFeedImpl", paymentTokenDataFeedImpl);
        vm.serializeAddress(objectKey, "mTokenDataFeedProxy", address(mTokenDataFeed));
        vm.serializeAddress(objectKey, "usdcDataFeedProxy", address(usdcDataFeed));
        string memory json = vm.serializeAddress(objectKey, "usdtDataFeedProxy", address(usdtDataFeed));

        _saveDeploymentJson(ARTIFACT_NAME, json);
    }
}
