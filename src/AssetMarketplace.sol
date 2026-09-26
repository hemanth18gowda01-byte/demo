// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AccessControl} from "./AccessControl.sol";
import {StableCoinTransaction} from "./StableCoinTransaction.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract AssetMarketplace is AccessControl, StableCoinTransaction {
    struct AssetForSale {
        uint256 tokenId;
        address seller;
        uint256 salePrice;
        bool status;
        uint256 timeStamp;
    }

    mapping(uint256 => AssetForSale) public assetsForSale;
    IERC721 public immutable assetNFT;

    constructor(address _assetNFTAddress, address _stablecoinAddress) StableCoinTransaction(_stablecoinAddress) {
        require(_assetNFTAddress != address(0), "Invalid NFT address");
        assetNFT = IERC721(_assetNFTAddress);
    }

    event AssetListedForSale(uint256 indexed tokenId, address indexed seller, uint256 salePrice);
    event AssetSaleCompleted(uint256 indexed tokenId, address indexed buyer, uint256 salePrice);
    event AssetSaleCancelled(uint256 indexed tokenId, address indexed seller);

    function _buyAsset(uint256 _tokenId) external {
        AssetForSale storage sale = assetsForSale[_tokenId];
        require(sale.status, "Asset is not for sale");
        require(assetNFT.ownerOf(_tokenId) == sale.seller, "Asset seller mismatch");
        require(sale.salePrice > 0, "Asset price must be greater than zero");
        require(
            usdcToken.allowance(msg.sender, address(this)) >= sale.salePrice,
            "Insufficient contract allowance. Approve USDC first"
        );
        require(
            assetNFT.getApproved(_tokenId) == address(this)
                || assetNFT.isApprovedForAll(sale.seller, address(this)),
            "Marketplace approval was revoked"
        );
        require(usdcToken.transferFrom(msg.sender, sale.seller, sale.salePrice), "Stablecoin payment failed");

        assetNFT.safeTransferFrom(sale.seller, msg.sender, _tokenId);
        sale.status = false;
        sale.timeStamp = block.timestamp;
        emit AssetSaleCompleted(_tokenId, msg.sender, sale.salePrice);
    }

    function _putAssetForSale(uint256 _tokenId, uint256 _salePrice) external {
        require(hasPermission(msg.sender, Permission.TRANSFER_ASSET), "Insufficient permissions");
        require(assetNFT.ownerOf(_tokenId) == msg.sender, "You are not the owner of this asset");
        require(_salePrice > 0, "Sale price should be greater than zero");
        require(
            assetNFT.getApproved(_tokenId) == address(this)
                || assetNFT.isApprovedForAll(msg.sender, address(this)),
            "Approve marketplace for this asset first"
        );
        assetsForSale[_tokenId] = AssetForSale({
            tokenId: _tokenId, seller: msg.sender, salePrice: _salePrice, status: true, timeStamp: block.timestamp
        });
        emit AssetListedForSale(_tokenId, msg.sender, _salePrice);
    }

    function _removeAssetFromSale(uint256 _tokenId) external {
        require(hasPermission(msg.sender, Permission.TRANSFER_ASSET), "Insufficient permissions");
        require(assetNFT.ownerOf(_tokenId) == msg.sender, "You are not the owner of this asset");
        require(assetsForSale[_tokenId].status, "Asset is not for sale");
        assetsForSale[_tokenId].status = false;
        emit AssetSaleCancelled(_tokenId, msg.sender);
    }
}
