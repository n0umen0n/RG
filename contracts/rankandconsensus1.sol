// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICommunityGovernanceContributions {
    struct Group {
        address[] members;
    }
    function getGroupsForWeek(uint256 _communityId, uint256 _weekNumber) external view returns (Group[] memory);
}
/**
 * @title CommunityGovernance
 * @dev Manages community creation, membership, and contributions
 * @custom:dev-run-script /script/threetogether.js
*/
contract CommunityGovernanceRankings {
    ICommunityGovernanceContributions public contributionsContract;

    uint256 constant SCALE = 1e18;

    struct Ranking {
        address[] rankedAddresses;
    }

    struct ConsensusRanking {
        address[] rankedAddresses;
        uint256[] scores;
        uint256 timestamp;
    }

    mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(address => Ranking)))) private rankings;
    mapping(uint256 => mapping(uint256 => mapping(uint256 => ConsensusRanking))) private consensusRankings;

    event RankingSubmitted(uint256 indexed communityId, uint256 weekNumber, uint256 groupId, address indexed submitter);
    event ConsensusReached(uint256 indexed communityId, uint256 weekNumber, uint256 groupId, address[] consensusRanking);

    constructor(address _contributionsContractAddress) {
        contributionsContract = ICommunityGovernanceContributions(_contributionsContractAddress);
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

     function determineConsensus(uint256 _communityId, uint256 _weekNumber, uint256 _groupId) public {
        ICommunityGovernanceContributions.Group[] memory groups = contributionsContract.getGroupsForWeek(_communityId, _weekNumber);
        require(_groupId < groups.length, "Invalid group ID");
        ICommunityGovernanceContributions.Group memory group = groups[_groupId];
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

  function calculateTransientScore(uint256 _communityId, uint256 _weekNumber, uint256 _groupId, address _member) private view returns (uint256) {
    ICommunityGovernanceContributions.Group[] memory groups = contributionsContract.getGroupsForWeek(_communityId, _weekNumber);
    require(_groupId < groups.length, "Invalid group ID");
    ICommunityGovernanceContributions.Group memory group = groups[_groupId];
    uint256 groupSize = group.members.length;
    uint256[] memory individualRankings = new uint256[](groupSize);
    uint256 rankingCount = 0;
    uint256 totalRanking = 0;

    for (uint256 i = 0; i < groupSize; i++) {
        address ranker = group.members[i];
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

     function calculateMaxVariance(uint256 groupSize) private pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 x = 1; x < groupSize; x++) {
            sum += x * (x + 1) / 2;
        }
        return (groupSize * sum * SCALE) / (groupSize - 1);
    }
     function calculateConsensusTerm(uint256[] memory individualRankings, uint256 count, uint256 groupSize) private pure returns (uint256) {
        if (count <= 1) return SCALE;

        uint256 variance = calculateVariance(individualRankings, count);
        uint256 maxVariance = calculateMaxVariance(groupSize);
        
        return SCALE - ((variance * SCALE) / maxVariance);
    }
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

  function isPartOfGroup(uint256 _communityId, uint256 _weekNumber, uint256 _groupId, address _member) private view returns (bool) {
        ICommunityGovernanceContributions.Group[] memory groups = contributionsContract.getGroupsForWeek(_communityId, _weekNumber);
        require(_groupId < groups.length, "Invalid group ID");
        ICommunityGovernanceContributions.Group memory group = groups[_groupId];
        for (uint256 i = 0; i < group.members.length; i++) {
            if (group.members[i] == _member) return true;
        }
        return false;
    }
    // Getter functions
    function getConsensusRanking(uint256 _communityId, uint256 _weekNumber, uint256 _groupId) public view returns (address[] memory rankedAddresses, uint256[] memory scores, uint256 timestamp) {
        ConsensusRanking storage consensusRanking = consensusRankings[_communityId][_weekNumber][_groupId];
        return (consensusRanking.rankedAddresses, consensusRanking.scores, consensusRanking.timestamp);
    }

    function getRanking(uint256 _communityId, uint256 _weekNumber, uint256 _groupId, address _user) public view returns (address[] memory) {
        Ranking storage ranking = rankings[_communityId][_weekNumber][_groupId][_user];
        return ranking.rankedAddresses.length > 0 ? ranking.rankedAddresses : new address[](0);
    }

    function getTransientScores(uint256 _communityId, uint256 _weekNumber, uint256 _groupId) public view returns (address[] memory, uint256[] memory) {
        ICommunityGovernanceContributions.Group[] memory groups = contributionsContract.getGroupsForWeek(_communityId, _weekNumber);
        require(_groupId < groups.length, "Invalid group ID");
        ICommunityGovernanceContributions.Group memory group =  groups[_groupId];
        uint256 groupSize = group.members.length;
        address[] memory members = new address[](groupSize);
        uint256[] memory scores = new uint256[](groupSize);

        for (uint256 i = 0; i < groupSize; i++) {
            members[i] = group.members[i];
            scores[i] = calculateTransientScore(_communityId, _weekNumber, _groupId, group.members[i]);
        }

        return (members, scores);
    }
}