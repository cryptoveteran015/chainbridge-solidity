// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface IDepositExecute {
    function deposit(bytes32 resourceID, uint8 destinationChainID, uint64 depositNonce, address depositer, bytes calldata data) external;

    function executeProposal(bytes32 resourceID, bytes calldata data) external;
}
