//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import { DeployContractly } from "./DeployContractly.s.sol";
import { DeployDelivery } from "./DeployDelivery.s.sol";
/**
 * @notice Main deployment script for all contracts
 * @dev Run this when you want to deploy multiple contracts at once
 *
 * Example: yarn deploy # runs this script(without`--file` flag)
 */

contract DeployScript is ScaffoldETHDeploy {
    function run() external {
        // Deploys all your contracts sequentially
        // DeployMyContract myContract = new DeployMyContract();
        // myContract.run();
        DeployContractly deployContractly = new DeployContractly();
        address contractlyAddress = address(deployContractly.run());
        DeployDelivery deployDelivery = new DeployDelivery();
        deployDelivery.run(contractlyAddress);
    }
}
