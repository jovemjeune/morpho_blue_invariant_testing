// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {Id, MarketParams, Position, Market} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";
import {SharesMathLib} from "src/libraries/SharesMathLib.sol";
import {MathLib} from "src/libraries/MathLib.sol";
import {MockERC20} from "@recon/MockERC20.sol";
import "src/libraries/ConstantsLib.sol";

abstract contract Properties is BeforeAfter, Asserts {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint256;

    // Borrows never exceed supply in any market
    function property_borrow_le_supply() public view {
        for (uint256 i; i < markets.length; i++) {
            Id id = markets[i].id();
            (uint128 totalSupplyAssets, , uint128 totalBorrowAssets, , , ) = morpho.market(id);
            assert(totalBorrowAssets <= totalSupplyAssets);
        }
    }

    // No actor has debt without collateral backing
    // Bad debt socialization sets borrowShares=0 atomically when collateral hits 0
    function property_no_borrower_without_collateral() public view {
        address[] memory actors = _getActors();
        for (uint256 i; i < markets.length; i++) {
            Id id = markets[i].id();
            for (uint256 j; j < actors.length; j++) {
                (, uint128 bs, uint128 c) = morpho.position(id, actors[j]);
                if (bs > 0) assert(c > 0);
            }
        }
    }

    // Morpho holds enough loan tokens to cover available liquidity
    function property_loan_token_solvency() public view {
        for (uint256 i; i < markets.length; i++) {
            Id id = markets[i].id();
            (uint128 tsa, , uint128 tba, , , ) = morpho.market(id);
            uint256 bal = MockERC20(markets[i].loanToken).balanceOf(address(morpho));
            assert(bal + uint256(tba) >= uint256(tsa));
        }
    }

    // Morpho holds enough collateral tokens to cover all known positions
    function property_collateral_solvency() public view {
        address[] memory actors = _getActors();
        for (uint256 i; i < markets.length; i++) {
            Id id = markets[i].id();
            uint256 totalColl;
            for (uint256 j; j < actors.length; j++) {
                (, , uint128 c) = morpho.position(id, actors[j]);
                totalColl += c;
            }
            uint256 bal = MockERC20(markets[i].collateralToken).balanceOf(address(morpho));
            assert(bal >= totalColl);
        }
    }

    // Market fee never exceeds MAX_FEE (25%)
    function property_fee_le_max() public view {
        for (uint256 i; i < markets.length; i++) {
            Id id = markets[i].id();
            (, , , , , uint128 fee) = morpho.market(id);
            assert(fee <= MAX_FEE);
        }
    }
}
