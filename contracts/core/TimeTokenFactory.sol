// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {TimeRedeemToken} from "./TimeRedeemToken.sol";
import {TimeDebtToken} from "./TimeDebtToken.sol";
import {ITimeTokenFactory} from "../interfaces/ITimeTokenFactory.sol";
contract TimeTokenFactory is ITimeTokenFactory {

    address private owner;
    address private manager;
    address public timeFlowFactory;

    constructor(address _owner, address _manager, address _timeFlowFactory){
        owner = _owner;
        manager = _manager;
        timeFlowFactory = _timeFlowFactory;
    }

    mapping(uint256 => TokenInfo) private tokenInfo;

    function transferManager(address newManager) external {
        require(msg.sender == owner);
        manager = newManager;
    }

    function createTokens(
        string memory redeemTokenName,
        string memory redeemTokenSymbol, 
        string memory deptTokenName, 
        string memory deptTokenSymbol,
        uint256 thisMarketId
    ) external {
        require(msg.sender == manager, "Non manager");
        address timeRedeemToken = address(
            new TimeRedeemToken{
                salt: keccak256(abi.encodePacked(thisMarketId, block.timestamp, block.chainid))
            }(timeFlowFactory,  thisMarketId, redeemTokenName, redeemTokenSymbol)
        );
        address timeDebtToken = address(
            new TimeDebtToken{
                salt: keccak256(abi.encodePacked(thisMarketId, block.timestamp, block.chainid))
            }(timeFlowFactory,  thisMarketId, deptTokenName, deptTokenSymbol)
        );
        tokenInfo[thisMarketId] = TokenInfo({
            redeemToken: timeRedeemToken,
            deptToken: timeDebtToken
        });
        emit CreateTokens(thisMarketId, timeRedeemToken, timeDebtToken);
        require(timeRedeemToken != address(0) && timeDebtToken != address(0), "Zero address");
    }

    function getTokenInfo(uint256 id) external view returns(TokenInfo memory){
        return tokenInfo[id];
    }
}