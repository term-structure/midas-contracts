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

contract DeployAccessController is Script {
    using StringHelper for string;

    string public network;
    uint256 public deployerPrivateKey;
    address public adminAddr;
    address public deployerAddr;
    bool isMainnet;

    MidasAccessControl public midasAccessControl;
    address accessControlImpl;

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
                // set admin to deployer for testing
                adminAddr = deployerAddr;
            }

            console.log("Admin:", adminAddr);
            console.log("Deployer:", deployerAddr);
        }
    }

    function run() public {
        console.log("Network:", network);
        console.log("Deployer balance:", deployerAddr.balance);

        vm.startBroadcast(deployerPrivateKey);
        // deploy MidasAccessControl
        {
            accessControlImpl = address(new MidasAccessControl());
            console.log("Impl deployed at:", address(accessControlImpl));

            bytes memory data = abi.encodeWithSignature("initialize()");

            midasAccessControl = MidasAccessControl(address(new ERC1967Proxy(address(accessControlImpl), data)));
            console.log("MidasAccessControl deployed at:", address(midasAccessControl));

            midasAccessControl.grantRole(midasAccessControl.DEFAULT_ADMIN_ROLE(), adminAddr);
            console.log("Granted admin role to:", adminAddr);

        }
        vm.stopBroadcast();
    }
}
