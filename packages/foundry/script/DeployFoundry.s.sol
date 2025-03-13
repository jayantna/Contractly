//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { Contractly } from "../contracts/Contractly.sol";
import { Delivery } from "../contracts/Delivery.sol";
import { GelatoFunctions } from "../contracts/GelatoFunctions.sol";
import { console } from "forge-std/console.sol";

contract DeployFoundry is Script {
    function run() external {
        address sender = 0x9a0FA1e56d01A6771c34DE9688a4477E3e8D5ec9;
        console.log("Sender:", sender);
        vm.startBroadcast();
        // Contractly contractly = new Contractly(sender);
        Delivery delivery = new Delivery(0xbDF351d76823A8714EE78e94abd4ff19Bbe5bcD8);
        // new GelatoFunctions(0xA5140205d3C34eC7397E202c581FF5984dd0Bc3D);
        vm.stopBroadcast();
    }
}