// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SmartAccount} from "../src/accountAbstraction/SmartAccount.sol";

interface IOwnedContract {
    function transferOwnership(address newOwner) external;
}

/// @notice Transfers ownership of the existing Sepolia contracts through the current SmartAccount owner.
contract TransferContractOwnership is Script {
    using MessageHashUtils for bytes32;

    address internal constant OWNER = 0x29d7F532A8a271cBaf1f27f2312Bf2188612e929;
    address internal constant SMART_ACCOUNT = 0xC4D1d7BD956fBdf34f4998e4d3dFE4c439A932c4;
    address internal constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(vm.addr(privateKey) == OWNER, "PRIVATE_KEY must control the configured owner");

        IEntryPoint entryPoint = IEntryPoint(ENTRY_POINT);
        address[] memory targets = _targets();
        _fundSmartAccount(privateKey);
        uint256 nonce = entryPoint.getNonce(SMART_ACCOUNT, 0);
        PackedUserOperation[] memory operations = new PackedUserOperation[](targets.length);

        for (uint256 i; i < targets.length; ++i) {
            bytes memory transferCall = abi.encodeWithSelector(IOwnedContract.transferOwnership.selector, OWNER);
            bytes memory executeCall = abi.encodeWithSelector(SmartAccount.execute.selector, targets[i], 0, transferCall);
            operations[i] = _signedUserOperation(executeCall, nonce + i, privateKey, entryPoint);
        }

        vm.startBroadcast(privateKey);
        entryPoint.handleOps(operations, payable(OWNER));
        vm.stopBroadcast();
    }

    function _targets() internal pure returns (address[] memory targets) {
        targets = new address[](4);
        targets[0] = 0xCbf2f3fEd1Af81c816F1C6B5219d0779bd50e758;
        targets[1] = 0x463C2C1f72a5593615881B0040c2F80fB4815c3f;
        targets[2] = 0xfb8c47c3bE943601d23ECae90194adb22752C16d;
        targets[3] = 0x08233BcBaBf0a67Ba0cCe00494c35cF8eC943f38;
    }

    function _fundSmartAccount(uint256 privateKey) internal {
        uint256 funding = vm.envOr("SMART_ACCOUNT_FUNDING_WEI", uint256(0.02 ether));
        if (SMART_ACCOUNT.balance >= funding) return;

        vm.startBroadcast(privateKey);
        (bool success,) = payable(SMART_ACCOUNT).call{value: funding}("");
        vm.stopBroadcast();
        require(success, "Unable to fund SmartAccount");
    }

    function _signedUserOperation(bytes memory callData, uint256 nonce, uint256 privateKey, IEntryPoint entryPoint)
        internal
        view
        returns (PackedUserOperation memory operation)
    {
        uint128 verificationGasLimit = 500_000;
        uint128 callGasLimit = 250_000;
        uint128 maxPriorityFeePerGas = 1 gwei;
        uint128 maxFeePerGas = 30 gwei;

        operation = PackedUserOperation({
            sender: SMART_ACCOUNT,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: 100_000,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });

        bytes32 digest = entryPoint.getUserOpHash(operation).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        operation.signature = abi.encodePacked(r, s, v);
    }
}
