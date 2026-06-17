// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "forge-std/console.sol";

import {BaseProductDeployment} from "script/deploy/common/BaseProductDeployment.s.sol";
import {DataFeed} from "contracts/feeds/DataFeed.sol";
import {XAUEUSDT} from "contracts/products/XAUEUSDT/XAUEUSDT.sol";
import {XaueUsdtCustomAggregatorFeed} from "contracts/products/XAUEUSDT/XaueUsdtCustomAggregatorFeed.sol";
import {XaueUsdtDataFeed} from "contracts/products/XAUEUSDT/XaueUsdtDataFeed.sol";

/**
 * @title DeployXAUEUSDTMToken
 * @notice Deploys the XAUE-USDT mToken for the Ethereum mainnet XAUE-USDT product.
 *
 * Output: deployment/<network>/XAUE-USDT-mtoken.json
 */
contract DeployXAUEUSDTMToken is BaseProductDeployment {
    string internal constant ARTIFACT_NAME = "XAUE-USDT-mtoken";

    // --- External addresses ---
    IERC20Metadata internal paymentToken;
    address internal paymentTokenPriceFeed;
    string internal paymentTokenSymbol;
    address internal pauseOperator;
    address internal feedAdmin;

    // --- Deployed contracts ---
    XAUEUSDT internal token;
    XaueUsdtCustomAggregatorFeed internal priceFeed;
    XaueUsdtDataFeed internal mTokenDataFeed;
    DataFeed internal paymentTokenDataFeed;

    // --- Implementation addresses ---
    address internal mTokenImpl;
    address internal customAggregatorFeedImpl;
    address internal dataFeedImpl;
    address internal paymentTokenDataFeedImpl;

    // --- mToken price feed parameters: expected 1:1 to USDT/USD ---
    int192 internal mTokenMinPrice = 99_700_000;
    int192 internal mTokenMaxPrice = 100_300_000;
    uint256 internal mTokenMaxDeviation = 300_000;
    uint256 internal mTokenHealthyDiff = 365 days;
    int192 internal mTokenInitialPrice = 100_000_000;

    // --- Payment token data feed parameters: expected 1:1 to USD ---
    int192 internal paymentTokenMinPrice = 99_700_000;
    int192 internal paymentTokenMaxPrice = 100_300_000;
    uint256 internal paymentTokenHealthyDiff = 1 days;

    function setUp() public {
        _setUpBase();
        _requireEthMainnet();

        paymentToken = IERC20Metadata(vm.envAddress(_envName("XAUE_USDT_PAYMENT_TOKEN_ADDRESS")));
        paymentTokenPriceFeed = vm.envAddress(_envName("XAUE_USDT_PAYMENT_TOKEN_PRICE_FEED_ADDRESS"));
        paymentTokenSymbol = paymentToken.symbol();
        pauseOperator = vm.envAddress(_envName("XAUE_USDT_PAUSE_OPERATOR_ADDRESS"));
        feedAdmin = vm.envAddress(_envName("XAUE_USDT_FEED_ADMIN_ADDRESS"));

        console.log("Payment token:", address(paymentToken));
        console.log("Payment token symbol:", paymentTokenSymbol);
        console.log("Payment token price feed:", paymentTokenPriceFeed);
        console.log("Pause operator:", pauseOperator);
        console.log("Feed admin:", feedAdmin);
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

    // -------- deployment --------

    function _deployMToken() internal {
        mTokenImpl = _resolveImpl(
            address(new XAUEUSDT()), "XAUE_USDT_MTOKEN_IMPL_ADDRESS", "xaueUSDTMTokenImpl", "XAUE-USDT mToken"
        );

        token = XAUEUSDT(
            address(
                new ERC1967Proxy(
                    mTokenImpl, abi.encodeWithSignature("initialize(address)", address(midasAccessControl))
                )
            )
        );
        console.log("XAUE-USDT proxy:", address(token));
    }

    function _deployFeeds() internal {
        customAggregatorFeedImpl = _resolveImpl(
            address(new XaueUsdtCustomAggregatorFeed()),
            "XAUE_USDT_CUSTOM_AGGREGATOR_FEED_IMPL_ADDRESS",
            "xaueUSDTCustomAggregatorFeedImpl",
            "XAUE-USDT custom aggregator feed"
        );

        priceFeed = XaueUsdtCustomAggregatorFeed(
            address(
                new ERC1967Proxy(
                    customAggregatorFeedImpl,
                    abi.encodeWithSignature(
                        "initialize(address,int192,int192,uint256,string)",
                        address(midasAccessControl),
                        mTokenMinPrice,
                        mTokenMaxPrice,
                        mTokenMaxDeviation,
                        "XAUE-USDT/USD Custom Aggregator Feed"
                    )
                )
            )
        );
        console.log("Price feed proxy:", address(priceFeed));

        dataFeedImpl = _resolveImpl(
            address(new XaueUsdtDataFeed()),
            "XAUE_USDT_DATA_FEED_IMPL_ADDRESS",
            "xaueUSDTDataFeedImpl",
            "XAUE-USDT data feed"
        );

        mTokenDataFeed = XaueUsdtDataFeed(
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
        console.log("mToken data feed proxy:", address(mTokenDataFeed));

        paymentTokenDataFeedImpl = _resolveImpl(
            address(new DataFeed()),
            "XAUE_USDT_PAYMENT_TOKEN_DATA_FEED_IMPL_ADDRESS",
            "genericDataFeedImpl",
            "Generic payment token data feed"
        );

        (address envDataFeed, bool envExists) = _optionalEnvAddress("XAUE_USDT_PAYMENT_TOKEN_DATA_FEED_ADDRESS");
        if (envExists) {
            paymentTokenDataFeed = DataFeed(envDataFeed);
            console.log("Reusing payment token data feed (env):", envDataFeed);
            _saveTokenDataFeed(
                paymentTokenSymbol, address(paymentTokenDataFeed), paymentTokenDataFeedImpl, paymentTokenPriceFeed
            );
        } else {
            (address savedProxy, bool savedExists) = _loadTokenDataFeed(paymentTokenSymbol);
            if (savedExists) {
                paymentTokenDataFeed = DataFeed(savedProxy);
                console.log("Reusing payment token data feed (saved):", savedProxy);
            } else {
                paymentTokenDataFeed = DataFeed(
                    address(
                        new ERC1967Proxy(
                            paymentTokenDataFeedImpl,
                            abi.encodeWithSignature(
                                "initialize(address,address,uint256,int256,int256)",
                                address(midasAccessControl),
                                paymentTokenPriceFeed,
                                paymentTokenHealthyDiff,
                                paymentTokenMinPrice,
                                paymentTokenMaxPrice
                            )
                        )
                    )
                );
                console.log("Payment token data feed proxy:", address(paymentTokenDataFeed));
                _saveTokenDataFeed(
                    paymentTokenSymbol, address(paymentTokenDataFeed), paymentTokenDataFeedImpl, paymentTokenPriceFeed
                );
            }
        }
    }

    // -------- configure --------

    function _setInitialPrice() internal {
        midasAccessControl.grantRole(priceFeed.feedAdminRole(), deployerAddr);

        priceFeed.setRoundData(mTokenInitialPrice);
        console.log("Initial price set");

        if (deployerAddr != feedAdmin) {
            midasAccessControl.revokeRole(priceFeed.feedAdminRole(), deployerAddr);
        }
    }

    function _grantRoles() internal {
        midasAccessControl.grantRole(token.XAUE_USDT_PAUSE_OPERATOR_ROLE(), pauseOperator);
        midasAccessControl.grantRole(priceFeed.feedAdminRole(), feedAdmin);
    }

    function _requireEthMainnet() internal view {
        require(block.chainid == 1, "XAUE-USDT: Ethereum mainnet only");
    }

    // -------- persistence --------

    function _saveDeployment() internal {
        string memory objectKey = ARTIFACT_NAME;

        vm.serializeAddress(objectKey, "mTokenImpl", mTokenImpl);
        vm.serializeAddress(objectKey, "mTokenProxy", address(token));
        vm.serializeAddress(objectKey, "priceFeedImpl", customAggregatorFeedImpl);
        vm.serializeAddress(objectKey, "priceFeedProxy", address(priceFeed));
        vm.serializeAddress(objectKey, "dataFeedImpl", dataFeedImpl);
        vm.serializeAddress(objectKey, "paymentTokenDataFeedImpl", paymentTokenDataFeedImpl);
        vm.serializeAddress(objectKey, "mTokenDataFeedProxy", address(mTokenDataFeed));
        string memory json = vm.serializeAddress(objectKey, "paymentTokenDataFeedProxy", address(paymentTokenDataFeed));

        _saveDeploymentJson(ARTIFACT_NAME, json);
    }
}
