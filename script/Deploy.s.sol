//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Identity} from "../src/IdentityRegistry.sol";
import {AccessControl} from "../src/AccessControl.sol";
import {DigitalAssetNFT} from "../src/AssetNFT.sol";
import {AssetMarketplace} from "../src/AssetMarketplace.sol";
import {HelperConfigure} from "./HelperConfigure.s.sol";
import {SmartAccount} from "../src/accountAbstraction/SmartAccount.sol";

contract Deploy is Script {
    address internal constant DEFAULT_SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        (HelperConfigure helperConfigure, SmartAccount smartAccount) = deploySmartAccount();
        HelperConfigure.NetworkConfig memory config = helperConfigure.getConfig();
        (Identity identity, AccessControl accessControl, DigitalAssetNFT digitalAssetNFT) =
            deployContracts(config.account);

        address usdcAddress = vm.envOr("USDC_ADDRESS", DEFAULT_SEPOLIA_USDC);
        AssetMarketplace marketplace = deployMarketplace(address(digitalAssetNFT), usdcAddress, config.account);

        console.log("Frontend CONTRACTS values:");
        console.log("smartAccount:", address(smartAccount));
        console.log("identity:", address(identity));
        console.log("accessControl:", address(accessControl));
        console.log("assetNFT:", address(digitalAssetNFT));
        console.log("stableCoin:", usdcAddress);
        console.log("marketplace:", address(marketplace));
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

    function deployMarketplace(address assetNFTAddress, address usdcAddress, address contractOwner)
        public
        returns (AssetMarketplace)
    {
        require(assetNFTAddress != address(0), "Invalid NFT address");
        require(usdcAddress != address(0), "Invalid USDC address");
        require(contractOwner != address(0), "Invalid contract owner");
        HelperConfigure helperConfigure = new HelperConfigure();
        HelperConfigure.NetworkConfig memory config = helperConfigure.getConfig();
        vm.startBroadcast(config.account);
        AssetMarketplace marketplace = new AssetMarketplace(assetNFTAddress, usdcAddress);
        marketplace.transferOwnership(contractOwner);
        vm.stopBroadcast();
        return marketplace;
    }
}
