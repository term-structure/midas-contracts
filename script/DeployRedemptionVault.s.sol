// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import "forge-std/console.sol";
import {StringHelper} from "./utils/StringHelper.sol";
import {MidasAccessControl} from "contracts/access/MidasAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20Mock} from "contracts/mocks/ERC20Mock.sol";
import {DepositVault} from "contracts/DepositVault.sol";
import {MTokenInitParams, ReceiversInitParams, InstantInitParams} from "contracts/interfaces/IManageableVault.sol";
import {FiatRedeptionInitParams} from "contracts/interfaces/IRedemptionVault.sol";
import {AggregatorV3Mock} from "contracts/mocks/AggregatorV3Mock.sol";
import {SanctionsListMock} from "contracts/mocks/SanctionsListTest.sol";
import {DataFeed} from "contracts/feeds/DataFeed.sol";
import {RedemptionVault} from "contracts/RedemptionVault.sol";

contract DeployRedemptionVaultScript is Script {
    using StringHelper for string;

    string public network;
    uint256 public deployerPrivateKey;
    address public adminAddr;
    address public deployerAddr;
    bool isMainnet;

    MidasAccessControl public midasAccessControl = MidasAccessControl(0x543E2A13A9C8c3AFF0958A13b8d6CAB8B8d3fc8a);
    SanctionsListMock public sanctionsList = SanctionsListMock(0xbCC35c5CC485ceA7fb389AfA248835de7D1Ec4E8);

    ERC20Mock paymentToken = ERC20Mock(0x024D70e25c81Bd24C22F74a4d51Ff0286849dbE5);
    ERC20Mock mToken = ERC20Mock(0xbDF7fEcb71E1BBCed57E244dCa0A874463bb40fa);
    AggregatorV3Mock paymentTokenPricefeed = AggregatorV3Mock(0x33325d8766ad11b2D8fBdaC89baEBF233d84e45f);
    AggregatorV3Mock mTokenPricefeed = AggregatorV3Mock(0xC0959f794Db1376385cC7276aF1B22dB35E20a07);
    DataFeed paymentTokenDataFeed = DataFeed(0x531caA76930607ABd80C7E3D80fa3e77f215dB48);
    DataFeed mTokenDataFeed = DataFeed(0x2Fb6A1e7b4cE2B8B8a239c34f2ecC0ccB39F061C);
    DepositVault depositVault = DepositVault(0xa0589d162e122EEF0923256C0575a26781d99c05);

    address tokenReceiver = 0x4479B26363c0465EE05A45ED13B4fAeA3E8b009A;

    RedemptionVault redemptionVault;

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

            console.log("Admin:", adminAddr);
            console.log("Deployer:", deployerAddr);
        }
    }

    function run() public {
        console.log("Network:", network);
        console.log("Deployer balance:", deployerAddr.balance);

        vm.startBroadcast(deployerPrivateKey);

        if (!isMainnet) {
            RedemptionVault impl = new RedemptionVault();
            console.log("RedemptionVault Impl deployed at:", address(impl));
            {
                FiatRedeptionInitParams memory _params =
                    FiatRedeptionInitParams({fiatAdditionalFee: 0, fiatFlatFee: 0, minFiatRedeemAmount: 0});
                /// @dev the value to check price between submit request and execute request
                uint256 _variationTolerance = 50; // 0.5%
                uint256 _minAmount = 0.001 ether; // 0.001 mToken token
                address _requestRedeemer = tokenReceiver;
                uint256 instantFee = 10; // 0.1%

                bytes memory data = abi.encodeWithSelector(
                    RedemptionVault.initialize.selector,
                    address(midasAccessControl),
                    MTokenInitParams({mToken: address(mToken), mTokenDataFeed: address(mTokenDataFeed)}),
                    ReceiversInitParams({tokensReceiver: tokenReceiver, feeReceiver: tokenReceiver}),
                    InstantInitParams({
                        instantFee: instantFee,
                        // use 18 decimals for instant limits
                        instantDailyLimit: 1000_000 ether
                    }),
                    address(sanctionsList),
                    _variationTolerance,
                    _minAmount,
                    _params,
                    _requestRedeemer
                );
                redemptionVault = RedemptionVault(address(new ERC1967Proxy(address(impl), data)));
            }

            console.log("RedemptionVault deployed at:", address(redemptionVault));

            midasAccessControl.grantRole(redemptionVault.vaultRole(), deployerAddr);
            console.log("Granted vault role to RedemptionVault for deployer:", deployerAddr);

            {
                // add payment token to redemption vault
                uint256 tokenFee = 0;
                uint256 allowance = type(uint256).max;
                bool stable = true;
                redemptionVault.addPaymentToken(
                    address(paymentToken), address(paymentTokenDataFeed), tokenFee, allowance, stable
                );
                console.log("Added payment token to RedemptionVault");
            }
            {
                // redeem some tokens
                address tokenOut = address(paymentToken);
                uint256 amountMTokenIn = 10 ether;
                uint256 minReceiveAmount = 9e6;
                mToken.approve(address(redemptionVault), amountMTokenIn);
                redemptionVault.redeemInstant(tokenOut, amountMTokenIn, minReceiveAmount);
                console.log("Redeemed mToken instant from RedemptionVault");
                uint256 mTokenBalance = mToken.balanceOf(deployerAddr);
                console.log("Deployer mToken balance after redeem:", mTokenBalance);
                uint256 paymentTokenBalance = paymentToken.balanceOf(deployerAddr);
                console.log("Deployer paymentToken balance after redeem:", paymentTokenBalance);
                uint256 paymentTokenInVault = paymentToken.balanceOf(address(redemptionVault));
                console.log("RedemptionVault paymentToken balance after redeem:", paymentTokenInVault);
                uint256 paymentTokenInReceiver = paymentToken.balanceOf(tokenReceiver);
                console.log("Tokens receiver paymentToken balance after redeem:", paymentTokenInReceiver);
            }
        }

        vm.stopBroadcast();
    }
}
