// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/console.sol";

import {BaseProductDeployment} from "script/deploy/common/BaseProductDeployment.s.sol";
import {DepositVault} from "contracts/DepositVault.sol";
import {RedemptionVault} from "contracts/RedemptionVault.sol";
import {MTokenInitParams, ReceiversInitParams, InstantInitParams} from "contracts/interfaces/IManageableVault.sol";
import {FiatRedeptionInitParams} from "contracts/interfaces/IRedemptionVault.sol";
import {XAUEUSDT} from "contracts/products/XAUEUSDT/XAUEUSDT.sol";
import {XaueUsdtDepositVault} from "contracts/products/XAUEUSDT/XaueUsdtDepositVault.sol";
import {XaueUsdtRedemptionVault} from "contracts/products/XAUEUSDT/XaueUsdtRedemptionVault.sol";

/**
 * @title DeployXAUEUSDTVaults
 * @notice Deploys Ethereum mainnet XAUE-USDT vaults for the XAUE-USDT product.
 *
 * Output: deployment/<network>/XAUE-USDT-vaults.json
 */
contract DeployXAUEUSDTVaults is BaseProductDeployment {
    string internal constant MTOKEN_ARTIFACT = "XAUE-USDT-mtoken";
    string internal constant ARTIFACT_NAME = "XAUE-USDT-vaults";

    bytes4 internal constant DEPOSIT_REQUEST_SELECTOR = bytes4(keccak256("depositRequest(address,uint256,bytes32)"));
    bytes4 internal constant DEPOSIT_REQUEST_WITH_CUSTOM_RECIPIENT_SELECTOR =
        bytes4(keccak256("depositRequest(address,uint256,bytes32,address)"));
    bytes4 internal constant REDEEM_INSTANT_SELECTOR = bytes4(keccak256("redeemInstant(address,uint256,uint256)"));
    bytes4 internal constant REDEEM_INSTANT_WITH_CUSTOM_RECIPIENT_SELECTOR =
        bytes4(keccak256("redeemInstant(address,uint256,uint256,address)"));

    // --- Addresses loaded from mToken deployment or env ---
    address internal mTokenProxy;
    address internal mTokenDataFeedProxy;
    address internal paymentTokenDataFeedProxy;
    string internal paymentTokenSymbol;

    // --- External addresses ---
    IERC20Metadata internal paymentToken;
    address internal sanctionsList;
    address internal tokenReceiver;
    address internal feeReceiver;
    address internal depositVaultAdmin;
    address internal redemptionVaultAdmin;
    address internal requestRedeemer;

    // --- Deployed contracts ---
    XaueUsdtDepositVault internal depositVault;
    XaueUsdtRedemptionVault internal redemptionVault;

    // --- Implementation addresses ---
    address internal depositVaultImpl;
    address internal redemptionVaultImpl;

    // --- Vault parameters ---
    uint256 internal variationTolerance = 30;
    uint256 internal minAmount = 1 ether;
    uint256 internal minMTokenAmountForFirstDeposit = 1 ether;
    uint256 internal maxSupplyCap = 1_000_000_000 ether;

    uint256 internal instantFeeDeposit = 0;
    uint256 internal instantDailyLimitDeposit = type(uint256).max;
    uint256 internal instantFeeWithdraw = 0;
    uint256 internal instantDailyLimitWithdraw = 1 ether;

    bool internal isPaymentTokenStable = true;
    uint256 internal paymentTokenDepositFee = 0;
    uint256 internal paymentTokenDepositAllowance = type(uint256).max;
    uint256 internal paymentTokenWithdrawFee = 0;
    uint256 internal paymentTokenWithdrawAllowance = type(uint256).max;

    uint256 internal fiatAdditionalFee = 0;
    uint256 internal fiatFlatFee = 0;
    uint256 internal minFiatRedeemAmount = 0;

    function setUp() public {
        _setUpBase();
        _requireEthMainnet();

        mTokenProxy = _loadMTokenAddress("mTokenProxy", "XAUE_USDT_MTOKEN_PROXY_ADDRESS");
        mTokenDataFeedProxy = _loadMTokenAddress("mTokenDataFeedProxy", "XAUE_USDT_MTOKEN_DATA_FEED_PROXY_ADDRESS");

        paymentToken = IERC20Metadata(vm.envAddress(_envName("XAUE_USDT_PAYMENT_TOKEN_ADDRESS")));
        paymentTokenSymbol = paymentToken.symbol();
        paymentTokenDataFeedProxy = _resolvePaymentTokenDataFeed();
        sanctionsList = vm.envAddress(_envName("XAUE_USDT_SANCTIONS_LIST_ADDRESS"));
        tokenReceiver = vm.envAddress(_envName("XAUE_USDT_TOKEN_RECEIVER_ADDRESS"));
        feeReceiver = vm.envAddress(_envName("XAUE_USDT_FEE_RECEIVER_ADDRESS"));
        depositVaultAdmin = vm.envAddress(_envName("XAUE_USDT_DEPOSIT_VAULT_ADMIN_ADDRESS"));
        redemptionVaultAdmin = vm.envAddress(_envName("XAUE_USDT_REDEMPTION_VAULT_ADMIN_ADDRESS"));
        requestRedeemer = vm.envAddress(_envName("XAUE_USDT_REQUEST_REDEEMER_ADDRESS"));

        console.log("mToken proxy:", mTokenProxy);
        console.log("mToken data feed proxy:", mTokenDataFeedProxy);
        console.log("Payment token data feed proxy:", paymentTokenDataFeedProxy);
        console.log("Payment token:", address(paymentToken));
        console.log("Sanctions list:", sanctionsList);
        console.log("Token receiver:", tokenReceiver);
        console.log("Fee receiver:", feeReceiver);
        console.log("Deposit vault admin:", depositVaultAdmin);
        console.log("Redemption vault admin:", redemptionVaultAdmin);
        console.log("Request redeemer:", requestRedeemer);
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        _deployVaults();
        _grantTemporaryRoles();
        _configureVaults();
        _pauseRequestMintingAndInstantRedemptions();
        _grantRoles();
        _revokeTemporaryRoles();
        _saveDeployment();

        vm.stopBroadcast();
    }

    // -------- helpers --------

    function _loadMTokenAddress(string memory jsonKey, string memory envSuffix) internal view returns (address) {
        (address envAddr, bool envExists) = _optionalEnvAddress(envSuffix);
        if (envExists) {
            return envAddr;
        }
        return _loadProductAddress(MTOKEN_ARTIFACT, jsonKey);
    }

    function _resolvePaymentTokenDataFeed() internal view returns (address) {
        (address envAddr, bool envExists) = _optionalEnvAddress("XAUE_USDT_PAYMENT_TOKEN_DATA_FEED_ADDRESS");
        if (envExists) return envAddr;

        string memory mtokenFile = _deploymentFilePath(MTOKEN_ARTIFACT);
        if (vm.isFile(mtokenFile)) {
            string memory json = vm.readFile(mtokenFile);
            if (vm.keyExistsJson(json, ".paymentTokenDataFeedProxy")) {
                return vm.parseJsonAddress(json, ".paymentTokenDataFeedProxy");
            }
        }

        (address savedProxy, bool savedExists) = _loadTokenDataFeed(paymentTokenSymbol);
        require(savedExists, "Payment token data feed not found");
        return savedProxy;
    }

    function _requireEthMainnet() internal view {
        require(block.chainid == 1, "XAUE-USDT: Ethereum mainnet only");
    }

    // -------- deployment --------

    function _deployVaults() internal {
        depositVaultImpl = _resolveImpl(
            address(new XaueUsdtDepositVault()),
            "XAUE_USDT_DEPOSIT_VAULT_IMPL_ADDRESS",
            "xaueUSDTDepositVaultImpl",
            "XAUE-USDT deposit vault"
        );

        depositVault = XaueUsdtDepositVault(
            address(
                new ERC1967Proxy(
                    depositVaultImpl,
                    abi.encodeWithSelector(
                        DepositVault.initialize.selector,
                        address(midasAccessControl),
                        MTokenInitParams({mToken: mTokenProxy, mTokenDataFeed: mTokenDataFeedProxy}),
                        ReceiversInitParams({tokensReceiver: tokenReceiver, feeReceiver: feeReceiver}),
                        InstantInitParams({instantFee: instantFeeDeposit, instantDailyLimit: instantDailyLimitDeposit}),
                        sanctionsList,
                        variationTolerance,
                        minAmount,
                        minMTokenAmountForFirstDeposit,
                        maxSupplyCap
                    )
                )
            )
        );
        console.log("Deposit vault proxy:", address(depositVault));

        redemptionVaultImpl = _resolveImpl(
            address(new XaueUsdtRedemptionVault()),
            "XAUE_USDT_REDEMPTION_VAULT_IMPL_ADDRESS",
            "xaueUSDTRedemptionVaultImpl",
            "XAUE-USDT redemption vault"
        );

        FiatRedeptionInitParams memory fiatParams = FiatRedeptionInitParams({
            fiatAdditionalFee: fiatAdditionalFee, fiatFlatFee: fiatFlatFee, minFiatRedeemAmount: minFiatRedeemAmount
        });

        redemptionVault = XaueUsdtRedemptionVault(
            address(
                new ERC1967Proxy(
                    redemptionVaultImpl,
                    abi.encodeWithSelector(
                        RedemptionVault.initialize.selector,
                        address(midasAccessControl),
                        MTokenInitParams({mToken: mTokenProxy, mTokenDataFeed: mTokenDataFeedProxy}),
                        ReceiversInitParams({tokensReceiver: tokenReceiver, feeReceiver: feeReceiver}),
                        InstantInitParams({
                            instantFee: instantFeeWithdraw, instantDailyLimit: instantDailyLimitWithdraw
                        }),
                        sanctionsList,
                        variationTolerance,
                        minAmount,
                        fiatParams,
                        requestRedeemer
                    )
                )
            )
        );
        console.log("Redemption vault proxy:", address(redemptionVault));
    }

    // -------- configure --------

    function _grantTemporaryRoles() internal {
        midasAccessControl.grantRole(depositVault.vaultRole(), deployerAddr);
        midasAccessControl.grantRole(redemptionVault.vaultRole(), deployerAddr);
    }

    function _configureVaults() internal {
        depositVault.addPaymentToken(
            address(paymentToken),
            paymentTokenDataFeedProxy,
            paymentTokenDepositFee,
            paymentTokenDepositAllowance,
            isPaymentTokenStable
        );

        redemptionVault.addPaymentToken(
            address(paymentToken),
            paymentTokenDataFeedProxy,
            paymentTokenWithdrawFee,
            paymentTokenWithdrawAllowance,
            isPaymentTokenStable
        );
    }

    function _pauseRequestMintingAndInstantRedemptions() internal {
        depositVault.pauseFn(DEPOSIT_REQUEST_SELECTOR);
        depositVault.pauseFn(DEPOSIT_REQUEST_WITH_CUSTOM_RECIPIENT_SELECTOR);

        redemptionVault.pauseFn(REDEEM_INSTANT_SELECTOR);
        redemptionVault.pauseFn(REDEEM_INSTANT_WITH_CUSTOM_RECIPIENT_SELECTOR);
    }

    function _grantRoles() internal {
        XAUEUSDT token = XAUEUSDT(mTokenProxy);

        midasAccessControl.grantRole(token.XAUE_USDT_MINT_OPERATOR_ROLE(), address(depositVault));
        midasAccessControl.grantRole(depositVault.vaultRole(), depositVaultAdmin);

        midasAccessControl.grantRole(token.XAUE_USDT_BURN_OPERATOR_ROLE(), address(redemptionVault));
        midasAccessControl.grantRole(redemptionVault.vaultRole(), redemptionVaultAdmin);
    }

    function _revokeTemporaryRoles() internal {
        if (deployerAddr != depositVaultAdmin) {
            midasAccessControl.revokeRole(depositVault.vaultRole(), deployerAddr);
        }
        if (deployerAddr != redemptionVaultAdmin) {
            midasAccessControl.revokeRole(redemptionVault.vaultRole(), deployerAddr);
        }
    }

    // -------- persistence --------

    function _saveDeployment() internal {
        string memory objectKey = ARTIFACT_NAME;

        vm.serializeAddress(objectKey, "depositVaultImpl", depositVaultImpl);
        vm.serializeAddress(objectKey, "depositVaultProxy", address(depositVault));
        vm.serializeAddress(objectKey, "redemptionVaultImpl", redemptionVaultImpl);
        string memory json = vm.serializeAddress(objectKey, "redemptionVaultProxy", address(redemptionVault));

        _saveDeploymentJson(ARTIFACT_NAME, json);
    }
}
