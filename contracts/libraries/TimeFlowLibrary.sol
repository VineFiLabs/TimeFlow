// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

library TimeFlowLibrary {

    function _getTotalCollateral(
        uint64 price,
        uint128 amount
    ) internal pure returns (uint256 totalCollateral){
        totalCollateral = price * amount / (10 ** 6);
    }

    function _fee(
        uint256 total,
        uint8 tokenDecimals
    ) internal pure returns (uint256 _thisFee) {
        if (
            total >= 10 * 10 ** tokenDecimals &&
            total < 1000 * 10 ** tokenDecimals
        ) {
            _thisFee = total / 100;
        } else if (
            total >= 1000 * 10 ** tokenDecimals &&
            total < 10000 * 10 ** tokenDecimals
        ) {
            _thisFee = (total / 1000) * 80;
        } else if (total >= 10000 * 10 ** tokenDecimals) {
            _thisFee = (total / 1000) * 50;
        } else {
            
        }
    }
}
