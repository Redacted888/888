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
