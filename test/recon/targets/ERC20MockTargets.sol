// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import "src/mocks/ERC20Mock.sol";

abstract contract ERC20MockTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function eRC20Mock_approve(address spender, uint256 amount) internal asActor {
        eRC20Mock.approve(spender, amount);
    }

    function eRC20Mock_setBalance(address account, uint256 amount) internal asActor {
        eRC20Mock.setBalance(account, amount);
    }

    function eRC20Mock_transfer(address to, uint256 amount) internal asActor {
        eRC20Mock.transfer(to, amount);
    }

    function eRC20Mock_transferFrom(address from, address to, uint256 amount) internal asActor {
        eRC20Mock.transferFrom(from, to, amount);
    }
}