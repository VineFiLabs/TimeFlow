// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {ITimeFlowFactory} from "../interfaces/ITimeFlowFactory.sol";
import {IGovernance} from "../interfaces/IGovernance.sol";
import {TimeFlowCore} from "./TimeFlowCore.sol";
contract TimeFlowFactory is ITimeFlowFactory {

    uint256 public marketId;
    address public governance;

    constructor(address _governance) {
        governance = _governance;
    }

    mapping(uint256 => MarketInfo) private marketInfo;

    function createMarket() external {
        address currentManager = IGovernance(governance).manager();
        require(msg.sender == currentManager);
        address timeFlowCore = address(
            new TimeFlowCore{
                salt: keccak256(abi.encodePacked(marketId, block.timestamp, block.chainid))
            }(governance, currentManager, marketId)
        );
        marketInfo[marketId] = MarketInfo({
            market: timeFlowCore,
            createTime: uint64(block.timestamp)
        });
        emit CreateMarket(marketId, timeFlowCore);
        marketId++;
        require(timeFlowCore != address(0), "Zero address");
    }

    function getMarketInfo(uint256 id) external view returns(MarketInfo memory) {
        return marketInfo[id];
    }
}