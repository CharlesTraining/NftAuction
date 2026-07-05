// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console2 } from "forge-std/Script.sol";

import { AuctionFactory } from "../src/factory/AuctionFactory.sol";
import { AuctionFactoryV2 } from "../src/factory/AuctionFactoryV2.sol";

contract UpgradeAuction is Script {
    function run() external returns (AuctionFactoryV2 factoryV2, AuctionFactoryV2 implementationV2) {
        uint256 upgraderPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxy = vm.envAddress("AUCTION_FACTORY_PROXY");
        uint256 version = vm.envOr("AUCTION_FACTORY_VERSION", uint256(2));

        vm.startBroadcast(upgraderPrivateKey);

        implementationV2 = new AuctionFactoryV2();
        AuctionFactory(payable(proxy))
            .upgradeToAndCall(address(implementationV2), abi.encodeCall(AuctionFactoryV2.initializeV2, (version)));
        factoryV2 = AuctionFactoryV2(payable(proxy));

        vm.stopBroadcast();

        console2.log("auctionFactory proxy", proxy);
        console2.log("auctionFactory implementationV2", address(implementationV2));
        console2.log("auctionFactory version", factoryV2.version());
    }
}
