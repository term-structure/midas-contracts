// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "forge-std/console.sol";

import {BaseProductDeployment} from "script/deploy/common/BaseProductDeployment.s.sol";
import {DataFeed} from "contracts/feeds/DataFeed.sol";
import {TermPrime} from "contracts/products/termPrime/TermPrime.sol";
import {TermPrimeCustomAggregatorFeed} from
    "contracts/products/termPrime/TermPrimeCustomAggregatorFeed.sol";
import {TermPrimeDataFeed} from "contracts/products/termPrime/TermPrimeDataFeed.sol";

/**
 * @title DeployTermPrimeMToken
 * @notice Deploys the TermPrime mToken, custom aggregator price feed,
 *         and data feeds (mToken + payment token). Saves implementation
 *         addresses to shared-implementations.json for cross-product reuse.
 *         Reuses the existing access control and USDC data feed.
 *
 * Output: deployment/<network>/termPrime-mtoken.json
 */
contract DeployTermPrimeMToken is BaseProductDeployment {
    string internal constant ARTIFACT_NAME = "termPrime-mtoken";

    // --- External addresses (from env) ---
    IERC20Metadata internal paymentToken;
    address internal paymentTokenPriceFeed;
    string internal paymentTokenSymbol;
    address internal pauseOperator;
    address internal feedAdmin;

    // --- Deployed contracts ---
    TermPrime internal termPrime;
    TermPrimeCustomAggregatorFeed internal priceFeed;
    TermPrimeDataFeed internal mTokenDataFeed;
    DataFeed internal paymentTokenDataFeed;

    // --- Implementation addresses ---
    address internal mTokenImpl;
    address internal customAggregatorFeedImpl;
    address internal dataFeedImpl;
    address internal paymentTokenDataFeedImpl;

    // --- mToken price feed parameters ---
    int192 internal mTokenMinPrice = 0.1e8;
    int192 internal mTokenMaxPrice = 100e8;
    uint256 internal mTokenMaxDeviation = 10e8;
    // 7-day healthy diff matches the strategy vault's data feed update cycle
    uint256 internal mTokenHealthyDiff = 7 days;
    int192 internal mTokenInitialPrice = 1e8;

    // --- Payment token data feed parameters (used only when deploying a new feed) ---
    int192 internal paymentTokenMinPrice = 99_700_000;
    int192 internal paymentTokenMaxPrice = 100_300_000;
    uint256 internal paymentTokenHealthyDiff = 1 days;

    function setUp() public {
        _setUpBase();

        paymentToken = IERC20Metadata(vm.envAddress(_envName("TERM_PRIME_PAYMENT_TOKEN_ADDRESS")));
        paymentTokenPriceFeed = vm.envAddress(_envName("TERM_PRIME_PAYMENT_TOKEN_PRICE_FEED_ADDRESS"));
        paymentTokenSymbol = paymentToken.symbol();
        pauseOperator = vm.envAddress(_envName("TERM_PRIME_PAUSE_OPERATOR_ADDRESS"));
        feedAdmin = vm.envAddress(_envName("TERM_PRIME_FEED_ADMIN_ADDRESS"));

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
            address(new TermPrime()),
            "TERM_PRIME_MTOKEN_IMPL_ADDRESS",
            "termPrimeMTokenImpl",
            "TermPrime mToken"
        );

        termPrime = TermPrime(
            address(
                new ERC1967Proxy(
                    mTokenImpl, abi.encodeWithSignature("initialize(address)", address(midasAccessControl))
                )
            )
        );
        console.log("TermPrime proxy:", address(termPrime));
    }

    function _deployFeeds() internal {
        customAggregatorFeedImpl = _resolveImpl(
            address(new TermPrimeCustomAggregatorFeed()),
            "TERM_PRIME_CUSTOM_AGGREGATOR_FEED_IMPL_ADDRESS",
            "termPrimeCustomAggregatorFeedImpl",
            "TermPrime custom aggregator feed"
        );

        priceFeed = TermPrimeCustomAggregatorFeed(
            address(
                new ERC1967Proxy(
                    customAggregatorFeedImpl,
                    abi.encodeWithSignature(
                        "initialize(address,int192,int192,uint256,string)",
                        address(midasAccessControl),
                        mTokenMinPrice,
                        mTokenMaxPrice,
                        mTokenMaxDeviation,
                        "primeUSDC/USD Custom Aggregator Feed"
                    )
                )
            )
        );
        console.log("Price feed proxy:", address(priceFeed));

        dataFeedImpl = _resolveImpl(
            address(new TermPrimeDataFeed()),
            "TERM_PRIME_DATA_FEED_IMPL_ADDRESS",
            "termPrimeDataFeedImpl",
            "TermPrime data feed"
        );

        mTokenDataFeed = TermPrimeDataFeed(
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
            "TERM_PRIME_PAYMENT_TOKEN_DATA_FEED_IMPL_ADDRESS",
            "genericDataFeedImpl",
            "Generic payment token data feed"
        );

        // Payment token data feed: env override → <SYMBOL>-datafeed.json → deploy new
        // Set TERM_PRIME_PAYMENT_TOKEN_DATA_FEED_ADDRESS to reuse an existing USDC data feed
        (address envDataFeed, bool envExists) = _optionalEnvAddress("TERM_PRIME_PAYMENT_TOKEN_DATA_FEED_ADDRESS");
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
        // Temporary feed admin role for deployer
        midasAccessControl.grantRole(priceFeed.feedAdminRole(), deployerAddr);

        priceFeed.setRoundData(mTokenInitialPrice);
        console.log("Initial price set");

        // Revoke temporary role if not the permanent feed admin
        if (deployerAddr != feedAdmin) {
            midasAccessControl.revokeRole(priceFeed.feedAdminRole(), deployerAddr);
        }
    }

    function _grantRoles() internal {
        midasAccessControl.grantRole(termPrime.TERM_PRIME_PAUSE_OPERATOR_ROLE(), pauseOperator);
        midasAccessControl.grantRole(priceFeed.feedAdminRole(), feedAdmin);
    }

    // -------- persistence --------

    function _saveDeployment() internal {
        string memory objectKey = ARTIFACT_NAME;

        vm.serializeAddress(objectKey, "mTokenImpl", mTokenImpl);
        vm.serializeAddress(objectKey, "mTokenProxy", address(termPrime));
        vm.serializeAddress(objectKey, "priceFeedImpl", customAggregatorFeedImpl);
        vm.serializeAddress(objectKey, "priceFeedProxy", address(priceFeed));
        vm.serializeAddress(objectKey, "dataFeedImpl", dataFeedImpl);
        vm.serializeAddress(objectKey, "paymentTokenDataFeedImpl", paymentTokenDataFeedImpl);
        vm.serializeAddress(objectKey, "mTokenDataFeedProxy", address(mTokenDataFeed));
        string memory json =
            vm.serializeAddress(objectKey, "paymentTokenDataFeedProxy", address(paymentTokenDataFeed));

        _saveDeploymentJson(ARTIFACT_NAME, json);
    }
}
