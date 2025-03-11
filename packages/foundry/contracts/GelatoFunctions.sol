// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDelivery} from "./Interface/IDelivery.sol";

contract GelatoFunctions {
    // State variable to store the last update timestamp
    IDelivery private delivery;

    constructor(address _deliveryAddress) {
        delivery = IDelivery(_deliveryAddress);
    }
    // Event to emit when an update occurs
    event Updated(uint256 timestamp);

    function checker() external view returns (bool, bytes memory) {
        uint256 lastUpdate = delivery.getLastAutomationUpdate();
        if (block.timestamp < lastUpdate + 5 minutes) {
          return (false, bytes("Not enough time has passed since the last update"));
        }
        bytes memory execPayload = abi.encodeCall(IDelivery.checkDeliveryStatus, (1));
        return (true, execPayload);
    }
}