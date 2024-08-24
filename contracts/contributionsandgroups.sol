// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICommunityGovernanceProfiles {
    function getUserProfile(address _user) external view returns (string memory, string memory, string memory);
    function getUserCommunityData(address _user, uint256 _communityId) external view returns (uint256, uint256, uint256, bool, address[] memory);
    function getCommunityProfile(uint256 _communityId) external view returns (string memory, string memory, string memory, address, uint256);
}
/**
 * @title CommunityGovernance
 * @dev Manages community creation, membership, and contributions
 * @custom:dev-run-script /script/twotogether.js
*/
contract CommunityGovernanceContributions {
    ICommunityGovernanceProfiles public profilesContract;

    uint256 constant SCALE = 1e18;

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

    struct Ranking {
        address[] rankedAddresses;
    }

  // Update the ConsensusRanking struct
struct ConsensusRanking {
    address[] rankedAddresses;
    uint256[] scores;
    uint256 timestamp;
}

    uint8[] private lastRoomSizes;
    Group[] private groups;
    mapping(address => mapping(uint256 => UserContributions)) public userContributions;
    mapping(uint256 => mapping(uint256 => address[])) private weeklyContributors;
    mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(address => Ranking)))) private rankings;
    mapping(uint256 => mapping(uint256 => mapping(uint256 => ConsensusRanking))) private consensusRankings;
    mapping(uint256 => mapping(uint256 => Group[])) private weeklyGroups;

    event ContributionSubmitted(address indexed user, uint256 indexed communityId, uint256 weekNumber, uint256 contributionIndex);
    event GroupsCreated(uint256 indexed communityId, uint256 weekNumber, uint256 groupCount);
    event RankingSubmitted(uint256 indexed communityId, uint256 weekNumber, uint256 groupId, address indexed submitter);
    event ConsensusReached(uint256 indexed communityId, uint256 weekNumber, uint256 groupId, address[] consensusRanking);

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


function submitRanking(uint256 _communityId, uint256 _weekNumber, uint256 _groupId, address[] memory _ranking) public {
    require(_ranking.length > 0 && _ranking.length <= 6, "Ranking must have 1 to 6 members");
    require(isPartOfGroup(_communityId, _weekNumber, _groupId, msg.sender), "Sender not part of the group");
    require(rankings[_communityId][_weekNumber][_groupId][msg.sender].rankedAddresses.length == 0, "Ranking already submitted");

    bool senderIncluded = false;
    for (uint256 i = 0; i < _ranking.length; i++) {
        require(isPartOfGroup(_communityId, _weekNumber, _groupId, _ranking[i]), "Invalid address in ranking");
        if (_ranking[i] == msg.sender) senderIncluded = true;
    }
    require(senderIncluded, "Sender must be included in the ranking");

    rankings[_communityId][_weekNumber][_groupId][msg.sender] = Ranking(_ranking);
    emit RankingSubmitted(_communityId, _weekNumber, _groupId, msg.sender);
}

function isPartOfGroup(uint256 _communityId, uint256 _weekNumber, uint256 _groupId, address _member) private view returns (bool) {
    require(_groupId < weeklyGroups[_communityId][_weekNumber].length, "Invalid group ID");
    Group storage group = weeklyGroups[_communityId][_weekNumber][_groupId];
    for (uint256 i = 0; i < group.members.length; i++) {
        if (group.members[i] == _member) return true;
    }
    return false;
}


// Update the determineConsensus function
function determineConsensus(uint256 _communityId, uint256 _weekNumber, uint256 _groupId) public {
    Group storage group = groups[_groupId];
    require(group.members.length > 0, "Group does not exist");

    uint256 groupSize = group.members.length;
    address[] memory members = new address[](groupSize);
    uint256[] memory transientScores = new uint256[](groupSize);

    for (uint256 i = 0; i < groupSize; i++) {
        members[i] = group.members[i];
        transientScores[i] = calculateTransientScore(_communityId, _weekNumber, _groupId, members[i]);
    }

    quickSort(members, transientScores, int(0), int(groupSize - 1));

    consensusRankings[_communityId][_weekNumber][_groupId] = ConsensusRanking(members, transientScores, block.timestamp);
    emit ConsensusReached(_communityId, _weekNumber, _groupId, members);
}

// Improved function
function calculateScores(uint256 _communityId, uint256 _weekNumber, uint256 _groupId, Group storage group, address[] memory members, uint256[] memory transientScores) internal view returns (bool) {
    for (uint256 i = 0; i < group.members.length; i++) {
        members[i] = group.members[i];
        transientScores[i] = calculateTransientScore(_communityId, _weekNumber, _groupId, members[i]);
        if (transientScores[i] == 0) {
            return false;
        }
    }
    return true;
}
/*
function createGroupsForCurrentWeek(uint256 _communityId) public {
    (, , , , uint256 currentWeek) = profilesContract.getCommunityProfile(_communityId);
    require(weeklyGroups[_communityId][currentWeek].length == 0, "Groups already created for this week");

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
*/
function createGroupsForCurrentWeek(uint256 _communityId) public {
    (, , , , uint256 currentWeek) = profilesContract.getCommunityProfile(_communityId);
    
    // Remove the check for existing groups and instead clear any existing groups
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

   
// Update the calculateTransientScore function
function calculateTransientScore(uint256 _communityId, uint256 _weekNumber, uint256 _groupId, address _member) private view returns (uint256) {
    uint256 groupSize = groups[_groupId].members.length;
    uint256[] memory individualRankings = new uint256[](groupSize);
    uint256 rankingCount = 0;
    uint256 totalRanking = 0;

    for (uint256 i = 0; i < groupSize; i++) {
        address ranker = groups[_groupId].members[i];
        Ranking storage ranking = rankings[_communityId][_weekNumber][_groupId][ranker];
        
        if (ranking.rankedAddresses.length > 0) {
            for (uint256 j = 0; j < ranking.rankedAddresses.length; j++) {
                if (ranking.rankedAddresses[j] == _member) {
                    individualRankings[rankingCount] = j + 1;
                    totalRanking += j + 1;
                    rankingCount++;
                    break;
                }
            }
        }
    }

    if (rankingCount == 0) return 0;

    uint256 averageRanking = (totalRanking * SCALE) / rankingCount;
    uint256 consensusTerm = calculateConsensusTerm(individualRankings, rankingCount, groupSize);

    return (averageRanking * consensusTerm) / SCALE;
}
// Add the calculateConsensusTerm function
function calculateConsensusTerm(uint256[] memory individualRankings, uint256 count, uint256 groupSize) private pure returns (uint256) {
    if (count <= 1) return SCALE;

    uint256 variance = calculateVariance(individualRankings, count);
    uint256 maxVariance = calculateMaxVariance(groupSize);
    
    return SCALE - ((variance * SCALE) / maxVariance);
}
    // Helper functions
    function shuffle(address[] memory array) internal view {
        for (uint256 i = array.length - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i))) % (i + 1);
            (array[i], array[j]) = (array[j], array[i]);
        }
    }

    // Update the calculateVariance function
function calculateVariance(uint256[] memory values, uint256 count) private pure returns (uint256) {
    if (count <= 1) return 0;

    uint256 sum = 0;
    uint256 sumSquared = 0;

    for (uint256 i = 0; i < count; i++) {
        sum += values[i];
        sumSquared += values[i] * values[i];
    }

    uint256 mean = (sum * SCALE) / count;
    uint256 meanSquared = (mean * mean) / SCALE;
    uint256 averageSquared = (sumSquared * SCALE) / count;

    return averageSquared > meanSquared ? averageSquared - meanSquared : 0;
}


    function determineRoomSizes(uint256 numParticipants) internal pure returns (uint8[] memory) {
        return numParticipants <= 20 ? hardcodedRoomSizes(numParticipants) : genericRoomSizes(numParticipants);
    }


// Update the calculateMaxVariance function
function calculateMaxVariance(uint256 groupSize) private pure returns (uint256) {
    uint256 sum = 0;
    for (uint256 x = 1; x < groupSize; x++) {
        sum += x * (x + 1) / 2;
    }
    return (groupSize * sum * SCALE) / (groupSize - 1);
}

    function isPartOfGroup(uint256 _groupId, address _member) private view returns (bool) {
        Group storage group = groups[_groupId];
        for (uint256 i = 0; i < group.members.length; i++) {
            if (group.members[i] == _member) return true;
        }
        return false;
    }

    function isContributor(uint256 _communityId, uint256 _week, address _user) internal view returns (bool) {
        address[] memory contributors = weeklyContributors[_communityId][_week];
        for (uint i = 0; i < contributors.length; i++) {
            if (contributors[i] == _user) return true;
        }
        return false;
    }

    
// Add the quickSort function
function quickSort(address[] memory members, uint256[] memory scores, int left, int right) internal pure {
    int i = left;
    int j = right;
    if (i == j) return;
    uint256 pivot = scores[uint256(left + (right - left) / 2)];
    while (i <= j) {
        while (scores[uint256(i)] > pivot) i++;
        while (pivot > scores[uint256(j)]) j--;
        if (i <= j) {
            (members[uint256(i)], members[uint256(j)]) = (members[uint256(j)], members[uint256(i)]);
            (scores[uint256(i)], scores[uint256(j)]) = (scores[uint256(j)], scores[uint256(i)]);
            i++;
            j--;
        }
    }
    if (left < j)
        quickSort(members, scores, left, j);
    if (i < right)
        quickSort(members, scores, i, right);
}

    // Getter functions
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

    function getGroupMembers(uint256 groupId) public view returns (address[] memory) {
        require(groupId < groups.length, "Invalid group ID");
        return groups[groupId].members;
    }

    function getGroupCount() public view returns (uint256) {
        return groups.length;
    }

    function getLastRoomSizes() public view returns (uint8[] memory) {
        return lastRoomSizes;
    }

    function getDetailedGroupInfo() public view returns (uint256[] memory groupIds, uint256[] memory groupSizes) {
        groupIds = new uint256[](groups.length);
        groupSizes = new uint256[](groups.length);
        for (uint256 i = 0; i < groups.length; i++) {
            groupIds[i] = i;
            groupSizes[i] = groups[i].members.length;
        }
    }

    function getWeeklyContributors(uint256 _communityId, uint256 _week) public view returns (address[] memory) {
        return weeklyContributors[_communityId][_week];
    }

 // Update the getConsensusRanking function
function getConsensusRanking(uint256 _communityId, uint256 _weekNumber, uint256 _groupId) public view returns (address[] memory rankedAddresses, uint256[] memory scores, uint256 timestamp) {
    ConsensusRanking storage consensusRanking = consensusRankings[_communityId][_weekNumber][_groupId];
    return (consensusRanking.rankedAddresses, consensusRanking.scores, consensusRanking.timestamp);
}

    function getRanking(uint256 _communityId, uint256 _weekNumber, uint256 _groupId, address _user) public view returns (address[] memory) {
        Ranking storage ranking = rankings[_communityId][_weekNumber][_groupId][_user];
        return ranking.rankedAddresses.length > 0 ? ranking.rankedAddresses : new address[](0);
    }
// Add this function for debugging and verification
function getTransientScores(uint256 _communityId, uint256 _weekNumber, uint256 _groupId) public view returns (address[] memory, uint256[] memory) {
    Group storage group = groups[_groupId];
    uint256 groupSize = group.members.length;
    address[] memory members = new address[](groupSize);
    uint256[] memory scores = new uint256[](groupSize);

    for (uint256 i = 0; i < groupSize; i++) {
        members[i] = group.members[i];
        scores[i] = calculateTransientScore(_communityId, _weekNumber, _groupId, group.members[i]);
    }

    return (members, scores);
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