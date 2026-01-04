// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Proxy.sol";
import "./ERC1967Storage.sol";

/**
 * @title TransparentUpgradeableProxy
 *
 * @dev
 * Transparent Proxy 패턴의 핵심 구현체.
 *
 * 역할:
 * - 일반 사용자 호출 → implementation으로 delegatecall
 * - admin 호출 → 오직 업그레이드만 허용
 * - admin이 실수로 ERC20 로직을 호출하는 것을 구조적으로 차단
 *
 * 이 컨트랙트는:
 * - delegatecall 엔진은 Proxy.sol에 위임하고
 * - 구현 주소 / admin 주소 관리는 ERC1967Storage.sol에 위임하며
 * - "누가 무엇을 할 수 있는가"라는 정책만 담당한다.
 */
contract TransparentUpgradeableProxy is Proxy, ERC1967Storage {
    // =============================== ERRORS ===============================
    /**
     * @dev admin이 업그레이드 함수가 아닌 일반 호출을 시도했을 때 발생
     */
    error ProxyDeniedAdminAccess();

    /**
     * @dev msg.value가 있는데 초기화 호출(data)이 없는 경우
     * ETH가 프록시에 갇히는 사고 방지용
     */
    error NonPayable();

    // =============================== CONSTRUCTOR ===============================
    /**
     * @param implementation_ 초기 implementation 주소
     * @param admin_          프록시 admin 주소 (보통 ProxyAdmin 컨트랙트)
     * @param data            초기화용 calldata (initialize(...) 인코딩)
     *
     * 동작:
     * 1) ERC1967 슬롯에 implementation 저장
     * 2) ERC1967 슬롯에 admin 저장
     * 3) data가 있으면 implementation으로 delegatecall하여 initialize 실행
     *
     * 중요:
     * - constructor는 "프록시 자신의 storage"를 초기화한다.
     * - 이 시점에 실행되는 delegatecall은
     *   곧바로 프록시 storage를 초기화하는 유일한 기회다.
     */
    constructor(
        address implementation_,
        address admin_,
        bytes memory data
    ) payable {
        // implementation 주소 설정 (컨트랙트인지 검증 포함)
        _setImplementation(implementation_);

        // admin 주소 설정
        _setAdmin(admin_);

        // 초기화 calldata 처리
        if (data.length > 0) {
            // data가 있다면 반드시 delegatecall 수행
            (bool success, bytes memory returndata) =
                implementation_.delegatecall(data);

            if (!success) {
                // initialize 실패 시 원본 revert reason 그대로 전달
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
        } else {
            // data가 없는데 ETH가 같이 들어오면 ETH가 고립될 수 있음
            if (msg.value != 0) {
                revert NonPayable();
            }
        }
    }

    // =============================== TRANSPARENT DISPATCH LOGIC ===============================
    /**
     * @dev Proxy.sol에서 선언된 추상 함수 구현
     *
     * - 현재 implementation 주소를 ERC1967 슬롯에서 읽어 반환
     */
    function _implementation()
        internal
        view
        override
        returns (address)
    {
        return _getImplementation();
    }

    /**
     * @dev Transparent Proxy의 핵심 분기 로직
     *
     * 규칙:
     * 1) msg.sender == admin
     *    - 오직 upgradeToAndCall만 허용
     *    - 나머지는 전부 revert
     *
     * 2) msg.sender != admin
     *    - 무조건 implementation으로 delegatecall
     */
    function _fallback() internal override {
        if (msg.sender == _getAdmin()) {
            // admin이 호출한 경우
            if (msg.sig != this.upgradeToAndCall.selector) {
                revert ProxyDeniedAdminAccess();
            }
            _dispatchUpgradeToAndCall();
        } else {
            // 일반 사용자는 항상 implementation으로 위임
            super._fallback();
        }
    }

    // =============================== UPGRADE LOGIC ===============================
    /**
     * @dev Transparent Proxy의 유일한 외부 관리 함수
     *
     * - 이 함수는 ABI에 나타나지 않는다.
     * - admin이 proxy에 호출하면 fallback에서 selector로 감지되어 실행된다.
     *
     * 형식:
     * upgradeToAndCall(address newImplementation, bytes data)
     */
    function upgradeToAndCall(address, bytes calldata) external payable {
        // 이 함수는 fallback에서만 접근되며,
        // 직접 호출되면 정상 경로가 아니다.
        revert("DIRECT_CALL_NOT_ALLOWED");
    }

    /**
     * @dev 실제 업그레이드 수행 로직
     *
     * - calldata에서 newImplementation, data를 직접 디코딩
     * - implementation 슬롯 교체
     * - 필요 시 delegatecall로 후속 초기화 실행
     */
    function _dispatchUpgradeToAndCall() private {
        // msg.data 구조:
        // [4 bytes selector][32 bytes address][32 bytes offset][...bytes data]
        (address newImplementation, bytes memory data) =
            abi.decode(msg.data[4:], (address, bytes));

        // implementation 교체
        _setImplementation(newImplementation);

        // 후속 초기화 호출
        if (data.length > 0) {
            (bool success, bytes memory returndata) =
                newImplementation.delegatecall(data);

            if (!success) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
        } else {
            // data가 없는데 ETH가 있으면 ETH 고립 방지
            if (msg.value != 0) {
                revert NonPayable();
            }
        }
    }
}