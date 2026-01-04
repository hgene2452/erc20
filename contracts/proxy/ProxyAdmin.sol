// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ProxyAdmin
 * @dev
 * TransparentUpgradeableProxy의 업그레이드를 전담하는 관리자 컨트랙트.
 *
 * 핵심 개념:
 * - Proxy의 admin을 EOA(지갑)로 두지 않고 이 컨트랙트로 둔다.
 * - 이 컨트랙트의 owner(EOA)만 업그레이드를 트리거할 수 있다.
 *
 * 효과:
 * - 운영자가 실수로 proxy에 transfer 같은 일반 호출을 하는 사고 방지
 * - "업그레이드 권한"과 "사용자 계정"을 구조적으로 분리
 */
 contract ProxyAdmin {
    // =============================== EVENTS ===============================
    /**
     * @dev 소유권 이전 이벤트
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // =============================== ERRORS ===============================
    error NotOwner();
    error ZeroAddress();

    // =============================== STORAGE ===============================
    /**
     * @dev 업그레이드 권한을 가진 EOA
     */
    address public owner;

    // =============================== MODIFIERS ===============================
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    // =============================== CONSTRUCTOR ===============================
    /**
     * @param initialOwner ProxyAdmin을 제어할 초기 owner (보통 배포자 EOA)
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert ZeroAddress();
        }
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    // =============================== OWNERSHIP MANAGEMENT ===============================
    /**
     * @dev 업그레이드 권한(owner) 이전
     *
     * - 프록시 admin 자체는 변하지 않음
     * - "누가 업그레이드를 트리거할 수 있는가"만 변경
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert ZeroAddress();
        }
        address previous = owner;
        owner = newOwner;
        emit OwnershipTransferred(previous, newOwner);
    }

    // =============================== UPGRADE API ===============================
    /**
     * @dev 프록시의 구현 컨트랙트를 교체하고,
     *      필요하면 초기화(delegatecall)까지 수행한다.
     *
     * @param proxy          TransparentUpgradeableProxy 주소
     * @param implementation 새 구현(implementation) 주소
     * @param data           초기화용 calldata (예: initializeV2())
     *
     * 호출 흐름:
     * owner(EOA)
     *   → ProxyAdmin.upgradeAndCall()
     *     → proxy.call(upgradeToAndCall)
     *       → TransparentUpgradeableProxy fallback
     *         → implementation 교체 + delegatecall
     *
     * 중요:
     * - 이 컨트랙트는 "업그레이드 요청"만 전달한다.
     * - 실제 검증/슬롯 변경/초기화는 프록시가 수행한다.
     */
    function upgradeAndCall(
        address proxy,
        address implementation,
        bytes calldata data
    ) external payable onlyOwner {
        // TransparentUpgradeableProxy는
        // upgradeToAndCall(address,bytes) selector만 허용한다.
        (bool success, bytes memory returndata) = proxy.call{value: msg.value}(
            abi.encodeWithSignature(
                "upgradeToAndCall(address,bytes)",
                implementation,
                data
            )
        );

        if (!success) {
            // revert reason 그대로 전달
            assembly {
                revert(add(returndata, 0x20), mload(returndata))
            }
        }
    }
 }