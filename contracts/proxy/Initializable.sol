// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Initializable
 *
 * @dev
 * - constructor 대신 initialize 함수를 사용해 업그레이드 가능 컨트랙트를 초기화한다.
 * - initialize / reinitialize 함수가 딱 한 번씩만 실행되도록 보장한다.
 * - 구현 컨트랙트 직접 초기화 공격 방지.
 */
abstract contract Initializable {
    error InvalidInitialization();
    error NotInitializing();

    uint64 private _initializedVersion;
    bool private _initializing;

    event Initialized(uint64 version);

    modifier initializer() {
        // 이미 다른 초기화가 진행 중인 상태에서 initializer를 다시 호출하는 것은 금지
        // (일반적으로 initialize()는 최상위 1번만 호출되게 설계)
        if (_initializing) revert InvalidInitialization();

        // 이미 버전이 0이 아니면(초기화됨) 재호출 금지
        if (_initializedVersion != 0) revert InvalidInitialization();

        // top-level 초기화 시작
        _initializedVersion = 1;
        _initializing = true;

        _;

        // top-level 초기화 종료
        _initializing = false;
        emit Initialized(1);
    }
    modifier reinitializer(uint64 version) {
        if (_initializing) revert InvalidInitialization();
        if (_initializedVersion >= version) revert InvalidInitialization();

        _initializedVersion = version;
        _initializing = true;

        _;

        _initializing = false;
        emit Initialized(version);
    }
    modifier onlyInitializing() {
        if (!_initializing) revert NotInitializing();
        _;
    }

    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
    function _getInitializedVersion() internal view returns (uint64) {
        return _initializedVersion;
    }
    function _disableInitializers() internal {
        if (_initializing) revert InvalidInitialization();

        if (_initializedVersion != type(uint64).max) {
            _initializedVersion = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }
}
