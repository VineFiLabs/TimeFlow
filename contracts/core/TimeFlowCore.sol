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

    uint64 public latestMaxBuyPrice;
    uint64 public latestMinSellPrice;
    uint64 public latestMaxDoneBuyPrice;
    uint64 public latestMaxDoneSellPrice;

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
        uint128 _amount,
        uint64 _price
    ) external nonReentrant {
        _checkOrderCloseState();
        if(_orderType == OrderType.buy){
            orderInfo[orderId].state = OrderState.buying;
            userInfo[msg.sender].buyIdGroup.push(orderId);
            if(_price > latestMaxBuyPrice){
                latestMaxBuyPrice = _price;
            }
        }else {
            orderInfo[orderId].state = OrderState.selling;
            userInfo[msg.sender].sellIdGroup.push(orderId);
            if(_price < latestMinSellPrice){
                latestMinSellPrice = _price;
            }
        }
        orderInfo[orderId].orderType = _orderType;
        uint256 total = TimeFlowLibrary._getTotalCollateral(_price, _amount);
        address collateral = _getMarketConfig().collateral;
        require(total >= 10 * 10 ** _collateralDecimals(collateral), "Less than 10$");
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), total);
        orderInfo[orderId].amount = _amount;
        orderInfo[orderId].price = _price;
        orderInfo[orderId].creator = msg.sender;
        orderInfo[orderId].creationTime = block.timestamp;
        _join();
        emit CreateOrder(orderId, msg.sender, total);
        orderId++;
    }

    function matchTrade(
        OrderType _orderType,
        uint128 _amount,
        uint64 _price,
        uint256[] calldata orderIds
    ) external nonReentrant {
        _checkOrderCloseState();
        uint256 collateralTokenAmount;
        uint256 totalFee;
        uint128 waitTokenAmount;
        address collateral = _getMarketConfig().collateral;
        unchecked{
            for(uint256 i; i<orderIds.length; i++){
                uint128 remainAmount;
                uint64 currentPrice = orderInfo[orderIds[i]].price;
                address creator = orderInfo[orderIds[i]].creator;
                if(msg.sender != creator){
                    //buy
                    if(_orderType == OrderType.buy){
                        if(orderInfo[orderIds[i]].state == OrderState.selling){
                            if(currentPrice <= _price){
                                remainAmount = orderInfo[orderIds[i]].amount - orderInfo[orderIds[i]].doneAmount;
                                if(remainAmount > 0){
                                    userInfo[msg.sender].buyIdGroup.push(orderIds[i]);
                                    userInfo[creator].sellDoneAmount += remainAmount;
                                    totalFee += TimeFlowLibrary._fee(remainAmount, _collateralDecimals(collateral));
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
                                if(remainAmount > 0){
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
                            orderInfo[orderIds[i]].doneAmount += remainAmount;
                            orderInfo[orderIds[i]].state = OrderState.found;
                        }
                        orderInfo[orderIds[i]].trader = msg.sender;
                        waitTokenAmount += remainAmount;
                        collateralTokenAmount += TimeFlowLibrary._getTotalCollateral(currentPrice, remainAmount);
                    }
                }else{
                    revert InvalidUser();
                }
            }
        }
        if(waitTokenAmount == 0){revert ZeroQuantity();}
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), collateralTokenAmount);
        _join();
        if(_orderType == OrderType.buy){
            userInfo[msg.sender].buyDoneAmount += waitTokenAmount;
            _safeTransferFee(collateral, totalFee);
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
                        uint128 remainAmount = orderInfo[orderIds[i]].amount - orderInfo[orderIds[i]].doneAmount;
                        if(remainAmount >0){
                            cancelCollateralTokenAmount += TimeFlowLibrary._getTotalCollateral(orderInfo[orderIds[i]].price, remainAmount);
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
                        if(orderInfo[orderIds[i]].creatorWithdrawState == ZEROBYTES1){
                            refundAmount += TimeFlowLibrary._getTotalCollateral(
                                orderInfo[orderIds[i]].price, 
                                orderInfo[orderIds[i]].amount - orderInfo[orderIds[i]].doneAmount
                            );
                            orderInfo[orderIds[i]].creatorWithdrawState = ONEBYTES1;
                        }
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
        uint256 totalFee;
        uint256 collateralTokenAmount;
        uint256 waitTokenAmount;
        unchecked {
            for(uint256 i; i< orderIds.length; i++){
                uint128 amount = orderInfo[orderIds[i]].amount;
                uint256 thisTotalAmount = TimeFlowLibrary._getTotalCollateral(orderInfo[orderIds[i]].price, amount);
                if(msg.sender == orderInfo[orderIds[i]].creator){
                    if(
                        orderType == OrderType.buy && 
                        orderInfo[orderIds[i]].orderType == orderType && 
                        orderInfo[orderIds[i]].state == OrderState.done
                    ){
                        if(orderInfo[orderIds[i]].creatorWithdrawState == ZEROBYTES1){
                            waitTokenAmount += amount;
                            orderInfo[orderIds[i]].creatorWithdrawState = ONEBYTES1;
                        }
                    } else if(
                        orderType == OrderType.sell && 
                        orderInfo[orderIds[i]].orderType == orderType && 
                        orderInfo[orderIds[i]].state == OrderState.done
                    ){
                        if(orderInfo[orderIds[i]].creatorWithdrawState == ZEROBYTES1){
                            collateralTokenAmount += thisTotalAmount;
                            totalFee += TimeFlowLibrary._fee(thisTotalAmount, tokenDecimals);
                            orderInfo[orderIds[i]].creatorWithdrawState = ONEBYTES1;
                        }
                    }
                }else if (msg.sender == orderInfo[orderIds[i]].trader){
                    if(
                        orderType == OrderType.buy && 
                        orderInfo[orderIds[i]].orderType == OrderType.sell && 
                        orderInfo[orderIds[i]].state == OrderState.done
                    ){
                        if(orderInfo[orderIds[i]].traderWithdrawState == ZEROBYTES1){
                            waitTokenAmount += amount;
                            orderInfo[orderIds[i]].traderWithdrawState = ONEBYTES1;
                        }
                    } else if(
                        orderType == OrderType.sell && 
                        orderInfo[orderIds[i]].orderType == OrderType.buy && 
                        orderInfo[orderIds[i]].state == OrderState.done
                    ){
                        if(orderInfo[orderIds[i]].traderWithdrawState == ZEROBYTES1){
                            collateralTokenAmount += thisTotalAmount;
                            totalFee += TimeFlowLibrary._fee(thisTotalAmount, tokenDecimals);
                            orderInfo[orderIds[i]].traderWithdrawState = ONEBYTES1;
                        }
                    }
                }else {
                    revert InvalidUser();
                }
            }
        }
       
        if(orderType == OrderType.buy){
            if(waitTokenAmount == 0){revert ZeroQuantity();}
            IERC20(waitToken).safeTransfer(msg.sender, waitTokenAmount);
        // sell pay fee
        }else{
            if(collateralTokenAmount == 0){revert ZeroQuantity();}
            IERC20(collateral).safeTransfer(msg.sender, collateralTokenAmount * 2 - totalFee);
            _safeTransferFee(collateral, totalFee);
        }
        emit WithdrawOrders(orderIds);
    }

    function withdrawLiquidatedDamages(uint256[] calldata orderIds) external {
        _checkOrderEndState();
        address collateral = _getMarketConfig().collateral;
        uint8 tokenDecimals = _collateralDecimals(collateral);
        uint256 liquidatedDamagesAmount;
        uint256 totalFee;
        unchecked {
            for(uint256 i; i< orderIds.length; i++){
                uint256 thisTotalAmount = TimeFlowLibrary._getTotalCollateral(orderInfo[orderIds[i]].price, orderInfo[orderIds[i]].amount);
                if(msg.sender == orderInfo[orderIds[i]].creator){
                    if(orderInfo[orderIds[i]].state == OrderState.found){
                        if(orderInfo[orderIds[i]].orderType == OrderType.buy){
                            if(orderInfo[orderIds[i]].creatorWithdrawState == ZEROBYTES1){
                                liquidatedDamagesAmount += thisTotalAmount;
                                totalFee += TimeFlowLibrary._fee(thisTotalAmount, tokenDecimals);
                                orderInfo[orderIds[i]].creatorWithdrawState = ONEBYTES1; 
                            }
                        }
                    }
                }else if(msg.sender == orderInfo[orderIds[i]].trader){
                    if(orderInfo[orderIds[i]].state == OrderState.found){
                        if(orderInfo[orderIds[i]].orderType == OrderType.sell){
                            if(orderInfo[orderIds[i]].traderWithdrawState == ZEROBYTES1){
                                liquidatedDamagesAmount += thisTotalAmount;
                                totalFee += TimeFlowLibrary._fee(thisTotalAmount, tokenDecimals);
                                orderInfo[orderIds[i]].traderWithdrawState = ONEBYTES1;
                            }
                        }
                    }
                }else{
                    revert InvalidUser();
                }
            }
        }
        if(liquidatedDamagesAmount == 0){revert ZeroQuantity();}
        IERC20(collateral).safeTransfer(msg.sender, liquidatedDamagesAmount * 2 - totalFee);
        _safeTransferFee(collateral, totalFee);
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
        if(block.timestamp + 12 hours >= _getMarketConfig().endTime){revert OrderAlreadyClose(block.timestamp);}
    }

    function _checkOrderEndState() private view {
        uint256 endTime = _getMarketConfig().endTime;
        if(endTime == 0 || block.timestamp <= endTime){revert NotEnd(block.timestamp);}
    }

    function _join() private {
        IGovernance(governance).join(msg.sender, currentMarketId);
    }

    function getOrderInfo(uint256 thisOrderId) external view returns(OrderInfo memory) {
        return orderInfo[thisOrderId];
    }

    function getUserInfo(address user) external view returns (
        uint128 thisBuyDoneAmount,
        uint128 thisSellDoneAmount
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