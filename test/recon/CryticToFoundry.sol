// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";

import "forge-std/console2.sol";

import {Test} from "forge-std/Test.sol";
import {TargetFunctions} from "./TargetFunctions.sol";
import {Id, MarketParams} from "src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "src/libraries/MarketParamsLib.sol";
import {MockERC20} from "@recon/MockERC20.sol";


// forge test --match-contract CryticToFoundry -vv
contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    using MarketParamsLib for MarketParams;

    function setUp() public {
        setup();

        targetContract(address(this));
    }

    // === FOUNDRY INVARIANTS (same properties, forge-compatible) === //

    function invariant_borrow_le_supply() public view {
        property_borrow_le_supply();
    }

    function invariant_no_borrower_without_collateral() public view {
        property_no_borrower_without_collateral();
    }

    function invariant_loan_token_solvency() public view {
        property_loan_token_solvency();
    }

    function invariant_collateral_solvency() public view {
        property_collateral_solvency();
    }

    function invariant_fee_le_max() public view {
        property_fee_le_max();
    }

    // === COVERAGE HELPERS === //

    function onMorphoSupply(uint256, bytes calldata) external {}
    function onMorphoRepay(uint256, bytes calldata) external {}
    function onMorphoSupplyCollateral(uint256, bytes calldata) external {}

    function test_setOwner_coverage() public {
        morpho.setOwner(address(0xDEAD));
    }

    function test_callback_coverage() public {
        MockERC20(markets[0].loanToken).mint(address(this), 100e18);
        MockERC20(markets[0].loanToken).approve(address(morpho), type(uint256).max);
        MockERC20(markets[0].collateralToken).mint(address(this), 100e18);
        MockERC20(markets[0].collateralToken).approve(address(morpho), type(uint256).max);

        morpho.supply(markets[0], 10e18, 0, address(this), hex"01");
        morpho.supplyCollateral(markets[0], 10e18, address(this), hex"01");
        morpho.borrow(markets[0], 3e18, 0, address(this), address(this));
        morpho.repay(markets[0], 3e18, 0, address(this), hex"01");
    }

    // forge test --match-test test_badDebt_supply_share_value -vvv
    function test_badDebt_supply_share_value() public {
        uint256 VIRTUAL_SHARES = 1e6;
        uint256 VIRTUAL_ASSETS = 1;

        // 1. Supply liquidity + collateral + borrow near LLTV
        morpho_supply_clamped(0, 100e18);
        morpho_supplyCollateral_clamped(0, 100e18);
        morpho_borrow_clamped(0, 30e18);

        // Snapshot supply share value BEFORE
        Id id = markets[0].id();
        (uint128 tsaBefore, uint128 tssBefore, , , , ) = morpho.market(id);
        uint256 valueBefore = (uint256(tsaBefore) + VIRTUAL_ASSETS) * 1e18
            / (uint256(tssBefore) + VIRTUAL_SHARES);
        console2.log("supply share value before:", valueBefore);

        // 2. Oracle price crashes 1,000,000x — position deeply underwater
        oracleMock.setPrice(1e30);

        // 3. Seize ALL collateral — forces bad debt socialization
        address actor = _getActor();
        (, , uint128 c) = morpho.position(id, actor);
        vm.prank(actor);
        morpho.liquidate(markets[0], actor, uint256(c), 0, hex"");

        // 4. Verify bad debt was socialized: supply share value decreased
        (uint128 tsaAfter, uint128 tssAfter, , , , ) = morpho.market(id);
        uint256 valueAfter = (uint256(tsaAfter) + VIRTUAL_ASSETS) * 1e18
            / (uint256(tssAfter) + VIRTUAL_SHARES);
        console2.log("supply share value after: ", valueAfter);
        console2.log("lender loss (assets):     ", uint256(tsaBefore) - uint256(tsaAfter));

        assertTrue(
            (uint256(tsaAfter) + VIRTUAL_ASSETS) * (uint256(tssBefore) + VIRTUAL_SHARES) <
            (uint256(tsaBefore) + VIRTUAL_ASSETS) * (uint256(tssAfter) + VIRTUAL_SHARES),
            "BAD DEBT: supply share value decreased - lenders lost funds"
        );
    }
}