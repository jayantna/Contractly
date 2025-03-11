//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { Contractly } from "../contracts/Contractly.sol";
import { Delivery } from "../contracts/Delivery.sol";
import { GelatoFunctions } from "../contracts/GelatoFunctions.sol";

contract DeployFoundry is Script {
    function run() external {
        vm.startBroadcast();
        // Contractly contractly = new Contractly(msg.sender);
        Delivery delivery = new Delivery(0xdC2A123491136132F0AC0Ec9d2e6C96Eb4c2CB9D);
        // new GelatoFunctions(0xA5140205d3C34eC7397E202c581FF5984dd0Bc3D);
        vm.stopBroadcast();
    }
}