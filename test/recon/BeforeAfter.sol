// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "./Setup.sol";
import {Id, MarketParams} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";

abstract contract BeforeAfter is Setup {
    using MarketParamsLib for MarketParams;

    struct Vars {
        uint256[3] totalSupplyAssets;
        uint256[3] totalBorrowAssets;
        uint256[3] totalSupplyShares;
        uint256[3] totalBorrowShares;
        uint256[3] actorBorrowShares;
        uint256[3] actorCollateral;
    }

    Vars internal _before;
    Vars internal _after;

    modifier updateGhosts {
        __before();
        _;
        __after();
    }

    function _snapshot(Vars storage vars) internal {
        address actor = _getActor();
        for (uint256 i; i < markets.length; i++) {
            Id id = markets[i].id();
            (uint128 tsa, uint128 tss, uint128 tba, uint128 tbs, , ) = morpho.market(id);
            vars.totalSupplyAssets[i] = tsa;
            vars.totalSupplyShares[i] = tss;
            vars.totalBorrowAssets[i] = tba;
            vars.totalBorrowShares[i] = tbs;
            (, uint128 bs, uint128 c) = morpho.position(id, actor);
            vars.actorBorrowShares[i] = bs;
            vars.actorCollateral[i] = c;
        }
    }

    function __before() internal {
        _snapshot(_before);
    }

    function __after() internal {
        _snapshot(_after);
        for (uint256 i; i < markets.length; i++) {
            // Solvency: borrows never exceed supply
            assert(_after.totalBorrowAssets[i] <= _after.totalSupplyAssets[i]);
            // No borrower without collateral (bad debt must be realized atomically)
            if (_after.actorBorrowShares[i] > 0) {
                assert(_after.actorCollateral[i] > 0);
            }
        }
    }
}
