//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";

contract SmartAccount is IAccount, Ownable {
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__InvalidDestination();
    error MinimalAccount__CallFailed(bytes result);
    error MinimalAccount__InvalidEntryPoint();

    IEntryPoint private immutable i_entryPoint;

    constructor(address entryPoint) Ownable(msg.sender) {
        if (entryPoint == address(0)) {
            revert MinimalAccount__InvalidEntryPoint();
        }
        i_entryPoint = IEntryPoint(entryPoint);
    }
    receive() external payable {}

    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }
    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
        if (dest == address(0)) {
            revert MinimalAccount__InvalidDestination();
        }
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        bool success;
        assembly {
            success := call(gas(), caller(), missingAccountFunds, 0, 0, 0, 0)
        }
        require(success, "Failed to pay prefund");
    }

    //A Signature is valid if the signer is the owner of the account
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        //_validateSignature will revert if the signature is invalid, so if we reach this point, the signature is valid
        if (missingAccountFunds != 0) {
            _payPrefund(missingAccountFunds);
        }
    }

    // EIP - 191 version of signed hash
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    /*/////////////////////////////////////////////////////////////////////////////////////
                                    GETTERS
    /////////////////////////////////////////////////////////////////////////////////////*/
    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
