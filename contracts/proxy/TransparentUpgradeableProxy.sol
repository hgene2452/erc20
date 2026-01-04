// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Proxy.sol";
import "./ERC1967Storage.sol";

/**
 * @title TransparentUpgradeableProxy
 *
 * @dev
 * - Transparent Proxy 패턴의 정책 담당자이다.
 * - 호출자를 기준으로 위임 vs 업그레이드 분기.
 * - delegatecall 엔진과 storage 관리는 다른 컨트랙트에 위임한다.
 */
contract TransparentUpgradeableProxy is Proxy, ERC1967Storage {
    error ProxyDeniedAdminAccess();
    error NonPayable();

    /**
     * @dev
     * - 프록시 최초 설정
     * - implementation, admin 슬롯 초기화
     * - 초기화 calldata가 있으면 delegatecall 실행
     */
    constructor(address implementation_, address admin_, bytes memory data) payable {
        _setImplementation(implementation_);
        _setAdmin(admin_);

        // data가 있으면 초기화(delegatecall)
        if (data.length > 0) {
            _functionDelegateCall(implementation_, data);
        } else {
            // 초기화 호출 없이 ETH가 들어오면 프록시에 ETH가 갇힐 수 있음 → 방지
            if (msg.value != 0) revert NonPayable();
        }
    }

    /**
     * @dev
     * - Proxy가 사용할 현재 implementation 주소 반환
     */
    function _implementation() internal view override returns (address) {
        return _getImplementation();
    }

    /**
     * @dev 
     * - Transparent 패턴의 핵심 분기 로직이다.
     * - msg.sender가 admin인지 여부에 따라 호출을 분기 처리한다.
     */
    function _fallback() internal override {
        if (msg.sender == _getAdmin()) {
            // admin은 "업그레이드 호출"만 가능
            if (msg.sig != this.upgradeToAndCall.selector) {
                revert ProxyDeniedAdminAccess();
            }
            _dispatchUpgradeToAndCall();
        } else {
            // 일반 사용자는 구현으로 위임
            super._fallback();
        }
    }

    /**
     * @dev
     * - 업그레이드 selector 확보용 placeholder 함수이다.
     * - 직접 호출되면 항상 revert 된다.
     */
    function upgradeToAndCall(address, bytes calldata) external payable {
        revert("DIRECT_CALL_NOT_ALLOWED");
    }
    /**
     * @dev
     * - 실제 업그레이드 수행 로직
     * - msg.data에서 (newImplementation, data)를 직접 디코딩
     */
    function _dispatchUpgradeToAndCall() private {
        (address newImplementation, bytes memory data) =
            abi.decode(msg.data[4:], (address, bytes));

        if (data.length == 0 && msg.value != 0) revert NonPayable();

        _upgradeToAndCall(newImplementation, data);
    }
}
