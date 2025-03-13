// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Contractly.sol";

contract Delivery {
    // ======== Errors ========
    error Delivery__VendorAlreadyAssigned();
    error Delivery__VendorNotSigned();
    error Delivery__InsufficientStakeAmount();

    // ======== State Variables ========
    Contractly public immutable contractly;
    uint256 private lastAutomationUpdate;
    mapping(uint256 => bool) private hasVendorAssigned;
    address private immutable owner;
    mapping(uint256 => uint256) private awbToAgreementId;

    // ======== Events ========
    event AgreementCreated(uint256 indexed agreementId, address creator);
    event DeliveryCreated(uint256 indexed agreementId, address vendor, address customer);
    event BatchDeliveryCreated(uint128[] expirationTimes, uint256[] totalStakingAmounts, address[] customerAddresses);

    // ======== Constructor ========
    constructor(address _contractlyAddress) {
        contractly = Contractly(_contractlyAddress);
        lastAutomationUpdate = 0;
        owner = msg.sender;
    }

    // ======== Core Functions ========

    /**
     * @dev Creates a new delivery (vendor -> customer) agreement
     * @param _expirationTime The timestamp when the agreement expires
     * @param _totalStakingAmount The total amount that needs to be staked across all parties
     * @param _customerAddress The address of the customer
     */
    function createDelivery(uint128 _expirationTime, uint256 _totalStakingAmount, address _customerAddress, uint256 _awbNumber) public payable returns (uint256) {
        address sender = msg.sender;
        uint256 agreementId = contractly.createAgreement(sender, _expirationTime, _totalStakingAmount);
        
        if (hasVendorAssigned[agreementId]) {
            revert Delivery__VendorAlreadyAssigned();
        }
        
        contractly.addParty(agreementId, sender, true, true, 100);
        hasVendorAssigned[agreementId] = true;
        
        contractly.addParty(agreementId, _customerAddress, false, false, 0);
        
        contractly.signAgreement(agreementId, sender);
        contractly.stakeAgreement{ value: msg.value }(agreementId, sender);
        contractly.lockAgreement(agreementId);

        awbToAgreementId[_awbNumber] = agreementId;
        
        emit DeliveryCreated(agreementId, sender, _customerAddress);
        return agreementId;
    }

    /**
     * @dev Creates multiple delivery (vendor -> customer)[] agreements.
     * @param _expirationTimes The timestamps when the agreements expire
     * @param _totalStakingAmounts The total amounts that need to be staked across all parties
     * @param _customerAddresses The addresses of the customers
     */
    function batchCreateDelivery(uint128[] calldata _expirationTimes, uint256[] calldata _totalStakingAmounts, address[] calldata _customerAddresses) public payable returns (uint256[] memory) {
        uint256 length = _customerAddresses.length;
        address sender = msg.sender;
        uint256[] memory agreementIds = new uint256[](length);
        
        uint256 totalRequiredStake = 0;
        for (uint256 i = 0; i < length;) {
            totalRequiredStake += _totalStakingAmounts[i];
            unchecked { ++i; }
        }
        if (msg.value < totalRequiredStake) revert Delivery__InsufficientStakeAmount();

        for (uint256 i = 0; i < length;) {
            uint256 agreementId = contractly.createAgreement(sender, _expirationTimes[i], _totalStakingAmounts[i]);
            
            contractly.addParty(agreementId, sender, true, true, 100);
            hasVendorAssigned[agreementId] = true;
            
            contractly.addParty(agreementId, _customerAddresses[i], false, false, 0);
            
            contractly.signAgreement(agreementId, sender);
            contractly.stakeAgreement{ value: _totalStakingAmounts[i] }(agreementId, sender);
            contractly.lockAgreement(agreementId);
            
            agreementIds[i] = agreementId;
            unchecked { ++i; }
        }
        
        emit BatchDeliveryCreated(_expirationTimes, _totalStakingAmounts, _customerAddresses);
        return agreementIds;
    }

    function stakeAgreement(uint256 _agreementId, uint256 _amount) public payable {
        if (!contractly.getPartyHasSigned(_agreementId, msg.sender)) {
            revert Delivery__VendorNotSigned();
        }
        
        // Get parties before making external call to stake
        (,,,,,,, address[] memory parties) = getAgreementDetails(_agreementId);
        
        contractly.stakeAgreement{ value: _amount }(_agreementId, msg.sender);
        
        // Check if all parties have staked to automatically lock the agreement
        bool allPartiesStaked = true;
        for (uint256 i = 0; i < parties.length;) {
            if (contractly.getPartyStakeAmount(_agreementId, parties[i]) == 0 && 
                contractly.getPartyRequiresStaking(_agreementId, parties[i])) {
                allPartiesStaked = false;
                break;
            }
            unchecked { ++i; }
        }
        
        if (allPartiesStaked) {
            contractly.lockAgreement(_agreementId);
        }
    }

    function fulfillAgreement(uint256 _agreementId) public {
        contractly.fulfillAgreement(_agreementId);
    }

    function breachAgreement(uint256 _agreementId, address _breachingParty) public {
        contractly.breachAgreement(_agreementId, _breachingParty);
    }

    function checkDeliveryStatus(uint256 _agreementId) public {
        (,,,uint256 expirationTime,,,Contractly.AgreementStatus status,) = getAgreementDetails(_agreementId);
        
        if(block.timestamp >= expirationTime && status == Contractly.AgreementStatus.Locked) {
            fulfillAgreement(_agreementId);
        }
        
        lastAutomationUpdate = block.timestamp;
    }

    // ======== Getters ========

    function getAgreementDetails(uint256 _agreementId) public view returns (uint256 id, address creator, uint256 creationTime, uint256 expirationTime, uint256 disputeWindowDuration, uint256 totalStakingAmount, Contractly.AgreementStatus status, address[] memory partyAddresses) {
        return contractly.getAgreement(_agreementId);
    }

    function getHasVendorAssigned(uint256 _agreementId) public view returns (bool) {
        return hasVendorAssigned[_agreementId];
    }

    function getLastAutomationUpdate() public view returns (uint256) {
        return lastAutomationUpdate;
    }

    function getAwbToAgreementId(uint256 _awbNumber) public view returns (uint256){
        return awbToAgreementId[_awbNumber];
    }
}