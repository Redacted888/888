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

