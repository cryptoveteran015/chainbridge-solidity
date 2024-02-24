// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./ERC721MinterBurnerPauser.sol";

contract ERC721Safe {
    using SafeMath for uint256;

    function fundERC721(address tokenAddress, address owner, uint tokenID) public {
        IERC721 erc721 = IERC721(tokenAddress);
        erc721.transferFrom(owner, address(this), tokenID);
    }

    function lockERC721(address tokenAddress, address owner, address recipient, uint tokenID) internal {
        IERC721 erc721 = IERC721(tokenAddress);
        erc721.transferFrom(owner, recipient, tokenID);

    }

    function releaseERC721(address tokenAddress, address owner, address recipient, uint256 tokenID) internal {
        IERC721 erc721 = IERC721(tokenAddress);
        erc721.transferFrom(owner, recipient, tokenID);
    }

    function mintERC721(address tokenAddress, address recipient, uint256 tokenID, bytes memory data) internal {
        ERC721MinterBurnerPauser erc721 = ERC721MinterBurnerPauser(tokenAddress);
        erc721.mint(recipient, tokenID, string(data));
    }

    function burnERC721(address tokenAddress, uint256 tokenID) internal {
        ERC721MinterBurnerPauser erc721 = ERC721MinterBurnerPauser(tokenAddress);
        erc721.burn(tokenID);
    }

}
