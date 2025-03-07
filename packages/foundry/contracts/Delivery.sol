// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Contractly.sol";
import "forge-std/console.sol";

contract Delivery {
    // ======== Errors ========
    error Delivery__VendorAlreadyAssigned();
    error Delivery__VendorNotSigned();

    // ======== State Variables ========
    Contractly public contractly;
    mapping(uint256 agreementId => bool hasVendorAssigned) private hasVendorAssigned;

    // ======== Events ========
    event AgreementCreated(uint256 indexed agreementId, string title, address creator);
    event DeliveryCreated(uint256 indexed agreementId, string title, address vendor, address customer);
    event BatchDeliveryCreated(string[] titles, uint256[] expirationTimes, uint256[] totalStakingAmounts, address[] customerAddresses);

    // ======== Constructor ========
    constructor(address _contractlyAddress) {
        contractly = Contractly(_contractlyAddress);
    }

    // ======== Core Functions ========

    /**
     * @dev Creates a new delivery (vendor -> customer) agreement
     * @param _title The title of the agreement
     * @param _expirationTime The timestamp when the agreement expires
     * @param _totalStakingAmount The total amount that needs to be staked across all parties
     * @param _customerAddress The address of the customer
     */
    function createDelivery(string memory _title, uint256 _expirationTime, uint256 _totalStakingAmount, address _customerAddress) public payable returns (uint256) {
        uint256 agreementId = _createAgreement(_title, _expirationTime, _totalStakingAmount);
        _addVendorParty(agreementId, msg.sender);
        _addCustomerParty(agreementId, _customerAddress);
        _signAgreement(agreementId);
        stakeAgreement(agreementId, _totalStakingAmount);
        contractly.lockAgreement(agreementId);
        emit DeliveryCreated(agreementId, _title, msg.sender, _customerAddress);
        return agreementId;
    }

    /**
     * @dev Creates multiple delivery (vendor -> customer)[] agreements.
     * @param _titles The titles of the agreements
     * @param _expirationTimes The timestamps when the agreements expire
     * @param _totalStakingAmounts The total amounts that need to be staked across all parties
     * @param _customerAddresses The addresses of the customers
     */
    function batchCreateDelivery(string[] memory _titles, uint256[] memory _expirationTimes, uint256[] memory _totalStakingAmounts, address[] memory _customerAddresses) public payable returns (uint256[] memory) {
        uint256[] memory agreementIds = new uint256[](_customerAddresses.length);
        for (uint256 i = 0; i < _customerAddresses.length; i++) {
            uint256 agreementId = _createAgreement(_titles[i], _expirationTimes[i], _totalStakingAmounts[i]);
            _addVendorParty(agreementId, msg.sender);
            _addCustomerParty(agreementId, _customerAddresses[i]);
            _signAgreement(agreementId);
            stakeAgreement(agreementId, _totalStakingAmounts[i]);
            contractly.lockAgreement(agreementId);
            agreementIds[i] = agreementId;
        }
        emit BatchDeliveryCreated(_titles, _expirationTimes, _totalStakingAmounts, _customerAddresses);
        return agreementIds;
    }

    function stakeAgreement(uint256 _agreementId, uint256 _amount) public payable {
        if (!contractly.getPartyHasSigned(_agreementId, msg.sender)) {
            revert Delivery__VendorNotSigned();
        }
        contractly.stakeAgreement{ value: _amount }(_agreementId, msg.sender);
        // Check if all parties have staked to automatically lock the agreement
        (,,,,,,,, address[] memory parties) = getAgreementDetails(_agreementId);
        bool allPartiesStaked = true;
        for (uint256 i = 0; i < parties.length; i++) {
            if (contractly.stakedFunds(_agreementId, parties[i]) == 0) {
                allPartiesStaked = false;
                break;
            }
        }
        if (allPartiesStaked) {
            contractly.lockAgreement(_agreementId);
        }
    }

    function fulfillAgreement(uint256 _agreementId) public {
        contractly.fulfillAgreement(_agreementId);
    }

    function breachAgreement(uint256 _agreementId, address _breachingParty) public {
        console.log("breaching party", _breachingParty);
        console.log("agreement id", _agreementId);
        console.log("status", uint256(contractly.getAgreementStatus(_agreementId)));
        console.log("party count", contractly.getPartyCount(_agreementId));
        console.log("party address at index 0", contractly.getPartyAddressAtIndex(_agreementId, 0));
        console.log("party address at index 1", contractly.getPartyAddressAtIndex(_agreementId, 1));
        console.log("party stake amount at index 0", contractly.getPartyStakeAmount(_agreementId, contractly.getPartyAddressAtIndex(_agreementId, 0)));
        console.log("party stake amount at index 1", contractly.getPartyStakeAmount(_agreementId, contractly.getPartyAddressAtIndex(_agreementId, 1)));
        contractly.breachAgreement(_agreementId, _breachingParty);

        console.log("After breach");
        console.log("breaching party", _breachingParty);
        console.log("agreement id", _agreementId);
        console.log("status", uint256(contractly.getAgreementStatus(_agreementId)));
        console.log("party count", contractly.getPartyCount(_agreementId));
        console.log("party address at index 0", contractly.getPartyAddressAtIndex(_agreementId, 0));
        console.log("party address at index 1", contractly.getPartyAddressAtIndex(_agreementId, 1));
        console.log("party stake amount at index 0", contractly.getPartyStakeAmount(_agreementId, contractly.getPartyAddressAtIndex(_agreementId, 0)));
        console.log("party stake amount at index 1", contractly.getPartyStakeAmount(_agreementId, contractly.getPartyAddressAtIndex(_agreementId, 1)));
    }

    // ======== Internal Functions ========

    function _createAgreement(string memory _title, uint256 _expirationTime, uint256 _totalStakingAmount) internal returns (uint256) {
        // Create the agreement in Contractly
        uint256 agreementId = contractly.createAgreement(_title, msg.sender, _expirationTime, _totalStakingAmount);

        emit AgreementCreated(agreementId, _title, msg.sender);

        return agreementId;
    }

    function _addVendorParty(uint256 _agreementId, address _partyAddress) internal {
        if (hasVendorAssigned[_agreementId]) {
            revert Delivery__VendorAlreadyAssigned();
        }
        contractly.addParty(_agreementId, _partyAddress, true, true, 100);
        hasVendorAssigned[_agreementId] = true;
    }

    function _addCustomerParty(uint256 _agreementId, address _partyAddress) internal {
        contractly.addParty(_agreementId, _partyAddress, false, false, 0);
    }

    function _signAgreement(uint256 _agreementId) internal {
        contractly.signAgreement(_agreementId, msg.sender);
    }

    // ======== Getters ========

    function getAgreementDetails(uint256 _agreementId) public view returns (uint256 id, string memory title, address creator, uint256 creationTime, uint256 expirationTime, uint256 disputeWindowDuration, uint256 totalStakingAmount, Contractly.AgreementStatus status, address[] memory partyAddresses) {
        return contractly.getAgreement(_agreementId);
    }

    function getHasVendorAssigned(uint256 _agreementId) public view returns (bool) {
        return hasVendorAssigned[_agreementId];
    }
}
