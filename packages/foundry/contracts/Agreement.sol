// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Contractly.sol";

/**
 * @title Agreement
 * @dev Contract for managing individual agreements
 * @notice 2 party staking agreement with 50-50 stake ratio
 */
contract Agreement {
    // ======== State Variables ========
    Contractly public contractly;
    uint256 private constant STAKE_RATIO = 50;
    bool private constant REQUIRES_ALL_PARTIES_TO_SIGN = true;
    bool private constant IS_STAKING_REQUIRED = true;

    // ======== Events ========
    event AgreementCreated(uint256 indexed agreementId, string title, address creator);

    // ======== Constructor ========
    constructor(address _contractlyAddress) {
        contractly = Contractly(_contractlyAddress);
    }

    // ======== Core Functions ========
    function createAgreement(string memory _title, uint256 _expirationTime, uint256 _totalStakingAmount) public returns (uint256) {
        // Create the agreement in Contractly
        uint256 agreementId = contractly.createAgreement(_title, msg.sender, _expirationTime, _totalStakingAmount, IS_STAKING_REQUIRED, REQUIRES_ALL_PARTIES_TO_SIGN);

        emit AgreementCreated(agreementId, _title, msg.sender);

        return agreementId;
    }

    function signAgreementWithStakeDetails(uint256 _agreementId) public {
        // Check if party exists by trying to get their details
        try contractly.getParty(_agreementId, msg.sender) returns (bool, uint256, bool) {
            // Party exists, proceed with signing
            contractly.signAgreement(_agreementId, msg.sender);
        } catch {
            // Party doesn't exist, add them first then sign
            addParty(_agreementId, msg.sender, IS_STAKING_REQUIRED);
            contractly.signAgreement(_agreementId, msg.sender);
        }
    }

    function addParty(uint256 _agreementId, address _partyAddress, bool _requiresStaking) internal {
        contractly.addParty(_agreementId, _partyAddress, _requiresStaking, STAKE_RATIO);
    }

    function stakeAgreement(uint256 _agreementId) public payable {
        contractly.stakeAgreement{value: msg.value}(_agreementId, msg.sender);
        
        // Check if all parties have staked to automatically lock the agreement
        (,,,,,,,,,, address[] memory parties) = getAgreementDetails(_agreementId);
        bool allPartiesStaked = true;
        
        for (uint i = 0; i < parties.length; i++) {
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
        contractly.breachAgreement(_agreementId, _breachingParty);
    }


    // ======== Getters ========

    function getAgreementDetails(uint256 _agreementId) public view returns (uint256 id, string memory title, address creator, uint256 creationTime, uint256 expirationTime, uint256 disputeWindowDuration, uint256 totalStakingAmount, Contractly.AgreementStatus status, bool requiresAllPartiesToSign, bool isStakingRequired, address[] memory partyAddresses) {
        return contractly.getAgreement(_agreementId);
    }
}
