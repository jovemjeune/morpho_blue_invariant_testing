// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {MarketParams} from "src/interfaces/IMorpho.sol";
import {Morpho} from "src/Morpho.sol";

/// @notice Minimal manager for programmatic market deployment in the recon harness.
/// Owns the Morpho instance and gates privileged setup operations behind an `admin`.
contract MarketManager {
    address public admin;
    Morpho public immutable morpho;

    error NotAdmin();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    constructor(address initialAdmin) {
        admin = initialAdmin;
        morpho = new Morpho(address(this));
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }

    function enableIrm(address irm) external onlyAdmin {
        morpho.enableIrm(irm);
    }

    function enableLltv(uint256 lltv) external onlyAdmin {
        morpho.enableLltv(lltv);
    }

    function createMarket(MarketParams calldata params) external onlyAdmin {
        morpho.createMarket(params);
    }
}
