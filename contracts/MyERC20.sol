// SPDX-License-Identifier: MIT
// Solidity 0.4.17 버전 이상
pragma solidity ^0.8.20;

import "./IERC20.sol";

contract MyERC20 is IERC20 {
    // ==== Token metadata ====
    // 상태변수 정의
    // - 상태변수는 private로 선언하여 외부에서 직접 접근하지 못하게 함 (함수로만 공개)
    string private _name;
    string private _symbol;
    // - immutable 키워드를 사용하여 배포 시에만 값을 설정하고 이후에는 변경 불가
    uint8 private immutable _decimals;
    // - 컨트랙트를 배포한 admin
    address private owner;

    // ==== ERC-20 standard state variables ====
    uint256 private _totalSupply;
    // - 각 주소(address)의 잔액(balance)을 저장하는 매핑(mapping)
    //   c.f. _balances[주소] = 잔액 형태로 사용
    mapping(address => uint256) private _balances;
    // - 각 소유자(owner)가 승인한 지출자(spender)의 허용량(allowance)을 저장하는 이중 매핑
    //   c.f. _allowances[소유자][지출자] = 허용량 형태로 사용
    mapping(address => mapping(address => uint256)) private _allowances;

    // ==== Constructor ====
    // - 배포 시점에 초기화
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;

        owner = msg.sender;

        // 초기 공급량을 소유자에게 전송
        // - 이때, decimals를 고려하여 초기 공급량을 설정
        _mint(msg.sender, initialSupply * (10 ** uint256(decimals_)));
    }

    // ==== Token metadata functions ====
    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    // ==== ERC-20 standard functions ====
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }
    function allowance(address owner_, address spender) external view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    // ==== External functions for transferring tokens ====
    // - value가 0이어도 정상 처리되어야 함
    // - Transfer 이벤트가 발생해야 함
    function transfer(address to, uint256 value) external override returns (bool) {
        address from = msg.sender;
        _transfer(from, to, value);
        return true;
    }
    // - _allowances를 갱신해야 함
    function approve(address spender, uint256 value) external override returns (bool) {
        address owner_ = msg.sender;
        _approve(owner_, spender, value);
        return true;
    }
    // - allowance가 충분한지 확인해야 함
    // - _allowances를 갱신해야 함 (차감)
    // - Transfer 이벤트가 발생해야 함
    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        address spender = msg.sender;

        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    // additional external function
    function mint(address to, uint256 amountWhole) external onlyOwner returns (bool) {
        _mint(to, amountWhole * (10 ** uint256(_decimals)));
        return true;
    }

    // ==== Internal functions for transferring tokens ====
    // - 존재하지 않는 주소 (address(0))로 전송, 승인 불가
    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0) && to != address(0), "ZERO_ADDRESS");

        uint256 fromBal = _balances[from];
        require(fromBal >= value, "INSUFFICIENT_BALANCE");

        // 0 전송도 정상 (value=0이면 변화 없지만 이벤트는 emit)
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

            unchecked {
                _allowances[owner_][spender] = current - value;
            }

            // (선택) transferFrom 이후에도 Approval 이벤트로 "남은 한도" 갱신을 로그로 남김
            emit Approval(owner_, spender, _allowances[owner_][spender]);
        }
    }

    // ==== additional internal functions and modifiers ====
    // - Transfer 이벤트 발생
    // - totalSupply, _balances 갱신 (증가)
    // - ERC20 관례상 from 주소는 0이어야 함 (발행되는 토큰이므로 어디에서도 온 게 아니라, 새로 생겼다는 의미)
    function _mint(address to, uint256 value) internal {
        require(to != address(0), "ZERO_ADDRESS");

        _totalSupply += value;
        _balances[to] += value;

        emit Transfer(address(0), to, value);
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }
}