// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Proxy
 *
 * @dev
 * - 프록시의 delegatecall 기술적 구현을 담당하는 추상 컨트랙트.
 * - TransparentUpgradeableProxy가 상속받아 사용한다.
 * - 모든 외부 호출을 현재 implementation으로 delegatecall 한다.
 * - 권한, 정책, admin 개념은 전혀 모른다.
 */
abstract contract Proxy {
    /**
     * @dev 
     * - 현재 delegatecall 대상 implementation 주소를 반환한다. 
     * - 실제 주고 제공은 자식 컨트랙트에서 구현한다.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev
     * - calldata를 복사해 implementation으로 delegatecall을 수행한다.
     * - delegatecall 결과를 그대로 반환하거나 revert 한다.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())

            let result := delegatecall(
                gas(),
                implementation,
                0x00,
                calldatasize(),
                0x00,
                0x00
            )

            returndatacopy(0x00, 0x00, returndatasize())

            switch result
            case 0 {
                revert(0x00, returndatasize())
            }
            default {
                return(0x00, returndatasize())
            }
        }
    }

    /**
     * @dev
     * - fallback 진입 시 실제로 delegatecall을 수행하는 내부 진입점이다.
     * - 자식 컨트랙트에서 override 가능하다.
     *   (TransparentUpgradeableProxy에서는 admin 분기 처리를 한다)
     */
    function _fallback() internal virtual {
        _delegate(_implementation());
    }

    /**
     * @dev
     * - 존재하지 않는 함수에 대한 호출을 처리한다.
     * - _fallback()을 호출한다.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev
     * - 빈 calldata + ETH 전송 시 호출되는 special 함수이다.
     * - _fallback()을 호출한다.
     */
    receive() external payable virtual {
        _fallback();
    }
}
