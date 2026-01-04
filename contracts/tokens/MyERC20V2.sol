// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../proxy/Initializable.sol";
import "./interfaces/IERC20.sol";

 /**
 * @title MyERC20V2
 *
 * @dev
 * V1에서 업그레이드된 ERC20 구현 컨트랙트 (Transparent Proxy 뒤에서 실행됨)
 *
 * 업그레이더블 컨트랙트 핵심 규칙:
 * 1) V1의 storage layout을 절대 변경하지 않는다
 * 2) 새로운 상태 변수는 반드시 "뒤에만" 추가한다
 * 3) V2 전용 초기화 로직은 reinitializer(2)를 사용한다
 * 4) constructor는 사용하지 않고 initialize 계열 함수만 사용한다
 */
contract MyERC20V2 is Initializable, IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    address private _owner;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // V2 STORAGE (새로 추가된 영역)
    /**
     * @dev
     * - 특정 주소만 transfer / mint / burn 등을 수행할 수 있도록 제한하는 옵션
     */
    mapping(address => bool) private _whitelist;
    /**
     * @dev
     * - whitelist 기능 자체의 on/off 스위치
     * - false면 whitelist는 무시됨
     */
    bool private _whitelistEnabled;

    event Burn(address indexed from, uint256 value);
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event WhitelistUpdated(address indexed account, bool allowed);
    event WhitelistEnabled(bool enabled);
    event MetadataUpdated(string name, string symbol, uint8 decimals);

    /**
     * @dev
     * - 구현 컨트랙트 보호용 constructor
     *
     * - 프록시 환경에서는 constructor가 실행되지 않는다
     * - 하지만 구현 컨트랙트를 직접 호출하는 공격을 방지하기 위해
     *   initialize 계열 함수를 영구적으로 비활성화한다
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev
     * - V1과 동일한 시그니처의 initialize
     *
     * 왜 남겨두는가?
     * - 이미 V1에서 initializer(version=1)가 실행됨
     * - proxy가 V2로 업그레이드된 후 이 함수는 "자동으로 막힌 상태"
     * - 실수로 호출되더라도 revert 되어 안전함
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupplyWhole_,
        address owner_
    ) external initializer {
        require(owner_ != address(0), "OWNER_ZERO");

        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _owner = owner_;

        _mint(owner_, initialSupplyWhole_ * (10 ** uint256(_decimals)));
    }
    /**
     * @dev
     * - V2 전용 초기화 함수
     *
     * - reinitializer(2): version 2에서 딱 1번만 실행 가능
     * - whitelist 기능의 초기 상태를 설정
     */
    function initializeV2(bool whitelistEnabled_) external reinitializer(2) {
        _whitelistEnabled = whitelistEnabled_;
        emit WhitelistEnabled(whitelistEnabled_);
    }

    function name() external view returns (string memory) { return _name; }
    function symbol() external view returns (string memory) { return _symbol; }
    function decimals() external view returns (uint8) { return _decimals; }
    function owner() external view returns (address) { return _owner; }
    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) external view override returns (uint256) { return _balances[account]; }
    function allowance(address owner_, address spender) external view override returns (uint256) { return _allowances[owner_][spender]; }
    function isWhitelisted(address account) external view returns (bool) {
        return _whitelist[account];
    }
    function whitelistEnabled() external view returns (bool) {
        return _whitelistEnabled;
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        _enforceWhitelistIfNeeded(msg.sender, to);
        _transfer(msg.sender, to, value);
        return true;
    }
    function approve(address spender, uint256 value) external override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }
    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        _enforceWhitelistIfNeeded(from, to);
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "NOT_OWNER");
        _;
    }
    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "OWNER_ZERO");
        address prev = _owner;
        _owner = newOwner;
        emit OwnerChanged(prev, newOwner);
    }

    function setWhitelistEnabled(bool enabled) external onlyOwner {
        _whitelistEnabled = enabled;
        emit WhitelistEnabled(enabled);
    }
    function setWhitelisted(address account, bool allowed) external onlyOwner {
        require(account != address(0), "ZERO_ADDRESS");
        _whitelist[account] = allowed;
        emit WhitelistUpdated(account, allowed);
    }

    function mint(address to, uint256 amountWhole) external onlyOwner returns (bool) {
        if (_whitelistEnabled) {
            require(_whitelist[to], "TO_NOT_WHITELISTED");
        }
        _mint(to, amountWhole * (10 ** uint256(_decimals)));
        return true;
    }
    function burn(uint256 amountWhole) external returns (bool) {
        uint256 value = amountWhole * (10 ** uint256(_decimals));
        _burn(msg.sender, value);
        return true;
    }
    function burnFrom(address from, uint256 amountWhole) external returns (bool) {
        uint256 value = amountWhole * (10 ** uint256(_decimals));
        _spendAllowance(from, msg.sender, value);
        _burn(from, value);
        return true;
    }

    /**
     * @dev
     * - 토큰 메타데이터 변경 (실습/관리 목적)
     * - 실무에서는 decimals 변경은 매우 위험함
     */
    function updateMetadata(
        string calldata newName,
        string calldata newSymbol,
        uint8 newDecimals
    ) external onlyOwner {
        _name = newName;
        _symbol = newSymbol;

        // 실습 목적이면 허용
        _decimals = newDecimals;

        emit MetadataUpdated(newName, newSymbol, newDecimals);
    }

    function _enforceWhitelistIfNeeded(address from, address to) internal view {
        if (_whitelistEnabled) {
            require(_whitelist[from], "FROM_NOT_WHITELISTED");
            require(_whitelist[to], "TO_NOT_WHITELISTED");
        }
    }
    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0) && to != address(0), "ZERO_ADDRESS");

        uint256 fromBal = _balances[from];
        require(fromBal >= value, "INSUFFICIENT_BALANCE");

        unchecked {
            _balances[from] = fromBal - value;
            _balances[to] += value;
        }
        emit Transfer(from, to, value);
    }
    function _approve(address owner_, address spender, uint256 value) internal {
        require(owner_ != address(0) && spender != address(0), "ZERO_ADDRESS");
        _allowances[owner_][spender] = value;
        emit Approval(owner_, spender, value);
    }
    function _spendAllowance(address owner_, address spender, uint256 value) internal {
        uint256 current = _allowances[owner_][spender];
        if (current != type(uint256).max) {
            require(current >= value, "INSUFFICIENT_ALLOWANCE");
            unchecked { _allowances[owner_][spender] = current - value; }
            emit Approval(owner_, spender, _allowances[owner_][spender]);
        }
    }
    function _mint(address to, uint256 value) internal {
        require(to != address(0), "ZERO_ADDRESS");
        _totalSupply += value;
        _balances[to] += value;
        emit Transfer(address(0), to, value);
    }
    function _burn(address from, uint256 value) internal {
        require(from != address(0), "ZERO_ADDRESS");
        uint256 bal = _balances[from];
        require(bal >= value, "INSUFFICIENT_BALANCE");

        unchecked {
            _balances[from] = bal - value;
            _totalSupply -= value;
        }

        emit Transfer(from, address(0), value);
        emit Burn(from, value);
    }

    /**
     * @dev
     * - 다음 버전(V3, V4...)에서 사용할 storage 공간 예약
     * - V1(50) → V2에서 일부 사용 → 남은 48
     */
    uint256[48] private __gap;
}
