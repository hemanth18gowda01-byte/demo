//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Identity} from "../src/IdentityRegistry.sol";
import {AccessControl} from "../src/AccessControl.sol";
import {DigitalAssetNFT} from "../src/AssetNFT.sol";
import {AssetMarketplace} from "../src/AssetMarketplace.sol";
import {StableCoinTransaction} from "../src/StableCoinTransaction.sol";
import {HelperConfigure} from "./HelperConfigure.s.sol";
import {SmartAccount} from "../src/accountAbstraction/SmartAccount.sol";

contract Deploy is Script {
    address internal constant DEFAULT_SEPOLIA_USDC = 0x1C7d4b196CB0C7B01D7F6E2B8D5b4A1D0a8Bc4cA;

    function run() external {
        (HelperConfigure helperConfigure, SmartAccount smartAccount) = deploySmartAccount();
        HelperConfigure.NetworkConfig memory config = helperConfigure.getConfig();
        (Identity identity, AccessControl accessControl, DigitalAssetNFT digitalAssetNFT) =
            deployContracts(config.account);

        StableCoinTransaction stableCoin = deployStableCoin();
        AssetMarketplace marketplace = deployMarketplace(address(stableCoin), config.account);

        console.log("SmartAccount deployed at:", address(smartAccount));
        console.log("Identity deployed at:", address(identity));
        console.log("AccessControl deployed at:", address(accessControl));
        console.log("DigitalAssetNFT deployed at:", address(digitalAssetNFT));
        console.log("StableCoinTransaction deployed at:", address(stableCoin));
        console.log("AssetMarketplace deployed at:", address(marketplace));
    }

    function deploySmartAccount() public returns (HelperConfigure, SmartAccount) {
        HelperConfigure helperConfigure = new HelperConfigure();
        HelperConfigure.NetworkConfig memory config = helperConfigure.getConfig();
        vm.startBroadcast(config.account);
        SmartAccount smartAccount = new SmartAccount(config.entryPoint);
        vm.stopBroadcast();
        return (helperConfigure, smartAccount);
    }

    function deployContracts(address contractOwner) public returns (Identity, AccessControl, DigitalAssetNFT) {
        require(contractOwner != address(0), "Invalid contract owner");
        HelperConfigure helperConfigure = new HelperConfigure();
        HelperConfigure.NetworkConfig memory config = helperConfigure.getConfig();
        vm.startBroadcast(config.account);
        Identity identity = new Identity();
        AccessControl accessControl = new AccessControl();
        DigitalAssetNFT digitalAssetNFT = new DigitalAssetNFT();
        identity.transferOwnership(contractOwner);
        accessControl.transferOwnership(contractOwner);
        digitalAssetNFT.transferOwnership(contractOwner);
        vm.stopBroadcast();
        return (identity, accessControl, digitalAssetNFT);
    }

    function deployStableCoin() public returns (StableCoinTransaction) {
        HelperConfigure helperConfigure = new HelperConfigure();
        HelperConfigure.NetworkConfig memory config = helperConfigure.getConfig();
        address usdcAddress = vm.envOr("USDC_ADDRESS", DEFAULT_SEPOLIA_USDC);
        vm.startBroadcast(config.account);
        StableCoinTransaction stableCoin = new StableCoinTransaction(usdcAddress);
        vm.stopBroadcast();
        return stableCoin;
    }

    function deployMarketplace(address stableCoinAddress, address contractOwner) public returns (AssetMarketplace) {
        require(stableCoinAddress != address(0), "Invalid stablecoin contract address");
        require(contractOwner != address(0), "Invalid contract owner");
        HelperConfigure helperConfigure = new HelperConfigure();
        HelperConfigure.NetworkConfig memory config = helperConfigure.getConfig();
        vm.startBroadcast(config.account);
        AssetMarketplace marketplace = new AssetMarketplace(stableCoinAddress);
        marketplace.transferOwnership(contractOwner);
        vm.stopBroadcast();
        return marketplace;
    }
}
