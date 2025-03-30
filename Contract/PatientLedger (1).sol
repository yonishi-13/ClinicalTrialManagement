// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PatientLedger {
    using ECDSA for bytes32;

    address public immutable admin;

    struct VerifiedPatient {
        bytes32 uniqueId;
        bytes32 hashedData;
        string DID; // Decentralized Identity
        bool hasConsented;
        uint8 status; // 0 = Unverified, 1 = Verified, 2 = Eligible
    }

    mapping(address => VerifiedPatient) private verifiedPatients;
    mapping(bytes32 => address) private patientAddressById;

    event PatientStored(address indexed patientAddress, bytes32 uniqueId, string DID);
    event ConsentUpdated(address indexed patientAddress, bool hasConsented);
    event PatientStatusUpdated(address indexed patientAddress, uint8 status);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier patientExists(address _patientAddress) {
        require(verifiedPatients[_patientAddress].uniqueId != bytes32(0), "Patient not found");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function storeVerifiedPatient(address _patientAddress, bytes32 _uniqueId, bytes32 _hashedData, string memory _DID) external onlyAdmin {
        require(patientAddressById[_uniqueId] == address(0), "Patient already registered");

        verifiedPatients[_patientAddress] = VerifiedPatient(_uniqueId, _hashedData, _DID, false, 1); // Status 1 = Verified
        patientAddressById[_uniqueId] = _patientAddress;

        emit PatientStored(_patientAddress, _uniqueId, _DID);
    }

    function updateConsent(address _patientAddress, bool _hasConsented) external onlyAdmin patientExists(_patientAddress) {
        verifiedPatients[_patientAddress].hasConsented = _hasConsented;
        emit ConsentUpdated(_patientAddress, _hasConsented);
    }

    function updatePatientStatus(address _patientAddress, bytes32 _hashedData, bool _isEligible) external onlyAdmin patientExists(_patientAddress) {
        VerifiedPatient storage patient = verifiedPatients[_patientAddress];
        require(patient.hashedData == _hashedData, "Data mismatch");
        patient.status = _isEligible ? 2 : 1; // 2 = Eligible, 1 = Verified only

        emit PatientStatusUpdated(_patientAddress, patient.status);
    }

    function getVerifiedPatient(address _patientAddress) external view patientExists(_patientAddress) returns (bytes32, bytes32, string memory, bool, uint8) {
        VerifiedPatient memory patient = verifiedPatients[_patientAddress];
        return (patient.uniqueId, patient.hashedData, patient.DID, patient.hasConsented, patient.status);
    }

    function isPatientRegistered(address _patientAddress) external view returns (bool) {
        return verifiedPatients[_patientAddress].uniqueId != bytes32(0);
    }

    function isPatientVerified(address _patientAddress) external view returns (bool) {
        return verifiedPatients[_patientAddress].status >= 1; // 1 = Verified or Eligible
    }

    function isPatientEligible(address _patientAddress) external view returns (bool) {
        return verifiedPatients[_patientAddress].status == 2; // 2 = Eligible
    }
}
