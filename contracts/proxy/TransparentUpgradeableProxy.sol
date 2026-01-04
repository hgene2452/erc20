// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Proxy.sol";
import "./ERC1967Storage.sol";

/**
 * @title TransparentUpgradeableProxy
 *
 * @dev
 * Transparent Proxy 정책:
 * - 일반 사용자(msg.sender != admin): 모든 호출을 implementation으로 delegatecall
 * - 관리자(msg.sender == admin): fallback 경로로는 절대 구현 로직 접근 불가(무조건 revert)
 * - 대신 업그레이드는 "명시적인 함수" upgradeToAndCall()로만 수행 가능
 */
contract TransparentUpgradeableProxy is Proxy, ERC1967Storage {
    error ProxyDeniedAdminAccess();
    error NonPayable();

    /**
     * @dev
     * 프록시 최초 설정(딱 1번)
     * - implementation/admin 슬롯 세팅
     * - data가 있으면 delegatecall로 initialize 수행(프록시 스토리지 초기화)
     */
    constructor(address implementation_, address admin_, bytes memory data) payable {
        _setImplementation(implementation_);
        _setAdmin(admin_);

        if (data.length > 0) {
            _functionDelegateCall(implementation_, data);
        } else {
            // 초기화 없이 ETH가 들어오면 프록시에 ETH가 고립될 수 있어 방지
            if (msg.value != 0) revert NonPayable();
        }
    }

    /**
     * @dev Proxy가 delegatecall할 implementation 주소 제공
     */
    function _implementation() internal view override returns (address) {
        return _getImplementation();
    }

    /**
     * @dev Transparent 규칙 핵심:
     * - admin은 fallback으로 들어오는 모든 호출을 막는다
     *   (admin이 실수로 token.transfer 같은 걸 호출하는 사고 방지)
     * - 일반 유저만 implementation으로 위임
     */
    function _fallback() internal override {
        if (msg.sender == _getAdmin()) {
            revert ProxyDeniedAdminAccess();
        }
        super._fallback();
    }

    /**
     * @dev 업그레이드 실행 함수 (placeholder 아님. 실제 동작 함수)
     * - admin(=ProxyAdmin 컨트랙트)만 호출 가능
     * - 구현 교체 + (선택) data로 후속 초기화(delegatecall)
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable {
        if (msg.sender != _getAdmin()) revert ProxyDeniedAdminAccess();

        // data 없이 ETH만 보내면 프록시에 ETH가 고립될 수 있어 방지
        if (data.length == 0 && msg.value != 0) revert NonPayable();

        _upgradeToAndCall(newImplementation, data);
    }
}
