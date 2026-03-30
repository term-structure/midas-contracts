// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {StringHelper} from "script/utils/StringHelper.sol";
import {MidasAccessControl} from "contracts/access/MidasAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract BaseProductDeployment is Script {
    using StringHelper for string;

    string internal network;
    string internal networkUpper;
    uint256 internal deployerPrivateKey;
    address internal adminAddr;
    address internal deployerAddr;
    bool internal isMainnet;
    bool internal isL2;

    MidasAccessControl internal midasAccessControl;

    string internal constant SHARED_IMPL_FILE = "shared-implementations";
    string internal constant ACCESS_CONTROL_ARTIFACT = "midas-access-control";

    function _setUpBase() internal {
        network = vm.envString("NETWORK");
        networkUpper = network.toUpper();
        isMainnet = vm.envBool("IS_MAINNET");
        isL2 = vm.envBool("IS_L2");

        deployerPrivateKey = vm.envUint(_envName("DEPLOYER_PRIVATE_KEY"));
        adminAddr = vm.envAddress(_envName("ADMIN_ADDRESS"));
        deployerAddr = vm.addr(deployerPrivateKey);

        if (!isMainnet) {
            adminAddr = deployerAddr;
        }

        (address configuredAccessControl, bool hasAccessControlEnv) = _optionalEnvAddress("MIDAS_ACCESS_CONTROL_ADDRESS");
        if (hasAccessControlEnv) {
            midasAccessControl = MidasAccessControl(configuredAccessControl);
        } else {
            midasAccessControl = MidasAccessControl(_loadMidasAccessControlFromDeployment());
        }

        console.log("Network:", network);
        console.log("Mainnet:", isMainnet);
        console.log("L2:", isL2);
        console.log("Admin:", adminAddr);
        console.log("Deployer:", deployerAddr);
        console.log("MidasAccessControl:", address(midasAccessControl));
    }

    function _loadMidasAccessControlFromDeployment() internal view returns (address) {
        string memory filePath = _deploymentFilePath(ACCESS_CONTROL_ARTIFACT);
        require(vm.isFile(filePath), "Missing MIDAS_ACCESS_CONTROL env and deployment JSON");

        string memory json = vm.readFile(filePath);

        if (vm.keyExistsJson(json, ".accessControlProxy")) {
            return vm.parseJsonAddress(json, ".accessControlProxy");
        }
        if (vm.keyExistsJson(json, ".networkAccessControl")) {
            return vm.parseJsonAddress(json, ".networkAccessControl");
        }

        revert("MIDAS access control address not found in deployment JSON");
    }

    function _envName(string memory suffix) internal view returns (string memory) {
        return string(abi.encodePacked(networkUpper, "_", suffix));
    }

    function _optionalEnvAddress(string memory suffix) internal view returns (address, bool) {
        string memory envName = _envName(suffix);
        if (vm.envExists(envName)) {
            return (vm.envAddress(envName), true);
        }
        return (address(0), false);
    }

    function _deploymentDir() internal view returns (string memory) {
        return string(abi.encodePacked("deployment/", network, "/"));
    }

    function _deploymentFilePath(string memory name) internal view returns (string memory) {
        return string(abi.encodePacked(_deploymentDir(), name, ".json"));
    }

    function _saveDeploymentJson(string memory name, string memory json) internal {
        string memory filePath = _deploymentFilePath(name);
        vm.writeJson(json, filePath);
        console.log("Saved deployment JSON:", filePath);
    }

    function _saveSharedImpl(string memory key, address impl) internal {
        string memory filePath = _deploymentFilePath(SHARED_IMPL_FILE);
        if (!vm.isFile(filePath)) {
            vm.writeJson("{}", filePath);
        }
        string memory dotKey = string(abi.encodePacked(".", key));
        string memory dollarKey = string(abi.encodePacked("$.", key));
        string memory jsonValue = string(abi.encodePacked('"', vm.toString(impl), '"'));

        // Foundry JSON path support can vary between versions; try both path styles.
        vm.writeJson(jsonValue, filePath, dotKey);
        vm.writeJson(jsonValue, filePath, dollarKey);

        string memory json = vm.readFile(filePath);
        bool exists = vm.keyExistsJson(json, dotKey) || vm.keyExistsJson(json, dollarKey);

        // Fallback: accumulate into a full object and overwrite file if path writes are unsupported.
        if (!exists) {
            string memory fullJson = vm.serializeAddress(SHARED_IMPL_FILE, key, impl);
            vm.writeJson(fullJson, filePath);

            json = vm.readFile(filePath);
            exists = vm.keyExistsJson(json, dotKey) || vm.keyExistsJson(json, dollarKey);
        }

        require(exists, "Shared impl write failed");

        console.log("Saved shared impl", key);
        console.log("  address:", impl);
    }

    function _loadSharedImpl(string memory key) internal view returns (address, bool) {
        string memory filePath = _deploymentFilePath(SHARED_IMPL_FILE);
        if (!vm.isFile(filePath)) return (address(0), false);
        string memory json = vm.readFile(filePath);
        string memory dotKey = string(abi.encodePacked(".", key));
        string memory dollarKey = string(abi.encodePacked("$.", key));
        if (vm.keyExistsJson(json, dotKey)) {
            return (vm.parseJsonAddress(json, dotKey), true);
        }
        if (vm.keyExistsJson(json, dollarKey)) {
            return (vm.parseJsonAddress(json, dollarKey), true);
        }
        return (address(0), false);
    }

    function _resolveImpl(address newImpl, string memory envSuffix, string memory sharedKey, string memory label)
        internal
        returns (address)
    {
        // 1. Try env override first
        (address envImpl, bool envExists) = _optionalEnvAddress(envSuffix);
        if (envExists) {
            console.log("Reusing implementation (env) for", label);
            console.log("  address:", envImpl);
            _saveSharedImpl(sharedKey, envImpl);
            return envImpl;
        }

        // 2. Try shared implementations JSON
        (address sharedImpl, bool sharedExists) = _loadSharedImpl(sharedKey);
        if (sharedExists) {
            console.log("Reusing implementation (shared) for", label);
            console.log("  address:", sharedImpl);
            _saveSharedImpl(sharedKey, sharedImpl);
            return sharedImpl;
        }

        // 3. Use newly deployed impl and save to shared
        console.log("Deployed new implementation for", label);
        console.log("  address:", newImpl);
        _saveSharedImpl(sharedKey, newImpl);
        return newImpl;
    }

    function _loadProductJson(string memory name) internal view returns (string memory) {
        string memory filePath = _deploymentFilePath(name);
        return vm.readFile(filePath);
    }

    function _loadProductAddress(string memory name, string memory key) internal view returns (address) {
        string memory json = _loadProductJson(name);
        return vm.parseJsonAddress(json, string(abi.encodePacked(".", key)));
    }

    // -------- token data feed persistence --------

    function _tokenDataFeedName(string memory symbol) internal pure returns (string memory) {
        return string(abi.encodePacked(symbol, "-datafeed"));
    }

    function _saveTokenDataFeed(string memory symbol, address proxy, address impl, address aggregator) internal {
        string memory name = _tokenDataFeedName(symbol);
        string memory objectKey = name;
        vm.serializeAddress(objectKey, "dataFeedProxy", proxy);
        vm.serializeAddress(objectKey, "dataFeedImpl", impl);
        string memory json = vm.serializeAddress(objectKey, "aggregatorPriceFeed", aggregator);
        _saveDeploymentJson(name, json);
        console.log("Saved token data feed:", symbol);
    }

    function _loadTokenDataFeed(string memory symbol) internal view returns (address proxy, bool exists) {
        string memory filePath = _deploymentFilePath(_tokenDataFeedName(symbol));
        if (!vm.isFile(filePath)) return (address(0), false);
        string memory json = vm.readFile(filePath);
        if (!vm.keyExistsJson(json, ".dataFeedProxy")) return (address(0), false);
        proxy = vm.parseJsonAddress(json, ".dataFeedProxy");
        exists = true;
    }
}
