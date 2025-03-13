//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Contractly } from "../contracts/Contractly.sol";
import { IContractly } from "../contracts/Interface/IContractly.sol";
import { Delivery } from "../contracts/Delivery.sol";

contract TestDelivery is Test {
    Contractly contractly;
    Delivery delivery;

    address BOB = makeAddr("BOB");
    address ALICE = makeAddr("ALICE");
    address CAROL = makeAddr("CAROL");
    address VENDOR = makeAddr("VENDOR");

    function setUp() public {
        contractly = new Contractly(address(this));
        delivery = new Delivery(address(contractly));
        contractly.addAuthorizedContract(address(delivery));
    }

    modifier fundAllUsers() {
        vm.deal(ALICE, 10 ether);
        vm.deal(BOB, 10 ether);
        vm.deal(CAROL, 10 ether);
        vm.deal(VENDOR, 1000 ether);
        _;
    }

    function testCreateDelivery() public fundAllUsers {
        vm.prank(VENDOR);
        uint256 deliveryId = delivery.createDelivery{ value: 1 ether }(uint128(block.timestamp + 1 days), 1 ether, ALICE, 123);
        assertEq(deliveryId, 0);
        assertEq(delivery.getHasVendorAssigned(deliveryId), true);
        assertEq(contractly.getPartyCount(deliveryId), 2);

        assertEq(contractly.getPartyAddressAtIndex(deliveryId, 0), VENDOR); // Vendor should be the first party
        assertEq(contractly.getPartyAddressAtIndex(deliveryId, 1), ALICE); // Customer should be the second party

        assertEq(contractly.getPartyRequiresStaking(deliveryId, VENDOR), true); // Vendor should require staking
        assertEq(contractly.getPartyRequiresStaking(deliveryId, ALICE), false); // Customer should not require staking

        assertEq(contractly.getPartyStakeRatio(deliveryId, VENDOR), 100); // Vendor should have a stake ratio of 100
        assertEq(contractly.getPartyStakeRatio(deliveryId, ALICE), 0); // Customer should have a stake ratio of 0

        assertEq(contractly.getPartyHasSigned(deliveryId, VENDOR), true); // Vendor should have signed the delivery
        assertEq(contractly.getPartyHasSigned(deliveryId, ALICE), false); // Customer should not have signed the delivery

        assertEq(contractly.getPartyStakeAmount(deliveryId, VENDOR), 1 ether); // Vendor should have a stake amount of 1 ether
        assertEq(contractly.getPartyStakeAmount(deliveryId, ALICE), 0 ether); // Customer should have a stake amount of 0 ether
    }

    function testBatchCreateDelivery() public fundAllUsers {
        uint128[] memory expirationTimes = new uint128[](2);
        expirationTimes[0] = uint128(block.timestamp + 1 days);
        expirationTimes[1] = uint128(block.timestamp + 2 days);
        address[] memory customerAddresses = new address[](2);
        customerAddresses[0] = ALICE;
        customerAddresses[1] = BOB;
        uint256[] memory totalStakingAmounts = new uint256[](2);
        totalStakingAmounts[0] = 2 ether;
        totalStakingAmounts[1] = 1 ether;

        vm.prank(VENDOR);
        uint256[] memory deliveryIds = delivery.batchCreateDelivery{ value: 3 ether }(expirationTimes, totalStakingAmounts, customerAddresses);
        for (uint256 i = 0; i < deliveryIds.length; i++) {
            assertEq(deliveryIds[i], i); // deliveryIds should be the index of the delivery in sequential order
            assertEq(delivery.getHasVendorAssigned(deliveryIds[i]), true); // vendor should be assigned to the all deliveries
            assertEq(contractly.getPartyCount(deliveryIds[i]), 2); // there should be 2 parties in the delivery

            assertEq(contractly.getPartyAddressAtIndex(deliveryIds[i], 0), VENDOR); // Vendor should be the first party
            assertEq(contractly.getPartyAddressAtIndex(deliveryIds[i], 1), customerAddresses[i]); // Customer should be the second party

            assertEq(contractly.getPartyRequiresStaking(deliveryIds[i], VENDOR), true); // Vendor should require staking
            assertEq(contractly.getPartyRequiresStaking(deliveryIds[i], customerAddresses[i]), false); // Customer should not require staking

            assertEq(contractly.getPartyStakeRatio(deliveryIds[i], VENDOR), 100); // Vendor should have a stake ratio of 1 ether
            assertEq(contractly.getPartyStakeRatio(deliveryIds[i], customerAddresses[i]), 0); // Customer should have a stake ratio of 0 ether

            assertEq(contractly.getPartyHasSigned(deliveryIds[i], VENDOR), true); // Vendor should have signed the delivery
            assertEq(contractly.getPartyHasSigned(deliveryIds[i], customerAddresses[i]), false); // Customer should not have signed the delivery
        }
        assertEq(contractly.getPartyStakeAmount(deliveryIds[0], VENDOR), 2 ether); // Vendor should have a stake amount of 2 ether
        assertEq(contractly.getPartyStakeAmount(deliveryIds[0], ALICE), 0 ether); // ALICE should have a stake amount of 0 ether
        assertEq(contractly.getPartyStakeAmount(deliveryIds[1], VENDOR), 1 ether); // Vendor should have a stake amount of 1 ether
        assertEq(contractly.getPartyStakeAmount(deliveryIds[1], BOB), 0 ether); // BOB should have a stake amount of 0 ether
    }

    modifier createBatchDelivery() {
        string[] memory titles = new string[](2);
        titles[0] = "Test Delivery 1";
        titles[1] = "Test Delivery 2";
        uint128[] memory expirationTimes = new uint128[](2);
        expirationTimes[0] = uint128(block.timestamp + 1 days);
        expirationTimes[1] = uint128(block.timestamp + 2 days);
        address[] memory customerAddresses = new address[](2);
        customerAddresses[0] = ALICE;
        customerAddresses[1] = BOB;
        uint256[] memory totalStakingAmounts = new uint256[](2);
        totalStakingAmounts[0] = 2 ether;
        totalStakingAmounts[1] = 1 ether;

        vm.prank(VENDOR);
        uint256[] memory deliveryIds = delivery.batchCreateDelivery{ value: 3 ether }(expirationTimes, totalStakingAmounts, customerAddresses);
        _;
    }

    function testFulfillDelivery() public fundAllUsers createBatchDelivery {
        vm.prank(ALICE);
        vm.warp(block.timestamp + 3 days);
        delivery.fulfillAgreement(0);
        assertEq(uint256(contractly.getAgreementStatus(0)), uint256(IContractly.AgreementStatus.Fulfilled));
    }

    function testBreachDelivery() public fundAllUsers createBatchDelivery {
        vm.prank(ALICE);
        vm.warp(block.timestamp + 3 days);
        delivery.breachAgreement(0, VENDOR);
        delivery.breachAgreement(1, VENDOR);
        assertEq(uint256(contractly.getAgreementStatus(0)), uint256(IContractly.AgreementStatus.Breached));
        assertEq(ALICE.balance, 12 ether);
        assertEq(BOB.balance, 11 ether);
        assertEq(VENDOR.balance, 1000 ether - 3 ether);
    }

    function testGetAgreement() public fundAllUsers createBatchDelivery(){
        (,,,,,,, address[] memory parties) = delivery.getAgreementDetails(0);
    }
}
