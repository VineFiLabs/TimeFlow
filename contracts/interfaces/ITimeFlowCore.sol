// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;
interface ITimeFlowCore {

    enum OrderType{
        buy, 
        sell
    }

    enum OrderState{
        inexistence, 
        buying, 
        selling, 
        found, 
        fail, 
        done
    }

    struct OrderInfo{
        OrderType orderType;
        OrderState state;
        bytes1 creatorWithdrawState;
        bytes1 traderWithdrawState;
        address trader;
        address creator;
        uint64 amount;
        uint64 doneAmount;
        uint128 price;
        uint256 creationTime;
    }

    struct UserInfo{
        uint64 buyDoneAmount;
        uint64 sellDoneAmount;
        // uint256 collateralTokenAmount;
        uint256[] buyIdGroup;
        uint256[] sellIdGroup;
    }

    event CreateOrder(uint256 indexed id, address creator, uint256 total);
    event MatchOrders(uint256[] indexed ids, OrderType thisOrderType);
    event CancelOrders(uint256[] indexed ids);
    event DepositeOrders(uint256[] indexed ids);
    event RefundOrders(uint256[] indexed ids);
    event WithdrawOrders(uint256[] indexed ids);
    event WithdrawLiquidatedDamages(uint256[] indexed ids);

    error InvalidPrice(uint128);
    error ZeroQuantity();
    error OrderAlreadyClose(uint256);
    error NotEnd(uint256);
    error InvalidUser();

    function currentMarketId() external view returns(uint256);
    function orderId() external view returns(uint256);
    function latestMaxBuyPrice() external view returns(uint128);
    function latestMinSellPrice() external view returns(uint128);
    function latestMaxDoneBuyPrice() external view returns(uint128);
    function latestMaxDoneSellPrice() external view returns(uint128);

    function getOrderInfo(uint256 thisOrderId) external view returns(OrderInfo memory);

    function getUserInfo(address user) external view returns(
        uint64 thisBuyDoneAmount,
        uint64 thisSellDoneAmount
    );

    function indexUserBuyId(address user, uint256 index) external view returns(uint256 buyId);

    function indexUserSellId(address user, uint256 index) external view returns(uint256 sellId);

    function getUserBuyIdsLength(address user) external view returns(uint256);

    function getUserSellIdsLength(address user) external view returns(uint256);


}