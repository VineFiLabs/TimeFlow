// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IGovernance} from "../interfaces/IGovernance.sol";
import {ITimeFlowCore} from "../interfaces/ITimeFlowCore.sol";
import {ITimeFlowFactory} from "../interfaces/ITimeFlowFactory.sol";
import {TimeFlowLibrary} from "../libraries/TimeFlowLibrary.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract TimeFlowHelper {

    bytes1 private immutable ZEROBYTES1;
    bytes1 private immutable ONEBYTES1 = 0x01;
    address public governance;
    address public timeFlowFactory;
    address public owner;

    constructor(address _governance, address _timeFlowFactory){
        governance = _governance;
        timeFlowFactory = _timeFlowFactory;
        owner = msg.sender;
    }

    enum OrderCurrentState{
        inexistence,
        trading,
        found,
        refund,
        absenteeism,
        done
    }

    function changeConfig(address _governance, address _timeFlowFactory) external {
        require(msg.sender == owner, "Non owner");
        governance = _governance;
        timeFlowFactory = _timeFlowFactory;
    }

    function getLastestOrderId(uint256 marketId) public view returns(uint256){
        address market = _getMarket(marketId);
        return ITimeFlowCore(market).orderId();
    }

    function getLastestMarketId() public view returns(uint256){
        return ITimeFlowFactory(timeFlowFactory).marketId();
    } 

    function getOrdersInfo(uint256 marketId, uint256[] calldata orderIds) external view returns(
        OrderCurrentState[] memory orderCurrentStateGroup,
        ITimeFlowCore.OrderInfo[] memory orderInfoGroup
    ){
        uint256 len = orderIds.length;
        orderInfoGroup = new ITimeFlowCore.OrderInfo[](len);
        orderCurrentStateGroup = new OrderCurrentState[](len);
        unchecked {
            for(uint256 i; i<len; i++){
                orderCurrentStateGroup[i] = getOrderState(marketId, orderIds[i]);
                orderInfoGroup[i] = getOrderInfo(marketId, orderIds[i]);
            }
        }
    }

    function getMarketInfo(
        uint256 pageIndex
    ) external view returns(
        ITimeFlowFactory.MarketInfo[] memory marketInfoGroup,
        IGovernance.MarketConfig[] memory marketConfigGroup
    ){  
        uint256 lastestMarketId = getLastestMarketId();
        if(lastestMarketId > 0){
            require(pageIndex <= lastestMarketId / 10, "Page index overflow");
            uint256 len;
            uint256 currentMarketId;
            if(lastestMarketId <= 10){
                len = lastestMarketId;
            }else {
                if(lastestMarketId % 10 == 0){
                    len = 10;
                }else{
                    len = lastestMarketId % 10;
                }
                if(pageIndex !=0 ){
                    currentMarketId = pageIndex * 10;
                }
            }
            marketInfoGroup = new ITimeFlowFactory.MarketInfo[](len);
            marketConfigGroup = new IGovernance.MarketConfig[](len);
            unchecked {
                for(uint256 i; i<len; i++){
                    marketInfoGroup[i] = ITimeFlowFactory(timeFlowFactory).getMarketInfo(currentMarketId);
                    marketConfigGroup[i] = IGovernance(governance).getMarketConfig(currentMarketId);
                    currentMarketId++;
                }
            }
        }
    }

    function getMarketOrderInfos(
        uint256 marketId, 
        uint256 pageIndex
    ) external view returns(ITimeFlowCore.OrderInfo[] memory orderInfoGroup){
        uint256 lastestOrderId = getLastestOrderId(marketId);
        if(lastestOrderId > 0){
            require(pageIndex <= lastestOrderId / 10, "Page index overflow");
            uint256 len;
            uint256 currentOrderId;
            if(lastestOrderId <= 10){
                len = lastestOrderId;
            }else {
                if(lastestOrderId % 10 == 0){
                    len = 10;
                }else{
                    len = lastestOrderId % 10;
                }
                if(pageIndex !=0 ){
                    currentOrderId = pageIndex * 10;
                }
            }
            orderInfoGroup = new ITimeFlowCore.OrderInfo[](len);
            unchecked {
                for(uint256 i; i<len; i++){
                    orderInfoGroup[i] = getOrderInfo(marketId, currentOrderId);
                    currentOrderId++;
                }
            }
        }
    }

    function getOrderInfo(uint256 marketId, uint256 orderId) public view returns(ITimeFlowCore.OrderInfo memory){
        address market = _getMarket(marketId);
        return ITimeFlowCore(market).getOrderInfo(orderId);
    }

    function getMarketUserInfo(uint256 marketId, address user) external view returns(
        uint128 buyDoneAmount,
        uint128 sellDoneAmount
    ){
        address market = _getMarket(marketId);
        (buyDoneAmount, sellDoneAmount) = ITimeFlowCore(market).getUserInfo(user);
    }

    function getMarketLastestPriceInfo(uint256 marketId) external view returns(
        uint64 thisLatestMaxBuyPrice,
        uint64 thisLatestMinSellPrice,
        uint64 thisLatestMaxDoneBuyPrice,
        uint64 thisLatestMaxDoneSellPrice
    ){
        address market = _getMarket(marketId);
        thisLatestMaxBuyPrice = ITimeFlowCore(market).latestMaxBuyPrice();
        thisLatestMinSellPrice = ITimeFlowCore(market).latestMinSellPrice();
        thisLatestMaxDoneBuyPrice = ITimeFlowCore(market).latestMaxDoneBuyPrice();
        thisLatestMaxDoneSellPrice = ITimeFlowCore(market).latestMaxDoneSellPrice();
    }

    function getUserJoinMarkets(address user, uint256 pageIndex) external view returns(uint256[] memory marketIds) {
         uint256 joinMarketLen = IGovernance(governance).getUserJoinMarketLength(user);
        if(joinMarketLen > 0){
            require(pageIndex <= joinMarketLen / 10, "Page index overflow");
            uint256 len;
            uint256 indexId;
            if(joinMarketLen <= 10){
                len = joinMarketLen;
            }else {
                if(joinMarketLen % 10 == 0){
                    len = 10;
                }else{
                    len = joinMarketLen % 10;
                }
                if(pageIndex !=0 ){
                    indexId = pageIndex * 10;
                }
            }
            marketIds = new uint256[](len);
            unchecked {
                for(uint256 i; i<len; i++){
                    marketIds[i] = IGovernance(governance).indexUserJoinInfoGroup(user, indexId);
                    indexId++;
                }
            }
        }
    }

    function indexUserBuyIds(
        uint256 marketId, 
        address user, 
        uint16 pageIndex
    ) external view returns(uint256[] memory buyIdGroup) {
        uint256 len;
        uint256 currentId;
        address market = _getMarket(marketId);
        uint256 buyIdsLength = ITimeFlowCore(market).getUserBuyIdsLength(user);
        require(pageIndex <= buyIdsLength / 10, "Page index overflow");
        if(buyIdsLength >0 ){
            if(buyIdsLength <= 10){
                len = buyIdsLength;
            }else {
                if(buyIdsLength % 10 == 0){
                    len = 10;
                }else {
                    len = buyIdsLength % 10;
                }
                if(pageIndex >0 ){
                    currentId = pageIndex* 10;
                }
            }
            buyIdGroup = new uint256[](len);
            unchecked {
                for(uint256 i; i<len; i++){
                    buyIdGroup[i] = currentId;
                    currentId++;
                }
            }
        }
    }

    function indexUserSellIds(
        uint256 marketId, 
        address user, 
        uint16 pageIndex
    ) external view returns(uint256[] memory sellIdGroup) {
        uint256 len;
        uint256 currentId;
        address market = _getMarket(marketId);
        uint256 sellIdsLength = ITimeFlowCore(market).getUserSellIdsLength(user);
        require(pageIndex <= sellIdsLength / 10, "Page index overflow");
        if(sellIdsLength >0 ){
            if(sellIdsLength <= 10){
                len = sellIdsLength;
            }else {
                if(sellIdsLength % 10 == 0){
                    len = 10;
                }else {
                    len = sellIdsLength % 10;
                }
                if(pageIndex >0 ){
                    currentId = pageIndex* 10;
                }
            }
        }
        sellIdGroup = new uint256[](len);
        unchecked {
            for(uint256 i; i<len; i++){
                sellIdGroup[i] = currentId;
                currentId++;
            }
        }
    }

    function getOrderState(
        uint256 marketId, 
        uint256 orderId
    ) public view returns(OrderCurrentState state) {
        ITimeFlowCore.OrderInfo memory newOrderInfo = getOrderInfo(marketId, orderId);
        uint256 endTime = _getEndTime(marketId); 
        if(endTime == 0 || block.timestamp <= endTime){
            if(
                newOrderInfo.state == ITimeFlowCore.OrderState.buying || 
                newOrderInfo.state == ITimeFlowCore.OrderState.selling
            ){
                state = OrderCurrentState.trading;
            }else if(newOrderInfo.state == ITimeFlowCore.OrderState.found){
                state = OrderCurrentState.found;
            }else if(newOrderInfo.state == ITimeFlowCore.OrderState.done){
                state = OrderCurrentState.done;
            }
            else{
                state = OrderCurrentState.inexistence;
            }
        }else{
            if(
                newOrderInfo.state == ITimeFlowCore.OrderState.buying || 
                newOrderInfo.state == ITimeFlowCore.OrderState.selling
            ){
                state = OrderCurrentState.refund;
            }else if(
                newOrderInfo.state == ITimeFlowCore.OrderState.found
            ){
                state = OrderCurrentState.absenteeism;
            }else if(
                newOrderInfo.state == ITimeFlowCore.OrderState.done
            ){
                state = OrderCurrentState.done;
            }else {
                state = OrderCurrentState.inexistence;
            }
        }
    }
    
    function getTokenDecimals(address token) public view returns(uint8) {
        return IERC20Metadata(token).decimals();
    }

    function getUserTokenBalance(address token, address user) public view returns(uint256) {
        return IERC20(token).balanceOf(user);
    }

    function getFee(
        uint256 marketId,
        uint256 total
    ) public view returns(uint256 _thisFee){
        address collateral = IGovernance(governance).getMarketConfig(marketId).collateral;
        uint8 decimals = getTokenDecimals(collateral);
        _thisFee = TimeFlowLibrary._fee(
            total,
            decimals
        );
    }

    function getTradeAmount(
        ITimeFlowCore.OrderType orderType,
        uint64 price,
        uint256 marketId,
        uint256[] calldata orderIds
    ) external view returns(
        uint256 fee,
        uint256 collateralTokenAmount,
        uint256 waitTokenAmount
    ) {
        if(block.timestamp + 12 hours < _getEndTime(marketId)){
            unchecked{
                for(uint256 i; i<orderIds.length; i++){
                    ITimeFlowCore.OrderInfo memory newOrderInfo = getOrderInfo(marketId, orderIds[i]);
                    uint64 currentPrice = newOrderInfo.price;
                    uint128 remainAmount;
                    //buy
                    if(orderType == ITimeFlowCore.OrderType.buy){
                        if(newOrderInfo.state == ITimeFlowCore.OrderState.selling){
                            if(currentPrice <= price){
                                remainAmount = newOrderInfo.amount - newOrderInfo.doneAmount;
                                if(remainAmount > 0){
                                    fee += getFee(marketId, remainAmount);
                                }
                            }
                        }
                    }else{
                        //sell
                        if(newOrderInfo.state == ITimeFlowCore.OrderState.buying){
                            if(currentPrice >= price){
                                remainAmount = newOrderInfo.amount - newOrderInfo.doneAmount;
                            }
                        }
                    }
                    if(remainAmount> 0){   
                        waitTokenAmount += remainAmount;
                        collateralTokenAmount += TimeFlowLibrary._getTotalCollateral(newOrderInfo.price , remainAmount);
                    }
                }
            }
        }
        if(collateralTokenAmount > 0){
            if(orderType == ITimeFlowCore.OrderType.buy){
                collateralTokenAmount = collateralTokenAmount * 2 - fee;
            }
        }
            
    }

    function getCancelAmount(
        uint256 marketId,
        address user,
        uint256[] calldata orderIds
    ) external view returns(
        uint256 fee,
        uint256 collateralTokenAmount
    ) { 
        if(block.timestamp + 12 hours < _getEndTime(marketId)){
            unchecked {
                for(uint256 i; i<orderIds.length; i++){
                    ITimeFlowCore.OrderInfo memory newOrderInfo = getOrderInfo(marketId, orderIds[i]);
                    if(user == newOrderInfo.creator){
                        if(
                            newOrderInfo.state == ITimeFlowCore.OrderState.buying || 
                            newOrderInfo.state == ITimeFlowCore.OrderState.selling
                        ){
                            uint128 remainAmount = newOrderInfo.amount - newOrderInfo.doneAmount;
                            if(remainAmount >0){
                                collateralTokenAmount += TimeFlowLibrary._getTotalCollateral(newOrderInfo.price , remainAmount);
                            }
                            newOrderInfo.state = ITimeFlowCore.OrderState.fail;
                        }
                    }
                }
            }
            fee = collateralTokenAmount * 5 / 1000;
            collateralTokenAmount = collateralTokenAmount - fee;
        }
    }

    function getDepositeAmount(
        uint256 marketId,
        address user,
        uint256[] calldata orderIds
    ) external view returns (
        uint256 waitTokenAmount
    ){  
        unchecked {
            for(uint256 i; i< orderIds.length; i++){
                ITimeFlowCore.OrderInfo memory newOrderInfo = getOrderInfo(marketId, orderIds[i]);
                if(user == newOrderInfo.creator){
                    if(
                        newOrderInfo.orderType == ITimeFlowCore.OrderType.sell && 
                        newOrderInfo.state == ITimeFlowCore.OrderState.found
                    ){
                        waitTokenAmount +=  newOrderInfo.doneAmount;
                    }
                }else if(user == newOrderInfo.trader){
                    if(
                        newOrderInfo.orderType == ITimeFlowCore.OrderType.buy && 
                        newOrderInfo.state == ITimeFlowCore.OrderState.found
                    ){
                        waitTokenAmount +=  newOrderInfo.doneAmount;
                    }
                }
            }
        }
    }

    function getRefundAmount(
        uint256 marketId,
        address user,
        uint256[] calldata orderIds
    ) external view returns(uint256 collateralTokenAmount) {
        if(block.timestamp > _getEndTime(marketId) && _getEndTime(marketId) != 0){
            unchecked {
                for(uint256 i; i<orderIds.length; i++){
                    ITimeFlowCore.OrderInfo memory newOrderInfo = getOrderInfo(marketId, orderIds[i]);
                    if(user == newOrderInfo.creator){
                        if(
                            newOrderInfo.state == ITimeFlowCore.OrderState.buying || 
                            newOrderInfo.state == ITimeFlowCore.OrderState.selling
                        ){
                            collateralTokenAmount += TimeFlowLibrary._getTotalCollateral(newOrderInfo.price , newOrderInfo.amount - newOrderInfo.doneAmount);
                        }
                    }
                }
            }
        }
    }

    function getDoneOrderWithdrawAmount(
        uint256 marketId,
        address user,
        uint256[] calldata orderIds
    ) external view returns(
        uint256 fee,
        uint256 collateralTokenAmount,
        uint256 waitTokenAmount
    ){
        if(block.timestamp > _getEndTime(marketId)){
            unchecked {
                for(uint256 i; i< orderIds.length; i++){
                    ITimeFlowCore.OrderInfo memory newOrderInfo = getOrderInfo(marketId, orderIds[i]);
                    uint256 thisTotalAmount = TimeFlowLibrary._getTotalCollateral(newOrderInfo.price, newOrderInfo.amount);
                    if(user == newOrderInfo.creator){
                        if(
                            newOrderInfo.orderType == ITimeFlowCore.OrderType.buy && 
                            newOrderInfo.state == ITimeFlowCore.OrderState.done
                        ){
                            if(newOrderInfo.creatorWithdrawState == ZEROBYTES1){
                                waitTokenAmount += newOrderInfo.amount;
                            }
                        } else if(
                            newOrderInfo.orderType == ITimeFlowCore.OrderType.sell && 
                            newOrderInfo.state == ITimeFlowCore.OrderState.done
                        ){
                            if(newOrderInfo.creatorWithdrawState == ZEROBYTES1){
                                collateralTokenAmount += thisTotalAmount;
                                fee += getFee(marketId, thisTotalAmount);
                            }
                        }
                    }else if (user == newOrderInfo.trader){
                        if(
                            newOrderInfo.orderType == ITimeFlowCore.OrderType.buy && 
                            newOrderInfo.state == ITimeFlowCore.OrderState.done
                        ){
                            if(newOrderInfo.traderWithdrawState == ZEROBYTES1){
                                collateralTokenAmount += thisTotalAmount;
                                fee += getFee(marketId, thisTotalAmount);
                            }
                        } else if(
                            newOrderInfo.orderType == ITimeFlowCore.OrderType.sell && 
                            newOrderInfo.state == ITimeFlowCore.OrderState.done
                        ){
                            if(newOrderInfo.traderWithdrawState == ZEROBYTES1){
                                waitTokenAmount += newOrderInfo.amount;
                            }
                        }
                    }else {
                        revert("Invalid user");
                    }
                }
            }
        }
        collateralTokenAmount = collateralTokenAmount * 2 - fee;
    }

    function getLiquidatedDamages(
        uint256 marketId,
        address user,
        uint256[] calldata orderIds
    ) external view returns (
        uint256 fee,
        uint256 collateralTokenAmount
    ){
        if(block.timestamp > _getEndTime(marketId)){
            unchecked {
                for(uint256 i; i< orderIds.length; i++){
                    ITimeFlowCore.OrderInfo memory newOrderInfo = getOrderInfo(marketId, orderIds[i]);
                    uint256 thisTotalAmount = TimeFlowLibrary._getTotalCollateral(newOrderInfo.price, newOrderInfo.amount);
                    if(user == newOrderInfo.creator){
                        if(newOrderInfo.state == ITimeFlowCore.OrderState.found){
                            if(newOrderInfo.orderType == ITimeFlowCore.OrderType.buy){}
                        }
                    }else if(user == newOrderInfo.trader){
                        if(newOrderInfo.state == ITimeFlowCore.OrderState.found){
                            if(newOrderInfo.orderType == ITimeFlowCore.OrderType.sell){}
                        }
                    }else{
                        revert("Invalid user");
                    }
                    collateralTokenAmount += thisTotalAmount;
                    fee += getFee(marketId, thisTotalAmount);
                }
            }
        }
        collateralTokenAmount = collateralTokenAmount * 2 - fee;
    }

    function _getMarket(uint256 marketId) private view returns(address) {
        return ITimeFlowFactory(timeFlowFactory).getMarketInfo(marketId).market;
    }

    function _getEndTime(uint256 marketId) private view returns(uint256) {
        return IGovernance(governance).getMarketConfig(marketId).endTime;
    }

}