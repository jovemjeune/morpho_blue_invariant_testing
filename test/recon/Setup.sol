// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {BaseSetup} from "@chimera/BaseSetup.sol";
import {vm} from "@chimera/Hevm.sol";

// Managers
import {ActorManager} from "@recon/ActorManager.sol";
import {AssetManager} from "@recon/AssetManager.sol";

// Helpers
import {Utils} from "@recon/Utils.sol";

// Your deps
import {ERC20Mock} from  "src/mocks/ERC20Mock.sol";
import "src/mocks/IrmMock.sol";
import "src/Morpho.sol";
import "src/mocks/OracleMock.sol";
import {MarketManager} from "./MarketManager.sol";

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {
    ERC20Mock eRC20Mock;
    IrmMock irmMock;
    Morpho morpho;
    MarketManager marketManager;
    OracleMock oracleMock;
    MarketParams[] markets;
    address loan;
    address coll; 
    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {
        //Add essential contracts
        irmMock = new IrmMock();
        marketManager = new MarketManager(address(this));
        morpho = marketManager.morpho();
        oracleMock = new OracleMock(); 
        //Enable Lltv 
        marketManager.enableIrm(address(irmMock));
        marketManager.enableLltv(0.385e18);
        marketManager.enableLltv(0.625e18);
        marketManager.enableLltv(0.86e18);
        // Register actors owner will be this address
        _addActor(address(0xA11CE)); //user1
        _addActor(address(0xB0B));   //user2 
    
        //CreateNewMarkets 
        _createNewMarket(0.385e18);  // low  — tiny borrow room
        _createNewMarket(0.625e18);  // mid  — moderate
        _createNewMarket(0.86e18);   // high — tight liquidation
        //
    }
    function _createNewMarket(uint256 _lltv) internal{
        loan = _newAsset(18);
        coll = _newAsset(18);
        MarketParams memory params = MarketParams({
                loanToken:loan,
                collateralToken:coll,
                oracle:address(oracleMock),
                irm: address(irmMock),
                lltv:_lltv
                });  
                marketManager.createMarket(params);
                markets.push(params);   
                address[] memory spenders = new address[](1);
                spenders[0] = address(morpho);
                _finalizeAssetDeployment(_getActors(),spenders,type(uint128).max);
                 oracleMock.setPrice(1e36);
    }
    /// === MODIFIERS === ///
    /// Prank admin and actor
    modifier asAdmin {
        vm.prank(address(this));
        _;
    }

    modifier asActor {
        vm.prank(address(_getActor()));
        _;
    }
}
