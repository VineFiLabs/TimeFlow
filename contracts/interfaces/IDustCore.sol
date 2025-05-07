// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IDustCore{

    enum FlowWay{
        doTransfer,
        flow
    }

    enum UserFlowState{
        sendFlow,
        receiveFlow
    }

    struct DustCollateralInfo {
        bytes1 activeState;
        uint8 liquidationRatio;
        uint16 liquidationRewardRatio; 
        uint256 reserve;
    }

    struct DustFlowInfo {
        FlowWay way;
        address sender;
        address receiver;
        address flowToken;
        uint64 startTime;
        uint64 endTime;
        uint128 amount;
        uint128 doneAmount;
        uint256 lastestWithdrawTime;
    } 
    
    event Initialize(bytes1 state);
    event LockEvent(bytes1 state);
    event Flow(FlowWay indexed way, address indexed sender, address receiver, uint256 amount);

}

