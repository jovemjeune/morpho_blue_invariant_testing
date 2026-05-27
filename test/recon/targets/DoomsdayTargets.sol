// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import {Id, MarketParams} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";
import {SharesMathLib} from "src/libraries/SharesMathLib.sol";
import {MathLib} from "src/libraries/MathLib.sol";
import "src/libraries/ConstantsLib.sol";

abstract contract DoomsdayTargets is
    BaseTargetFunctions,
    Properties
{
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint256;

    modifier stateless() {
        _;
        revert("stateless");
    }

    // Full-collateral liquidation — forces bad debt socialization if position is underwater
    function property_liquidate_every_position(uint8 marketId, uint8 actorIdx) public stateless {
        marketId = uint8(marketId % markets.length);
        address[] memory actors = _getActors();
        actorIdx = uint8(actorIdx % actors.length);
        address borrower = actors[actorIdx];
        Id id = markets[marketId].id();
        (, , uint128 c) = morpho.position(id, borrower);
        if (c == 0) return;
        morpho.liquidate(markets[marketId], borrower, uint256(c), 0, hex"");
    }

    // Supply share value must not decrease (accounting for virtual shares/assets)
    function property_supply_share_value_nondecreasing(uint8 marketId) public stateless {
        marketId = uint8(marketId % markets.length);
        if (_before.totalSupplyShares[marketId] == 0 || _after.totalSupplyShares[marketId] == 0) return;
        uint256 VIRTUAL_SHARES = 1e6;
        uint256 VIRTUAL_ASSETS = 1;
        t(
            (_after.totalSupplyAssets[marketId] + VIRTUAL_ASSETS) * (_before.totalSupplyShares[marketId] + VIRTUAL_SHARES) >=
            (_before.totalSupplyAssets[marketId] + VIRTUAL_ASSETS) * (_after.totalSupplyShares[marketId] + VIRTUAL_SHARES),
            "supply share value decreased"
        );
    }

    // Borrower's health: maxBorrow >= borrowed, or position is legitimately liquidatable
    function property_position_health(uint8 marketId, uint8 actorIdx) public stateless {
        marketId = uint8(marketId % markets.length);
        address[] memory actors = _getActors();
        actorIdx = uint8(actorIdx % actors.length);
        Id id = markets[marketId].id();
        (, uint128 bs, uint128 c) = morpho.position(id, actors[actorIdx]);
        if (bs == 0) return;
        (, , uint128 tba, uint128 tbs, , ) = morpho.market(id);
        uint256 borrowed = uint256(bs).toAssetsUp(tba, tbs);
        uint256 collateralPrice = oracleMock.price();
        uint256 maxBorrow = uint256(c).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(markets[marketId].lltv);
        if (maxBorrow >= borrowed) {
            t(c > 0, "healthy position has no collateral");
        }
    }
}
