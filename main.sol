// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title EightEightEight
/// @notice Triple-eight house. Golden reel logic, tiered payouts, and vault splits.
///         Calibrated for low-volatility sessions; house reserve and max exposure capped per spin.

error EightHouseClosed();
error EightStakeBelowFloor();
error EightStakeAboveCeiling();
error EightSpinInProgress();
error EightOnlyCroupier();
error EightOnlyVault();
error EightZeroDisallowed();
error EightHousePaused();
error EightInsufficientReserve();
error EightClaimWindowClosed();
error EightNoPendingPayout();
error EightInvalidTier();
error EightDuplicateSpin();
error EightReentrancyBlocked();
error EightSpinNotFound();
error EightReserveBelowMinimum();

event ReelStopped(uint256 indexed spinId, address indexed player, uint8 tier, uint256 payoutWei, uint256 atBlock);
event ChipStaked(uint256 indexed spinId, address indexed player, uint256 amountWei, uint256 atBlock);
event HousePayout(address indexed to, uint256 amountWei, uint8 reason);
event CroupierRotated(address indexed previous, address indexed next);
event PauseToggled(bool paused);
event ReserveTopped(uint256 amountWei);
event TierHit(uint256 spinId, uint8 tier, uint256 multiplierBps);
event TreasurySwept(uint256 amountWei, uint256 atBlock);

uint256 constant SPIN_FLOOR_WEI = 0.001 ether;
uint256 constant SPIN_CEILING_WEI = 2 ether;
uint256 constant HOUSE_EDGE_BPS = 280;
uint256 constant TIER_ONE_MULTIPLIER_BPS = 888;
uint256 constant TIER_TWO_MULTIPLIER_BPS = 1888;
uint256 constant TIER_THREE_MULTIPLIER_BPS = 8888;
uint256 constant VAULT_SHARE_BPS = 120;
uint256 constant HOUSE_RESERVE_MIN_WEI = 0.5 ether;
uint256 constant CLAIM_DELAY_BLOCKS = 3;
uint256 constant TIER_ONE_CHANCE_BPS = 4200;
uint256 constant TIER_TWO_CHANCE_BPS = 880;
uint256 constant TIER_THREE_CHANCE_BPS = 88;

address constant DEFAULT_CROUPIER = 0x9D4e7F2a1B8c3E6f0A5d9C2b7E4f1a8D3c6B9e0F;
address constant DEFAULT_VAULT = 0x3F6a9E1c4B7d0e2A5f8C1b4D7e0a3F6c9B2e5d8A;
address constant DEFAULT_RESERVE_TOPUP = 0x7C2b5E8a1D4f9c0B3e6A8d1F4c7B0e3A6d9C2f5B;

contract EightEightEight {
    struct SpinRecord {
        address player;
        uint256 stakeWei;
        uint256 placedAtBlock;
        uint8 tier;
        uint256 payoutWei;
        bool settled;
        bool claimable;
    }

    struct HouseState {
        uint256 totalSpins;
        uint256 totalStaked;
        uint256 totalPaidOut;
        uint256 reserveBalance;
    }

    address private _croupier;
    address public immutable vault_;
    address public immutable reserveTopup_;

    uint256 private _spinCounter;
    uint256 private _lock;
    bool private _paused;

    HouseState private _house;
    mapping(uint256 => SpinRecord) private _spins;
    mapping(address => uint256[]) private _playerSpins;
    mapping(address => uint256) private _pendingClaim;

    modifier onlyCroupier() {
        if (msg.sender != _croupier) revert EightOnlyCroupier();
        _;
    }

    modifier onlyVault() {
        if (msg.sender != vault_) revert EightOnlyVault();
        _;
    }

    modifier whenOpen() {
        if (_paused) revert EightHousePaused();
        _;
    }

    modifier noReentrancy() {
        if (_lock != 0) revert EightReentrancyBlocked();
        _lock = 1;
        _;
        _lock = 0;
    }

    constructor() {
        _croupier = DEFAULT_CROUPIER;
        vault_ = DEFAULT_VAULT;
        reserveTopup_ = DEFAULT_RESERVE_TOPUP;
        _paused = false;
        _house.reserveBalance = 0;
        _house.totalSpins = 0;
        _house.totalStaked = 0;
        _house.totalPaidOut = 0;
    }

    receive() external payable {
        if (msg.sender == reserveTopup_) {
            _house.reserveBalance += msg.value;
            emit ReserveTopped(msg.value);
        }
    }

    function spin() external payable whenOpen noReentrancy returns (uint256 spinId) {
        if (msg.value < SPIN_FLOOR_WEI) revert EightStakeBelowFloor();
        if (msg.value > SPIN_CEILING_WEI) revert EightStakeAboveCeiling();

        spinId = ++_spinCounter;
        SpinRecord storage rec = _spins[spinId];
        rec.player = msg.sender;
        rec.stakeWei = msg.value;
        rec.placedAtBlock = block.number;
        rec.settled = false;
        rec.claimable = false;

        _house.totalStaked += msg.value;
        _house.reserveBalance += msg.value;
        _playerSpins[msg.sender].push(spinId);

        emit ChipStaked(spinId, msg.sender, msg.value, block.number);

        uint256 netStake = (msg.value * (10000 - HOUSE_EDGE_BPS)) / 10000;
        uint256 maxPayout = (netStake * TIER_THREE_MULTIPLIER_BPS) / 10000;
        if (_house.reserveBalance < maxPayout) revert EightInsufficientReserve();
        if (_house.reserveBalance - maxPayout < HOUSE_RESERVE_MIN_WEI) revert EightReserveBelowMinimum();

        uint256 roll = _entropy(spinId) % 10000;
        uint8 tier;
        if (roll < TIER_THREE_CHANCE_BPS) {
            tier = 3;
        } else if (roll < TIER_THREE_CHANCE_BPS + TIER_TWO_CHANCE_BPS) {
            tier = 2;
        } else if (roll < TIER_THREE_CHANCE_BPS + TIER_TWO_CHANCE_BPS + TIER_ONE_CHANCE_BPS) {
            tier = 1;
        } else {
            tier = 0;
        }

        rec.tier = tier;
        uint256 multBps = tier == 3 ? TIER_THREE_MULTIPLIER_BPS
            : tier == 2 ? TIER_TWO_MULTIPLIER_BPS
            : tier == 1 ? TIER_ONE_MULTIPLIER_BPS
            : 0;
        rec.payoutWei = (netStake * multBps) / 10000;
        rec.settled = true;
        rec.claimable = true;

        _house.reserveBalance -= rec.payoutWei;
        _house.totalPaidOut += rec.payoutWei;
        _house.totalSpins += 1;

        _pendingClaim[msg.sender] += rec.payoutWei;

        emit TierHit(spinId, tier, multBps);
        emit ReelStopped(spinId, msg.sender, tier, rec.payoutWei, block.number);
    }

    function claimPayout() external whenOpen noReentrancy {
        uint256 amount = _pendingClaim[msg.sender];
        if (amount == 0) revert EightNoPendingPayout();
        _pendingClaim[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
