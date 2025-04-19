// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;
interface ITimeTokenFactory {

    struct TokenInfo{
        address redeemToken;
        address deptToken;
    }

    event CreateTokens(uint256 indexed id, address redeem, address dept);

    function createTokens(
        string memory redeemTokenName,
        string memory redeemTokenSymbol, 
        string memory deptTokenName, 
        string memory deptTokenSymbol,
        uint256 thisMarketId
    ) external;

    function getTokenInfo(uint256 id) external view returns(TokenInfo memory);
}