// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Contractly
 * @dev Framework for creating self-enforcing digital agreements
 */
contract Contractly {
    // ======== State Variables ========
    address public owner;
    uint256 public agreementCount; // Counter for the number of agreements created (incremented on each createAgreement call)
    mapping(address => bool) public authorizedContracts; // Mapping to track authorized contracts

    enum AgreementStatus {
        Pending,
        Active,
        Fulfilled,
        Breached,
        Disputed,
        Canceled
    }

    struct Agreement {
        uint256 id;
        string title;
        string description;
        address creator;
        address[] parties;
        mapping(address => bool) hasSignedAgreement;
        uint256 creationTime;
        uint256 expirationTime;
        uint256 stakingAmount;
        AgreementStatus status;
        bool requiresAllPartiesToSign;
        bool isStakingRequired;
    }

    // Mapping from agreement ID to Agreement
    mapping(uint256 => Agreement) public agreements;

    // Mapping to track staked funds by agreement and party
    mapping(uint256 => mapping(address => uint256)) public stakedFunds;

    // ======== Events ========
    event AgreementCreated(uint256 agreementId, address creator, string title);
    event AgreementSigned(uint256 agreementId, address party);
    event AgreementActivated(uint256 agreementId);
    event AgreementFulfilled(uint256 agreementId);
    event AgreementBreached(uint256 agreementId, address breachingParty);
    event FundsStaked(uint256 agreementId, address party, uint256 amount);
    event FundsReleased(uint256 agreementId, address party, uint256 amount);

    // ======== Constructor ========
    constructor(address _owner) {
        owner = _owner;
        agreementCount = 0;
    }

    // ======== Modifiers ========
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier agreementExists(uint256 _agreementId) {
        require(agreements[_agreementId].creationTime > 0, "Agreement does not exist");
        _;
    }

    modifier onlyParty(uint256 _agreementId) {
        bool isParty = false;
        for (uint256 i = 0; i < agreements[_agreementId].parties.length; i++) {
            if (agreements[_agreementId].parties[i] == msg.sender) {
                isParty = true;
                break;
            }
        }
        require(isParty, "Only parties to the agreement can call this function");
        _;
    }

    // ======== Core Functions ========

    /**
     * @dev Creates a new agreement
     * @param _title Title of the agreement
     * @param _description Detailed description of the agreement
     * @param _parties Addresses of all parties involved
     * @param _expirationTime Timestamp when the agreement expires
     * @param _requiresAllPartiesToSign Whether all parties must sign before activation
     * @param _isStakingRequired Whether parties must stake funds
     * @param _stakingAmount Amount each party must stake (in wei)
     */
    function createAgreement(string memory _title, string memory _description, address[] memory _parties, uint256 _expirationTime, bool _requiresAllPartiesToSign, bool _isStakingRequired, uint256 _stakingAmount) public returns (uint256) {
        require(_parties.length > 0, "Must include at least one party");
        require(_expirationTime > block.timestamp, "Expiration time must be in the future");

        uint256 agreementId = agreementCount;
        Agreement storage newAgreement = agreements[agreementId];

        newAgreement.id = agreementId;
        newAgreement.title = _title;
        newAgreement.description = _description;
        newAgreement.creator = msg.sender;
        newAgreement.parties = _parties;
        newAgreement.creationTime = block.timestamp;
        newAgreement.expirationTime = _expirationTime;
        newAgreement.status = AgreementStatus.Pending;
        newAgreement.requiresAllPartiesToSign = _requiresAllPartiesToSign;
        newAgreement.isStakingRequired = _isStakingRequired;
        newAgreement.stakingAmount = _stakingAmount;

        agreementCount++;

        emit AgreementCreated(agreementId, msg.sender, _title);

        return agreementId;
    }

    /**
     * @dev Allows a party to sign an agreement
     * @param _agreementId The ID of the agreement to sign
     */
    function signAgreement(uint256 _agreementId) public agreementExists(_agreementId) onlyParty(_agreementId) {
        Agreement storage agreement = agreements[_agreementId];

        require(agreement.status == AgreementStatus.Pending, "Agreement must be in Pending status");
        require(!agreement.hasSignedAgreement[msg.sender], "Party has already signed");

        agreement.hasSignedAgreement[msg.sender] = true;

        emit AgreementSigned(_agreementId, msg.sender);

        // Check if all required parties have signed and if staking conditions are met
        bool allSigned = true;
        if (agreement.requiresAllPartiesToSign) {
            for (uint256 i = 0; i < agreement.parties.length; i++) {
                if (!agreement.hasSignedAgreement[agreement.parties[i]]) {
                    allSigned = false;
                    break;
                }
            }
        }

        // Check if staking conditions are met
        bool stakingMet = !agreement.isStakingRequired;
        if (agreement.isStakingRequired) {
            stakingMet = true;
            for (uint256 i = 0; i < agreement.parties.length; i++) {
                address party = agreement.parties[i];
                if (stakedFunds[_agreementId][party] < agreement.stakingAmount) {
                    stakingMet = false;
                    break;
                }
            }
        }

        // Activate the agreement if conditions are met
        if (allSigned && stakingMet) {
            agreement.status = AgreementStatus.Active;
            emit AgreementActivated(_agreementId);
        }
    }

    /**
     * @dev Allows a party to stake funds for an agreement
     * @param _agreementId The ID of the agreement
     */
    function stakeAgreement(uint256 _agreementId) public payable agreementExists(_agreementId) onlyParty(_agreementId) {
        Agreement storage agreement = agreements[_agreementId];

        require(agreement.status == AgreementStatus.Pending, "Agreement must be in Pending status");
        require(agreement.isStakingRequired, "Agreement does not require staking");
        require(msg.value == agreement.stakingAmount, "Must stake exact required amount");
        require(stakedFunds[_agreementId][msg.sender] == 0, "Already staked for this agreement");

        stakedFunds[_agreementId][msg.sender] = msg.value;

        emit FundsStaked(_agreementId, msg.sender, msg.value);

        // Check if all conditions are met to activate
        bool allSigned = true;
        if (agreement.requiresAllPartiesToSign) {
            for (uint256 i = 0; i < agreement.parties.length; i++) {
                if (!agreement.hasSignedAgreement[agreement.parties[i]]) {
                    allSigned = false;
                    break;
                }
            }
        }

        bool allStaked = true;
        for (uint256 i = 0; i < agreement.parties.length; i++) {
            address party = agreement.parties[i];
            if (stakedFunds[_agreementId][party] < agreement.stakingAmount) {
                allStaked = false;
                break;
            }
        }

        // Activate the agreement if conditions are met
        if (allSigned && allStaked) {
            agreement.status = AgreementStatus.Active;
            emit AgreementActivated(_agreementId);
        }
    }

    function fulfillAgreement(uint256 _agreementId) public agreementExists(_agreementId) {
        Agreement storage agreement = agreements[_agreementId];

        // Only allow calls from authorized contracts or the system
        require(msg.sender == owner || isAuthorizedContract(msg.sender), "Only authorized contracts can mark as fulfilled");
        require(agreement.status == AgreementStatus.Active, "Agreement must be active");

        agreement.status = AgreementStatus.Fulfilled;

        // Return staked funds to all parties
        for (uint256 i = 0; i < agreement.parties.length; i++) {
            address party = agreement.parties[i];
            uint256 amount = stakedFunds[_agreementId][party];
            if (amount > 0) {
                stakedFunds[_agreementId][party] = 0;
                (bool success,) = party.call{ value: amount }("");
                require(success, "Failed to return funds");
                emit FundsReleased(_agreementId, party, amount);
            }
        }

        emit AgreementFulfilled(_agreementId);
    }

    function breachAgreement(uint256 _agreementId, address _breachingParty) public agreementExists(_agreementId) {
        Agreement storage agreement = agreements[_agreementId];

        // Only allow calls from authorized contracts or the system
        require(msg.sender == owner || isAuthorizedContract(msg.sender), "Only authorized contracts can mark as breached");
        require(agreement.status == AgreementStatus.Active, "Agreement must be active");

        agreement.status = AgreementStatus.Breached;

        // Handle breach consequences - distribute the breaching party's funds
        uint256 breachingPartyStake = stakedFunds[_agreementId][_breachingParty];
        if (breachingPartyStake > 0) {
            stakedFunds[_agreementId][_breachingParty] = 0;

            // Identify non-breaching parties
            address[] memory nonBreachingParties = new address[](agreement.parties.length - 1);
            uint256 j = 0;
            for (uint256 i = 0; i < agreement.parties.length; i++) {
                if (agreement.parties[i] != _breachingParty) {
                    nonBreachingParties[j] = agreement.parties[i];
                    j++;
                }
            }

            // Distribute compensation
            uint256 compensationPerParty = breachingPartyStake / nonBreachingParties.length;

            for (uint256 i = 0; i < nonBreachingParties.length; i++) {
                (bool success,) = nonBreachingParties[i].call{ value: compensationPerParty }("");
                require(success, "Failed to distribute funds");
                emit FundsReleased(_agreementId, nonBreachingParties[i], compensationPerParty);
            }
        }

        // Return stakes to non-breaching parties
        for (uint256 i = 0; i < agreement.parties.length; i++) {
            address party = agreement.parties[i];
            if (party != _breachingParty) {
                uint256 amount = stakedFunds[_agreementId][party];
                if (amount > 0) {
                    stakedFunds[_agreementId][party] = 0;
                    (bool success,) = party.call{ value: amount }("");
                    require(success, "Failed to return funds");
                    emit FundsReleased(_agreementId, party, amount);
                }
            }
        }

        emit AgreementBreached(_agreementId, _breachingParty);
    }

    function addAuthorizedContract(address _contractAddress) public onlyOwner {
        authorizedContracts[_contractAddress] = true;
    }

    function removeAuthorizedContract(address _contractAddress) public onlyOwner {
        authorizedContracts[_contractAddress] = false;
    }

    // ======== Utility Functions ========

    /**
     * @dev Checks if an address is a party to an agreement
     * @param _agreementId The ID of the agreement
     * @param _address The address to check
     * @return bool True if the address is a party to the agreement
     */
    function isAgreementParty(uint256 _agreementId, address _address) public view agreementExists(_agreementId) returns (bool) {
        for (uint256 i = 0; i < agreements[_agreementId].parties.length; i++) {
            if (agreements[_agreementId].parties[i] == _address) return true;
        }
        return false;
    }

    /**
     * @dev Gets the status of an agreement
     * @param _agreementId The ID of the agreement
     * @return AgreementStatus The current status of the agreement
     */
    function getAgreementStatus(uint256 _agreementId) public view agreementExists(_agreementId) returns (AgreementStatus) {
        return agreements[_agreementId].status;
    }

    /**
     * @dev Gets the staked amount for a party in an agreement
     * @param _agreementId The ID of the agreement
     * @param _party The address of the party
     * @return uint256 The amount staked by the party
     */
    function getStakedAmount(uint256 _agreementId, address _party) public view agreementExists(_agreementId) returns (uint256) {
        return stakedFunds[_agreementId][_party];
    }

    function isAuthorizedContract(address _contractAddress) public view returns (bool) {
        return authorizedContracts[_contractAddress];
    }
}
