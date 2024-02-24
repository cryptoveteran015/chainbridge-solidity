// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "../interfaces/IDepositExecute.sol";
import "./HandlerHelpers.sol";
import "../ERC20Safe.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract ERC20Handler is IDepositExecute, HandlerHelpers, ERC20Safe {
    struct DepositRecord {
        address _tokenAddress;
        uint8    _lenDestinationRecipientAddress;
        uint8   _destinationChainID;
        bytes32 _resourceID;
        bytes   _destinationRecipientAddress;
        address _depositer;
        uint    _amount;
    }

    // depositNonce => Deposit Record
    mapping (uint8 => mapping(uint64 => DepositRecord)) public _depositRecords;

    constructor(
        address          bridgeAddress
    ) public {
        _bridgeAddress = bridgeAddress;
    }

    function getDepositRecord(uint64 depositNonce, uint8 destId) external view returns (DepositRecord memory) {
        return _depositRecords[destId][depositNonce];
    }

    function deposit(
        bytes32 resourceID,
        uint8   destinationChainID,
        uint64  depositNonce,
        address depositer,
        bytes   calldata data
    ) external override onlyBridge {
        bytes   memory recipientAddress;
        uint256        amount;
        uint256        lenRecipientAddress;

        assembly {

            amount := calldataload(0xC4)

            recipientAddress := mload(0x40)
            lenRecipientAddress := calldataload(0xE4)
            mstore(0x40, add(0x20, add(recipientAddress, lenRecipientAddress)))

            calldatacopy(
                recipientAddress, // copy to destinationRecipientAddress
                0xE4, // copy from calldata @ 0x104
                sub(calldatasize(), 0xE) // copy size (calldatasize - 0x104)
            )
        }

        address tokenAddress = _resourceIDToTokenContractAddress[resourceID];
        require(_contractWhitelist[tokenAddress], "Provided tokenAddress is not whitelisted");

        if (_burnList[tokenAddress]) {
            burnERC20(tokenAddress, depositer, amount);
        } else {
            lockERC20(tokenAddress, depositer, address(this), amount);
        }

        _depositRecords[destinationChainID][depositNonce] = DepositRecord(
            tokenAddress,
            uint8(lenRecipientAddress),
            destinationChainID,
            resourceID,
            recipientAddress,
            depositer,
            amount
        );
    }

    function executeProposal(bytes32 resourceID, bytes calldata data) external override onlyBridge {
        uint256       amount;
        bytes  memory destinationRecipientAddress;

        assembly {
            amount := calldataload(0x64)

            destinationRecipientAddress := mload(0x40)
            let lenDestinationRecipientAddress := calldataload(0x84)
            mstore(0x40, add(0x20, add(destinationRecipientAddress, lenDestinationRecipientAddress)))

            // in the calldata the destinationRecipientAddress is stored at 0xC4 after accounting for the function signature and length declaration
            calldatacopy(
                destinationRecipientAddress, // copy to destinationRecipientAddress
                0x84, // copy from calldata @ 0x84
                sub(calldatasize(), 0x84) // copy size to the end of calldata
            )
        }

        bytes20 recipientAddress;
        address tokenAddress = _resourceIDToTokenContractAddress[resourceID];

        assembly {
            recipientAddress := mload(add(destinationRecipientAddress, 0x20))
        }

        require(_contractWhitelist[tokenAddress], "Provided tokenAddress is not whitelisted");

        if (_burnList[tokenAddress]) {
            mintERC20(tokenAddress, address(recipientAddress), amount);
        } else {
            releaseERC20(tokenAddress, address(recipientAddress), amount);
        }
    }

    function withdraw(address tokenAddress, address recipient, uint amount) external override onlyBridge {
        releaseERC20(tokenAddress, recipient, amount);
    }
}
