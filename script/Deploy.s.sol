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
import {AggregatorV3Mock} from "contracts/mocks/AggregatorV3Mock.sol";
import {SanctionsListMock} from "contracts/mocks/SanctionsListTest.sol";
import {DataFeed} from "contracts/feeds/DataFeed.sol";

contract DeployScript is Script {
    using StringHelper for string;

    string public network;
    uint256 public deployerPrivateKey;
    address public adminAddr;
    address public deployerAddr;
    bool isMainnet;

    MidasAccessControl public midasAccessControl;
    SanctionsListMock public sanctionsList;

    ERC20Mock paymentToken;
    ERC20Mock mToken;
    AggregatorV3Mock paymentTokenPricefeed;
    AggregatorV3Mock mTokenPricefeed;
    DataFeed paymentTokenDataFeed;
    DataFeed mTokenDataFeed;
    DepositVault depositVault;

    address tokenReceiver = 0x4479B26363c0465EE05A45ED13B4fAeA3E8b009A;

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
        MidasAccessControl impl = new MidasAccessControl();
        console.log("Impl deployed at:", address(impl));

        bytes memory data = abi.encodeWithSignature("initialize()");

        midasAccessControl = MidasAccessControl(address(new ERC1967Proxy(
            address(impl), data
        )));
        console.log("MidasAccessControl deployed at:", address(midasAccessControl));

        if (!isMainnet) {
            mToken = new ERC20Mock(18);
            console.log("mToken deployed at:", address(mToken));

            // add payment token to deposit vault
            paymentToken = new ERC20Mock(6);
            console.log("Deployed mock payment token at:", address(paymentToken));
            paymentToken.mint(deployerAddr, 1_000_000e6); // mint 1,000,000 USDC to deployer
            console.log("Minted 1,000,000 paymentToken to deployer");

            mTokenPricefeed = new AggregatorV3Mock();
            console.log("mToken pricefeed deployed at:", address(mTokenPricefeed));
            mTokenPricefeed.setRoundData(1 * 10 ** 8); // Set price to 1 MTK = $1

            paymentTokenPricefeed = new AggregatorV3Mock();
            console.log("paymentToken pricefeed deployed at:", address(paymentTokenPricefeed));
            paymentTokenPricefeed.setRoundData(1 * 10 ** 8); // Set price to 1 MTK = $1

            {
                DataFeed feedsImpl = new DataFeed();
                console.log("Deployed DataFeed impl at:", address(feedsImpl));
            
                uint256 _healthyDiff = type(uint256).max;
                int256 _minExpectedAnswer = 1;
                int256 _maxExpectedAnswer = type(int256).max;
                data = abi.encodeWithSignature(
                    "initialize(address,address,uint256,int256,int256)",
                    address(midasAccessControl),
                    address(mTokenPricefeed),
                    _healthyDiff,
                    _minExpectedAnswer,
                    _maxExpectedAnswer
                );
                mTokenDataFeed = DataFeed(address(new ERC1967Proxy(
                    address(feedsImpl), data
                )));
                console.log("mToken data feed deployed at:", address(mTokenDataFeed));

                data = abi.encodeWithSignature(
                    "initialize(address,address,uint256,int256,int256)",
                    address(midasAccessControl),
                    address(paymentTokenPricefeed),
                    _healthyDiff,
                    _minExpectedAnswer,
                    _maxExpectedAnswer
                );
                paymentTokenDataFeed = DataFeed(address(new ERC1967Proxy(
                    address(feedsImpl), data
                )));
                console.log("paymentToken data feed deployed at:", address(paymentTokenDataFeed));
            }

            DepositVault vaultImpl = new DepositVault();
            console.log("DepositVault impl deployed at:", address(vaultImpl));

            {
                uint256 _variationTolerance = 50; // 0.5%
                uint256 _minAmount = 10 ether;
                uint256 _minMTokenAmountForFirstDeposit = 10 ether;
                uint256 _maxSupplyCap = 1_000_000 ether;
                SanctionsListMock _sanctionsList = new SanctionsListMock();
                console.log("SanctionsListMock deployed at:", address(_sanctionsList));

                bytes memory initData = abi.encodeWithSelector(
                    DepositVault.initialize.selector,
                    address(midasAccessControl),
                    MTokenInitParams({
                        mToken: address(mToken),
                        mTokenDataFeed: address(mTokenDataFeed)
                    }),
                    ReceiversInitParams({
                        tokensReceiver: tokenReceiver,
                        feeReceiver: tokenReceiver
                    }),
                    InstantInitParams({
                        instantFee: 0,
                        // use 18 decimals for instant limits
                        instantDailyLimit: 1000_000 ether
                    }),
                    address(_sanctionsList),
                    _variationTolerance,
                    _minAmount,
                    _minMTokenAmountForFirstDeposit,
                    _maxSupplyCap
                );
                depositVault = DepositVault(address(new ERC1967Proxy(
                    address(vaultImpl), initData
                )));
                console.log("DepositVault deployed at:", address(depositVault));
            }

            midasAccessControl.grantRole(
                depositVault.vaultRole(),
                deployerAddr
            );
            console.log("Granted vault role to deployer");

            uint256 tokenFee = 0;
            uint256 allowance = type(uint256).max;
            bool stable = true;
            depositVault.addPaymentToken(address(paymentToken), address(paymentTokenDataFeed),
                tokenFee, allowance, stable
            );
            console.log("Added payment token to DepositVault");

            // Approve depositVault to spend paymentToken
            uint256 depositAmount = 100e6; // 100 USDC
            paymentToken.approve(address(depositVault), depositAmount);
            // Make a deposit
            uint256 minReceiveAmount = 100e6; // 100 * 1e6 (assuming mToken has 6 decimals)
            bytes32 referrerId;
            // deposit amount must convert to 18 decimals inside depositInstant
            depositVault.depositInstant(address(paymentToken), depositAmount * 1e12, minReceiveAmount * 1e12, referrerId
            );
            console.log("Deposited", depositAmount, "payment tokens to DepositVault");

            uint256 mTokenBalance = mToken.balanceOf(deployerAddr);
            console.log("Deployer mToken balance after deposit:", mTokenBalance);

            uint256 paymentTokenBalance = paymentToken.balanceOf(deployerAddr);
            console.log("Deployer paymentToken balance after deposit:", paymentTokenBalance);

            uint256 paymentTokenInVault = paymentToken.balanceOf(address(depositVault));
            console.log("DepositVault paymentToken balance after deposit:", paymentTokenInVault);

            uint256 paymentTokenInReceiver = paymentToken.balanceOf(tokenReceiver);
            console.log("Tokens receiver paymentToken balance after deposit:", paymentTokenInReceiver);
        }

        vm.stopBroadcast();
    }
}