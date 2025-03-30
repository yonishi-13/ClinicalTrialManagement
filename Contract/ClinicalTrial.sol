// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./PatientLedger.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ClinicalTrialLedger {
    struct TrialRecord {
        address patientAddress;
        string eventType; // e.g., "Dosing", "Side Effect", "Follow-up"
        string drugName;
        string description;
        uint256 timestamp;
        bytes32 hashedData; // Ensuring integrity of medical reports & device readings
    }

    mapping(address => TrialRecord[]) private trialHistory;
    mapping(address => bytes32) public latestPatientHash; // Stores the latest verified data hash

    PatientLedger public patientLedger;
    AggregatorV3Interface internal chainlinkOracle;
    address public admin;

    event TrialDataStored(
        address indexed patientAddress,
        string eventType,
        string drugName,
        uint256 timestamp,
        bytes32 hashedData
    );

    modifier onlyVerifiedResearcher() {
        require(msg.sender == admin, "Only verified researchers can log data");
        _;
    }

    modifier onlyVerifiedPatient(address _patientAddress) {
        require(patientLedger.isPatientVerified(_patientAddress), "Patient not verified");
        _;
    }

    constructor(address _patientLedgerAddress, address _oracleAddress) {
        patientLedger = PatientLedger(_patientLedgerAddress);
        chainlinkOracle = AggregatorV3Interface(_oracleAddress);
        admin = msg.sender; // Only contract deployer (admin) can log trial data
    }

    function storeTrialEvent(
        address _patientAddress,
        string memory _eventType,
        string memory _drugName,
        string memory _description,
        bytes32 _hashedData
    ) external onlyVerifiedResearcher onlyVerifiedPatient(_patientAddress) {
        TrialRecord memory newRecord = TrialRecord(
            _patientAddress,
            _eventType,
            _drugName,
            _description,
            block.timestamp,
            _hashedData
        );

        trialHistory[_patientAddress].push(newRecord);
        latestPatientHash[_patientAddress] = _hashedData; // Store latest hashed data

        emit TrialDataStored(_patientAddress, _eventType, _drugName, block.timestamp, _hashedData);
    }

    function getPatientTrials(address _patientAddress) external view returns (TrialRecord[] memory) {
        return trialHistory[_patientAddress];
    }

    function getLatestTrialEvent(address _patientAddress) external view returns (TrialRecord memory) {
        require(trialHistory[_patientAddress].length > 0, "No trial data found");
        return trialHistory[_patientAddress][trialHistory[_patientAddress].length - 1];
    }

    function fetchLatestSensorData() public view returns (int256) {
        (, int256 latestReading, , , ) = chainlinkOracle.latestRoundData();
        return latestReading; // Fetches real-time biometric readings or other clinical data
    }
}
