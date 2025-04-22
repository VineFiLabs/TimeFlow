// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Dust} from "./Dust.sol";
import {IDustCore} from "../interfaces/IDustCore.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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

    function mintDust(
        address collateral,
        uint128 amount,
        uint128 price
    ) external Lock {
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
        _mint(msg.sender, mintAmount);
    }

    function refund(
        address collateral,
        uint128 amount,
        uint128 price
    ) external {
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

        // uint256 withdrawCollateralAmount = amount;
        _burn(msg.sender, withdrawCollateralAmount);
        IERC20(collateral).safeTransfer(msg.sender, withdrawCollateralAmount);
    }

    function liquidate(
        address collateral,
        address user,
        uint256 price
    ) external {}

    function flow(
        FlowWay way,
        uint64 endTime,
        address receiver,
        uint128 amount
    ) external {
        uint64 currentTime = uint64(block.timestamp);
        uint64 thisEndTime = currentTime + endTime;
        require(receiver != address(0) && receiver != address(this), "Invalid receiver");
        if (way == FlowWay.doTransfer) {

        } else if (way == FlowWay.flow) {
            require(amount >= 10 ** 18, "At least 10 ** 18 dust");
            require(thisEndTime - 60 >= currentTime, "Invalid endTime");
            userFlowId[msg.sender][UserFlowState.sendFlow].push(flowId);
            userFlowId[receiver][UserFlowState.receiveFlow].push(flowId);
            flowId++;
        } else {
            revert("Invalid way");
        }
        _burn(msg.sender, amount);
        dustFlowInfo[flowId] = DustFlowInfo({
            way: way,
            sender: msg.sender,
            receiver: receiver,
            startTime: currentTime,
            endTime: thisEndTime,
            amount: amount,
            doneAmount: 0
        });
        emit Flow(way, msg.sender, receiver, amount);
    }

    function receiveDustFlow(uint256 id) external {
        address receiver = dustFlowInfo[id].receiver;
        require(msg.sender == receiver, "Not this receiver");
        uint128 withdrawAmount = getReceiveAmount(id);
        require(withdrawAmount > 0, "All completed");
        dustFlowInfo[id].doneAmount += withdrawAmount;
        require(_mint(receiver, withdrawAmount), "Mint fail");
    }

    function _checkOwner() private view {
        require(msg.sender == owner, "Non owner");
    }

    function _checkManager() private view {
        require(msg.sender == manager, "Non manager");
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

    function getUserFlowId(address user, UserFlowState state, uint256 index) external view returns (uint256) {
        return userFlowId[user][state][index];
    }

    function getDustFlowInfo(
        uint256 id
    ) external view returns (DustFlowInfo memory) {
        return dustFlowInfo[id];
    }

    function getDustCollateralInfo(
        address collateral
    ) external view returns (DustCollateralInfo memory) {
        return dustCollateralInfo[collateral];
    }

    function getTokenDecimals(address token) public view returns (uint8) {
        return IERC20Metadata(token).decimals();
    }

    function getUserTokenbalance(
        address token,
        address user
    ) public view returns (uint256) {
        return IERC20(token).balanceOf(user);
    }

    function getReceiveAmount(
        uint256 id
    ) public view returns (uint128 remainAmount) {
        uint64 startTime = dustFlowInfo[id].startTime;
        uint64 endTime = dustFlowInfo[id].endTime;
        uint128 amount = dustFlowInfo[id].amount;
        uint128 doneAmount = dustFlowInfo[id].doneAmount;
        uint128 quantityPerSecond = amount / (endTime - startTime);
        if (block.timestamp >= endTime) {
            remainAmount = amount - doneAmount;
        } else {
            remainAmount =
                uint128(block.timestamp - startTime) *
                quantityPerSecond;
        }
    }

    function getExpectedAmount(
        address collateral,
        uint128 amount,
        uint128 price
    ) external view returns (uint256 dustAmount) {
        uint8 collateralDecimals = getTokenDecimals(collateral);
        dustAmount = _getExpectedAmount(collateralDecimals, amount, price);
    }

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

    function indexUserSenderFlowInfos(
        UserFlowState state,
        address user,
        uint256 pageIndex
    ) external view returns (DustFlowInfo[] memory dustFlowInfoGroup) {
        uint256 flowIdsLength = userFlowId[user][state].length;
        if (flowIdsLength > 0) {
            uint256 len;
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
                    currentUserFlowId = pageIndex * 10;
                }
            }
            dustFlowInfoGroup = new DustFlowInfo[](len);
            unchecked {
                for (uint256 i; i < len; i++) {
                    dustFlowInfoGroup[i] = dustFlowInfo[
                        currentUserFlowId
                    ];
                    currentUserFlowId++;
                }
            }
        }
    }
}
