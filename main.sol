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
