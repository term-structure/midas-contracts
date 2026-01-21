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
import {pUSDC} from "contracts/products/pUSDC/pUSDC.sol";
import {PUSDCCustomAggregatorFeed} from "contracts/products/pUSDC/PUSDCCustomAggregatorFeed.sol";
import {PUSDCDataFeed} from "contracts/products/pUSDC/PUSDCDataFeed.sol";
import {PUSDCDepositVault} from "contracts/products/pUSDC/PUSDCDepositVault.sol";
import {PUSDCRedemptionVault} from "contracts/products/pUSDC/PUSDCRedemptionVault.sol";

contract DeployMtoken is Script {
    using StringHelper for string;

    string public network;
    uint256 public deployerPrivateKey;
    address public adminAddr;
    address public deployerAddr;
    bool isMainnet;

    MidasAccessControl public midasAccessControl;

    PUSDCCustomAggregatorFeed paymentTokenDataFeed;
    PUSDCDepositVault depositVault;
    pUSDC pusdc;
    PUSDCCustomAggregatorFeed pUSDCFeed;
    PUSDCDataFeed pUSDCDataFeed;

    address paymentToken;
    address paymentTokenPriceFeed;

    address pusdcImpl;
    address customAggregatorFeedImpl;
    address dataFeedImpl;

    int192 minPrice = 0.8e8; // 0.8 USD
    int192 maxPrice = 1.8e8; // 1.8 USD
    uint256 maxDeviation = 1e8; // 1% max deviation
    // the healthyDiff is set to max uint256 to disable answer update time checks
    uint256 healthyDiff = type(uint256).max;
    uint256 healthyDiff_paymentToken = type(uint256).max;

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
            if (!isMainnet) {
                adminAddr = deployerAddr;
            }

            midasAccessControl = MidasAccessControl(
                vm.envAddress(string(abi.encodePacked(networkUpper, "_MIDAS_ACCESS_CONTROL_ADDRESS")))
            );
            paymentToken = vm.envAddress(string(abi.encodePacked(networkUpper, "_PAYMENT_TOKEN_ADDRESS")));
            paymentTokenPriceFeed =
                vm.envAddress(string(abi.encodePacked(networkUpper, "_PAYMENT_TOKEN_PRICE_FEED_ADDRESS")));

            string memory paymentTokenDataFeedVar =
                string(abi.encodePacked(networkUpper, "_PAYMENT_TOKEN_DATA_FEED_ADDRESS"));
            if (vm.envExists(paymentTokenDataFeedVar)) {
                paymentTokenDataFeed = PUSDCCustomAggregatorFeed(
                    vm.envAddress(string(abi.encodePacked(networkUpper, "_PAYMENT_TOKEN_DATA_FEED_ADDRESS")))
                );
            }

            console.log("Admin:", adminAddr);
            console.log("Deployer:", deployerAddr);
        }
    }

    function run() public {
        console.log("Network:", network);
        console.log("Deployer balance:", deployerAddr.balance);

        vm.startBroadcast(deployerPrivateKey);
        // deploy pUSDC and related contracts
        {
            pusdcImpl = address(new pUSDC());
            console.log("pUSDC impl deployed at:", address(pusdcImpl));

            bytes memory data = abi.encodeWithSignature("initialize(address)", address(midasAccessControl));

            pusdc = pUSDC(address(new ERC1967Proxy(address(pusdcImpl), data)));
            console.log("pUSDC deployed at:", address(pusdc));

            // grant pasuer role to admin
            midasAccessControl.grantRole(pusdc.P_USDC_PAUSE_OPERATOR_ROLE(), adminAddr);

            customAggregatorFeedImpl = address(new PUSDCCustomAggregatorFeed());
            console.log("PUSDCCustomAggregatorFeed impl deployed at:", address(customAggregatorFeedImpl));
            data = abi.encodeWithSignature(
                "initialize(address,int192,int192,uint256,string)",
                address(midasAccessControl),
                minPrice,
                maxPrice,
                maxDeviation,
                "pUSDC/USD Custom Aggregator Feed"
            );
            pUSDCFeed = PUSDCCustomAggregatorFeed(address(new ERC1967Proxy(address(customAggregatorFeedImpl), data)));
            console.log("pUSDCFeed deployed at:", address(pUSDCFeed));

            dataFeedImpl = address(new PUSDCDataFeed());
            console.log("PUSDCDataFeed impl deployed at:", address(dataFeedImpl));

            data = abi.encodeWithSignature(
                "initialize(address,address,uint256,int256,int256)",
                address(midasAccessControl),
                address(pUSDCFeed),
                healthyDiff,
                minPrice,
                maxPrice
            );
            pUSDCDataFeed = PUSDCDataFeed(address(new ERC1967Proxy(address(dataFeedImpl), data)));
            console.log("pUSDCDataFeed deployed at:", address(pUSDCDataFeed));

            midasAccessControl.grantRole(pUSDCDataFeed.feedAdminRole(), adminAddr);
            console.log("Granted pUSDC data feed admin role to admin");
        }

        // deploy payment token data feed if not provided
        if (address(paymentTokenDataFeed) == address(0)) {
            bytes memory data = abi.encodeWithSignature(
                "initialize(address,address,uint256,int256,int256)",
                address(midasAccessControl),
                address(paymentTokenPriceFeed),
                healthyDiff_paymentToken,
                minPrice,
                maxPrice
            );
            paymentTokenDataFeed = PUSDCCustomAggregatorFeed(address(new ERC1967Proxy(dataFeedImpl, data)));
            console.log("payment token data feed deployed at:", address(paymentTokenDataFeed));

            midasAccessControl.grantRole(paymentTokenDataFeed.feedAdminRole(), adminAddr);
            console.log("Granted payment token data feed admin role to admin");
        }

        vm.stopBroadcast();
    }
}
