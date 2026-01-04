// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ITransparentUpgradeableProxy.sol";

/**
 * @dev 
 * - 프록시 업그레이드 전용 관리자
 * - proxy의 admin 역할을 수행한다.
 * - owner만 업그레이드 가능하다.
 */
contract ProxyAdmin {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddress();

    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /**
     * @dev
     * - ProxyAdmin 최초 소유자 설정
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    /**
     * @dev
     * - ProxyAdmin 소유권 이전
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    /**
     * @dev 
     * - 프록시에 업그레이드 요청 전달
     * - TransparentUpgradeableProxy의 upgradeToAndCall() 호출
     */
    function upgradeAndCall(
        ITransparentUpgradeableProxy proxy,
        address newImplementation,
        bytes calldata data
    ) external payable onlyOwner {
        proxy.upgradeToAndCall{value: msg.value}(newImplementation, data);
    }
}
