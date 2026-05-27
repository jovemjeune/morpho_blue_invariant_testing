// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

// Targets
// NOTE: Always import and apply them in alphabetical order, so much easier to debug!
import { AdminTargets } from "./targets/AdminTargets.sol";
import { DoomsdayTargets } from "./targets/DoomsdayTargets.sol";
import { ERC20MockTargets } from "./targets/ERC20MockTargets.sol";
import { ManagersTargets } from "./targets/ManagersTargets.sol";
import { MorphoTargets } from "./targets/MorphoTargets.sol";
import { OracleMockTargets } from "./targets/OracleMockTargets.sol";

import {Id, MarketParams, IMorpho} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";
import {SharesMathLib} from "src/libraries/SharesMathLib.sol";
import {MockERC20} from "@recon/MockERC20.sol";
import {FlashBorrowerMock} from "src/mocks/FlashBorrowerMock.sol";

abstract contract TargetFunctions is
    AdminTargets,
    DoomsdayTargets,
    ERC20MockTargets,
    ManagersTargets,
    MorphoTargets,
    OracleMockTargets
{
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;

    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    // === ADMIN (call morpho directly — asActor would override asAdmin prank) === //

    function morpho_setFee_clamped(uint8 marketId, uint256 newFee) public asAdmin {
        marketId = uint8(marketId % markets.length);
        newFee = between(newFee, 0, 0.25e18);
        morpho.setFee(markets[marketId], newFee);
    }

    function morpho_setFeeRecipient_clamped(uint8 actorIdx) public asAdmin {
        address[] memory actors = _getActors();
        actorIdx = uint8(actorIdx % actors.length);
        morpho.setFeeRecipient(actors[actorIdx]);
    }

    // === SUPPLY === //

    function morpho_supply_clamped(uint8 marketId, uint256 assets) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        assets = between(assets, 1, 10e24);
        address actor = _getActor();
        morpho_supply(markets[marketId], assets, 0, actor, hex"");
    }

    function morpho_withdraw_clamped(uint8 marketId, uint256 assets) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        Id id = markets[marketId].id();
        address actor = _getActor();
        (uint256 ss, , ) = morpho.position(id, actor);
        if (ss == 0) return;
        (uint128 tsa, uint128 tss, , , , ) = morpho.market(id);
        uint256 maxAssets = ss.toAssetsDown(tsa, tss);
        if (maxAssets == 0) return;
        assets = between(assets, 1, maxAssets);
        morpho_withdraw(markets[marketId], assets, 0, actor, actor);
    }

    // === COLLATERAL === //

    function morpho_supplyCollateral_clamped(uint8 marketId, uint256 assets) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        assets = between(assets, 1, 10e24);
        address actor = _getActor();
        morpho_supplyCollateral(markets[marketId], assets, actor, hex"");
    }

    function morpho_withdrawCollateral_clamped(uint8 marketId, uint256 assets) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        Id id = markets[marketId].id();
        address actor = _getActor();
        (, , uint128 c) = morpho.position(id, actor);
        if (c == 0) return;
        assets = between(assets, 1, uint256(c));
        morpho_withdrawCollateral(markets[marketId], assets, actor, actor);
    }

    // === BORROW === //

    function morpho_borrow_clamped(uint8 marketId, uint256 assets) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        assets = between(assets, 1, 10e24);
        address actor = _getActor();
        morpho_borrow(markets[marketId], assets, 0, actor, actor);
    }

    function morpho_repay_clamped(uint8 marketId, uint256 assets) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        Id id = markets[marketId].id();
        address actor = _getActor();
        (, uint128 bs, ) = morpho.position(id, actor);
        if (bs == 0) return;
        (, , uint128 tba, uint128 tbs, , ) = morpho.market(id);
        uint256 owed = uint256(bs).toAssetsUp(tba, tbs);
        if (owed == 0) return;
        assets = between(assets, 1, owed);
        morpho_repay(markets[marketId], assets, 0, actor, hex"");
    }

    // === LIQUIDATION === //

    function morpho_liquidate_clamped(uint8 marketId, uint8 actorIdx, uint256 seizedAssets) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        address[] memory actors = _getActors();
        actorIdx = uint8(actorIdx % actors.length);
        address borrower = actors[actorIdx];
        Id id = markets[marketId].id();
        (, , uint128 c) = morpho.position(id, borrower);
        if (c == 0) return;
        seizedAssets = between(seizedAssets, 1, uint256(c));
        morpho_liquidate(markets[marketId], borrower, seizedAssets, 0, hex"");
    }


    // === ORACLE === //

    function oracleMock_setPrice_clamped(uint256 newPrice) public {
        newPrice = between(newPrice, 1e30, 1e42);
        oracleMock.setPrice(newPrice);
    }

    // === INTEREST === //

    function morpho_accrueInterest_clamped(uint8 marketId) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        morpho.accrueInterest(markets[marketId]);
    }

    // === AUTHORIZATION === //

    function morpho_setAuthorization_clamped(uint8 actorIdx, bool newIsAuthorized) public asActor {
        address[] memory actors = _getActors();
        actorIdx = uint8(actorIdx % actors.length);
        morpho.setAuthorization(actors[actorIdx], newIsAuthorized);
    }

    // === DELEGATION === //

    function morpho_withdraw_onBehalf_clamped(uint8 marketId, uint8 ownerIdx, uint256 assets) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        address[] memory actors = _getActors();
        ownerIdx = uint8(ownerIdx % actors.length);
        address owner = actors[ownerIdx];
        address actor = _getActor();
        Id id = markets[marketId].id();
        (uint256 ss, , ) = morpho.position(id, owner);
        if (ss == 0) return;
        (uint128 tsa, uint128 tss, , , , ) = morpho.market(id);
        uint256 maxAssets = ss.toAssetsDown(tsa, tss);
        if (maxAssets == 0) return;
        assets = between(assets, 1, maxAssets);
        vm.prank(actor);
        morpho.withdraw(markets[marketId], assets, 0, owner, actor);
    }

    function morpho_borrow_onBehalf_clamped(uint8 marketId, uint8 ownerIdx, uint256 assets) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        address[] memory actors = _getActors();
        ownerIdx = uint8(ownerIdx % actors.length);
        address owner = actors[ownerIdx];
        address actor = _getActor();
        assets = between(assets, 1, 10e24);
        vm.prank(actor);
        morpho.borrow(markets[marketId], assets, 0, owner, actor);
    }

    // === SHARES PATH (assets=0) — Ivan-style, hits conversion branches === //

    function morpho_supply_shares_clamped(uint8 marketId, uint256 shares) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        shares = between(shares, 1, type(uint128).max);
        address actor = _getActor();
        morpho_supply(markets[marketId], 0, shares, actor, hex"");
    }

    function morpho_withdraw_shares_clamped(uint8 marketId, uint256 shares) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        Id id = markets[marketId].id();
        address actor = _getActor();
        (uint256 ss, , ) = morpho.position(id, actor);
        if (ss == 0) return;
        shares = between(shares, 1, ss);
        morpho_withdraw(markets[marketId], 0, shares, actor, actor);
    }

    function morpho_borrow_shares_clamped(uint8 marketId, uint256 shares) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        shares = between(shares, 1, type(uint128).max);
        address actor = _getActor();
        morpho_borrow(markets[marketId], 0, shares, actor, actor);
    }

    function morpho_repay_shares_clamped(uint8 marketId, uint256 shares) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        Id id = markets[marketId].id();
        address actor = _getActor();
        (, uint128 bs, ) = morpho.position(id, actor);
        if (bs == 0) return;
        shares = between(shares, 1, uint256(bs));
        morpho_repay(markets[marketId], 0, shares, actor, hex"");
    }

    function morpho_liquidate_repayShares_clamped(uint8 marketId, uint8 actorIdx, uint256 repaidShares) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        address[] memory actors = _getActors();
        actorIdx = uint8(actorIdx % actors.length);
        address borrower = actors[actorIdx];
        Id id = markets[marketId].id();
        (, uint128 bs, ) = morpho.position(id, borrower);
        if (bs == 0) return;
        repaidShares = between(repaidShares, 1, uint256(bs));
        morpho_liquidate(markets[marketId], borrower, 0, repaidShares, hex"");
    }

    // === FLASH LOAN === //

    function morpho_flashLoan_clamped(uint8 marketId, uint256 assets) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        assets = between(assets, 1, 10e24);
        address token = markets[marketId].loanToken;
        FlashBorrowerMock borrower = new FlashBorrowerMock(IMorpho(address(morpho)));
        borrower.flashLoan(token, assets, abi.encode(token));
    }

    // === INTEREST (warp so _accrueInterest runs with elapsed > 0) === //

    function guided_accrueInterest(uint8 marketId, uint256 warpSecs) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        warpSecs = between(warpSecs, 1, 365 days);
        vm.warp(block.timestamp + warpSecs);
        morpho.accrueInterest(markets[marketId]);
    }

    // === GUIDED COMPOSITES === //

    // Supply liquidity then post collateral then borrow — full leveraged position in one call
    function guided_supplyBorrow(uint8 marketId, uint256 supplyAmt, uint256 collAmt, uint256 borrowAmt) public updateGhosts {
        marketId = uint8(marketId % markets.length);
        supplyAmt = between(supplyAmt, 1e18, 1e24);
        collAmt = between(collAmt, 1e18, 1e24);
        uint256 maxBorrow = collAmt * markets[marketId].lltv / 1e18;
        uint256 limit = maxBorrow < supplyAmt ? maxBorrow : supplyAmt;
        if (limit == 0) return;
        borrowAmt = between(borrowAmt, 1, limit);
        address actor = _getActor();
        vm.startPrank(actor);
        morpho.supply(markets[marketId], supplyAmt, 0, actor, hex"");
        morpho.supplyCollateral(markets[marketId], collAmt, actor, hex"");
        morpho.borrow(markets[marketId], borrowAmt, 0, actor, actor);
        vm.stopPrank();
    }

    // Open position then crash oracle and liquidate full collateral (liquidation + bad debt paths)
    function guided_crashAndLiquidate(uint8 marketId, uint256 supplyAmt, uint256 collAmt, uint256 borrowAmt)
        public
        updateGhosts
    {
        marketId = uint8(marketId % markets.length);
        supplyAmt = between(supplyAmt, 1e18, 1e24);
        collAmt = between(collAmt, 1e18, 1e24);
        uint256 maxBorrow = collAmt * markets[marketId].lltv / 1e18;
        uint256 limit = maxBorrow < supplyAmt ? maxBorrow : supplyAmt;
        if (limit == 0) return;
        borrowAmt = between(borrowAmt, 1, limit);
        address actor = _getActor();
        vm.startPrank(actor);
        morpho.supply(markets[marketId], supplyAmt, 0, actor, hex"");
        morpho.supplyCollateral(markets[marketId], collAmt, actor, hex"");
        morpho.borrow(markets[marketId], borrowAmt, 0, actor, actor);
        vm.stopPrank();
        oracleMock.setPrice(1e24);
        Id id = markets[marketId].id();
        (, , uint128 c) = morpho.position(id, actor);
        if (c == 0) return;
        morpho.liquidate(markets[marketId], actor, uint256(c), 0, hex"");
    }
}
