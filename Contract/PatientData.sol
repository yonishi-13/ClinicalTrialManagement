// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./PatientVerification.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PatientDataStorage {
    using ECDSA for bytes32;

    address public admin;
    PatientVerification public patientVerification;

    struct PatientData {
        bytes32 hashedData;
        string DID;
        uint256 age;
        uint256 BMI;
        uint256 ALT;
        uint256 AST;
        uint256 bilirubin;
        uint256 albumin;
        bool isEligible;
    }

    mapping(address => PatientData) public patientRecords;

    event PatientDataStored(address indexed patientAddress, bytes32 hashedData, string DID);
    event EligibilityChecked(address indexed patientAddress, bool isEligible);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyVerifiedPatient() {
        (bytes32 uniqueId, bytes32 hashedData, string memory DID, bool isVerified, bool isEligible, bool hasConsented) = patientVerification.patients(msg.sender);
        require(isVerified, "Patient not verified");
        _;
    }

    constructor(address _patientVerification) {
        admin = msg.sender;
        patientVerification = PatientVerification(_patientVerification);
    }

    function storePatientData(
        string memory _DID,
        uint256[6] memory clinicalData // Reduce parameters by grouping into an array
    ) external onlyVerifiedPatient {
        // Hash patient data
        bytes32 hashedData = keccak256(
            abi.encodePacked(msg.sender, _DID, clinicalData)
        );

        // Store data in struct to reduce local variables
        patientRecords[msg.sender] = PatientData({
            hashedData: hashedData,
            DID: _DID,
            age: clinicalData[0],
            BMI: clinicalData[1],
            ALT: clinicalData[2],
            AST: clinicalData[3],
            bilirubin: clinicalData[4],
            albumin: clinicalData[5],
            isEligible: false
        });

        emit PatientDataStored(msg.sender, hashedData, _DID);

        // Automatically check eligibility
        checkEligibility(msg.sender);
    }

    function checkEligibility(address _patientAddress) public onlyAdmin {
        PatientData storage patient = patientRecords[_patientAddress];

        bool isEligibleNow = !(patient.age < 18 || patient.age > 60 ||
                               patient.BMI < 18 || patient.BMI > 30 ||
                               patient.ALT > 50 || patient.AST > 50 ||
                               patient.bilirubin > 120 || patient.albumin < 350);

        patient.isEligible = isEligibleNow;

        emit EligibilityChecked(_patientAddress, isEligibleNow);
    }

    function getPatientData(address _patient) external view returns (bytes32, string memory, bool) {
        PatientData memory data = patientRecords[_patient];
        return (data.hashedData, data.DID, data.isEligible);
    }
}
