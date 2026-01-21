// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import "forge-std/console.sol";
import {StringHelper} from "./utils/StringHelper.sol";
import {MidasAccessControl} from "contracts/access/MidasAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20Mock} from "contracts/mocks/ERC20Mock.sol";
import {DepositVault} from "contracts/DepositVault.sol";
import {MTokenInitParams, ReceiversInitParams, InstantInitParams} from "contracts/interfaces/IManageableVault.sol";
import {AggregatorV3Mock} from "contracts/mocks/AggregatorV3Mock.sol";
import {SanctionsListMock} from "contracts/mocks/SanctionsListTest.sol";
import {DataFeed} from "contracts/feeds/DataFeed.sol";
import {pUSDC} from "contracts/products/pUSDC/pUSDC.sol";
import {PUSDCCustomAggregatorFeed} from "contracts/products/pUSDC/PUSDCCustomAggregatorFeed.sol";
import {PUSDCDataFeed} from "contracts/products/pUSDC/PUSDCDataFeed.sol";
import {PUSDCDepositVault} from "contracts/products/pUSDC/PUSDCDepositVault.sol";
import {PUSDCRedemptionVault} from "contracts/products/pUSDC/PUSDCRedemptionVault.sol";
import {FiatRedeptionInitParams} from "contracts/interfaces/IRedemptionVault.sol";
import {RedemptionVault} from "contracts/RedemptionVault.sol";

contract DeployVaults is Script {
    using StringHelper for string;

    string public network;
    uint256 public deployerPrivateKey;
    uint256 adminPrivateKey;
    address public adminAddr;
    address public deployerAddr;
    bool isMainnet;

    MidasAccessControl public midasAccessControl;
    SanctionsListMock public sanctionsList;

    IERC20 paymentToken;
    address paymentTokenPricefeed;
    PUSDCCustomAggregatorFeed public paymentTokenDataFeed;

    pUSDC pusdc;
    PUSDCCustomAggregatorFeed pUSDCFeed;
    PUSDCDataFeed pUSDCDataFeed;

    PUSDCDepositVault depositVault;
    PUSDCRedemptionVault pUSDCRedemptionVault;

    address depositVaultImpl;
    address redemptionVaultImpl;

    address tokenReceiver;

    uint256 _variationTolerance = 50; // 0.5%
    uint256 _minAmount = 10 ether;
    uint256 _minMTokenAmountForFirstDeposit = 10 ether;
    uint256 _maxSupplyCap = 1_000_000 ether;
    uint256 instantFee_Deposit = 0;
    uint256 instantDailyLimit_Deposit = 1_000_000 ether;

    bool isPaymentTokenStable = true;
    uint256 paymentTokenTokenFee = 0;
    uint256 paymentTokenAllowance = type(uint256).max;

    uint256 paymentTokenTokenWithdrawFee = 0;
    uint256 paymentTokenWithdrawAllowance = type(uint256).max;
    uint256 instantFee_Withdraw = 10; // 0.1%
    uint256 instantDailyLimit_Withdraw = 1_000_000 ether;
    uint256 mintAmount_Withdraw = 0.01 ether; // 0.01 mToken

    uint256 fiatAdditionalFee = 0;
    uint256 fiatFlatFee = 0;
    uint256 minFiatRedeemAmount = 0;

    function setUp() public {
        // Load network from environment variable
        network = vm.envString("NETWORK");
        isMainnet = vm.envBool("IS_MAINNET");
        // Load network-specific configuration
        {
            string memory networkUpper = network.toUpper();
            string memory privateKeyVar = string(abi.encodePacked(networkUpper, "_DEPLOYER_PRIVATE_KEY"));
            string memory adminVar = string(abi.encodePacked(networkUpper, "_ADMIN_ADDRESS"));

            deployerPrivateKey = vm.envUint(privateKeyVar);
            adminAddr = vm.envAddress(adminVar);
            deployerAddr = vm.addr(deployerPrivateKey);
            tokenReceiver = vm.envAddress(string(abi.encodePacked(networkUpper, "_TOKEN_RECEIVER_ADDRESS")));

            if (!isMainnet) {
                adminAddr = deployerAddr; // TEMPORARY: set admin to deployer for testing
                adminPrivateKey = vm.envUint(string(abi.encodePacked(networkUpper, "_ADMIN_PRIVATE_KEY")));
            }
            midasAccessControl = MidasAccessControl(
                vm.envAddress(string(abi.encodePacked(networkUpper, "_MIDAS_ACCESS_CONTROL_ADDRESS")))
            );
            sanctionsList =
                SanctionsListMock(vm.envAddress(string(abi.encodePacked(networkUpper, "_SANCTIONS_LIST_ADDRESS"))));

            paymentToken = IERC20(vm.envAddress(string(abi.encodePacked(networkUpper, "_PAYMENT_TOKEN_ADDRESS"))));
            paymentTokenPricefeed =
                vm.envAddress(string(abi.encodePacked(networkUpper, "_PAYMENT_TOKEN_PRICE_FEED_ADDRESS")));
            paymentTokenDataFeed = PUSDCCustomAggregatorFeed(
                vm.envAddress(string(abi.encodePacked(networkUpper, "_PAYMENT_TOKEN_DATA_FEED_ADDRESS")))
            );

            pusdc = pUSDC(vm.envAddress(string(abi.encodePacked(networkUpper, "_MTOKEN_ADDRESS"))));
            pUSDCFeed = PUSDCCustomAggregatorFeed(
                vm.envAddress(string(abi.encodePacked(networkUpper, "_MTOKEN_PRICE_FEED_ADDRESS")))
            );
            pUSDCDataFeed =
                PUSDCDataFeed(vm.envAddress(string(abi.encodePacked(networkUpper, "_MTOKEN_DATA_FEED_ADDRESS"))));

            console.log("Admin:", adminAddr);
            console.log("Deployer:", deployerAddr);
        }
    }

    function run() public {
        console.log("Network:", network);
        console.log("Deployer balance:", deployerAddr.balance);

        vm.startBroadcast(deployerPrivateKey);

        depositVaultImpl = address(new PUSDCDepositVault());
        console.log("PUSDCDepositVault impl deployed at:", address(depositVaultImpl));
        redemptionVaultImpl = address(new PUSDCRedemptionVault());
        console.log("PUSDCRedemptionVault impl deployed at:", address(redemptionVaultImpl));

        {
            bytes memory initData = abi.encodeWithSelector(
                DepositVault.initialize.selector,
                address(midasAccessControl),
                MTokenInitParams({mToken: address(pusdc), mTokenDataFeed: address(pUSDCDataFeed)}),
                ReceiversInitParams({tokensReceiver: tokenReceiver, feeReceiver: tokenReceiver}),
                InstantInitParams({
                    instantFee: instantFee_Deposit,
                    // use 18 decimals for instant limits
                    instantDailyLimit: instantDailyLimit_Deposit
                }),
                address(sanctionsList),
                _variationTolerance,
                _minAmount,
                _minMTokenAmountForFirstDeposit,
                _maxSupplyCap
            );
            depositVault = PUSDCDepositVault(address(new ERC1967Proxy(address(depositVaultImpl), initData)));
            console.log("DepositVault deployed at:", address(depositVault));

            // grant minter role to deposit vault
            midasAccessControl.grantRole(pusdc.P_USDC_MINT_OPERATOR_ROLE(), address(depositVault));
            console.log("Granted pUSDC minter role to DepositVault");
        }

        midasAccessControl.grantRole(depositVault.vaultRole(), adminAddr);
        console.log("Granted vault role to admin");

        depositVault.addPaymentToken(
            address(paymentToken),
            address(paymentTokenDataFeed),
            paymentTokenTokenFee,
            paymentTokenAllowance,
            isPaymentTokenStable
        );
        console.log("Added payment token to DepositVault");

        {
            FiatRedeptionInitParams memory _params = FiatRedeptionInitParams({
                fiatAdditionalFee: fiatAdditionalFee,
                fiatFlatFee: fiatFlatFee,
                minFiatRedeemAmount: minFiatRedeemAmount
            });
            bytes memory data = abi.encodeWithSelector(
                RedemptionVault.initialize.selector,
                address(midasAccessControl),
                MTokenInitParams({mToken: address(pusdc), mTokenDataFeed: address(pUSDCDataFeed)}),
                ReceiversInitParams({tokensReceiver: tokenReceiver, feeReceiver: tokenReceiver}),
                InstantInitParams({
                    instantFee: instantFee_Withdraw,
                    // use 18 decimals for instant limits
                    instantDailyLimit: instantDailyLimit_Withdraw
                }),
                address(sanctionsList),
                _variationTolerance,
                mintAmount_Withdraw,
                _params,
                tokenReceiver
            );
            pUSDCRedemptionVault = PUSDCRedemptionVault(address(new ERC1967Proxy(address(redemptionVaultImpl), data)));
            console.log("PUSDCRedemptionVault deployed at:", address(pUSDCRedemptionVault));

            // grant vault role to redemption vault
            midasAccessControl.grantRole(pUSDCRedemptionVault.vaultRole(), adminAddr);
            console.log("Granted vault role to RedemptionVault for admin:", adminAddr);

            // grant burner role to redemption vault
            midasAccessControl.grantRole(pusdc.P_USDC_BURN_OPERATOR_ROLE(), address(pUSDCRedemptionVault));
            console.log("Granted pUSDC burner role to PUSDCRedemptionVault");

            // add payment token to redemption vault
            pUSDCRedemptionVault.addPaymentToken(
                address(paymentToken),
                address(paymentTokenDataFeed),
                paymentTokenTokenWithdrawFee,
                paymentTokenWithdrawAllowance,
                isPaymentTokenStable
            );
            console.log("Added payment token to PUSDCRedemptionVault");
        }

        testDeposit();
        testRedeem();
        vm.stopBroadcast();
    }

    function testDeposit() public {
        if (!isMainnet) {
            // update pUSDC price
            pUSDCFeed.setRoundData(1 * 10 ** 8); // Set price to 1 pUSDC = $1
            console.log("Set pUSDC pricefeed to $1");

            // Approve depositVault to spend mockUSDC
            uint256 depositAmount = 100e6; // 100 USDC
            paymentToken.approve(address(depositVault), depositAmount);
            // Make a deposit
            uint256 minReceiveAmount = 100e6; // 100 * 1e6 (assuming mToken has 6 decimals)
            bytes32 referrerId;
            // deposit amount must convert to 18 decimals inside depositInstant
            depositVault.depositInstant(
                address(paymentToken), depositAmount * 1e12, minReceiveAmount * 1e12, referrerId
            );
            console.log("Deposited", depositAmount, "payment tokens to DepositVault");

            uint256 pusdcBalance = pusdc.balanceOf(deployerAddr);
            console.log("Deployer pusdc balance after deposit:", pusdcBalance);

            uint256 paymentTokenBalance = paymentToken.balanceOf(deployerAddr);
            console.log("Deployer payment token balance after deposit:", paymentTokenBalance);
            uint256 paymentTokenInVault = paymentToken.balanceOf(address(depositVault));
            console.log("DepositVault payment token balance after deposit:", paymentTokenInVault);

            uint256 paymentTokenInReceiver = paymentToken.balanceOf(tokenReceiver);
            console.log("Tokens receiver payment token balance after deposit:", paymentTokenInReceiver);
        }
    }

    function testRedeem() public {
        if (!isMainnet) {
            paymentToken.transfer(address(pUSDCRedemptionVault), 100e6);
            console.log("Funded RedemptionVault with payment tokens for redeem test");
            // redeem some tokens
            address tokenOut = address(paymentToken);
            uint256 amountMTokenIn = 10 ether;
            uint256 minReceiveAmount = 9e6;
            pusdc.approve(address(pUSDCRedemptionVault), amountMTokenIn);
            pUSDCRedemptionVault.redeemInstant(tokenOut, amountMTokenIn, minReceiveAmount);
            console.log("Redeemed pusdc instant from RedemptionVault");
            uint256 pusdcBalance = pusdc.balanceOf(deployerAddr);
            console.log("Deployer pusdc balance after redeem:", pusdcBalance);
            uint256 paymentTokenBalance = paymentToken.balanceOf(deployerAddr);
            console.log("Deployer paymentToken balance after redeem:", paymentTokenBalance);
            uint256 paymentTokenInVault = paymentToken.balanceOf(address(pUSDCRedemptionVault));
            console.log("RedemptionVault paymentToken balance after redeem:", paymentTokenInVault);
            uint256 paymentTokenInReceiver = paymentToken.balanceOf(tokenReceiver);
            console.log("Tokens receiver paymentToken balance after redeem:", paymentTokenInReceiver);
        }
    }
}
