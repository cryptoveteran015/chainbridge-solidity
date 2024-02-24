// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "../interfaces/IGenericHandler.sol";

contract GenericHandler is IGenericHandler {
    address public _bridgeAddress;

    struct DepositRecord {
        uint8   _destinationChainID;
        address _depositer;
        bytes32 _resourceID;
        bytes   _metaData;
    }

    // depositNonce => Deposit Record
    mapping (uint8 => mapping(uint64 => DepositRecord)) public _depositRecords;

    // resourceID => contract address
    mapping (bytes32 => address) public _resourceIDToContractAddress;

    // contract address => resourceID
    mapping (address => bytes32) public _contractAddressToResourceID;

    // contract address => deposit function signature
    mapping (address => bytes4) public _contractAddressToDepositFunctionSignature;

    // contract address => execute proposal function signature
    mapping (address => bytes4) public _contractAddressToExecuteFunctionSignature;

    // token contract address => is whitelisted
    mapping (address => bool) public _contractWhitelist;

    modifier onlyBridge() {
        _onlyBridge();
        _;
    }

    function _onlyBridge() private {
         require(msg.sender == _bridgeAddress, "sender must be bridge contract");
    }

    constructor(
        address          bridgeAddress,
        bytes32[] memory initialResourceIDs,
        address[] memory initialContractAddresses,
        bytes4[]  memory initialDepositFunctionSignatures,
        bytes4[]  memory initialExecuteFunctionSignatures
    ) public {
        require(initialResourceIDs.length == initialContractAddresses.length,
            "initialResourceIDs and initialContractAddresses len mismatch");

        require(initialContractAddresses.length == initialDepositFunctionSignatures.length,
            "provided contract addresses and function signatures len mismatch");

        require(initialDepositFunctionSignatures.length == initialExecuteFunctionSignatures.length,
            "provided deposit and execute function signatures len mismatch");

        _bridgeAddress = bridgeAddress;

        for (uint256 i = 0; i < initialResourceIDs.length; i++) {
            _setResource(
                initialResourceIDs[i],
                initialContractAddresses[i],
                initialDepositFunctionSignatures[i],
                initialExecuteFunctionSignatures[i]);
        }
    }

    function getDepositRecord(uint64 depositNonce, uint8 destId) external view returns (DepositRecord memory) {
        return _depositRecords[destId][depositNonce];
    }

    function setResource(
        bytes32 resourceID,
        address contractAddress,
        bytes4 depositFunctionSig,
        bytes4 executeFunctionSig
    ) external onlyBridge override {

        _setResource(resourceID, contractAddress, depositFunctionSig, executeFunctionSig);
    }

    function deposit(bytes32 resourceID, uint8 destinationChainID, uint64 depositNonce, address depositer, bytes calldata data) external onlyBridge {
        bytes32      lenMetadata;
        bytes memory metadata;

        assembly {
            // Load length of metadata from data + 64
            lenMetadata  := calldataload(0xC4)
            // Load free memory pointer
            metadata := mload(0x40)

            mstore(0x40, add(0x20, add(metadata, lenMetadata)))

            // func sig (4) + destinationChainId (padded to 32) + depositNonce (32) + depositor (32) +
            // bytes length (32) + resourceId (32) + length (32) = 0xC4

            calldatacopy(
                metadata, // copy to metadata
                0xC4, // copy from calldata after metadata length declaration @0xC4
                sub(calldatasize(), 0xC4)      // copy size (calldatasize - (0xC4 + the space metaData takes up))
            )
        }

        address contractAddress = _resourceIDToContractAddress[resourceID];
        require(_contractWhitelist[contractAddress], "provided contractAddress is not whitelisted");

        bytes4 sig = _contractAddressToDepositFunctionSignature[contractAddress];
        if (sig != bytes4(0)) {
            bytes memory callData = abi.encodePacked(sig, metadata);
            (bool success,) = contractAddress.call(callData);
            require(success, "delegatecall to contractAddress failed");
        }

        _depositRecords[destinationChainID][depositNonce] = DepositRecord(
            destinationChainID,
            depositer,
            resourceID,
            metadata
        );
    }

    function executeProposal(bytes32 resourceID, bytes calldata data) external onlyBridge {
        bytes memory metaData;
        assembly {

            // metadata has variable length
            // load free memory pointer to store metadata
            metaData := mload(0x40)
            // first 32 bytes of variable length in storage refer to length
            let lenMeta := calldataload(0x64)
            mstore(0x40, add(0x60, add(metaData, lenMeta)))

            // in the calldata, metadata is stored @0x64 after accounting for function signature, and 2 previous params
            calldatacopy(
                metaData,                     // copy to metaData
                0x64,                        // copy from calldata after data length declaration at 0x64
                sub(calldatasize(), 0x64)   // copy size (calldatasize - 0x64)
            )
        }

        address contractAddress = _resourceIDToContractAddress[resourceID];
        require(_contractWhitelist[contractAddress], "provided contractAddress is not whitelisted");

        bytes4 sig = _contractAddressToExecuteFunctionSignature[contractAddress];
        if (sig != bytes4(0)) {
            bytes memory callData = abi.encodePacked(sig, metaData);
            (bool success,) = contractAddress.call(callData);
            require(success, "delegatecall to contractAddress failed");
        }
    }

    function _setResource(
        bytes32 resourceID,
        address contractAddress,
        bytes4 depositFunctionSig,
        bytes4 executeFunctionSig
    ) internal {
        _resourceIDToContractAddress[resourceID] = contractAddress;
        _contractAddressToResourceID[contractAddress] = resourceID;
        _contractAddressToDepositFunctionSignature[contractAddress] = depositFunctionSig;
        _contractAddressToExecuteFunctionSignature[contractAddress] = executeFunctionSig;

        _contractWhitelist[contractAddress] = true;
    }
}
