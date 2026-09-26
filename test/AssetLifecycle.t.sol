// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DigitalAssetNFT} from "../src/AssetNFT.sol";
import {AssetMarketplace} from "../src/AssetMarketplace.sol";

contract MarketplaceTestToken is ERC20 {
	constructor() ERC20("Test USD Coin", "tUSDC") {}

	function mint(address receiver, uint256 amount) external {
		_mint(receiver, amount);
	}
}

contract AssetLifecycleTest is Test {
	uint256 private constant SALE_PRICE = 50e6;

	address private seller = makeAddr("seller");
	address private buyer = makeAddr("buyer");
	DigitalAssetNFT private assetNFT;
	MarketplaceTestToken private stablecoin;
	AssetMarketplace private marketplace;

	function setUp() public {
		assetNFT = new DigitalAssetNFT();
		assetNFT.transferOwnership(seller);
		vm.prank(seller);
		assetNFT.mintAsset("Test NFT", "ipfs://metadata", "Test", true);

		stablecoin = new MarketplaceTestToken();
		marketplace = new AssetMarketplace(address(assetNFT), address(stablecoin));
		marketplace.transferOwnership(seller);
	}

	function testListAndBuyTransfersTheAssetNFT() public {
		vm.prank(seller);
		assetNFT.approve(address(marketplace), 1);
		vm.prank(seller);
		marketplace._putAssetForSale(1, SALE_PRICE);

		stablecoin.mint(buyer, SALE_PRICE);
		vm.prank(buyer);
		stablecoin.approve(address(marketplace), SALE_PRICE);
		vm.prank(buyer);
		marketplace._buyAsset(1);

		assertEq(assetNFT.ownerOf(1), buyer);
		assertEq(stablecoin.balanceOf(seller), SALE_PRICE);
		assertEq(stablecoin.balanceOf(buyer), 0);
		(,,, bool active,) = marketplace.assetsForSale(1);
		assertFalse(active);
	}

	function testCannotListWithoutApprovingTheAssetNFT() public {
		vm.expectRevert(bytes("Approve marketplace for this asset first"));
		vm.prank(seller);
		marketplace._putAssetForSale(1, SALE_PRICE);
	}

	function testCannotBuyAnUnlistedAsset() public {
		vm.expectRevert(bytes("Asset is not for sale"));
		vm.prank(buyer);
		marketplace._buyAsset(1);
	}
}
