// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";



contract CommunityRespectToken is ERC1155, Ownable {
    constructor(address initialOwner) ERC1155("") Ownable(initialOwner) {
     console.log("Contract is being deployed!");
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data) public onlyOwner {
        _mint(account, id, amount, data);
    }

    function burn(address account, uint256 id, uint256 amount) public onlyOwner {
        _burn(account, id, amount);
    }

    // Disable transfers
    function safeTransferFrom(address, address, uint256, uint256, bytes memory) public pure override {
        revert("Transfers are not allowed");
    }

    function safeBatchTransferFrom(address, address, uint256[] memory, uint256[] memory, bytes memory) public pure override {
        revert("Transfers are not allowed");
    }
}
/**
 * @title CommunityGovernance
 * @dev Manages community creation, membership, and contributions
 * @custom:dev-run-script /script/create_communities.js
*/
contract CommunityGovernance {

 constructor() {
        respectToken = new CommunityRespectToken(address(this));
    }

    struct CommunityData {
        uint256 communityId;
        uint256 totalRespect;
        uint256 averageRespect;
        bool isApproved;
        address[] approvers;
    }

    struct UserProfile {
        string username;
        string description;
        string profilePicUrl;
        mapping(uint256 => CommunityData) communityData;
    }

     enum CommunityState { Regular, ContributionSubmission, ContributionRanking }

    struct Community {
        string name;
        string description;
        string imageUrl;
        address creator;
        uint256 memberCount;
        address[] members;
        CommunityState state;
        uint256 eventCount;
        uint256 nextContributionTime;
        address tokenContractAddress;
        uint256 respectToDistribute;
    }

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

    struct ContributionInput {
        string name;
        string description;
        string[] links;
    }

    struct ContributionView {
    string name;
    string description;
    string[] links;
}

    struct Group {
        address[] members;
    }

    struct MemberContributions {
        Contribution[] contributions;
    }

    uint8[] private lastRoomSizes;
    Group[] private groups;
    mapping(uint256 => mapping(address => MemberContributions)) private groupContributions;
    mapping(address => bool) public hasContributed;
    mapping(address => mapping(uint256 => UserContributions)) public userContributions;
    mapping(address => UserProfile) public users;
    mapping(uint256 => Community) public communities;
    uint256 public nextCommunityId = 1;

    CommunityRespectToken public respectToken;

    event ContributionSubmitted(address indexed user, uint256 indexed communityId, uint256 weekNumber, uint256 contributionIndex);
    event ProfileCreated(address indexed user, string username, bool isNewProfile);
    event CommunityJoined(address indexed user, uint256 indexed communityId, bool isApproved);
    event UserApproved(address indexed user, uint256 indexed communityId, address indexed approver);
    event CommunityCreated(uint256 indexed communityId, string name, address indexed creator);


function submitContributions(
    uint256 _communityId,
    ContributionInput[] memory _contributions
) public {
    require(bytes(users[msg.sender].username).length > 0, "Profile must exist to submit contributions");
    require(_communityId > 0 && _communityId < nextCommunityId, "Invalid community ID");
    require(users[msg.sender].communityData[_communityId].communityId != 0, "User not part of this community");
    require(_contributions.length > 0, "Must submit at least one contribution");

    Community storage community = communities[_communityId];
    uint256 currentWeek = community.eventCount;  // Use eventCount as the current week

    UserContributions storage userContrib = userContributions[msg.sender][_communityId];

    if (userContrib.communityId == 0) {
        userContrib.communityId = _communityId;
    }

    WeeklyContributions storage weeklyContrib = userContrib.weeklyContributions[currentWeek];

    // Always clear existing contributions for this week
    delete weeklyContrib.contributions;

    // Set or update the week number
    weeklyContrib.weekNumber = currentWeek;

    // Ensure the current week is in the contributedWeeks array
    if (userContrib.contributedWeeks.length == 0 || userContrib.contributedWeeks[userContrib.contributedWeeks.length - 1] != currentWeek) {
        userContrib.contributedWeeks.push(currentWeek);
    }

    // Add all new contributions
    for (uint256 i = 0; i < _contributions.length; i++) {
        Contribution memory newContribution = Contribution({
            name: _contributions[i].name,
            description: _contributions[i].description,
            links: _contributions[i].links
        });

        weeklyContrib.contributions.push(newContribution);
    }


    // Emit a single event to indicate that contributions for the week have been updated
    emit ContributionSubmitted(msg.sender, _communityId, currentWeek, _contributions.length);
}

    function createCommunity(string memory _name, string memory _description, string memory _imageUrl) public returns (uint256) {
    // Check if user profile exists, if not, create one
    if (bytes(users[msg.sender].username).length == 0) {
        UserProfile storage newUser = users[msg.sender];
        newUser.username = "First";
        newUser.description = "Creator of community";
        newUser.profilePicUrl = ""; // Empty profile picture
        emit ProfileCreated(msg.sender, newUser.username, true);
    }

    uint256 newCommunityId = nextCommunityId;
    Community storage newCommunity = communities[newCommunityId];
    
    newCommunity.name = _name;
    newCommunity.description = _description;
    newCommunity.imageUrl = _imageUrl;
    newCommunity.creator = msg.sender;
    newCommunity.memberCount = 1;
    newCommunity.members.push(msg.sender);
    newCommunity.state = CommunityState.Regular;
    newCommunity.eventCount = 0;
    newCommunity.nextContributionTime = block.timestamp + 1 weeks;
    newCommunity.tokenContractAddress = address(respectToken);
    newCommunity.respectToDistribute = 0;

    nextCommunityId++;

    CommunityData storage creatorCommunityData = users[msg.sender].communityData[newCommunityId];
    creatorCommunityData.communityId = newCommunityId;
    creatorCommunityData.totalRespect = 0;
    creatorCommunityData.averageRespect = 0;
    creatorCommunityData.isApproved = true; // Creator is automatically approved


    emit CommunityCreated(newCommunityId, _name, msg.sender);
    emit CommunityJoined(msg.sender, newCommunityId, true);

    return newCommunityId;
}

    function approveUser(address _user, uint256 _communityId) public {
        require(bytes(users[msg.sender].username).length > 0, "Approver profile does not exist");
        require(bytes(users[_user].username).length > 0, "User profile to approve does not exist");
        require(communities[_communityId].memberCount > 5, "Approval not required for first 5 members");

        CommunityData storage approverData = users[msg.sender].communityData[_communityId];
        require(approverData.communityId != 0, "Approver not part of this community");
        require(approverData.isApproved, "Approver must be an approved member of the community");

        CommunityData storage userData = users[_user].communityData[_communityId];
        require(userData.communityId != 0, "User not part of this community");
        require(!userData.isApproved, "User already approved");
        require(userData.approvers.length < 2, "User already has 2 approvals");

        for (uint i = 0; i < userData.approvers.length; i++) {
            require(userData.approvers[i] != msg.sender, "Approver has already approved this user");
        }

        userData.approvers.push(msg.sender);

        if (userData.approvers.length == 2) {
            userData.isApproved = true;
            userData.totalRespect = 0;
            userData.averageRespect = 0;
        }

        emit UserApproved(_user, _communityId, msg.sender);
    }


    function createProfileAndJoinCommunity(
        string memory _username,
        string memory _description,
        string memory _profilePicUrl,
        uint256 _communityId
    ) public {
        require(_communityId > 0 && _communityId < nextCommunityId, "Invalid community ID");

        UserProfile storage user = users[msg.sender];
        bool isNewProfile = bytes(user.username).length == 0;

        if (isNewProfile) {
            user.username = _username;
            user.description = _description;
            user.profilePicUrl = _profilePicUrl;
        }

        require(user.communityData[_communityId].communityId == 0, "Already joined this community");

        Community storage community = communities[_communityId];
        bool isApproved = community.memberCount < 5;

        CommunityData storage newCommunityData = user.communityData[_communityId];
        newCommunityData.communityId = _communityId;
        newCommunityData.totalRespect = 0;
        newCommunityData.averageRespect = 0;
        newCommunityData.isApproved = isApproved;

        community.memberCount++;
        community.members.push(msg.sender);

        emit ProfileCreated(msg.sender, _username, isNewProfile);
        emit CommunityJoined(msg.sender, _communityId, isApproved);
    }

function createGroups(address[] memory participants) public {
        require(participants.length > 0, "No participants");

        delete groups;
        shuffle(participants);

        uint8[] memory roomSizes = determineRoomSizes(participants.length);

        uint256 participantIndex = 0;
        for (uint256 i = 0; i < roomSizes.length; i++) {
            address[] memory groupMembers = new address[](roomSizes[i]);
            for (uint256 j = 0; j < roomSizes[i] && participantIndex < participants.length; j++) {
                groupMembers[j] = participants[participantIndex];
                participantIndex++;
            }
            groups.push(Group(groupMembers));
        }

    }

    function shuffle(address[] memory array) internal view {
        for (uint256 i = array.length - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i))) % (i + 1);
            (array[i], array[j]) = (array[j], array[i]);
        }
    }

    function determineRoomSizes(uint256 numParticipants) internal pure returns (uint8[] memory) {
        if (numParticipants <= 20) {
            return hardcodedRoomSizes(numParticipants);
        } else {
            return genericRoomSizes(numParticipants);
        }
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



    function getCommunityMembers(uint256 _communityId) public view returns (
        address[] memory memberAddresses,
        string[] memory memberUsernames,
        uint256[] memory totalRespects,
        uint256[] memory averageRespects
    ) {
        require(_communityId > 0 && _communityId < nextCommunityId, "Invalid community ID");
        
        Community storage community = communities[_communityId];
        uint256 memberCount = community.memberCount;
        
        memberAddresses = new address[](memberCount);
        memberUsernames = new string[](memberCount);
        totalRespects = new uint256[](memberCount);
        averageRespects = new uint256[](memberCount);
        
        for (uint256 i = 0; i < memberCount; i++) {
            address memberAddress = community.members[i];
            UserProfile storage user = users[memberAddress];
            CommunityData storage communityData = user.communityData[_communityId];
            
            memberAddresses[i] = memberAddress;
            memberUsernames[i] = user.username;
            totalRespects[i] = communityData.totalRespect;
            averageRespects[i] = communityData.averageRespect;
        }
    }

/*
function getContributions(address _user, uint256 _communityId, uint256 _weekNumber) public view returns (Contribution[] memory) {
    require(userContributions[_user][_communityId].communityId != 0, "No contributions found for this user in this community");
    return userContributions[_user][_communityId].weeklyContributions[_weekNumber].contributions;
}
*/

function getContributions(address _user, uint256 _communityId, uint256 _weekNumber) 
    public 
    view 
    returns (string[] memory names, string[] memory descriptions, string[][] memory links)
{
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
    
    return (names, descriptions, links);
}

function getUserContributedWeeks(address _user, uint256 _communityId) public view returns (uint256[] memory) {
    require(userContributions[_user][_communityId].communityId != 0, "No contributions found for this user in this community");
    return userContributions[_user][_communityId].contributedWeeks;
}

    function getUserProfile(address _user) public view returns (string memory, string memory, string memory) {
        require(bytes(users[_user].username).length > 0, "Profile does not exist");
        UserProfile storage user = users[_user];
        return (user.username, user.description, user.profilePicUrl);
    }

    function getUserCommunityData(address _user, uint256 _communityId) public view returns (uint256, uint256, uint256, bool, address[] memory) {
        require(bytes(users[_user].username).length > 0, "Profile does not exist");
        CommunityData storage communityData = users[_user].communityData[_communityId];
        require(communityData.communityId != 0, "User not part of this community");
        return (communityData.communityId, communityData.totalRespect, communityData.averageRespect, communityData.isApproved, communityData.approvers);
    }

    function getCommunityProfile(uint256 _communityId) public view returns (string memory, string memory, string memory, address, uint256) {
        require(_communityId > 0 && _communityId < nextCommunityId, "Invalid community ID");
        Community storage community = communities[_communityId];
        return (community.name, community.description, community.imageUrl, community.creator, community.memberCount);
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

    function getDetailedGroupInfo() public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory groupIds = new uint256[](groups.length);
        uint256[] memory groupSizes = new uint256[](groups.length);
        for (uint256 i = 0; i < groups.length; i++) {
            groupIds[i] = i;
            groupSizes[i] = groups[i].members.length;
        }
        return (groupIds, groupSizes);
    }

}



