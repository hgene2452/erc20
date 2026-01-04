// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Initializable
 * @dev
 * 업그레이더블 컨트랙트에서 constructor를 대체하기 위한 초기화 보호 장치.
 *
 * 핵심 문제:
 * - 프록시 뒤에서는 constructor가 실행되지 않는다.
 * - initialize()를 public/external로 열어두면
 *   아무나 여러 번 호출할 수 있는 치명적 보안 문제가 생긴다.
 *
 * 해결:
 * - initializer / reinitializer(version) modifier로
 *   "딱 한 번" 또는 "버전별 한 번"만 실행되도록 강제한다.
 *
 * 이 컨트랙트는:
 * - 구현(Implementation) 컨트랙트가 상속해서 사용한다.
 * - 프록시 storage에 상태를 기록한다.
 */
abstract contract Initializable {
    // =============================== ERRORS ===============================
    error AlreadyInitialized();
    error NotInitializing();

    // =============================== STORAGE ===============================
    /**
     * @dev
     * 초기화 상태를 기록하는 변수들.
     *
     * - _initializedVersion:
     *   마지막으로 실행된 initializer 버전
     *   (0 = 아직 초기화 안 됨)
     *
     * - _initializing:
     *   현재 초기화 실행 중인지 여부
     *
     * 중요:
     * - 이 변수들은 "프록시 storage"에 저장된다.
     * - 구현 컨트랙트 storage가 아니다.
     */
    uint64 private _initializedVersion;
    bool private _initializing;

    // =============================== EVENTS ===============================
    event Initialized(uint64 version);

    // =============================== MODIFIERS ===============================
    /**
     * @dev
     * 최초 1회만 실행 가능한 initializer.
     *
     * 보통 V1 구현의 initialize()에 사용한다.
     */
    modifier initializer() {
        if (_initializing) {
            revert AlreadyInitialized();
        }
        if (_initializedVersion != 0) {
            revert AlreadyInitialized();
        }

        _initializedVersion = 1;
        _initializing = true;

        _;

        _initializing = false;
        emit Initialized(1);
    }

    /**
     * @dev
     * 업그레이드 이후 추가 초기화를 위한 reinitializer.
     *
     * @param version 재초기화 버전
     * - 반드시 이전 version보다 커야 한다.
     * - 같은 version으로는 다시 실행 불가.
     *
     * 예:
     * - V1: initializer() → version 1
     * - V2: reinitializer(2)
     * - V3: reinitializer(3)
     */
    modifier reinitializer(uint64 version) {
        if (_initializing) {
            revert AlreadyInitialized();
        }
        if (_initializedVersion >= version) {
            revert AlreadyInitialized();
        }

        _initializedVersion = version;
        _initializing = true;

        _;

        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev
     * initializer / reinitializer 내부에서만 호출 가능한 함수 보호자.
     *
     * 여러 상속 구조에서:
     * - 부모 initialize 함수가
     * - 자식 initialize 함수 내부에서만 호출되도록 강제할 때 사용
     */
    modifier onlyInitializing() {
        if (!_initializing) {
            revert NotInitializing();
        }
        _;
    }

    // =============================== INTERNAL HELPERS ===============================
    /**
     * @dev
     * 현재 초기화가 진행 중인지 여부 반환
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }

    /**
     * @dev
     * 현재까지 실행된 initializer 버전 반환
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _initializedVersion;
    }

    /**
     * @dev
     * (권장)
     * 구현 컨트랙트 자체를 "영구적으로 초기화 불가" 상태로 만든다.
     *
     * - 구현 컨트랙트가 직접 initialize 되는 것을 방지
     * - 프록시를 통해서만 initialize 가능하게 강제
     *
     * 보통 구현 컨트랙트 constructor에서 호출한다.
     */
    function _disableInitializers() internal {
        if (_initializing) {
            revert AlreadyInitialized();
        }
        if (_initializedVersion != type(uint64).max) {
            _initializedVersion = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }
}
