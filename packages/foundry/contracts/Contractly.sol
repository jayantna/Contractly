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
    error FundsTransferFailed();
    error StakeRatioTooHigh();
    error TotalStakeRatioExceeds100();
    error PartyNotFound();
    error FundsDistributionFailed();
    error FundsReturnFailed();
    error AgreementNotExpired();

    // ======== State Variables ========
    address public owner;
    uint256 public agreementCount; // Counter for the number of agreements created (incremented on each createAgreement call)
    mapping(address => bool) public authorizedContracts; // Mapping to track authorized contracts

    enum AgreementStatus {
        Pending,
        Locked,
        Fulfilled,
        Breached,
        DisputeWindow,
        Disputed,
        Canceled
    }

    struct Party {
        bool requiresSignature;
        bool requiresStaking;
        uint256 stakeRatio; // Percentage of total stake amount (1-100)
        bool hasSigned; // Whether the party has signed the agreement
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
        bool isParty = false;
        Agreement storage agreement = agreements[_agreementId];
        for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
            if (agreement.partyAddresses[i] == msg.sender) {
                isParty = true;
                break;
            }
        }
        if (!isParty) revert NotAgreementParty();
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
     * @dev Creates a new agreement - can only be called by authorized contracts
     * @param _title Title of the agreement
     * @param _creator Creator of the agreement
     * @param _expirationTime Timestamp when the agreement expires
     * @param _totalStakingAmount Total amount that needs to be staked across all parties
     */
    function createAgreement(string memory _title, address _creator, uint256 _expirationTime, uint256 _totalStakingAmount) external onlyAuthorizedContract returns (uint256) {
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
    function addParty(uint256 _agreementId, address _partyAddress, bool _requiresSignature, bool _requiresStaking, uint256 _stakeRatio) external agreementExists(_agreementId) onlyPendingStatus(_agreementId) onlyAuthorizedContract {
        Agreement storage agreement = agreements[_agreementId];

        _requiresStaking = _requiresSignature ? _requiresStaking : false;
        _stakeRatio = _requiresStaking ? _stakeRatio : 0;

        if (_stakeRatio > 100) revert StakeRatioTooHigh();

        // Calculate total stake ratio by adding the new party's ratio to the sum of all existing parties' ratios.
        // This ensures the total stake ratio across all parties does not exceed 100%.
        uint256 totalRatio = _stakeRatio;
        if (agreement.partyAddresses.length > 0) {
            for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
                totalRatio += agreement.parties[agreement.partyAddresses[i]].stakeRatio;
            }
        }
        if (totalRatio > 100) revert TotalStakeRatioExceeds100();
        _addToAgreementParties(agreement, _partyAddress, _requiresSignature, _requiresStaking, _stakeRatio);
    }

    /**
     * @dev Allows a party to sign an agreement
     * @param _agreementId The ID of the agreement to sign
     */
    function signAgreement(uint256 _agreementId, address _signer) external agreementExists(_agreementId) onlyPendingStatus(_agreementId) onlyAuthorizedContract {
        Agreement storage agreement = agreements[_agreementId];
        Party storage party = agreement.parties[_signer];

        if (party.hasSigned) revert AlreadySigned();

        party.hasSigned = true;

        emit AgreementSigned(_agreementId, _signer);
    }

    /**
     * @dev Allows a party to stake funds for an agreement
     * @param _agreementId The ID of the agreement
     */
    function stakeAgreement(uint256 _agreementId, address _sender) external payable agreementExists(_agreementId) onlyPendingStatus(_agreementId) onlyAuthorizedContract {
        Agreement storage agreement = agreements[_agreementId];
        Party storage party = agreement.parties[_sender];
        if (!party.requiresStaking) revert StakingNotRequired();

        uint256 requiredStake = _getRequiredStakeAmount(_agreementId, _sender);
        if (msg.value != requiredStake) revert InvalidStakingAmount();
        if (stakedFunds[_agreementId][_sender] != 0) revert AlreadyStaked();

        stakedFunds[_agreementId][_sender] = msg.value;

        emit FundsStaked(_agreementId, _sender, msg.value);
    }

    function fulfillAgreement(uint256 _agreementId) external agreementExists(_agreementId) onlyAuthorizedContract {
        Agreement storage agreement = agreements[_agreementId];
        if (agreement.status != AgreementStatus.Locked) revert NotLockedStatus();

        if (block.timestamp < agreement.expirationTime) {
            revert AgreementNotExpired();
        }

        agreement.status = AgreementStatus.Fulfilled;

        // Return staked funds to all parties
        for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
            address party = agreement.partyAddresses[i];
            uint256 amount = getStakedAmount(_agreementId, party);
            if (amount > 0) {
                stakedFunds[_agreementId][party] = 0;
                (bool success,) = party.call{ value: amount }("");
                if (!success) revert FundsTransferFailed();
                emit FundsReleased(_agreementId, party, amount);
            }
        }
        emit AgreementFulfilled(_agreementId);
    }

    function breachAgreement(uint256 _agreementId, address _breachingParty) external agreementExists(_agreementId) onlyAuthorizedContract {
        Agreement storage agreement = agreements[_agreementId];
        if (agreement.status != AgreementStatus.Locked) revert NotLockedStatus();

        if (block.timestamp < agreement.expirationTime + agreement.disputeWindowDuration) {
            revert AgreementNotExpired();
        }

        agreement.status = AgreementStatus.Breached;

        // Handle breach consequences - distribute the breaching party's funds
        uint256 breachingPartyStake = getStakedAmount(_agreementId, _breachingParty);

        if (breachingPartyStake > 0) {
            stakedFunds[_agreementId][_breachingParty] = 0;

            bool allPartiesRequireSignature = true;
            for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
                if (!agreement.parties[agreement.partyAddresses[i]].requiresSignature) {
                    allPartiesRequireSignature = false;
                }
            }
            // If all parties require signatures, distribute the funds to the non-breaching parties in proportion to their stake ratio
            if (allPartiesRequireSignature) {
                // Calculate total stake ratio of non-breaching parties
                uint256 totalNonBreachingRatio = 0;
                for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
                    address party = agreement.partyAddresses[i];
                    if (party != _breachingParty) {
                        totalNonBreachingRatio += agreement.parties[party].stakeRatio;
                    }
                }

                // Create compensation array based on stake ratios
                uint256[] memory compensations = new uint256[](agreement.partyAddresses.length);
                for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
                    address party = agreement.partyAddresses[i];
                    if (party != _breachingParty && totalNonBreachingRatio > 0) {
                        // Calculate compensation proportional to stake ratio
                        compensations[i] = (breachingPartyStake * agreement.parties[party].stakeRatio) / totalNonBreachingRatio;
                    }
                }

                // Distribute compensation according to calculated amounts
                for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
                    address party = agreement.partyAddresses[i];
                    if (party != _breachingParty && compensations[i] > 0) {
                        (bool success,) = party.call{ value: compensations[i] }("");
                        if (!success) revert FundsDistributionFailed();
                    }
                }
            } else {
                // If all parties does not require signature, distribute the funds to non-breaching parties equally
                uint256 amountPerParty = breachingPartyStake / (agreement.partyAddresses.length - 1);
                for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
                    address party = agreement.partyAddresses[i];
                    if (party != _breachingParty) {
                        (bool success,) = party.call{ value: amountPerParty }("");
                        if (!success) revert FundsDistributionFailed();
                    }
                }
            }
        }

        // Return stakes to non-breaching parties
        for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
            address party = agreement.partyAddresses[i];
            if (party != _breachingParty) {
                uint256 amount = getStakedAmount(_agreementId, party);
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

    /**
     * @dev Locks an agreement when all required conditions are met
     * @param _agreementId The ID of the agreement to lock
     */
    function lockAgreement(uint256 _agreementId) external agreementExists(_agreementId) onlyPendingStatus(_agreementId) onlyAuthorizedContract {
        if (!_checkAllConditionsMet(_agreementId)) revert ConditionsNotMet();
        agreements[_agreementId].status = AgreementStatus.Locked;
        emit AgreementLocked(_agreementId);
    }

    // ======== Internal Functions ========

    /**
     * @dev Internal function to check if all conditions for locking are met
     * @param _agreementId The ID of the agreement to check
     * @return bool True if all conditions are met, false otherwise
     */
    function _checkAllConditionsMet(uint256 _agreementId) internal view returns (bool) {
        Agreement storage agreement = agreements[_agreementId];

        // Check if all required parties have signed
        for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
            if (agreement.parties[agreement.partyAddresses[i]].requiresSignature && !agreement.parties[agreement.partyAddresses[i]].hasSigned) {
                return false;
            }
        }

        // Check if all required staking is completed
        for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
            address partyAddress = agreement.partyAddresses[i];
            Party storage party = agreement.parties[partyAddress];
            if (party.requiresStaking) {
                uint256 requiredStake = _getRequiredStakeAmount(_agreementId, partyAddress);
                if (stakedFunds[_agreementId][partyAddress] < requiredStake) {
                    return false;
                }
            }
        }
        return true;
    }

    /**
     * @dev Calculates the required stake amount for a party based on their stake ratio
     * @param _agreementId The ID of the agreement
     * @param _partyAddress The address of the party
     * @return uint256 The required stake amount for the party
     */
    function _getRequiredStakeAmount(uint256 _agreementId, address _partyAddress) internal view agreementExists(_agreementId) returns (uint256) {
        Agreement storage agreement = agreements[_agreementId];
        Party storage party = agreement.parties[_partyAddress];

        if (!party.requiresStaking) return 0;

        return (agreement.totalStakingAmount * party.stakeRatio) / 100;
    }

    function _addToAgreementParties(Agreement storage _agreement, address _partyAddress, bool _requiresSignature, bool _requiresStaking, uint256 _stakeRatio) internal {
        _agreement.parties[_partyAddress] = Party({ requiresSignature: _requiresSignature, requiresStaking: _requiresStaking, stakeRatio: _stakeRatio, hasSigned: false });
        _agreement.partyAddresses.push(_partyAddress);
    }

    // ======== Getter Functions ========

    function getAgreementStatus(uint256 _agreementId) public view agreementExists(_agreementId) returns (AgreementStatus) {
        return agreements[_agreementId].status;
    }

    function getStakedAmount(uint256 _agreementId, address _party) public view agreementExists(_agreementId) returns (uint256) {
        return stakedFunds[_agreementId][_party];
    }

    function getAgreement(uint256 _agreementId) public view agreementExists(_agreementId) returns (uint256 id, string memory title, address creator, uint256 creationTime, uint256 expirationTime, uint256 disputeWindowDuration, uint256 totalStakingAmount, AgreementStatus status, address[] memory partyAddresses) {
        Agreement storage agreement = agreements[_agreementId];
        return (agreement.id, agreement.title, agreement.creator, agreement.creationTime, agreement.expirationTime, agreement.disputeWindowDuration, agreement.totalStakingAmount, agreement.status, agreement.partyAddresses);
    }

    function getParty(uint256 _agreementId, address _partyAddress) public view agreementExists(_agreementId) returns (bool requiresStaking, uint256 stakeRatio, bool hasSigned) {
        Agreement storage agreement = agreements[_agreementId];

        // Check if the party exists in partyAddresses array
        bool partyExists = false;
        for (uint256 i = 0; i < agreement.partyAddresses.length; i++) {
            if (agreement.partyAddresses[i] == _partyAddress) {
                partyExists = true;
                break;
            }
        }

        if (!partyExists) {
            revert PartyNotFound();
        }

        Party storage party = agreement.parties[_partyAddress];
        return (party.requiresStaking, party.stakeRatio, party.hasSigned);
    }

    function getPartyCount(uint256 _agreementId) public view agreementExists(_agreementId) returns (uint256) {
        return agreements[_agreementId].partyAddresses.length;
    }

    function getPartyAddresses(uint256 _agreementId) public view agreementExists(_agreementId) returns (address[] memory) {
        return agreements[_agreementId].partyAddresses;
    }

    function getPartyAddressAtIndex(uint256 _agreementId, uint256 _index) public view agreementExists(_agreementId) returns (address) {
        return agreements[_agreementId].partyAddresses[_index];
    }

    function isAuthorizedContract(address _contractAddress) public view returns (bool) {
        return authorizedContracts[_contractAddress];
    }

    function getPartyHasSigned(uint256 _agreementId, address _partyAddress) public view agreementExists(_agreementId) returns (bool) {
        return agreements[_agreementId].parties[_partyAddress].hasSigned;
    }

    function getPartyRequiresStaking(uint256 _agreementId, address _partyAddress) public view agreementExists(_agreementId) returns (bool) {
        return agreements[_agreementId].parties[_partyAddress].requiresStaking;
    }

    function getPartyStakeRatio(uint256 _agreementId, address _partyAddress) public view agreementExists(_agreementId) returns (uint256) {
        return agreements[_agreementId].parties[_partyAddress].stakeRatio;
    }

    function getPartyStakeAmount(uint256 _agreementId, address _partyAddress) public view agreementExists(_agreementId) returns (uint256) {
        return stakedFunds[_agreementId][_partyAddress];
    }
}
