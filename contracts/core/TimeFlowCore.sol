// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IGovernance} from "../interfaces/IGovernance.sol";
import {ITimeFlowCore} from "../interfaces/ITimeFlowCore.sol";
import {TimeFlowLibrary} from "../libraries/TimeFlowLibrary.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract TimeFlowCore is ReentrancyGuard, ITimeFlowCore {
    using SafeERC20 for IERC20;

    uint256 public currentMarketId;
    uint256 public orderId;

    bytes1 private immutable ZEROBYTES1;
    bytes1 private immutable ONEBYTES1 = 0x01;
    address public governance;
    address public manager;

    uint128 public latestMaxBuyPrice;
    uint128 public latestMinSellPrice;
    uint128 public latestMaxDoneBuyPrice;
    uint128 public latestMaxDoneSellPrice;

    constructor(
        address _governance,
        address _manager,
        uint256 _marketId
    ){
        manager = _manager;
        governance = _governance;
        currentMarketId = _marketId;
    }

    mapping(uint256 => OrderInfo) private orderInfo;
    mapping(address => UserInfo) private userInfo;

    modifier onlyManager{
        require(msg.sender == manager);
        _;
    }

    function putTrade(
        OrderType _orderType,
        uint64 _amount,
        uint128 _price
    ) external nonReentrant {
        _checkOrderCloseState();
        if(_orderType == OrderType.buy){
            if(_price >= latestMinSellPrice && latestMinSellPrice != 0){revert InvalidPrice(latestMinSellPrice);}
            orderInfo[orderId].state = OrderState.buying;
            userInfo[msg.sender].buyIdGroup.push(orderId);
            if(_price > latestMaxBuyPrice){
                latestMaxBuyPrice = _price;
            }
        }else {
            if(_price <= latestMaxBuyPrice && latestMaxBuyPrice != 0){revert InvalidPrice(latestMaxBuyPrice);}
            orderInfo[orderId].state = OrderState.selling;
            userInfo[msg.sender].sellIdGroup.push(orderId);
            if(_price < latestMinSellPrice){
                latestMinSellPrice = _price;
            }
        }
        orderInfo[orderId].orderType = _orderType;
        uint256 total = _amount * _price;
        address collateral = _getMarketConfig().collateral;
        require(total >= 10 * 10 ** _collateralDecimals(collateral));
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), total);
        orderInfo[orderId].amount = _amount;
        orderInfo[orderId].price = _price;
        orderInfo[orderId].creator = msg.sender;
        orderInfo[orderId].creationTime = block.timestamp;

        emit CreateOrder(orderId, msg.sender, total);
        orderId++;
    }

    function matchTrade(
        OrderType _orderType,
        uint64 _amount,
        uint128 _price,
        uint256[] calldata orderIds
    ) external nonReentrant {
        _checkOrderCloseState();
        uint256 collateralTokenAmount;
        uint64 waitTokenAmount;
        unchecked{
            for(uint256 i; i<orderIds.length; i++){
                uint64 remainAmount;
                uint128 currentPrice = orderInfo[orderIds[i]].price;
                address creator = orderInfo[orderIds[i]].creator;
                //buy
                if(_orderType == OrderType.buy){
                    if(orderInfo[orderIds[i]].state == OrderState.selling){
                        if(currentPrice <= _price){
                            remainAmount = orderInfo[orderIds[i]].amount - orderInfo[orderIds[i]].doneAmount;
                            if(remainAmount == 0){
                                orderInfo[orderIds[i]].doneAmount = orderInfo[orderIds[i]].amount;
                            }else {
                                userInfo[msg.sender].buyIdGroup.push(orderIds[i]);
                                userInfo[creator].sellDoneAmount += remainAmount;
                                if(currentPrice > latestMaxDoneSellPrice){
                                    latestMaxDoneSellPrice = currentPrice;
                                }
                            }
                        }
                    }
                }else{
                    //sell
                    if(orderInfo[orderIds[i]].state == OrderState.buying){
                        if(currentPrice >= _price){
                            remainAmount = orderInfo[orderIds[i]].amount - orderInfo[orderIds[i]].doneAmount;
                            if(remainAmount == 0){
                                orderInfo[orderIds[i]].doneAmount = orderInfo[orderIds[i]].amount;
                            }else{
                                userInfo[msg.sender].sellIdGroup.push(orderIds[i]);
                                userInfo[creator].buyDoneAmount += remainAmount;
                                if(currentPrice > latestMaxDoneBuyPrice){
                                    latestMaxDoneBuyPrice = currentPrice;
                                }
                            }
                        }
                    }
                }
                if(remainAmount> 0){   
                    if(remainAmount > _amount - waitTokenAmount){
                        orderInfo[orderIds[i]].doneAmount += _amount - waitTokenAmount;
                    }else{
                        orderInfo[orderIds[i]].doneAmount = orderInfo[orderIds[i]].amount;
                        orderInfo[orderIds[i]].state = OrderState.found;
                    }
                    orderInfo[orderIds[i]].trader = msg.sender;
                    waitTokenAmount += remainAmount;
                    collateralTokenAmount += remainAmount * currentPrice;
                }
            }
        }
        if(waitTokenAmount == 0){revert ZeroQuantity();}
        address collateral = _getMarketConfig().collateral;
        uint256 fee = TimeFlowLibrary._fee(collateralTokenAmount, _collateralDecimals(collateral));
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), collateralTokenAmount);
        
        if(_orderType == OrderType.buy){
            userInfo[msg.sender].buyDoneAmount += waitTokenAmount;
            _safeTransferFee(collateral, fee);
        }else{
            userInfo[msg.sender].sellDoneAmount += waitTokenAmount;
        }
        emit MatchOrders(orderIds, _orderType);
        
    }

    function Cancel(uint256[] calldata orderIds) external nonReentrant {
        _checkOrderCloseState();
        uint256 cancelCollateralTokenAmount;
        unchecked {
            for(uint256 i; i<orderIds.length; i++){
                if(msg.sender == orderInfo[orderIds[i]].creator){
                    if(orderInfo[orderIds[i]].state == OrderState.buying || orderInfo[orderIds[i]].state == OrderState.selling){
                        uint256 remainAmount = orderInfo[orderIds[i]].amount - orderInfo[orderIds[i]].doneAmount;
                        if(remainAmount >0){
                            cancelCollateralTokenAmount += remainAmount * orderInfo[orderIds[i]].price;
                        }
                        orderInfo[orderIds[i]].state = OrderState.fail;
                    }
                }
            }
        }
        if(cancelCollateralTokenAmount == 0){revert ZeroQuantity();}
        address collateral = _getMarketConfig().collateral;
        //0.5%
        uint256 fee = cancelCollateralTokenAmount * 5 / 1000;
        IERC20(collateral).safeTransfer(msg.sender, cancelCollateralTokenAmount - fee);
        _safeTransferFee(collateral, fee);
        emit CancelOrders(orderIds);
    }

    function deposite(uint256[] calldata orderIds) external nonReentrant {
        uint256 endTime = _getMarketConfig().endTime;
        if(block.timestamp >= endTime){revert OrderAlreadyClose(block.timestamp);}
        uint256 waitTokenAmount;
        unchecked {
            for(uint256 i; i< orderIds.length; i++){
                if(msg.sender == orderInfo[orderIds[i]].creator){
                    if(orderInfo[orderIds[i]].orderType == OrderType.sell && orderInfo[orderIds[i]].state == OrderState.found){
                        waitTokenAmount +=  orderInfo[orderIds[i]].doneAmount;
                        userInfo[msg.sender].sellDoneAmount -= orderInfo[orderIds[i]].doneAmount;
                        orderInfo[orderIds[i]].state = OrderState.done;
                    }
                }else if(msg.sender == orderInfo[orderIds[i]].trader){
                    if(orderInfo[orderIds[i]].orderType == OrderType.buy && orderInfo[orderIds[i]].state == OrderState.found){
                        waitTokenAmount +=  orderInfo[orderIds[i]].doneAmount;
                        userInfo[msg.sender].sellDoneAmount -= orderInfo[orderIds[i]].doneAmount;
                        orderInfo[orderIds[i]].state = OrderState.done;
                    }
                }
            }
        }
        if(waitTokenAmount ==0){revert ZeroQuantity();}
        address waitToken = _getMarketConfig().waitToken;
        IERC20(waitToken).safeTransferFrom(msg.sender, address(this), waitTokenAmount);
        emit DepositeOrders(orderIds);
    }

    function refund(uint256[] calldata orderIds) external nonReentrant {
        _checkOrderEndState();
        address collateral = _getMarketConfig().collateral;
        uint256 refundAmount;
        unchecked {
            for(uint256 i; i< orderIds.length; i++){
                if(msg.sender == orderInfo[orderIds[i]].creator){
                    if(orderInfo[orderIds[i]].state == OrderState.buying || orderInfo[orderIds[i]].state == OrderState.selling){
                        refundAmount += orderInfo[orderIds[i]].amount * orderInfo[orderIds[i]].price;
                        orderInfo[orderIds[i]].state = OrderState.fail;
                    }
                }
            }
        }
        if(refundAmount == 0){revert ZeroQuantity();}
        IERC20(collateral).safeTransfer(msg.sender, refundAmount);
        emit RefundOrders(orderIds);
    }

    function withdraw(OrderType orderType, uint256[] calldata orderIds) external nonReentrant {
        _checkOrderEndState();
        address waitToken = _getMarketConfig().waitToken;
        address collateral = _getMarketConfig().collateral;
        uint8 tokenDecimals = _collateralDecimals(collateral);
        uint256 collateralTokenAmount;
        uint256 waitTokenAmount;
        unchecked {
            for(uint256 i; i< orderIds.length; i++){
                if(msg.sender == orderInfo[orderIds[i]].creator){
                    if(
                        orderType == OrderType.buy && 
                        orderInfo[orderIds[i]].orderType == orderType && 
                        orderInfo[orderIds[i]].state == OrderState.done
                    ){
                        if(orderInfo[orderIds[i]].creatorWithdrawState == ZEROBYTES1){
                            waitTokenAmount += orderInfo[orderIds[i]].amount;
                            orderInfo[orderIds[i]].creatorWithdrawState = ONEBYTES1;
                        }
                    } else if(
                        orderType == OrderType.sell && 
                        orderInfo[orderIds[i]].orderType == orderType && 
                        orderInfo[orderIds[i]].state == OrderState.done
                    ){
                        if(orderInfo[orderIds[i]].creatorWithdrawState == ZEROBYTES1){
                            collateralTokenAmount += orderInfo[orderIds[i]].amount * orderInfo[orderIds[i]].price;
                            orderInfo[orderIds[i]].creatorWithdrawState = ONEBYTES1;
                        }
                    }
                }else if (msg.sender == orderInfo[orderIds[i]].trader){
                    if(
                        orderType == OrderType.buy && 
                        orderInfo[orderIds[i]].orderType == orderType && 
                        orderInfo[orderIds[i]].state == OrderState.done
                    ){
                        if(orderInfo[orderIds[i]].traderWithdrawState == ZEROBYTES1){
                            collateralTokenAmount += orderInfo[orderIds[i]].amount * orderInfo[orderIds[i]].price;
                            orderInfo[orderIds[i]].traderWithdrawState = ONEBYTES1;
                        }
                    } else if(
                        orderType == OrderType.sell && 
                        orderInfo[orderIds[i]].orderType == orderType && 
                        orderInfo[orderIds[i]].state == OrderState.done
                    ){
                        if(orderInfo[orderIds[i]].traderWithdrawState == ZEROBYTES1){
                            waitTokenAmount += orderInfo[orderIds[i]].amount;
                            orderInfo[orderIds[i]].traderWithdrawState = ONEBYTES1;
                        }
                    }
                }else {
                    revert InvalidUser();
                }
            }
        }
        if(waitTokenAmount == 0 || collateralTokenAmount == 0){revert ZeroQuantity();}
        if(orderType == OrderType.buy){
            IERC20(waitToken).safeTransfer(msg.sender, waitTokenAmount);
        // sell pay fee
        }else{
            uint256 fee = TimeFlowLibrary._fee(collateralTokenAmount, tokenDecimals);
            IERC20(collateral).safeTransfer(msg.sender, collateralTokenAmount * 2 - fee);
            _safeTransferFee(collateral, fee);
        }
        emit WithdrawOrders(orderIds);
    }

    function withdrawLiquidatedDamages(uint256[] calldata orderIds) external {
        _checkOrderEndState();
        address collateral = _getMarketConfig().collateral;
        uint8 tokenDecimals = _collateralDecimals(collateral);
        uint256 liquidatedDamagesAmount;
        unchecked {
            for(uint256 i; i< orderIds.length; i++){
                if(msg.sender == orderInfo[orderIds[i]].creator){
                    if(orderInfo[orderIds[i]].state == OrderState.found){
                        if(orderInfo[orderIds[i]].orderType == OrderType.buy){
                            orderInfo[orderIds[i]].state = OrderState.fail;
                        }
                    }
                }else if(msg.sender == orderInfo[orderIds[i]].trader){
                    if(orderInfo[orderIds[i]].state == OrderState.found){
                        if(orderInfo[orderIds[i]].orderType == OrderType.sell){
                            orderInfo[orderIds[i]].state = OrderState.fail;
                        }
                    }
                }else{
                    revert InvalidUser();
                }
                liquidatedDamagesAmount += orderInfo[orderIds[i]].amount * orderInfo[orderIds[i]].price;
            }
        }
        if(liquidatedDamagesAmount == 0){revert ZeroQuantity();}
        uint256 fee = TimeFlowLibrary._fee(liquidatedDamagesAmount, tokenDecimals);
        IERC20(collateral).safeTransfer(msg.sender, liquidatedDamagesAmount * 2 - fee);
        _safeTransferFee(collateral, fee);
        emit WithdrawLiquidatedDamages(orderIds);
    }

    function _getMarketConfig() private view returns(IGovernance.MarketConfig memory) {
        return IGovernance(governance).getMarketConfig(currentMarketId);
    }

    function _collateralDecimals(address collateral) private view returns(uint8){
        return IERC20Metadata(collateral).decimals();
    }

    function _getFeeInfo() private view returns(IGovernance.FeeInfo memory) {
        return IGovernance(governance).getFeeInfo();
    }

    function _safeTransferFee(address collateral, uint256 fee) private {
        uint256 dustFee = fee *  _getFeeInfo().rate / 100;
        uint256 protocolFee = fee * (100 -  _getFeeInfo().rate) / 100;
        address dust = _getFeeInfo().dust;
        address feeReceiver = _getFeeInfo().feeReceiver;
        //transfer to dust
        IERC20(collateral).safeTransfer(dust, dustFee);
        //transfer to feeReceiver
        IERC20(collateral).safeTransfer(feeReceiver, protocolFee);
    }

    function _checkOrderCloseState() private view {
        if(block.timestamp - 12 hours >= _getMarketConfig().endTime){revert OrderAlreadyClose(block.timestamp);}
    }

    function _checkOrderEndState() private view {
        uint256 endTime = _getMarketConfig().endTime;
        if(endTime == 0 || block.timestamp <= endTime){revert NotEnd(block.timestamp);}
    }

    function getOrderInfo(uint256 thisOrderId) external view returns(OrderInfo memory) {
        return orderInfo[thisOrderId];
    }

    function getUserInfo(address user) external view returns (
        uint64 thisBuyDoneAmount,
        uint64 thisSellDoneAmount
    ){
        thisBuyDoneAmount = userInfo[user].buyDoneAmount;
        thisSellDoneAmount = userInfo[user].sellDoneAmount;
    }

    function indexUserBuyId(address user, uint256 index) external view returns(uint256 buyId) {
        buyId = userInfo[user].buyIdGroup[index];
    }

    function indexUserSellId(address user, uint256 index) external view returns(uint256 sellId) {
        sellId = userInfo[user].sellIdGroup[index];
    }

    function getUserBuyIdsLength(address user) external view returns(uint256) {
        return userInfo[user].buyIdGroup.length;
    }

    function getUserSellIdsLength(address user) external view returns(uint256) {
        return userInfo[user].sellIdGroup.length;
    }

    

    
}