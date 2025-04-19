// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface IGovernance{
    
    struct FeeInfo{
        address feeReceiver;
        address dust;
        uint8 rate;
    }
    
    struct MarketConfig {
        address waitToken;
        address collateral;
        address timeRedeemToken;
        address timeDeptToken;
        uint256 endTime;
        bool initializeState;
    }

    event UpdateOwner(address oldOwner, address newOwner);
    event UpdateManager(address oldManager, address newManager);

    function owner() external view returns(address);
    function manager() external view returns(address);
    function getFeeInfo() external view returns(FeeInfo memory);
    function getMarketConfig(uint256 marketId) external view returns(MarketConfig memory);

}