// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;
interface ITimeToken {

    function depositeMint(
        address to,
        uint256 amount
    ) external returns(bool);

    function withdrawBurn(
        address to,
        uint256 amount
    ) external returns(bool);
    
}