// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IDust} from "../interfaces/IDust.sol";
import {IDustCore} from "../interfaces/IDustCore.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DustCore is ReentrancyGuard, IDustCore {
    using SafeERC20 for IERC20;

    address public dust;
    address public owner;
    address public manager;
    bytes1 private immutable ZEROBYTES1;
    bytes1 private immutable ONEBYTES1 = 0x01;
    bytes1 public initializeState;
    bytes1 public lockState;

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
    mapping(address => mapping(uint256 => DustFlowInfo)) private dustFlowInfo;
    mapping(address => uint256) private userFlowId;

    function initialize(
        address _dust,
        uint8[] calldata liquidationRatios,
        uint16[] calldata liquidationRewardRatios,
        address[] calldata collaterals
    ) external onlyManager {
        require(initializeState == ZEROBYTES1, "Already initialize");
        dust = _dust;
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
        emit Initialize(_dust, initializeState);
    }

    function setLockState(bytes1 state) external onlyManager {
        lockState = state;
        emit LockEvent(state);
    }

    function mintDust(
        address collateral,
        uint128 amount,
        uint128 price
    ) external Lock nonReentrant {
        require(
            dustCollateralInfo[collateral].activeState == ONEBYTES1,
            "Invalid collateral"
        );
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), amount);
        uint256 mintAmount = getExpectedAmount(collateral, amount, price);
        bool state = IDust(dust).depositeMint(msg.sender, mintAmount);
        require(state, "Mint fail");
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
        address thisReceiver;
        uint256 userBeforeFlowId = userFlowId[msg.sender];
        if (way == FlowWay.transfer) {
            thisReceiver = receiver;
        } else if (way == FlowWay.flow) {
            require(amount >= 10 ** 18, "At least 10 ** 18 dust");
            require(thisEndTime - 60 >= currentTime, "Invalid endTime");
            userFlowId[msg.sender]++;
            thisReceiver = address(this);
        } else {
            revert("Invalid way");
        }
        IERC20(dust).safeTransferFrom(msg.sender, thisReceiver, amount);
        dustFlowInfo[msg.sender][userBeforeFlowId] = DustFlowInfo({
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
        address receiver = dustFlowInfo[msg.sender][id].receiver;
        require(msg.sender == receiver, "Not this receiver");
        uint128 withdrawAmount = getReceiveAmount(id);
        require(withdrawAmount > 0, "All completed");
        dustFlowInfo[msg.sender][id].doneAmount += withdrawAmount;
        IERC20(dust).safeTransfer(receiver, withdrawAmount);
    }

    function _checkOwner() private view {
        require(msg.sender == owner, "Non owner");
    }

    function _checkManager() private view {
        require(msg.sender == manager, "Non manager");
    }

    function getUserFlowId(address user) external view returns (uint256) {
        return userFlowId[user];
    }

    function getDustFlowInfo(
        address user,
        uint256 id
    ) external view returns (DustFlowInfo memory) {
        return dustFlowInfo[user][id];
    }

    function getDustCollateralInfo(
        address collateral
    ) external view returns (DustCollateralInfo memory) {
        return dustCollateralInfo[collateral];
    }

    function getReceiveAmount(
        uint256 id
    ) public view returns (uint128 remainAmount) {
        uint64 startTime = dustFlowInfo[msg.sender][id].startTime;
        uint64 endTime = dustFlowInfo[msg.sender][id].endTime;
        uint128 amount = dustFlowInfo[msg.sender][id].amount;
        uint128 doneAmount = dustFlowInfo[msg.sender][id].doneAmount;
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
    ) public view returns (uint256 dustAmount) {
        uint8 collateralDecimals = IERC20Metadata(collateral).decimals();
        uint8 dustDecimals = IERC20Metadata(dust).decimals();
        if (collateralDecimals > 0) {
            if (collateralDecimals == dustDecimals) {
                dustAmount = (amount * price) / (10 ** 18);
            } else if (collateralDecimals < dustDecimals) {
                dustAmount =
                    (amount *
                        price *
                        (10 ** (dustDecimals - collateralDecimals))) /
                    (10 ** 18);
            } else {
                dustAmount =
                    (amount * price) /
                    (10 ** (collateralDecimals - dustDecimals)) /
                    (10 ** 18);
            }
        } else {
            revert("Invalid collateral");
        }
    }

    function indexUserFlowInfos(
        address user,
        uint256 pageIndex
    ) external view returns (DustFlowInfo[] memory dustFlowInfoGroup) {
        uint256 id = userFlowId[user];
        if (id > 0) {
            uint256 len;
            uint256 currentUserFlowId;
            require(pageIndex <= id / 10, "PageIndex overflow");
            if (id <= 10) {
                len = id;
            } else {
                if (id % 10 == 0) {
                    len = 10;
                } else {
                    len = id % 10;
                }
                if (pageIndex > 0) {
                    currentUserFlowId = pageIndex * 10;
                }
            }
            dustFlowInfoGroup = new DustFlowInfo[](len);
            unchecked {
                for (uint256 i; i < len; i++) {
                    dustFlowInfoGroup[i] = dustFlowInfo[user][
                        currentUserFlowId
                    ];
                    currentUserFlowId++;
                }
            }
        }
    }
}
