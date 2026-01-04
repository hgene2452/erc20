// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../proxy/Initializable.sol";
import "./interfaces/IERC20.sol";

/**
 * @title MyERC20V1
 *
 * @dev 
 * - 업그레이더블 ERC20 V1 (Transparent Proxy 뒤에서 동작)
 *
 * 핵심 규칙:
 * - constructor에서 상태 초기화
 * - initialize() + initializer modifier로 초기화 수행
 * - immutable 사용
 * - storage layout 절대 변경 금지 (V2 업그레이드 대비)
 */
contract MyERC20V1 is Initializable, IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    address private _owner;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor() {
        // 구현 컨트랙트 자체를 초기화 불가 상태로 잠금
        _disableInitializers();
    }
    /**
     * @dev constructor 대체 함수
     * proxy 배포 시 data로 delegatecall 되어 프록시 storage에 값이 저장된다.
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

        // whole 단위를 raw로 변환하여 발행
        _mint(owner_, initialSupplyWhole_ * (10 ** uint256(_decimals)));
    }

    function name() external view returns (string memory) { return _name; }
    function symbol() external view returns (string memory) { return _symbol; }
    function decimals() external view returns (uint8) { return _decimals; }
    function owner() external view returns (address) { return _owner; }
    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) external view override returns (uint256) { return _balances[account]; }
    function allowance(address owner_, address spender) external view override returns (uint256) { return _allowances[owner_][spender]; }

    // =============================================================
    //                        IERC20 ACTIONS
    // =============================================================
    function transfer(address to, uint256 value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }
    function approve(address spender, uint256 value) external override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }
    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }
    function mint(address to, uint256 amountWhole) external onlyOwner returns (bool) {
        _mint(to, amountWhole * (10 ** uint256(_decimals)));
        return true;
    }

    // =============================================================
    //                         INTERNAL LOGIC
    // =============================================================
    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0) && to != address(0), "ZERO_ADDRESS");

        uint256 fromBal = _balances[from];
        require(fromBal >= value, "INSUFFICIENT_BALANCE");

        unchecked {
            _balances[from] = fromBal - value;
            _balances[to] += value;
        }

        // ERC20 표준 이벤트 (필수)
        emit Transfer(from, to, value);
    }
    function _approve(address owner_, address spender, uint256 value) internal {
        require(owner_ != address(0) && spender != address(0), "ZERO_ADDRESS");

        _allowances[owner_][spender] = value;

        // ERC20 표준 이벤트 (필수)
        emit Approval(owner_, spender, value);
    }
    function _spendAllowance(address owner_, address spender, uint256 value) internal {
        uint256 current = _allowances[owner_][spender];

        // 무한 승인(uint256 max)은 감소시키지 않음 (가스/관례)
        if (current != type(uint256).max) {
            require(current >= value, "INSUFFICIENT_ALLOWANCE");

            unchecked {
                _allowances[owner_][spender] = current - value;
            }

            // transferFrom으로 allowance가 바뀌었으니 이벤트를 남기는 편이 관측에 유리
            emit Approval(owner_, spender, _allowances[owner_][spender]);
        }
    }
    function _mint(address to, uint256 value) internal {
        require(to != address(0), "ZERO_ADDRESS");

        _totalSupply += value;
        _balances[to] += value;

        // mint는 from=0x0
        emit Transfer(address(0), to, value);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "NOT_OWNER");
        _;
    }
    
    uint256[50] private __gap;
}
