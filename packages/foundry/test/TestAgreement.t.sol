//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Contractly} from "../contracts/Contractly.sol";
import {Agreement} from "../contracts/Agreement.sol";

contract TestAgreement is Test {
    Contractly contractly;
    Agreement agreement;

    address public ALICE = makeAddr("alice");
    address public BOB = makeAddr("bob");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() public {
        contractly = new Contractly(address(this));
        agreement = new Agreement(address(contractly));
        contractly.addAuthorizedContract(address(agreement));
        vm.deal(ALICE, STARTING_USER_BALANCE);
        vm.deal(BOB, STARTING_USER_BALANCE);
    }

    function testFulfillAgreement() public {
        // Create agreement
        uint256 agreementId = agreement.createAgreement("Test Agreement", block.timestamp + 1 days, 1 ether);
        assertEq(agreementId, 0);  // This is the agreement id 0
        contractly.getAgreementStatus(agreementId);

        // Sign agreement
        vm.prank(ALICE);
        agreement.signAgreementWithStakeDetails(agreementId);
        vm.prank(BOB);
        agreement.signAgreementWithStakeDetails(agreementId);
        (bool requiresStaking, uint256 stakeRatio, bool hasSigned) = contractly.getParty(agreementId, ALICE);
        assertEq(hasSigned, true);
        assertEq(requiresStaking, true);
        assertEq(stakeRatio, 50);
        (bool requiresStaking2, uint256 stakeRatio2, bool hasSigned2) = contractly.getParty(agreementId, BOB);
        assertEq(hasSigned2, true);
        assertEq(requiresStaking2, true);
        assertEq(stakeRatio2, 50);
        contractly.getAgreementStatus(agreementId);

        // Stake agreement
        vm.prank(ALICE);
        agreement.stakeAgreement{value: 0.5 ether}(agreementId);
        assertEq(contractly.getStakedAmount(agreementId, ALICE), 500000000000000000);
        assertEq(ALICE.balance, STARTING_USER_BALANCE - 0.5 ether);
        contractly.getAgreementStatus(agreementId);
        vm.prank(BOB);
        agreement.stakeAgreement{value: 0.5 ether}(agreementId);
        assertEq(contractly.getStakedAmount(agreementId, BOB), 500000000000000000);
        assertEq(BOB.balance, STARTING_USER_BALANCE - 0.5 ether);
        contractly.getAgreementStatus(agreementId);

        //Address of party at index 0
        address party0 = contractly.getPartyAddressAtIndex(agreementId, 0);
        assertEq(party0, ALICE);
        address party1 = contractly.getPartyAddressAtIndex(agreementId, 1);
        assertEq(party1, BOB);

        //get party count
        uint256 partyCount = contractly.getPartyCount(agreementId);
        assertEq(partyCount, 2);

        //Fulfill agreement
        vm.expectRevert();
        agreement.fulfillAgreement(agreementId);
        contractly.getAgreementStatus(agreementId);


        // Increase block timestamp by 2 days
        vm.warp(block.timestamp + 2 days);
        agreement.fulfillAgreement(agreementId);
        assertEq(ALICE.balance, STARTING_USER_BALANCE);
        assertEq(BOB.balance, STARTING_USER_BALANCE);
    }

    function testBreachAgreement() public {
      // Create agreement
        uint256 agreementId = agreement.createAgreement("Test Agreement", block.timestamp + 1 days, 1 ether);
        assertEq(agreementId, 0);  // This is the agreement id 0
        contractly.getAgreementStatus(agreementId);

        // Sign agreement
        vm.prank(ALICE);
        agreement.signAgreementWithStakeDetails(agreementId);
        vm.prank(BOB);
        agreement.signAgreementWithStakeDetails(agreementId);
        (bool requiresStaking, uint256 stakeRatio, bool hasSigned) = contractly.getParty(agreementId, ALICE);
        assertEq(hasSigned, true);
        assertEq(requiresStaking, true);
        assertEq(stakeRatio, 50);
        (bool requiresStaking2, uint256 stakeRatio2, bool hasSigned2) = contractly.getParty(agreementId, BOB);
        assertEq(hasSigned2, true);
        assertEq(requiresStaking2, true);
        assertEq(stakeRatio2, 50);
        contractly.getAgreementStatus(agreementId);

        // Stake agreement
        vm.prank(ALICE);
        agreement.stakeAgreement{value: 0.5 ether}(agreementId);
        assertEq(contractly.getStakedAmount(agreementId, ALICE), 500000000000000000);
        assertEq(ALICE.balance, STARTING_USER_BALANCE - 0.5 ether);
        contractly.getAgreementStatus(agreementId);
        vm.prank(BOB);
        agreement.stakeAgreement{value: 0.5 ether}(agreementId);
        assertEq(contractly.getStakedAmount(agreementId, BOB), 500000000000000000);
        assertEq(BOB.balance, STARTING_USER_BALANCE - 0.5 ether);
        contractly.getAgreementStatus(agreementId);

        //Address of party at index 0
        address party0 = contractly.getPartyAddressAtIndex(agreementId, 0);
        assertEq(party0, ALICE);
        address party1 = contractly.getPartyAddressAtIndex(agreementId, 1);
        assertEq(party1, BOB);

        //get party count
        uint256 partyCount = contractly.getPartyCount(agreementId);
        assertEq(partyCount, 2);

        //Breach agreement
        vm.expectRevert();
        agreement.breachAgreement(agreementId, ALICE);
        contractly.getAgreementStatus(agreementId);

        //Increase block timestamp by 2 days
        vm.warp(block.timestamp + 2 days);
        agreement.breachAgreement(agreementId, ALICE);
        assertEq(ALICE.balance, STARTING_USER_BALANCE - 0.5 ether);
        assertEq(BOB.balance, STARTING_USER_BALANCE + 0.5 ether);
 
    }
}