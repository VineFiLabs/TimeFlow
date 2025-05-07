// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Dust} from "./Dust.sol";
import {IDustCore} from "../interfaces/IDustCore.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
* @notice This is where the core functions of DUST are implemented
* @author VineLabs member 0xlive (https://github.com/VineFiLabs)
*/
contract DustCore is Dust, ReentrancyGuard, IDustCore {
    using SafeERC20 for IERC20;

    address public owner;
    address public manager;
    bytes1 private immutable ZEROBYTES1;
    bytes1 private immutable ONEBYTES1 = 0x01;
    bytes1 public initializeState;
    bytes1 public lockState;

    uint256 public flowId;

    constructor(address _owner, address _manager) {
        owner = _owner;
        manager = _manager;
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    modifier onlyManager() {
        _checkManager();
        _;
    }

    modifier Lock() {
        require(lockState == ZEROBYTES1, "Locked");
        _;
    }


    mapping(address => bool) private blacklist;
    mapping(address => DustCollateralInfo) private dustCollateralInfo;
    mapping(uint256 => DustFlowInfo) private dustFlowInfo;
    mapping(address => mapping(UserFlowState => uint256[])) private userFlowId;

    function initialize(
        uint8[] calldata liquidationRatios,
        uint16[] calldata liquidationRewardRatios,
        address[] calldata collaterals
    ) external onlyManager {
        require(initializeState == ZEROBYTES1, "Already initialize");
        unchecked {
            for (uint256 i; i < collaterals.length; i++) {
                dustCollateralInfo[collaterals[i]].activeState = ONEBYTES1;
                dustCollateralInfo[collaterals[i]]
                    .liquidationRatio = liquidationRatios[i];
                dustCollateralInfo[collaterals[i]]
                    .liquidationRewardRatio = liquidationRewardRatios[i];
            }
        }
        initializeState = ONEBYTES1;
        emit Initialize(initializeState);
    }

    function setLockState(bytes1 state) external onlyManager {
        lockState = state;
        emit LockEvent(state);
    }

    /**
    * @dev The administrator sets the blacklist address
    * @param blacklistGroup Blacklist address group
    * @param states Blacklist address group state
     */
    function setBlacklist(address[] calldata blacklistGroup, bool[] calldata states) external onlyManager {
        unchecked {
            for(uint256 i; i<blacklistGroup.length; i++){
                blacklist[blacklistGroup[i]] = states[i];
            }
        }
    }

    /**
    * @dev Deposit the collateral and mint DUST
    * @param collateral Enter the permitted address of the collateral
    * @param amount Quantity of mortgaged property
    * @param price Collateral: The price of 7
     */
    function mintDust(
        address collateral,
        uint128 amount,
        uint128 price
    ) external Lock nonReentrant {
        _checkBlacklist(msg.sender);
        require(
            dustCollateralInfo[collateral].activeState == ONEBYTES1,
            "Invalid collateral"
        );
        uint8 collateralDecimals = getTokenDecimals(collateral);
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), amount);
        uint256 mintAmount = _getExpectedAmount(
            collateralDecimals,
            amount,
            price
        );
        // uint256 mintAmount = amount;
        require(_mint(msg.sender, mintAmount), "Mint fail");
    }

    /**
    * @dev Destroy DUST and obtain the corresponding amount of collateral
    * @param collateral Enter the permitted address of the collateral
    * @param amount Quantity of mortgaged property
    * @param price The price of 7 : collateral
     */
    function refund(
        address collateral,
        uint128 amount,
        uint128 price
    ) external nonReentrant {
        uint8 collateralDecimals = getTokenDecimals(collateral);
        uint256 collateralBalance = getUserTokenbalance(
            collateral,
            address(this)
        );
        uint256 withdrawCollateralAmount = _getRefundAmount(
            collateralDecimals,
            amount,
            price,
            collateralBalance
        );

        IERC20(collateral).safeTransfer(msg.sender, withdrawCollateralAmount);
        require(_burn(msg.sender, withdrawCollateralAmount), "Burn fail");
    }

    /**
    * @dev DUST's unique secure transfer and stream payment
    * @param way The way to execute Flow
    * @param endTime If a stream payment is executed, endTime >= 60; otherwise, it is 0
    * @param amount Transfer quantity
    * @param receiver Receiving address
    * @param token flow token
     */
    function flow(
        FlowWay way,
        uint64 endTime,
        uint128 amount,
        address receiver,
        address token
    ) external {
        _checkBlacklist(receiver);
        uint64 currentTime = uint64(block.timestamp);
        uint64 thisEndTime = currentTime + endTime;
        require(receiver != address(0) && receiver != address(this) && receiver != msg.sender, "Invalid receiver");
        if (way == FlowWay.doTransfer) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            IERC20(token).safeTransfer(receiver, amount);
        } else if (way == FlowWay.flow) {
            require(amount >= 10 ** 18, "At least 10 ** 18 dust");
            require(thisEndTime - 60 >= currentTime, "Invalid endTime");
            userFlowId[msg.sender][UserFlowState.sendFlow].push(flowId);
            userFlowId[receiver][UserFlowState.receiveFlow].push(flowId);
            if(token == address(this)){
                require(_burn(msg.sender, amount), "Burn fail");
            }else{
                IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            }
            dustFlowInfo[flowId] = DustFlowInfo({
                way: way,
                sender: msg.sender,
                receiver: receiver,
                flowToken: token,
                startTime: currentTime,
                endTime: thisEndTime,
                amount: amount,
                doneAmount: 0,
                lastestWithdrawTime: 0
            });
            flowId++;
        } else {
            revert("Invalid way");
        }
        emit Flow(way, msg.sender, receiver, amount);
    }

    /**
    * @dev The recipient receives the stream payment
    * @param id The flowId corresponding to each flow payment
     */
    function receiveDustFlow(uint256 id) external {
        address receiver = dustFlowInfo[id].receiver;
        address token = dustFlowInfo[id].flowToken;
        require(msg.sender == receiver, "Not this receiver");
        uint128 withdrawAmount = getReceiveAmount(id);
        require(withdrawAmount > 0, "All completed");
        dustFlowInfo[id].doneAmount += withdrawAmount;
        dustFlowInfo[id].lastestWithdrawTime = block.timestamp;
        require(dustFlowInfo[id].doneAmount <= dustFlowInfo[id].amount, "Amount overflow");
        if(token == address(this)){
            require(_mint(receiver, withdrawAmount), "Mint fail");
        }else {
            IERC20(token).safeTransfer(receiver, withdrawAmount);
        }
    }

    function _checkOwner() private view {
        require(msg.sender == owner, "Non owner");
    }

    function _checkManager() private view {
        require(msg.sender == manager, "Non manager");
    }

    function _checkBlacklist(address user) private view {
        require(blacklist[user] == false, "blacklist");
    }

    function _getExpectedAmount(
        uint8 collateralDecimals,
        uint128 amount,
        uint128 price
    ) private pure returns (uint256 dustAmount) {
        if (collateralDecimals > 0) {
            if (collateralDecimals == 18) {
                dustAmount = ((amount / (10 ** 6)) * price);
            } else if (collateralDecimals < 18) {
                dustAmount = ((amount / (10 ** 6)) *
                    price *
                    (10 ** (10 - collateralDecimals)));
            } else {
                dustAmount =
                    ((amount / (10 ** 6)) * price) /
                    (10 ** (collateralDecimals - 10));
            }
        } else {
            revert("Invalid collateral");
        }
    }

    function _getRefundAmount(
        uint8 collateralDecimals,
        uint128 amount,
        uint128 price,
        uint256 collateralBalance
    ) private pure returns (uint256 refundAmount) {
        if (collateralDecimals > 0) {
            if (collateralDecimals == 18) {
                refundAmount = (amount / (10 ** 6)) * price;
            } else if (collateralDecimals < 18) {
                refundAmount =
                    ((amount / (10 ** 6)) * price) /
                    (10 ** (10 - collateralDecimals));
            } else {
                refundAmount = (((amount / (10 ** 6)) * price) *
                    (10 ** (collateralDecimals - 10)));
            }
        } else {
            revert("Invalid collateral");
        }
        if (refundAmount > collateralBalance) {
            revert("Insufficient");
        }
    }
    
    /**
    * @dev Index user flow payment flowId
    * @param user The sender or recipient using stream payment
    * @param state The sending or receiving enumeration of stream payments
    * @param index The array index within userFlowId
    * @return flowId
     */
    function getUserFlowId(address user, UserFlowState state, uint256 index) external view returns (uint256) {
        return userFlowId[user][state][index];
    }

    /**
    * @dev Obtain the length of the userFlowId array
    * @param user The sender or recipient using stream payment
    * @param state The sending or receiving enumeration of stream payments
    * @return length
     */
    function getUserFlowIdsLength(address user, UserFlowState state) external view returns (uint256) {
        return userFlowId[user][state].length;
    }

    /**
    * @dev Obtain the structure of the flow payment corresponding to the flowId
    * @param id flowId
    * @return DustFlowInfo
     */
    function getDustFlowInfo(
        uint256 id
    ) external view returns (DustFlowInfo memory) {
        return dustFlowInfo[id];
    }

    /**
    * @dev Obtain the information of the mortgaged property
    * @param collateral The permitted address of the collateral
    * @return DustCollateralInfo
     */
    function getDustCollateralInfo(
        address collateral
    ) external view returns (DustCollateralInfo memory) {
        return dustCollateralInfo[collateral];
    }

    /**
    * @dev Obtain the decimals of ERC20 Token
    * @param token ERC20Token
    * @return decimals
     */
    function getTokenDecimals(address token) public view returns (uint8) {
        return IERC20Metadata(token).decimals();
    }
    
    /**
    * @dev Obtain the number of tokens held by the user
    * @param token ERC20Token
    * @param user The user address for inspection
    * @return balance
     */
    function getUserTokenbalance(
        address token,
        address user
    ) public view returns (uint256) {
        return IERC20(token).balanceOf(user);
    }
    

    /**
    * @dev Obtain the current withdrawable quantity of the flow payment
    * @param id flowId
    * @return remain amount
     */
    function getReceiveAmount(
        uint256 id
    ) public view returns (uint128 remainAmount) {
        uint64 startTime = dustFlowInfo[id].startTime;
        uint64 endTime = dustFlowInfo[id].endTime;
        uint128 amount = dustFlowInfo[id].amount;
        uint128 doneAmount = dustFlowInfo[id].doneAmount;
        uint256 lastestWithdrawTime = dustFlowInfo[id].lastestWithdrawTime;
        if(endTime - startTime > 0){
            if(amount >= doneAmount){
                uint128 quantityPerSecond = amount / (endTime - startTime);
                if (block.timestamp >= endTime) {
                    remainAmount = amount - doneAmount;
                } else {
                    if(lastestWithdrawTime == 0){
                        remainAmount = uint128((block.timestamp - startTime) *
                        quantityPerSecond);
                    }else{
                        if(lastestWithdrawTime > startTime && lastestWithdrawTime < endTime) {
                            remainAmount = uint128((block.timestamp - lastestWithdrawTime) *
                        quantityPerSecond);
                        }
                    }
                    
                }
            }
        }
    }

    /**
    * @dev How much DUST can be minted by obtaining the deposited collateral
    * @param collateral Enter the permitted address of the collateral
    * @param amount Quantity of mortgaged property
    * @param price Collateral: The price of 7
    * @return dust amount
     */
    function getExpectedAmount(
        address collateral,
        uint128 amount,
        uint128 price
    ) external view returns (uint256 dustAmount) {
        uint8 collateralDecimals = getTokenDecimals(collateral);
        dustAmount = _getExpectedAmount(collateralDecimals, amount, price);
    }

    /**
    * @dev The quantity of the mortgaged property that received a refund
    * @param collateral Enter the permitted address of the collateral
    * @param amount Quantity of mortgaged property
    * @param price The price of 7 : collateral
    * @return collateral amount
     */
    function getRefundAmount(
        address collateral,
        uint128 amount,
        uint128 price
    ) public view returns (uint256 withdrawCollateralAmount) {
        uint8 collateralDecimals = getTokenDecimals(collateral);
        uint256 collateralBalance = getUserTokenbalance(
            collateral,
            address(this)
        );
        withdrawCollateralAmount = _getRefundAmount(
            collateralDecimals,
            amount,
            price,
            collateralBalance
        );
    }

    /**
    * @dev Index the payment information of user flow, with a maximum of 10 data stores per page
    * @param state Send or receive enumerations
    * @param user The sender or receiver of the stream payment
    * @param pageIndex page index
    * @return dustFlowInfoGroup DustFlowInfo structure array
    * @return receiveAmountGroup Array of acceptable quantities
     */
    function indexUserSenderFlowInfos(
        UserFlowState state,
        address user,
        uint256 pageIndex
    ) external view returns (
        DustFlowInfo[] memory dustFlowInfoGroup,
        uint128[] memory receiveAmountGroup
    ) {
        uint256 flowIdsLength = userFlowId[user][state].length;
        if (flowIdsLength > 0) {
            uint256 len;
            uint256 idIndex;
            uint256 currentUserFlowId;
            require(pageIndex <= flowIdsLength / 10, "PageIndex overflow");
            if (flowIdsLength <= 10) {
                len = flowIdsLength;
            } else {
                if (flowIdsLength % 10 == 0) {
                    len = 10;
                } else {
                    len = flowIdsLength % 10;
                }
                if (pageIndex > 0) {
                    idIndex = pageIndex * 10;
                    currentUserFlowId = userFlowId[user][state][idIndex];
                }
            }
            dustFlowInfoGroup = new DustFlowInfo[](len);
            receiveAmountGroup = new uint128[](len);
            unchecked {
                for (uint256 i; i < len; i++) {
                    dustFlowInfoGroup[i] = dustFlowInfo[
                        currentUserFlowId
                    ];
                    receiveAmountGroup[i] = getReceiveAmount(currentUserFlowId);
                    currentUserFlowId++;
                }
            }
        }
    }
}
