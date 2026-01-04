// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITransparentUpgradeableProxy {
    function upgradeToAndCall(
        address newImplementation,
        bytes calldata data
    ) external payable;
}
