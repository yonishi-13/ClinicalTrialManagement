// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract ClinicalTrialDataStorage is AccessControl {
    struct TrialData {
        string ipfsHash; // Hash of clinical trial datasets (adverse event reports, etc.)
        string metadata; // Summary metadata (e.g., trial phase, drug name)
        uint256 timestamp;
    }

    // Roles
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");
    bytes32 public constant RESEARCHER_ROLE = keccak256("RESEARCHER_ROLE");

    mapping(address => TrialData[]) private clinicalTrialRecords;

    event DataStored(address indexed uploader, string ipfsHash, uint256 timestamp);
    event AccessGranted(address indexed regulator, address indexed researcher);

    constructor(address _admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(REGULATOR_ROLE, _admin); // Admin acts as initial regulator
    }

    modifier onlyAuthorized() {
        require(
            hasRole(RESEARCHER_ROLE, msg.sender) || hasRole(REGULATOR_ROLE, msg.sender),
            "Unauthorized: Must be researcher or regulator"
        );
        _;
    }

    function storeTrialData(string memory _ipfsHash, string memory _metadata) external onlyAuthorized {
        TrialData memory newData = TrialData(_ipfsHash, _metadata, block.timestamp);
        clinicalTrialRecords[msg.sender].push(newData);

        emit DataStored(msg.sender, _ipfsHash, block.timestamp);
    }

    function getTrialData(address researcher) external view onlyRole(REGULATOR_ROLE) returns (TrialData[] memory) {
        return clinicalTrialRecords[researcher];
    }

    function grantResearcherAccess(address researcher) external onlyRole(REGULATOR_ROLE) {
        grantRole(RESEARCHER_ROLE, researcher);
        emit AccessGranted(msg.sender, researcher);
    }

    function revokeResearcherAccess(address researcher) external onlyRole(REGULATOR_ROLE) {
        revokeRole(RESEARCHER_ROLE, researcher);
    }
}
