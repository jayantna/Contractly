// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IContractly {
    enum AgreementStatus {
        Pending,
        Locked,
        Fulfilled,
        Breached,
        DisputeWindow,
        Disputed,
        Canceled
    }

    function getAgreementStatus(uint256 _agreementId) external view returns (AgreementStatus);
    function getPartyStakeAmount(uint256 _agreementId, address _party) external view returns (uint256);
    function getPartyStakeRatio(uint256 _agreementId, address _party) external view returns (uint256);
    function getPartyHasSigned(uint256 _agreementId, address _party) external view returns (bool);
    function getPartyRequiresStaking(uint256 _agreementId, address _party) external view returns (bool);
    function getPartyCount(uint256 _agreementId) external view returns (uint256);
    function getPartyAddressAtIndex(uint256 _agreementId, uint256 _index) external view returns (address);
    function stakeAgreement(uint256 _agreementId, address _sender) external payable;
}
