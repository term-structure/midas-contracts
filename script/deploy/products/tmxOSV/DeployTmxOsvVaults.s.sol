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
import {tmxOSV} from "contracts/products/tmxOSV/tmxOSV.sol";
import {TmxOsvDepositVault} from "contracts/products/tmxOSV/TmxOsvDepositVault.sol";
import {TmxOsvRedemptionVault} from "contracts/products/tmxOSV/TmxOsvRedemptionVault.sol";

/**
 * @title DeployTmxOsvVaults
 * @notice Deploys quote-only USDC/USDT vaults for tmxOSV on BNB Chain.
 *
 * Output: deployment/<network>/tmxOSV-vaults.json
 */
contract DeployTmxOsvVaults is BaseProductDeployment {
    string internal constant MTOKEN_ARTIFACT = "tmxOSV-mtoken";
    string internal constant ARTIFACT_NAME = "tmxOSV-vaults";

    uint256 internal constant BNB_CHAIN_ID = 56;
    address internal constant DEFAULT_ADMIN = 0x3171358cB9f27E6f5e4346Ab995675De4fCc407a;
    address internal constant DEFAULT_FUND = 0x96F1e9493F72B16B611a249f226cAcF0b27EBF51;
    address internal constant BNB_USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address internal constant BNB_USDT = 0x55d398326f99059fF775485246999027B3197955;

    address internal mTokenProxy;
    address internal mTokenDataFeedProxy;
    address internal usdcDataFeedProxy;
    address internal usdtDataFeedProxy;

    IERC20Metadata internal usdc;
    IERC20Metadata internal usdt;
    address internal sanctionsList;
    address internal productAdmin;
    address internal fund;

    TmxOsvDepositVault internal depositVault;
    TmxOsvRedemptionVault internal redemptionVault;

    address internal depositVaultImpl;
    address internal redemptionVaultImpl;

    uint256 internal variationTolerance = 500;
    uint256 internal minAmount = 10 ether;
    uint256 internal minMTokenAmountForFirstDeposit = 10 ether;
    uint256 internal maxSupplyCap = 10_000_000 ether;

    // Keep instant limits below the minimum operation amounts so deposits
    // and redemptions must use the request flow.
    uint256 internal instantFeeDeposit = 0;
    uint256 internal instantDailyLimitDeposit = 1;
    uint256 internal instantFeeWithdraw = 0;
    uint256 internal instantDailyLimitWithdraw = 1;
    uint256 internal minAmountWithdraw = 1 ether;

    bool internal isPaymentTokenStable = true;
    uint256 internal paymentTokenDepositFee = 0;
    uint256 internal paymentTokenDepositAllowance = 100_000_000 ether;
    uint256 internal paymentTokenWithdrawFee = 30; // 0.3%
    uint256 internal paymentTokenWithdrawAllowance = 100_000_000 ether;

    uint256 internal fiatAdditionalFee = 0;
    uint256 internal fiatFlatFee = 0;
    uint256 internal minFiatRedeemAmount = 0;

    function setUp() public {
        _setUpBase();
        require(block.chainid == BNB_CHAIN_ID, "tmxOSV: BNB Chain only");

        mTokenProxy = _loadMTokenAddress("mTokenProxy", "TMX_OSV_MTOKEN_PROXY_ADDRESS");
        mTokenDataFeedProxy = _loadMTokenAddress("mTokenDataFeedProxy", "TMX_OSV_MTOKEN_DATA_FEED_PROXY_ADDRESS");

        usdc = IERC20Metadata(_envAddressOr("TMX_OSV_USDC_ADDRESS", BNB_USDC));
        usdt = IERC20Metadata(_envAddressOr("TMX_OSV_USDT_ADDRESS", BNB_USDT));
        usdcDataFeedProxy =
            _resolvePaymentTokenDataFeed("usdcDataFeedProxy", "TMX_OSV_USDC_DATA_FEED_ADDRESS", usdc.symbol());
        usdtDataFeedProxy =
            _resolvePaymentTokenDataFeed("usdtDataFeedProxy", "TMX_OSV_USDT_DATA_FEED_ADDRESS", usdt.symbol());

        sanctionsList = _envAddressOr("TMX_OSV_SANCTIONS_LIST_ADDRESS", address(0));
        productAdmin = _envAddressOr("TMX_OSV_ADMIN_ADDRESS", DEFAULT_ADMIN);
        fund = _envAddressOr("TMX_OSV_FUND_ADDRESS", DEFAULT_FUND);

        console.log("mToken proxy:", mTokenProxy);
        console.log("mToken data feed proxy:", mTokenDataFeedProxy);
        console.log("USDC data feed proxy:", usdcDataFeedProxy);
        console.log("USDT data feed proxy:", usdtDataFeedProxy);
        console.log("Product admin:", productAdmin);
        console.log("Fund:", fund);
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

    function _envAddressOr(string memory suffix, address defaultValue) internal view returns (address) {
        (address configured, bool exists) = _optionalEnvAddress(suffix);
        return exists ? configured : defaultValue;
    }

    function _loadMTokenAddress(string memory jsonKey, string memory envSuffix) internal view returns (address) {
        (address envAddr, bool envExists) = _optionalEnvAddress(envSuffix);
        if (envExists) return envAddr;
        return _loadProductAddress(MTOKEN_ARTIFACT, jsonKey);
    }

    function _resolvePaymentTokenDataFeed(string memory jsonKey, string memory envSuffix, string memory symbol)
        internal
        view
        returns (address)
    {
        (address envAddr, bool envExists) = _optionalEnvAddress(envSuffix);
        if (envExists) return envAddr;

        string memory mtokenFile = _deploymentFilePath(MTOKEN_ARTIFACT);
        if (vm.isFile(mtokenFile)) {
            string memory json = vm.readFile(mtokenFile);
            string memory key = string(abi.encodePacked(".", jsonKey));
            if (vm.keyExistsJson(json, key)) {
                return vm.parseJsonAddress(json, key);
            }
        }

        (address savedProxy, bool savedExists) = _loadTokenDataFeed(symbol);
        require(savedExists, "Payment token data feed not found");
        return savedProxy;
    }

    function _deployVaults() internal {
        depositVaultImpl = _resolveImpl(
            address(new TmxOsvDepositVault()),
            "TMX_OSV_DEPOSIT_VAULT_IMPL_ADDRESS",
            "tmxOSVDepositVaultImpl",
            "tmxOSV deposit vault"
        );

        depositVault = TmxOsvDepositVault(
            address(
                new ERC1967Proxy(
                    depositVaultImpl,
                    abi.encodeWithSelector(
                        DepositVault.initialize.selector,
                        address(midasAccessControl),
                        MTokenInitParams({mToken: mTokenProxy, mTokenDataFeed: mTokenDataFeedProxy}),
                        ReceiversInitParams({tokensReceiver: fund, feeReceiver: fund}),
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
            address(new TmxOsvRedemptionVault()),
            "TMX_OSV_REDEMPTION_VAULT_IMPL_ADDRESS",
            "tmxOSVRedemptionVaultImpl",
            "tmxOSV redemption vault"
        );

        FiatRedeptionInitParams memory fiatParams = FiatRedeptionInitParams({
            fiatAdditionalFee: fiatAdditionalFee,
            fiatFlatFee: fiatFlatFee,
            minFiatRedeemAmount: minFiatRedeemAmount
        });

        redemptionVault = TmxOsvRedemptionVault(
            address(
                new ERC1967Proxy(
                    redemptionVaultImpl,
                    abi.encodeWithSelector(
                        RedemptionVault.initialize.selector,
                        address(midasAccessControl),
                        MTokenInitParams({mToken: mTokenProxy, mTokenDataFeed: mTokenDataFeedProxy}),
                        ReceiversInitParams({tokensReceiver: fund, feeReceiver: fund}),
                        InstantInitParams({instantFee: instantFeeWithdraw, instantDailyLimit: instantDailyLimitWithdraw}),
                        sanctionsList,
                        variationTolerance,
                        minAmountWithdraw,
                        fiatParams,
                        fund
                    )
                )
            )
        );
        console.log("Redemption vault proxy:", address(redemptionVault));
    }

    function _grantTemporaryRoles() internal {
        midasAccessControl.grantRole(depositVault.vaultRole(), deployerAddr);
        midasAccessControl.grantRole(redemptionVault.vaultRole(), deployerAddr);
    }

    function _configureVaults() internal {
        _addPaymentToken(address(usdc), usdcDataFeedProxy);
        _addPaymentToken(address(usdt), usdtDataFeedProxy);
    }

    function _addPaymentToken(address paymentToken, address dataFeed) internal {
        depositVault.addPaymentToken(
            paymentToken, dataFeed, paymentTokenDepositFee, paymentTokenDepositAllowance, isPaymentTokenStable
        );
        redemptionVault.addPaymentToken(
            paymentToken, dataFeed, paymentTokenWithdrawFee, paymentTokenWithdrawAllowance, isPaymentTokenStable
        );
    }

    function _grantRoles() internal {
        tmxOSV token = tmxOSV(mTokenProxy);

        midasAccessControl.grantRole(token.TMX_OSV_MINT_OPERATOR_ROLE(), address(depositVault));
        midasAccessControl.grantRole(depositVault.vaultRole(), productAdmin);

        midasAccessControl.grantRole(token.TMX_OSV_BURN_OPERATOR_ROLE(), address(redemptionVault));
        midasAccessControl.grantRole(redemptionVault.vaultRole(), productAdmin);
    }

    function _revokeTemporaryRoles() internal {
        if (deployerAddr != productAdmin) {
            midasAccessControl.revokeRole(depositVault.vaultRole(), deployerAddr);
            midasAccessControl.revokeRole(redemptionVault.vaultRole(), deployerAddr);
        }
    }

    function _saveDeployment() internal {
        string memory objectKey = ARTIFACT_NAME;

        vm.serializeAddress(objectKey, "depositVaultImpl", depositVaultImpl);
        vm.serializeAddress(objectKey, "depositVaultProxy", address(depositVault));
        vm.serializeAddress(objectKey, "redemptionVaultImpl", redemptionVaultImpl);
        string memory json = vm.serializeAddress(objectKey, "redemptionVaultProxy", address(redemptionVault));

        _saveDeploymentJson(ARTIFACT_NAME, json);
    }
}
