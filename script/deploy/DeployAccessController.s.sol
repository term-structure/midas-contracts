// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import "forge-std/console.sol";
import {StringHelper} from "../utils/StringHelper.sol";
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

    string internal constant DEPLOYMENT_ARTIFACT = "midas-access-control";

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
            accessControlImpl = 0x9b94Aac01EcBB8fb31E52cE21D1f57849A843Feb;
            console.log("Impl deployed at:", address(accessControlImpl));

            bytes memory data = abi.encodeWithSignature("initialize()");

            midasAccessControl = MidasAccessControl(address(new ERC1967Proxy(address(accessControlImpl), data)));
            console.log("MidasAccessControl deployed at:", address(midasAccessControl));

            midasAccessControl.grantRole(midasAccessControl.DEFAULT_ADMIN_ROLE(), adminAddr);
            console.log("Granted admin role to:", adminAddr);
        }

        _saveDeployment();
        vm.stopBroadcast();
    }

    function _deploymentFilePath() internal view returns (string memory) {
        return string(abi.encodePacked("deployment/", network, "/", DEPLOYMENT_ARTIFACT, ".json"));
    }

    function _saveDeployment() internal {
        string memory objectKey = DEPLOYMENT_ARTIFACT;
        vm.serializeAddress(objectKey, "accessControlImpl", accessControlImpl);
        vm.serializeAddress(objectKey, "accessControlProxy", address(midasAccessControl));
        vm.serializeAddress(objectKey, "admin", adminAddr);
        string memory json = vm.serializeAddress(objectKey, "deployer", deployerAddr);

        string memory filePath = _deploymentFilePath();
        vm.writeJson(json, filePath);
        console.log("Saved deployment JSON:", filePath);
    }
}
