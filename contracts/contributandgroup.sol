// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICommunityGovernanceProfiles {
    function getUserProfile(address _user) external view returns (string memory, string memory, string memory);
    function getUserCommunityData(address _user, uint256 _communityId) external view returns (uint256, uint256, uint256, bool, address[] memory);
    function getCommunityProfile(uint256 _communityId) external view returns (string memory, string memory, string memory, address, uint256);
}

contract CommunityGovernanceContributions {
    ICommunityGovernanceProfiles public profilesContract;

    struct Contribution {
        string name;
        string description;
        string[] links;
    }

    struct WeeklyContributions {
        uint256 weekNumber;
        Contribution[] contributions;
    }

    struct UserContributions {
        uint256 communityId;
        mapping(uint256 => WeeklyContributions) weeklyContributions;
        uint256[] contributedWeeks;
    }

    struct Group {
        address[] members;
    }

    mapping(address => mapping(uint256 => UserContributions)) public userContributions;
    mapping(uint256 => mapping(uint256 => address[])) private weeklyContributors;
    mapping(uint256 => mapping(uint256 => Group[])) private weeklyGroups;

    uint8[] private lastRoomSizes;

    event ContributionSubmitted(address indexed user, uint256 indexed communityId, uint256 weekNumber, uint256 contributionIndex);
    event GroupsCreated(uint256 indexed communityId, uint256 weekNumber, uint256 groupCount);

    constructor(address _profilesContractAddress) {
        profilesContract = ICommunityGovernanceProfiles(_profilesContractAddress);
    }



    function submitContributions(uint256 _communityId, Contribution[] memory _contributions) public {
        (string memory username, , ) = profilesContract.getUserProfile(msg.sender);
        require(bytes(username).length > 0, "Profile must exist to submit contributions");
        
        (uint256 communityId, , , bool isApproved, ) = profilesContract.getUserCommunityData(msg.sender, _communityId);
        require(communityId != 0 && isApproved, "User not approved in this community");
        require(_contributions.length > 0, "Must submit at least one contribution");

        (, , , , uint256 currentWeek) = profilesContract.getCommunityProfile(_communityId);

        UserContributions storage userContrib = userContributions[msg.sender][_communityId];
        if (userContrib.communityId == 0) userContrib.communityId = _communityId;

        WeeklyContributions storage weeklyContrib = userContrib.weeklyContributions[currentWeek];
        weeklyContrib.weekNumber = currentWeek;
        delete weeklyContrib.contributions;

        for (uint256 i = 0; i < _contributions.length; i++) {
            weeklyContrib.contributions.push(_contributions[i]);
        }

        if (userContrib.contributedWeeks.length == 0 || userContrib.contributedWeeks[userContrib.contributedWeeks.length - 1] != currentWeek) {
            userContrib.contributedWeeks.push(currentWeek);
        }

        if (!isContributor(_communityId, currentWeek, msg.sender)) {
            weeklyContributors[_communityId][currentWeek].push(msg.sender);
        }

        emit ContributionSubmitted(msg.sender, _communityId, currentWeek, _contributions.length);
    }

    function createGroupsForCurrentWeek(uint256 _communityId) public {
        (, , , , uint256 currentWeek) = profilesContract.getCommunityProfile(_communityId);
        
        delete weeklyGroups[_communityId][currentWeek];

        address[] memory participants = weeklyContributors[_communityId][currentWeek];
        require(participants.length > 0, "No contributors for the current week");

        shuffle(participants);
        uint8[] memory roomSizes = determineRoomSizes(participants.length);

        uint256 participantIndex = 0;
        for (uint256 i = 0; i < roomSizes.length; i++) {
            address[] memory groupMembers = new address[](roomSizes[i]);
            for (uint256 j = 0; j < roomSizes[i] && participantIndex < participants.length; j++) {
                groupMembers[j] = participants[participantIndex++];
            }
            weeklyGroups[_communityId][currentWeek].push(Group(groupMembers));
        }

        lastRoomSizes = roomSizes;
        emit GroupsCreated(_communityId, currentWeek, weeklyGroups[_communityId][currentWeek].length);
    }

      function getGroupsForWeek(uint256 _communityId, uint256 _weekNumber) public view returns (Group[] memory) {
        return weeklyGroups[_communityId][_weekNumber];
    }

    function getContributions(address _user, uint256 _communityId, uint256 _weekNumber) public view returns (string[] memory names, string[] memory descriptions, string[][] memory links) {
        require(userContributions[_user][_communityId].communityId != 0, "No contributions found for this user in this community");
        Contribution[] memory contributions = userContributions[_user][_communityId].weeklyContributions[_weekNumber].contributions;
        names = new string[](contributions.length);
        descriptions = new string[](contributions.length);
        links = new string[][](contributions.length);
        for (uint i = 0; i < contributions.length; i++) {
            names[i] = contributions[i].name;
            descriptions[i] = contributions[i].description;
            links[i] = contributions[i].links;
        }
    }

    function getUserContributedWeeks(address _user, uint256 _communityId) public view returns (uint256[] memory) {
        require(userContributions[_user][_communityId].communityId != 0, "No contributions found for this user in this community");
        return userContributions[_user][_communityId].contributedWeeks;
    }

    function getLastRoomSizes() public view returns (uint8[] memory) {
        return lastRoomSizes;
    }

    function getWeeklyContributors(uint256 _communityId, uint256 _week) public view returns (address[] memory) {
        return weeklyContributors[_communityId][_week];
    }

    function isContributor(uint256 _communityId, uint256 _week, address _user) internal view returns (bool) {
        address[] memory contributors = weeklyContributors[_communityId][_week];
        for (uint i = 0; i < contributors.length; i++) {
            if (contributors[i] == _user) return true;
        }
        return false;
    }

    function shuffle(address[] memory array) internal view {
        for (uint256 i = array.length - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i))) % (i + 1);
            (array[i], array[j]) = (array[j], array[i]);
        }
    }

    function determineRoomSizes(uint256 numParticipants) internal pure returns (uint8[] memory) {
        return numParticipants <= 20 ? hardcodedRoomSizes(numParticipants) : genericRoomSizes(numParticipants);
    }

    function hardcodedRoomSizes(uint256 numParticipants) internal pure returns (uint8[] memory) {
        uint8[] memory sizes;
        if (numParticipants == 1) sizes = new uint8[](1);
        else if (numParticipants == 2) sizes = new uint8[](1);
        else if (numParticipants == 3) sizes = new uint8[](1);
        else if (numParticipants == 4) sizes = new uint8[](1);
        else if (numParticipants == 5) sizes = new uint8[](1);
        else if (numParticipants == 6) sizes = new uint8[](1);
        else if (numParticipants == 7) sizes = new uint8[](2);
        else if (numParticipants == 8) sizes = new uint8[](2);
        else if (numParticipants == 9) sizes = new uint8[](2);
        else if (numParticipants == 10) sizes = new uint8[](2);
        else if (numParticipants == 11) sizes = new uint8[](2);
        else if (numParticipants == 12) sizes = new uint8[](2);
        else if (numParticipants == 13) sizes = new uint8[](3);
        else if (numParticipants == 14) sizes = new uint8[](3);
        else if (numParticipants == 15) sizes = new uint8[](3);
        else if (numParticipants == 16) sizes = new uint8[](3);
        else if (numParticipants == 17) sizes = new uint8[](3);
        else if (numParticipants == 18) sizes = new uint8[](3);
        else if (numParticipants == 19) sizes = new uint8[](4);
        else if (numParticipants == 20) sizes = new uint8[](4);

        if (numParticipants == 1) sizes[0] = 1;
        else if (numParticipants == 2) sizes[0] = 2;
        else if (numParticipants == 3) sizes[0] = 3;
        else if (numParticipants == 4) sizes[0] = 4;
        else if (numParticipants == 5) sizes[0] = 5;
        else if (numParticipants == 6) sizes[0] = 6;
        else if (numParticipants == 7) { sizes[0] = 3; sizes[1] = 4; }
        else if (numParticipants == 8) { sizes[0] = 4; sizes[1] = 4; }
        else if (numParticipants == 9) { sizes[0] = 5; sizes[1] = 4; }
        else if (numParticipants == 10) { sizes[0] = 5; sizes[1] = 5; }
        else if (numParticipants == 11) { sizes[0] = 5; sizes[1] = 6; }
        else if (numParticipants == 12) { sizes[0] = 6; sizes[1] = 6; }
        else if (numParticipants == 13) { sizes[0] = 5; sizes[1] = 4; sizes[2] = 4; }
        else if (numParticipants == 14) { sizes[0] = 5; sizes[1] = 5; sizes[2] = 4; }
        else if (numParticipants == 15) { sizes[0] = 5; sizes[1] = 5; sizes[2] = 5; }
        else if (numParticipants == 16) { sizes[0] = 6; sizes[1] = 5; sizes[2] = 5; }
        else if (numParticipants == 17) { sizes[0] = 6; sizes[1] = 6; sizes[2] = 5; }
        else if (numParticipants == 18) { sizes[0] = 6; sizes[1] = 6; sizes[2] = 6; }
        else if (numParticipants == 19) { sizes[0] = 5; sizes[1] = 5; sizes[2] = 5; sizes[3] = 4; }
        else if (numParticipants == 20) { sizes[0] = 5; sizes[1] = 5; sizes[2] = 5; sizes[3] = 5; }

        return sizes;
    }

    function genericRoomSizes(uint256 numParticipants) internal pure returns (uint8[] memory) {
        uint8[] memory sizes = new uint8[]((numParticipants + 5) / 6);  // Max possible rooms
        uint256 roomCount = 0;
        uint8 countOfFives = 0;

        while (numParticipants > 0) {
            if (numParticipants % 6 != 0 && countOfFives < 5) {
                sizes[roomCount++] = 5;
                numParticipants -= 5;
                countOfFives++;
            } else {
                sizes[roomCount++] = 6;
                numParticipants -= 6;
                if (countOfFives == 5) countOfFives = 0;
            }
        }

        // Trim the array to the actual number of rooms
        assembly {
            mstore(sizes, roomCount)
        }
        return sizes;
    }
}