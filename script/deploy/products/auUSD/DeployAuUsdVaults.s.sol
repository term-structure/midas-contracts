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
import {auUSD} from "contracts/products/auUSD/auUSD.sol";
import {AuUsdDepositVault} from "contracts/products/auUSD/AuUsdDepositVault.sol";
import {AuUsdRedemptionVault} from "contracts/products/auUSD/AuUsdRedemptionVault.sol";

/**
 * @title DeployAuUsdVaults
 * @notice Deploys auUSD deposit and redemption vaults.
 *         Reads mToken + data feed addresses from the mToken deployment JSON
 *         (auUSD-mtoken.json) or from environment variables.
 *
 * Output: deployment/<network>/auUSD-vaults.json
 */
contract DeployAuUsdVaults is BaseProductDeployment {
    string internal constant MTOKEN_ARTIFACT = "auUSD-mtoken";
    string internal constant ARTIFACT_NAME = "auUSD-vaults";

    // --- Addresses loaded from mToken deployment or env ---
    address internal mTokenProxy;
    address internal mTokenDataFeedProxy;
    address internal paymentTokenDataFeedProxy;
    string internal paymentTokenSymbol;

    // --- External addresses (from env) ---
    IERC20Metadata internal paymentToken;
    address internal sanctionsList;
    address internal tokenReceiver;
    address internal feeReceiver;
    address internal depositVaultAdmin;
    address internal redemptionVaultAdmin;

    // --- Deployed contracts ---
    AuUsdDepositVault internal depositVault;
    AuUsdRedemptionVault internal redemptionVault;

    // --- Implementation addresses ---
    address internal depositVaultImpl;
    address internal redemptionVaultImpl;

    // --- Vault parameters ---
    uint256 internal variationTolerance = 500;
    uint256 internal minAmount = 10 ether;
    uint256 internal minMTokenAmountForFirstDeposit = 10 ether;
    uint256 internal maxSupplyCap = 10_000_000 ether;

    uint256 internal instantFeeDeposit = 0;
    uint256 internal instantDailyLimitDeposit = 2_000_000 ether;
    uint256 internal instantFeeWithdraw = 50;
    uint256 internal instantDailyLimitWithdraw = 10_000 ether;
    uint256 internal mintAmountWithdraw = 1 ether;

    bool internal isPaymentTokenStable = true;
    uint256 internal paymentTokenDepositFee = 0;
    uint256 internal paymentTokenDepositAllowance = 100_000_000e18;
    uint256 internal paymentTokenWithdrawFee = 0;
    uint256 internal paymentTokenWithdrawAllowance = 100_000_000e18;

    uint256 internal fiatAdditionalFee = 0;
    uint256 internal fiatFlatFee = 0;
    uint256 internal minFiatRedeemAmount = 0;

    function setUp() public {
        _setUpBase();

        // Load mToken deployment addresses (env overrides JSON)
        mTokenProxy = _loadMTokenAddress("mTokenProxy", "AU_USD_MTOKEN_PROXY_ADDRESS");
        mTokenDataFeedProxy = _loadMTokenAddress("mTokenDataFeedProxy", "AU_USD_MTOKEN_DATA_FEED_PROXY_ADDRESS");

        paymentToken = IERC20Metadata(vm.envAddress(_envName("AU_USD_PAYMENT_TOKEN_ADDRESS")));
        paymentTokenSymbol = paymentToken.symbol();

        // Payment token data feed: env -> mToken JSON -> <SYMBOL>-datafeed.json
        paymentTokenDataFeedProxy = _resolvePaymentTokenDataFeed();
        sanctionsList = vm.envAddress(_envName("AU_USD_SANCTIONS_LIST_ADDRESS"));
        tokenReceiver = vm.envAddress(_envName("AU_USD_TOKEN_RECEIVER_ADDRESS"));
        feeReceiver = vm.envAddress(_envName("AU_USD_FEE_RECEIVER_ADDRESS"));
        depositVaultAdmin = vm.envAddress(_envName("AU_USD_DEPOSIT_VAULT_ADMIN_ADDRESS"));
        redemptionVaultAdmin = vm.envAddress(_envName("AU_USD_REDEMPTION_VAULT_ADMIN_ADDRESS"));

        console.log("mToken proxy:", mTokenProxy);
        console.log("mToken data feed proxy:", mTokenDataFeedProxy);
        console.log("Payment token data feed proxy:", paymentTokenDataFeedProxy);
        console.log("Payment token:", address(paymentToken));
        console.log("Sanctions list:", sanctionsList);
        console.log("Token receiver:", tokenReceiver);
        console.log("Fee receiver:", feeReceiver);
        console.log("Deposit vault admin:", depositVaultAdmin);
        console.log("Redemption vault admin:", redemptionVaultAdmin);
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        _deployVaults();
        _grantTemporaryRoles();
        _configureVaults();
        _grantRoles();
        _revokeTemporaryRoles();
        _saveDeployment();

        vm.stopBroadcast();
    }

    // -------- helpers --------

    /// @dev Try env override first, then fall back to mToken deployment JSON
    function _loadMTokenAddress(string memory jsonKey, string memory envSuffix) internal view returns (address) {
        (address envAddr, bool envExists) = _optionalEnvAddress(envSuffix);
        if (envExists) {
            return envAddr;
        }
        return _loadProductAddress(MTOKEN_ARTIFACT, jsonKey);
    }

    /// @dev Resolve payment token data feed: env -> mToken JSON -> <SYMBOL>-datafeed.json
    function _resolvePaymentTokenDataFeed() internal view returns (address) {
        (address envAddr, bool envExists) = _optionalEnvAddress("AU_USD_PAYMENT_TOKEN_DATA_FEED_ADDRESS");
        if (envExists) return envAddr;

        // Try mToken deployment JSON
        string memory mtokenFile = _deploymentFilePath(MTOKEN_ARTIFACT);
        if (vm.isFile(mtokenFile)) {
            string memory json = vm.readFile(mtokenFile);
            if (vm.keyExistsJson(json, ".paymentTokenDataFeedProxy")) {
                return vm.parseJsonAddress(json, ".paymentTokenDataFeedProxy");
            }
        }

        // Try <SYMBOL>-datafeed.json
        (address savedProxy, bool savedExists) = _loadTokenDataFeed(paymentTokenSymbol);
        require(savedExists, "Payment token data feed not found");
        return savedProxy;
    }

    // -------- deployment --------

    function _deployVaults() internal {
        depositVaultImpl = _resolveImpl(
            address(new AuUsdDepositVault()),
            "AU_USD_DEPOSIT_VAULT_IMPL_ADDRESS",
            "auUSDDepositVaultImpl",
            "auUSD deposit vault"
        );

        depositVault = AuUsdDepositVault(
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
            address(new AuUsdRedemptionVault()),
            "AU_USD_REDEMPTION_VAULT_IMPL_ADDRESS",
            "auUSDRedemptionVaultImpl",
            "auUSD redemption vault"
        );

        FiatRedeptionInitParams memory fiatParams = FiatRedeptionInitParams({
            fiatAdditionalFee: fiatAdditionalFee,
            fiatFlatFee: fiatFlatFee,
            minFiatRedeemAmount: minFiatRedeemAmount
        });

        address predictedRedemptionVault = vm.computeCreateAddress(deployerAddr, vm.getNonce(deployerAddr));
        console.log("Predicted redemption vault proxy:", predictedRedemptionVault);

        redemptionVault = AuUsdRedemptionVault(
            address(
                new ERC1967Proxy(
                    redemptionVaultImpl,
                    abi.encodeWithSelector(
                        RedemptionVault.initialize.selector,
                        address(midasAccessControl),
                        MTokenInitParams({mToken: mTokenProxy, mTokenDataFeed: mTokenDataFeedProxy}),
                        ReceiversInitParams({tokensReceiver: tokenReceiver, feeReceiver: feeReceiver}),
                        InstantInitParams({
                            instantFee: instantFeeWithdraw,
                            instantDailyLimit: instantDailyLimitWithdraw
                        }),
                        sanctionsList,
                        variationTolerance,
                        mintAmountWithdraw,
                        fiatParams,
                        predictedRedemptionVault
                    )
                )
            )
        );
        require(address(redemptionVault) == predictedRedemptionVault, "predicted redemption vault mismatch");
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

        redemptionVault.setRequestRedeemer(address(redemptionVault));
    }

    function _grantRoles() internal {
        auUSD token = auUSD(mTokenProxy);

        midasAccessControl.grantRole(token.AU_USD_MINT_OPERATOR_ROLE(), address(depositVault));
        midasAccessControl.grantRole(depositVault.vaultRole(), depositVaultAdmin);

        midasAccessControl.grantRole(token.AU_USD_BURN_OPERATOR_ROLE(), address(redemptionVault));
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
