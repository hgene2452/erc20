// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Proxy
 *
 * @dev
 * 프록시 패턴의 가장 기본이 되는 추상 컨트랙트.
 *
 * 역할:
 * - 외부에서 들어오는 모든 호출을 "현재 구현 컨트랙트(implementation)"로 전달(delegatecall)합니다.
 * - 실제 구현 주소를 어떻게 얻는지는 알지 못한다(_implementation()을 상속받은 컨트랙트가 구현).
 * 
 * 중요:
 * - 이 컨트랙트는 "정책"은 알지 못한다.
 * - 오직 "기계적인 delegatecall"만 수행한다.
 */
 abstract contract Proxy {
    /**
     * @dev
     * 현재 프록시가 delegatecall 해야 할 구현(implementation) 주소를 반환한다.
     *
     * - 반드시 상속받은 컨트랙트에서 override 되어야 한다.
     * - c.f. TransparentUpgraeableProxy에서는 ERC1967 슬롯에서 구현 주소를 읽어온다.
     *
     * - internal: 외부에서 직접 호출할 이유가 없고, fallback 함수에서만 사용되기 때문.
     * - view: 상태를 변경하지 않기 때문.
     * - virtual: 상속받은 컨트랙트에서 override 할 수 있어야 하기 때문.
     *
     * @return address 현재 구현 컨트랙트의 주소
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev
     * 프록시로 들어오는 모든 호출을 현재 구현 컨트랙트로 전달(delegatecall)한다.
     *
     * - msg.sender / msg.value / storage는 프록시 컨트랙트의 것을 사용한다.
     * - calldata는 그대로 구현 컨트랙트에 전달한다.
     * - 구현 컨트랙트의 return / revert도 그대로 프록시 컨트랙트의 것으로 전달된다.
     *
     * - 이 함수는 절대 return 하지 않는다(assembly에서 return/revert 처리).
     *
     * - internal: 외부에서 직접 호출할 이유가 없고, fallback 함수에서만 사용되기 때문.
     * - virtual: 상속받은 컨트랙트에서 override 할 수 있어야 하기 때문.
     *
     * @param implementation 현재 구현 컨트랙트의 주소
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // 1. calldata를 메모리에 복사
            calldatacopy(0x00, 0x00, calldatasize())

            // 2. delegatecall 
            // - gas: 남은 가스
            // - implementation: 호출할 구현 컨트랙트 주소
            // - input: [0x00, calldatasize()]
            // - output: 아직 크기를 모르므로 0x00, 0
            let result := delegatecall(
                gas(),
                implementation,
                0x00,
                calldatasize(),
                0x00,
                0
            )

            // 3. 반환값 복사
            returndatacopy(0x00, 0x00, returndatasize())

            // 4. delegatecall 결과에 따라 처리
            switch result
            case 0 {
                // 실패한 경우: revert
                revert(0x00, returndatasize())
            }
            default {
                // 성공한 경우: return
                return(0x00, returndatasize())
            }
        }
    }

    /**
     * @dev
     * fallback 로직의 실제 구현
     *
     * - 외부에서 호출된 함수가 이 컨트랙트에 정의되어 있지 않으면 무조건 여기로 들어온다.
     * - 이 함수는:
     *   1) 현재 implementation 주소를 얻고,
     *   2) _delegate()를 호출하여 구현 컨트랙트로 호출한다.
     *
     * - internal: 외부에서 직접 호출할 이유가 없고, fallback 함수에서만 사용되기 때문.
     * - virtual: 상속받은 컨트랙트에서 override 할 수 있어야 하기 때문.
     */
    function _fallback() internal virtual {
        _delegate(_implementation());
    }

    /**
     * @dev
     * Solodity의 fallback 함수
     *
     * - 어떤 함수 시그니처에도 매칭되지 않는 호출이 들어오면 이 함수가 호출된다.
     * - Transprent Proxy에서는 이 함수를 override해서 admin 전용 로직을 구현한다.
     *
     * - external: 외부에서 호출되기 때문.
     * - payable: 이더를 받을 수 있어야 하기 때문.
     * - virtual: 상속받은 컨트랙트에서 override 할 수 있어야 하기 때문.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev
     * Solodity의 receive 함수
     *
     * - 빈 calldata와 함께 이더가 전송되면 이 함수가 호출된다.
     * - receive 함수가 정의되어 있지 않으면, fallback 함수가 대신 호출된다.
     *   따라서 명시적으로 두는 것이 안전하다.
     *
     * - external: 외부에서 호출되기 때문.
     * - payable: 이더를 받을 수 있어야 하기 때문.
     * - virtual: 상속받은 컨트랙트에서 override 할 수 있어야 하기 때문.
     */
    receive() external payable virtual {
        _fallback();
    }
 }