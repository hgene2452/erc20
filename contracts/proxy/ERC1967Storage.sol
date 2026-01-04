// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ERC1967Storage
 *
 * @dev
 * - implementation / admin 주소를 충돌 없는 고정 슬롯에 저장/관리한다.
 * - 업그레이드 / 관리 로직에 필요한 공통 유틸을 제공한다.
 */
abstract contract ERC1967Storage {
    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    error ERC1967InvalidImplementation(address implementation);
    error ERC1967InvalidAdmin(address admin);

    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc; // keccak256("eip1967.proxy.implementation") - 1
    bytes32 internal constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103; // keccak256("eip1967.proxy.admin") - 1

    struct AddressSlot {
        address value;
    }
    /**
     * @dev
     * - 임의 storage slot을 address 저장소처럼 다루기 위한 어댑터
     * - r.value ↔ storage[slot]
     */
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }
    /**
     * @dev
     * - 현재 implementation 주소 반환
     * - ERC-1967 implementation slot에서 직접 읽어온다
     */
    function _getImplementation() internal view returns (address) {
        return _getAddressSlot(IMPLEMENTATION_SLOT).value;
    }
    /**
     * @dev
     * - implementation slot에 새 구현 주소 저장
     * - 컨트랙트 주소인지 검증한다
     */
    function _setImplementation(address newImplementation) internal {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        _getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }
    /**
     * @dev
     * - 현재 admin 주소 반환
     * - ERC-1967 implementation slot에서 직접 읽어온다
     */
    function _getAdmin() internal view returns (address) {
        return _getAddressSlot(ADMIN_SLOT).value;
    }
    /**
     * @dev
     * - admin slot에 새 구현 주소 저장
     * - 주소가 0이 아님을 검증한다
     */
    function _setAdmin(address newAdmin) internal {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        _getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev
     * - implementation 교체
     * - Upgraded 이벤트 처리
     * - 필요 시 후속 초기화(delegatecall) 실행
     */
    function _upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0) {
            _functionDelegateCall(newImplementation, data);
        }
    }
    /**
     * @dev
     * - admin 교체
     * - AdminChanged 이벤트 처리
     */
    function _changeAdmin(address newAdmin) internal {
        address previous = _getAdmin();
        _setAdmin(newAdmin);
        emit AdminChanged(previous, newAdmin);
    }

    /**
     * @dev
     * - delegatecall 실행
     * - 실패 시 구현 컨트랙트의 revert reason을 그대로 전달
     */
    function _functionDelegateCall(address target, bytes memory data) internal {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        if (!success) {
            _revertWithReason(returndata);
        }
    }
    /**
     * @dev
     * - delegatecall 실패 시 revert 
     * - reason 그대로 bubble up
     */
    function _revertWithReason(bytes memory returndata) internal pure {
        assembly {
            revert(add(returndata, 0x20), mload(returndata))
        }
    }

    /**
     * @dev
     * - 외부에서 implementation 주소 조회 (디버깅/조회용)
     */
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }
    /**
     * @dev
     * - 외부에서 admin 주소 조회 (디버깅/조회용)
     */
    function getAdmin() external view returns (address) {
        return _getAdmin();
    }
}
