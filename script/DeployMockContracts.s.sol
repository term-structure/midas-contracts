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

contract DeployMockContracts is Script {
    using StringHelper for string;

    string public network;
    uint256 public deployerPrivateKey;
    address public adminAddr;
    address public deployerAddr;
    bool isMainnet;

    address midasAccessControl;
    address sanctionsList;

    ERC20Mock mockUSDC;
    AggregatorV3Mock mockUSDCTokenPricefeed;

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

            midasAccessControl = vm.envAddress(string(abi.encodePacked(networkUpper, "_MIDAS_ACCESS_CONTROL_ADDRESS")));

            console.log("Admin:", adminAddr);
            console.log("Deployer:", deployerAddr);
        }
    }

    function run() public {
        console.log("Network:", network);
        console.log("Deployer balance:", deployerAddr.balance);

        vm.startBroadcast(deployerPrivateKey);

        if (!isMainnet) {
            // deploy mock sanctions list
            sanctionsList = address(new SanctionsListMock());
            console.log("SanctionsListMock deployed at:", sanctionsList);

            // add payment token to deposit vault
            mockUSDC = new ERC20Mock(6);
            console.log("Deployed mock payment token at:", address(mockUSDC));
            mockUSDC.mint(deployerAddr, 1_000_000e6); // mint 1,000,000 USDC to deployer
            console.log("Minted 1,000,000 mockUSDC to deployer");

            mockUSDCTokenPricefeed = new AggregatorV3Mock();
            console.log("mockUSDC pricefeed deployed at:", address(mockUSDCTokenPricefeed));
            mockUSDCTokenPricefeed.setRoundData(1 * 10 ** 8); // Set price to 1 USDC = $1
            console.log("Set mockUSDC pricefeed to $1");
        }

        vm.stopBroadcast();
    }
}
