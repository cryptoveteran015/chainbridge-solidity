// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface IERCHandler {
    function setResource(bytes32 resourceID, address contractAddress) external;
    
    function setBurnable(address contractAddress) external;
    
    function withdraw(address tokenAddress, address recipient, uint256 amountOrTokenID) external;
}
