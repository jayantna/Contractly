// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Contractly
 * @dev Framework for creating self-enforcing digital agreements
 */
contract Contractly {
    // ======== Custom Errors ========
    error OnlyOwner();
    error AgreementNotFound();
    error NotAgreementParty();
    error UnauthorizedContract();
    error NotPendingStatus();
    error FutureExpirationRequired();
    error AlreadySigned();
    error StakingNotRequired();
    error InvalidStakingAmount();
    error AlreadyStaked();
    error ConditionsNotMet();
    error NotLockedStatus();
    error NotActiveStatus();
    error FundsTransferFailed();
    error StakeRatioTooHigh();
    error TotalStakeRatioExceeds100();
    error PartyNotFound();
    error AgreementMustBeActive();
    error FundsDistributionFailed();
    error FundsReturnFailed();

    // ======== State Variables ========
    address public owner;
    uint256 public agreementCount; // Counter for the number of agreements created (incremented on each createAgreement call)
    mapping(address => bool) public authorizedContracts; // Mapping to track authorized contracts

    enum AgreementStatus {
        Pending,
        Locked,
        Active,
        Fulfilled,
        Breached,
        DisputeWindow,
        Disputed,
        Canceled
    }

    struct Party {
        bool requiresStaking;
        uint256 stakeRatio; // Percentage of total stake amount (1-100)
        bool hasSigned;     // Whether the party has signed the agreement
    }

    struct Agreement {
        uint256 id;
        string title;
        address creator;
        mapping(address => Party) parties;
        uint256 creationTime;
        uint256 expirationTime;
        uint256 disputeWindowDuration;
        uint256 totalStakingAmount;
        AgreementStatus status;
        bool requiresAllPartiesToSign;
        bool isStakingRequired;
        address[] partyAddresses;
    }

    // Mapping from agreement ID to Agreement
    mapping(uint256 => Agreement) public agreements;

    // Mapping to track staked funds by agreement and party
    mapping(uint256 => mapping(address => uint256)) public stakedFunds;

    // ======== Events ========
    event AgreementCreated(uint256 agreementId, address creator, string title);
    event AgreementSigned(uint256 agreementId, address party);
    event AgreementLocked(uint256 agreementId);
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
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier agreementExists(uint256 _agreementId) {
        if (agreements[_agreementId].creationTime == 0) revert AgreementNotFound();
        _;
    }

    modifier onlyParty(uint256 _agreementId) {
        if (agreements[_agreementId].parties[msg.sender].stakeRatio == 0) revert NotAgreementParty();
        _;
    }

    modifier onlyAuthorizedContract() {
        if (!authorizedContracts[msg.sender]) revert UnauthorizedContract();
        _;
    }

    modifier onlyPendingStatus(uint256 _agreementId) {
        if (agreements[_agreementId].status != AgreementStatus.Pending) revert NotPendingStatus();
        _;
    }

    // ======== Core Functions ========

    /**
     * @dev Creates a new agreement
     * @param _title Title of the agreement
     * @param _creator Creator of the agreement
     * @param _expirationTime Timestamp when the agreement expires
     * @param _totalStakingAmount Total amount that needs to be staked across all parties
     */
    function createAgreement(string memory _title, address _creator, uint256 _expirationTime, uint256 _totalStakingAmount) external returns (uint256) {
        if (_expirationTime <= block.timestamp) revert FutureExpirationRequired();

        uint256 agreementId = agreementCount;
        Agreement storage newAgreement = agreements[agreementId];

        newAgreement.id = agreementId;
        newAgreement.title = _title;
        newAgreement.creator = _creator;
        newAgreement.creationTime = block.timestamp;
        newAgreement.expirationTime = _expirationTime;
        newAgreement.status = AgreementStatus.Pending;
        newAgreement.totalStakingAmount = _totalStakingAmount;

        agreementCount++;

        emit AgreementCreated(agreementId, msg.sender, _title);

        return agreementId;
    }

    /**
     * @dev Adds a party to an agreement
     * @param _agreementId The ID of the agreement
     * @param _partyAddress Address of the party
     * @param _requiresStaking Whether this party needs to stake funds
     * @param _stakeRatio Percentage of total stake this party needs to provide (1-100)
     */
    function addParty(uint256 _agreementId, address _partyAddress, bool _requiresStaking, uint256 _stakeRatio) external 
        agreementExists(_agreementId) 
        onlyPendingStatus(_agreementId) 
    {
        Agreement storage agreement = agreements[_agreementId];
        if (_stakeRatio > 100) revert StakeRatioTooHigh();

        // Calculate total stake ratio including new party
        uint256 totalRatio = _stakeRatio;
        for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
            totalRatio += agreement.parties[agreement.partyAddresses[i]].stakeRatio;
        }
        if (totalRatio > 100) revert TotalStakeRatioExceeds100();

        agreement.parties[_partyAddress] = Party({
            requiresStaking: _requiresStaking,
            stakeRatio: _stakeRatio,
            hasSigned: false
        });
        agreement.partyAddresses.push(_partyAddress);
    }

    /**
     * @dev Allows a party to sign an agreement
     * @param _agreementId The ID of the agreement to sign
     */
    function signAgreement(uint256 _agreementId) public 
        agreementExists(_agreementId) 
        onlyPendingStatus(_agreementId) 
    {
        Agreement storage agreement = agreements[_agreementId];
        Party storage party = agreement.parties[msg.sender];
        if (party.stakeRatio == 0) revert NotAgreementParty();
        if (party.hasSigned) revert AlreadySigned();

        party.hasSigned = true;

        emit AgreementSigned(_agreementId, msg.sender);

        lockAgreement(_agreementId);
    }

    /**
     * @dev Allows a party to stake funds for an agreement
     * @param _agreementId The ID of the agreement
     */
    function stakeAgreement(uint256 _agreementId) public payable agreementExists(_agreementId) onlyParty(_agreementId) onlyPendingStatus(_agreementId) {
        Agreement storage agreement = agreements[_agreementId];
        if (!agreement.isStakingRequired) revert StakingNotRequired();

        Party storage party = agreement.parties[msg.sender];
        if (!party.requiresStaking) revert StakingNotRequired();

        uint256 requiredStake = (agreement.totalStakingAmount * party.stakeRatio) / 100;
        if (msg.value != requiredStake) revert InvalidStakingAmount();
        if (stakedFunds[_agreementId][msg.sender] != 0) revert AlreadyStaked();

        stakedFunds[_agreementId][msg.sender] = msg.value;

        emit FundsStaked(_agreementId, msg.sender, msg.value);

        lockAgreement(_agreementId);
    }

    /**
     * @dev Internal function to check if all conditions for locking are met
     * @param _agreementId The ID of the agreement to check
     * @return bool True if all conditions are met, false otherwise
     */
    function _checkAllConditionsMet(uint256 _agreementId) internal view returns (bool) {
        Agreement storage agreement = agreements[_agreementId];

        // Check if all required parties have signed
        if (agreement.requiresAllPartiesToSign) {
            for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
                if (!agreement.parties[agreement.partyAddresses[i]].hasSigned) {
                    return false;
                }
            }
        }

        // Check if all required staking is completed
        if (agreement.isStakingRequired) {
            for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
                address partyAddress = agreement.partyAddresses[i];
                Party storage party = agreement.parties[partyAddress];
                if (party.requiresStaking) {
                    uint256 requiredStake = (agreement.totalStakingAmount * party.stakeRatio) / 100;
                    if (stakedFunds[_agreementId][partyAddress] < requiredStake) {
                        return false;
                    }
                }
            }
        }

        return true;
    }

    /**
     * @dev Locks an agreement when all required conditions are met
     * @param _agreementId The ID of the agreement to lock
     */
    function lockAgreement(uint256 _agreementId) internal agreementExists(_agreementId) onlyPendingStatus(_agreementId) {
        if (!_checkAllConditionsMet(_agreementId)) revert ConditionsNotMet();

        // Set status to Locked
        agreements[_agreementId].status = AgreementStatus.Locked;

        emit AgreementLocked(_agreementId);
    }

    /**
     * @dev Activates a locked agreement - can only be called by authorized contracts
     * @param _agreementId The ID of the agreement to activate
     */
    function activateAgreement(uint256 _agreementId) external agreementExists(_agreementId) onlyAuthorizedContract {
        Agreement storage agreement = agreements[_agreementId];

        if (agreement.status != AgreementStatus.Locked) revert NotLockedStatus();

        // Set status to Active
        agreement.status = AgreementStatus.Active;

        emit AgreementActivated(_agreementId);
    }

    function fulfillAgreement(uint256 _agreementId) external agreementExists(_agreementId) onlyAuthorizedContract {
        Agreement storage agreement = agreements[_agreementId];
        if (agreement.status != AgreementStatus.Active) revert NotActiveStatus();

        agreement.status = AgreementStatus.Fulfilled;

        // Return staked funds to all parties
        for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
            address party = agreement.partyAddresses[i];
            uint256 amount = stakedFunds[_agreementId][party];
            if (amount > 0) {
                stakedFunds[_agreementId][party] = 0;
                (bool success,) = party.call{ value: amount }("");
                if (!success) revert FundsTransferFailed();
                emit FundsReleased(_agreementId, party, amount);
            }
        }

        emit AgreementFulfilled(_agreementId);
    }

    function breachAgreement(uint256 _agreementId, address _breachingParty) public agreementExists(_agreementId) onlyAuthorizedContract {
        Agreement storage agreement = agreements[_agreementId];
        if (agreement.status != AgreementStatus.Active) revert AgreementMustBeActive();

        agreement.status = AgreementStatus.Breached;

        // Handle breach consequences - distribute the breaching party's funds
        uint256 breachingPartyStake = stakedFunds[_agreementId][_breachingParty];
        if (breachingPartyStake > 0) {
            stakedFunds[_agreementId][_breachingParty] = 0;

            // Count non-breaching parties
            uint256 nonBreachingPartyCount = 0;
            for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
                if (agreement.partyAddresses[i] != _breachingParty) {
                    nonBreachingPartyCount++;
                }
            }

            // Distribute compensation
            uint256 compensationPerParty = breachingPartyStake / nonBreachingPartyCount;

            for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
                address party = agreement.partyAddresses[i];
                if (party != _breachingParty) {
                    (bool success,) = party.call{ value: compensationPerParty }("");
                    if (!success) revert FundsDistributionFailed();
                    emit FundsReleased(_agreementId, party, compensationPerParty);
                }
            }
        }

        // Return stakes to non-breaching parties
        for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
            address party = agreement.partyAddresses[i];
            if (party != _breachingParty) {
                uint256 amount = stakedFunds[_agreementId][party];
                if (amount > 0) {
                    stakedFunds[_agreementId][party] = 0;
                    (bool success,) = party.call{ value: amount }("");
                    if (!success) revert FundsReturnFailed();
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

    // ======== Getter Functions ========

    function isAgreementParty(uint256 _agreementId, address _address) public view agreementExists(_agreementId) returns (bool) {
        return agreements[_agreementId].parties[_address].stakeRatio != 0;
    }

    function getAgreementStatus(uint256 _agreementId) public view agreementExists(_agreementId) returns (AgreementStatus) {
        return agreements[_agreementId].status;
    }

    function getStakedAmount(uint256 _agreementId, address _party) public view agreementExists(_agreementId) returns (uint256) {
        return stakedFunds[_agreementId][_party];
    }

    function isAuthorizedContract(address _contractAddress) public view returns (bool) {
        return authorizedContracts[_contractAddress];
    }

    /**
     * @dev Checks if all conditions are met for an agreement to be locked
     * @param _agreementId The ID of the agreement to check
     * @return bool True if all conditions are met, false otherwise
     */
    function areAllConditionsMet(uint256 _agreementId) public view agreementExists(_agreementId) returns (bool) {
        return _checkAllConditionsMet(_agreementId);
    }
}
