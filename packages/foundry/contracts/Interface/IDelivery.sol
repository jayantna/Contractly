// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDelivery {
    function getLastAutomationUpdate() external view returns (uint256);
    function updateLastUpdate() external;
    function createDelivery(string memory _title, uint256 _expirationTime, uint256 _totalStakingAmount, address _customerAddress) external payable returns (uint256);
    function createBatchDelivery(string[] memory _titles, uint256[] memory _expirationTimes, uint256[] memory _totalStakingAmounts, address[] memory _customerAddresses) external payable returns (uint256[] memory);
    function fulfillAgreement(uint256 _agreementId) external;
    function breachAgreement(uint256 _agreementId, address _breachingParty) external;
    function checkDeliveryStatus(uint256 _agreementId) external;
}
