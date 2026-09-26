// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {AccessControl} from "../src/AccessControl.sol";
import {AssetMarketplace} from "../src/AssetMarketplace.sol";

contract DeployMarketplace is Script {
    address internal constant DEFAULT_SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address assetNFTAddress = vm.envAddress("ASSET_NFT_ADDRESS");
        address usdcAddress = vm.envOr("USDC_ADDRESS", DEFAULT_SEPOLIA_USDC);
        address deployer = vm.addr(deployerPrivateKey);
        address marketplaceOwner = vm.envOr("MARKETPLACE_OWNER", deployer);
        address marketplaceSeller = vm.envOr("MARKETPLACE_SELLER", address(0));

        vm.startBroadcast(deployerPrivateKey);
        AssetMarketplace marketplace = new AssetMarketplace(assetNFTAddress, usdcAddress);
        if (marketplaceSeller != address(0) && marketplaceSeller != marketplaceOwner) {
            marketplace.assignRole(marketplaceSeller, AccessControl.Role.EMPLOYEE);
            marketplace.grantPermission(marketplaceSeller, AccessControl.Permission.TRANSFER_ASSET);
        }
        if (marketplaceOwner != marketplace.OWNER()) {
            marketplace.transferOwnership(marketplaceOwner);
        }
        vm.stopBroadcast();

        console.log("marketplace:", address(marketplace));
        console.log("assetNFT:", assetNFTAddress);
        console.log("stableCoin:", usdcAddress);
        console.log("marketplaceOwner:", marketplace.OWNER());
    }
}