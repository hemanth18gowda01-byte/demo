//SPDX-License_Identifier:MIT
pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {AccessControl} from "./AccessControl.sol";

contract DigitalAssetNFT is ERC721, AccessControl {
    uint256 private tokenID;

    mapping(
        AssetState
            => mapping(
            AssetState
                => mapping(AssetState => mapping(AssetState => mapping(AssetState => mapping(AssetState => uint256))))
        )
    ) public assetFlowOrder;

    constructor() ERC721("BEL Electronics", "BEL Digital Assets") {
        tokenID = 1;
    }

    enum AssetState {
        CREATED,
        ALLOCATED,
        IN_USE,
        MAINTENANCE,
        RETURNED,
        FOR_SALE,
        DECOMMISSIONED
    }

    struct Asset {
        uint256 tokenId;
        string name;
        address ownedBy;
        string metadataURI;
        string assetType;
        AssetState assetState;
        bool isActive;
        address createdBy;
        string did;
        address assigningAssetTo;
    }

    mapping(uint256 => Asset) public assets;
    event mintedAssets(uint256 indexed tokenID, string metadataURI, bool isActive);

    function mintAsset(string memory _name, string memory _metadataURI, string memory _assetType, bool _isActive)
        external
    {
        require(hasPermission(msg.sender, Permission.CREATE_ASSET), "You don't have permission to mint assets");
        _safeMint(OWNER, tokenID);
        assets[tokenID] = Asset({
            tokenId: tokenID,
            name: _name,
            ownedBy: msg.sender,
            metadataURI: _metadataURI,
            assetType: _assetType,
            assetState: AssetState.CREATED,
            isActive: _isActive,
            createdBy: msg.sender,
            did: "",
            assigningAssetTo: address(0)
        });
        // The safe-mint callback must complete before this event is emitted.
        // forge-lint: disable-next-line(reentrancy-events)
        emit mintedAssets(tokenID, _metadataURI, _isActive);
        tokenID++;
    }

    function getAsset(uint256 _tokenID)
        external
        view
        returns (uint256, string memory, string memory, string memory, bool, address)
    {
        return (
            assets[_tokenID].tokenId,
            assets[_tokenID].name,
            assets[_tokenID].metadataURI,
            assets[_tokenID].assetType,
            assets[_tokenID].isActive,
            assets[_tokenID].createdBy
        );
    }

    function assignAsset(uint256 _tokenId, string memory _did, address _assignedTo) external {
        require(hasPermission(msg.sender, Permission.ALLOCATE_ASSET), "You cannot assign");
        assets[_tokenId].did = _did;
        assets[_tokenId].assigningAssetTo = _assignedTo;
        assets[_tokenId].assetState = AssetState.ALLOCATED;
    }

    function updateAssetState(uint256 _tokenId, AssetState _assetState) external {
        require(hasPermission(msg.sender, Permission.ALLOCATE_ASSET), "You cannot change");
        assets[_tokenId].assetState = _assetState;
    }

    function _finalizeAssetTransfer(uint256 _tokenId, address _newOwnerAddress) internal {
        require(_newOwnerAddress != address(0), "Address doesn't exists");
        assets[_tokenId].ownedBy = _newOwnerAddress;
        assets[_tokenId].isActive = false;
        assets[_tokenId].did = "";
        assets[_tokenId].assigningAssetTo = address(0);
    }

    function transferAsset(uint256 _tokenId, uint256 _newTokenId, address _newOwnerAddress) external {
        require(hasPermission(msg.sender, Permission.TRANSFER_ASSET), "You cannot transfer Assets");
        require(_newOwnerAddress != address(0), "Address doesn't exists");
        _transfer(ownerOf(_tokenId), _newOwnerAddress, _tokenId);
        assets[_tokenId].tokenId = _newTokenId;
        _finalizeAssetTransfer(_tokenId, _newOwnerAddress);
    }
}
