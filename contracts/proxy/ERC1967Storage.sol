// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ERC1967Storage
 * @dev
 * ERC1967 표준에 따라 프록시가 사용하는 핵심 주소(implementation, admin 등)를
 * "충돌 위험이 매우 낮은 고정 storage slot"에 저장하고 읽어오는 기능을 제공하는 유틸리티.
 *
 * - TransparentUpgradeableProxy 같은 프록시 컨트랙트가 상속해서 사용한다.
 * - delegatecall 환경에서 "프록시 storage"와 "구현 컨트랙트 storage"가 충돌하면 대참사가 나기 때문에
 *   (balances가 admin 주소로 덮이는 등) 반드시 표준 슬롯을 쓰는 게 안전하다.
 * 
 * 표준 슬롯:
 * - IMPLEMENTATION_SLOT: keccak256("eip1967.proxy.implementation") - 1
 * - ADMIN_SLOT: keccak256("eip1967.proxy.admin") - 1
 */
 abstract contract ERC1967Storage {
    // =============================== EVENTS ===============================
    /**
     * @dev 구현(implementation) 주소가 업그레이드될 때 발생하는 이벤트.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev 관리자(admin) 주소가 변경될 때 발생하는 이벤트.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    // =============================== ERRORS ===============================
    error ERC1967InvalidImplementation(address implementation);
    error ERC1967InvalidAdmin(address admin);

    // =============================== ERC1967 SLOTS ===============================
    /**
     * @dev
     * keccak256("eip1967.proxy.implementation") - 1
     * 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
     */
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev
     * keccak256("eip1967.proxy.admin") - 1
     * 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
     */
    bytes32 internal constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    
    // =============================== INTERNAL SLOT HELPERS ===============================
    /**
     * @dev StorageSlot 패턴(주소 슬롯)
     * 특정 slot 위치를 address 값 저장소로 취급하기 위한 구조체.
     */
    struct AddressSlot {
        address value;
    }

    /**
     * @dev slot 위치를 AddressSlot로 "캐스팅"해서 접근할 수 있게 해준다.
     * Solidity 문법으로는 임의 slot에 직접 접근이 까다로워서 assembly를 사용한다.
     */
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    // =============================== IMPLEMENTATION GET/SET ===============================
    /**
     * @dev 현재 구현(implementation) 주소를 반환한다.
     */
    function _getImplementation() internal view returns (address) {
        return _getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev 구현(implementation) 주소 저장
     * - newImplementation은 반드시 컨트랙트(code length > 0)여야 한다.
     * - 이벤트는 여기서 emit하지 않고, 업그레이드 함수에서 emit하는 스타일도 가능하지만
     *   보통 여기서 emit하는 편이 추적이 쉬워서 함께 제공한다.
     */
    function _setImplementation(address newImplementation) internal {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        _getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
        
        emit Upgraded(newImplementation);
    }

    // =============================== ADMIN GET/SET ===============================
    /**
     * @dev 현재 admin 주소 반환
     */
    function _getAdmin() internal view returns (address) {
        return _getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev admin 주소 저장
     * - admin은 0 주소 불가
     * - AdminChanged 이벤트도 같이 발생시켜 추적 가능하게 한다.
     */
    function _setAdmin(address newAdmin) internal {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }

        address previous = _getAdmin();
        _getAddressSlot(ADMIN_SLOT).value = newAdmin;

        emit AdminChanged(previous, newAdmin);
    }

    // =============================== OPTIONAL: EXTERNAL READERS ===============================
    /**
     * @dev (선택) 외부에서 읽기 쉽게 공개 getter 제공.
     */
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    function getAdmin() external view returns (address) {
        return _getAdmin();
    }
 }