// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./PatientLedger.sol";

contract PatientVerification {
    using ECDSA for bytes32;
    
    address public admin;
    PatientLedger public patientLedger;

    struct Patient {
        bytes32 uniqueId;
        bytes32 hashedData;
        string DID; // Decentralized Identity
        bool isVerified;
        bool isEligible;
        bool hasConsented;
    }

    mapping(address => Patient) public patients;
    mapping(bytes32 => address) public patientAddressesByUniqueId;
    mapping(address => bool) public authorizedResearchers;

    event PatientRegistered(address indexed patientAddress, bytes32 uniqueId, string DID);
    event PatientVerified(address indexed patientAddress, bytes32 uniqueId);
    event EligibilityChecked(address indexed patientAddress, bool isEligible);
    event ConsentProvided(address indexed patientAddress, bool hasConsented);
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }
    
    modifier onlyResearcher() {
        require(authorizedResearchers[msg.sender], "Only authorized researchers can verify");
        _;
    }
    
    modifier onlyVerifiedPatient() {
        require(patients[msg.sender].isVerified, "Patient not verified");
        _;
    }

    constructor(address _patientLedger) {
        admin = msg.sender;
        patientLedger = PatientLedger(_patientLedger);
    }

    function authorizeResearcher(address _researcher) external onlyAdmin {
        authorizedResearchers[_researcher] = true;
    }

    function registerPatient(bytes32 _hashedData, string memory _DID) external {
        require(patients[msg.sender].uniqueId == bytes32(0), "Patient already registered");
        bytes32 uniqueId = keccak256(abi.encodePacked(msg.sender, _DID));
        patients[msg.sender] = Patient(uniqueId, _hashedData, _DID, false, false, false);
        patientAddressesByUniqueId[uniqueId] = msg.sender;
        emit PatientRegistered(msg.sender, uniqueId, _DID);
    }

    function provideConsent() external onlyVerifiedPatient {
        patients[msg.sender].hasConsented = true;
        emit ConsentProvided(msg.sender, true);
    }

    function verifyPatient(address _patientAddress, bytes32 _originalData, bytes memory _signature) external onlyResearcher {
        Patient storage patient = patients[_patientAddress];
        require(patient.hashedData != bytes32(0), "Patient not registered");
        require(!patient.isVerified, "Patient already verified");
        bytes32 messageHash = keccak256(abi.encodePacked(_originalData));
        require(ECDSA.recover(messageHash, _signature) == _patientAddress, "Invalid signature");
        require(patient.hashedData == messageHash, "Data mismatch");
        patient.isVerified = true;
        patientLedger.storeVerifiedPatient(_patientAddress, patient.uniqueId, patient.hashedData, patient.DID);
        emit PatientVerified(_patientAddress, patient.uniqueId);
    }

    function checkEligibility(uint256 _age, uint256 _BMI, uint256 _ALT, uint256 _AST, uint256 _bilirubin, uint256 _albumin) external onlyAdmin {
        require(patients[msg.sender].isVerified, "Patient not verified");
        bool isEligible = !(_age < 18 || _age > 60 || _BMI < 18 || _BMI > 30 || _ALT > 50 || _AST > 50 || _bilirubin > 120 || _albumin < 350);
        patients[msg.sender].isEligible = isEligible;
        patientLedger.updatePatientStatus(msg.sender, patients[msg.sender].hashedData, isEligible);
        emit EligibilityChecked(msg.sender, isEligible);
    }
}
