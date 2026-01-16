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

contract DeployMarketsScript is Script {
    using StringHelper for string;

    string public network;
    uint256 public deployerPrivateKey;
    address public adminAddr;
    address public deployerAddr;
    bool isMainnet;

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

        ERC1967Proxy ac_proxy = new ERC1967Proxy(
            address(impl), data
        );
        console.log("MidasAccessControl deployed at:", address(ac_proxy));

        if (!isMainnet) {
            ERC20Mock mockToken = new ERC20Mock(6);
            console.log("MockToken deployed at:", address(mockToken));

            mockToken.mint(deployerAddr, 1_000_000 * 10 ** mockToken.decimals());
            console.log("Minted 1,000,000 MTK to deployer");

            AggregatorV3Mock dataFeed = new AggregatorV3Mock();
            console.log("AggregatorV3Mock deployed at:", address(dataFeed));
            dataFeed.setRoundData(1 * 10 ** 8); // Set price to 1 MTK = $1

            DepositVault vaultImpl = new DepositVault();
            console.log("DepositVault impl deployed at:", address(vaultImpl));

            uint256 _variationTolerance = 50; // 0.5%
            uint256 _minAmount = 10 * 10 ** mockToken.decimals();
            uint256 _minMTokenAmountForFirstDeposit = 100 * 10 ** mockToken.decimals();
            uint256 _maxSupplyCap = 1_000_000 * 10 ** mockToken.decimals();
            SanctionsListMock _sanctionsList = new SanctionsListMock();
            console.log("SanctionsListMock deployed at:", address(_sanctionsList));

            bytes memory initData = abi.encodeWithSelector(
                DepositVault.initialize.selector,
                address(ac_proxy),
                MTokenInitParams({
                    mToken: address(mockToken),
                    mTokenDataFeed: address(dataFeed)
                }),
                ReceiversInitParams({
                    tokensReceiver: deployerAddr,
                    feeReceiver: deployerAddr
                }),
                InstantInitParams({
                    instantFee: 0,
                    instantDailyLimit: 10_000 * 10 ** mockToken.decimals()
                }),
                address(_sanctionsList),
                _variationTolerance,
                _minAmount,
                _minMTokenAmountForFirstDeposit,
                _maxSupplyCap
            );

            ERC1967Proxy vaultProxy = new ERC1967Proxy(
                address(vaultImpl), initData
            );
            console.log("DepositVault deployed at:", address(vaultProxy));
        }

        vm.stopBroadcast();
    }
}