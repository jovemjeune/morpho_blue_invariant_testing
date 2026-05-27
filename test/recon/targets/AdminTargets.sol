// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

abstract contract AdminTargets is
    BaseTargetFunctions,
    Properties
{
    // Enable new LLTV (clamped < 100%)
    function morpho_enableLltv_clamped(uint256 lltv) public asAdmin {
        lltv = between(lltv, 0.01e18, 0.99e18);
        morpho.enableLltv(lltv);
    }
}
