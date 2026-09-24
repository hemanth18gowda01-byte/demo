//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {AccessControl} from "./AccessControl.sol";

contract Identity is AccessControl {
    address[] controllers;

    enum EntityType {
        EMPLOYEE,
        AUTHORITY,
        FOUNDER
    }

    struct DIDRegistry {
        string did;
        bytes32 documentHash;
        EntityType entityType;
        bool active;
        uint256 registeredAt;
        address whoRegistered;
    }

    mapping(address => DIDRegistry) public dids;

    mapping(address => bool) public isController;

    mapping(string => DIDRegistry) public searchByDid;

    event getIdentity(
        address indexed wallet,
        string did,
        EntityType entityType,
        bool active,
        uint256 registeredAt,
        bytes32 documentHash,
        address whoRegistered
    );

    // event isActive(
    //     address indexed wallet,
    //     string did,
    //     EntityType entityType,
    //     bool active,
    //     address whoRegistered
    // );

    function registerIdentities(
        string memory _did,
        bytes32 _documentHash,
        EntityType _entityType,
        uint256 _registeredAt,
        address _address
    ) external {
        require(role[msg.sender]==Role.ADMIN || role[msg.sender]==Role.MANAGER || role[msg.sender]==Role.AUDITOR, "You Cannot Change Anything here....!!!!");
        require(!dids[_address].active, "Candidate Already Registered");
        dids[_address] = DIDRegistry({
            did: _did,
            entityType: _entityType,
            active: true,
            documentHash: _documentHash,
            registeredAt: _registeredAt,
            whoRegistered: msg.sender
        });
        emit getIdentity(_address, _did, _entityType, true, _registeredAt, _documentHash, msg.sender);
    }

    function getIdentities(address _address)
        public
        view
        returns (string memory, bytes32, EntityType, bool, uint256, address)
    {
        require(role[msg.sender]==Role.ADMIN || role[msg.sender]==Role.MANAGER || role[msg.sender]==Role.AUDITOR, "You Cannot Change Anything here....!!!!");
        require(dids[_address].active, "No Candidate Registered in this Identity");
        return (
            dids[_address].did,
            dids[_address].documentHash,
            dids[_address].entityType,
            dids[_address].active,
            dids[_address].registeredAt,
            dids[_address].whoRegistered
        );
    }

    function updateIdentity(address _address, bytes32 _documentHash, EntityType _entityType) external {
        require(role[msg.sender]==Role.ADMIN || role[msg.sender]==Role.MANAGER || role[msg.sender]==Role.AUDITOR, "You Cannot Change Anything here....!!!!");
        require(dids[_address].active, "No Candidate Registered in this Identity");
        dids[_address].documentHash = _documentHash;
        dids[_address].entityType = _entityType;
    }

    function deactivateIdentity(address _address) external {
        require(role[msg.sender]==Role.ADMIN || role[msg.sender]==Role.MANAGER || role[msg.sender]==Role.AUDITOR, "You Cannot Change Anything here....!!!!");
        require(dids[_address].active, "Candidate Already Deactivated,No need to Deactivate");
        dids[_address].active = false;
    }

    function isActive(address _address) public view returns (bool) {
        return dids[_address].active;
    }
}
