// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface IGenericHandler {
    function setResource(bytes32 resourceID, address contractAddress, bytes4 depositFunctionSig, bytes4 executeFunctionSig) external;
}