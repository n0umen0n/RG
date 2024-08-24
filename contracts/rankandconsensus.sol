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
        uint256[] rankedScores;
    }

    struct ConsensusRanking {
        uint256[] rankedScores;
        uint256[] transientScores;
        uint256 timestamp;
    }

    mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(address => Ranking)))) private rankings;
    mapping(uint256 => mapping(uint256 => mapping(uint256 => ConsensusRanking))) private consensusRankings;

    event RankingSubmitted(uint256 indexed communityId, uint256 weekNumber, uint256 groupId, address indexed submitter);
    event ConsensusReached(uint256 indexed communityId, uint256 weekNumber, uint256 groupId, uint256[] consensusRanking);
    event DebugLog(string message, uint256 value);

    constructor(address _contributionsContractAddress) {
        contributionsContract = ICommunityGovernanceContributions(_contributionsContractAddress);
    }

    function submitRanking(uint256 _communityId, uint256 _weekNumber, uint256 _groupId, uint256[] memory _ranking) public {
        ICommunityGovernanceContributions.Group[] memory groups = contributionsContract.getGroupsForWeek(_communityId, _weekNumber);
        require(_groupId < groups.length, "Invalid group ID");
        ICommunityGovernanceContributions.Group memory group = groups[_groupId];
        require(_ranking.length == group.members.length, "Ranking must include all group members");
        require(isPartOfGroup(group, msg.sender), "Sender not part of the group");
        require(rankings[_communityId][_weekNumber][_groupId][msg.sender].rankedScores.length == 0, "Ranking already submitted");

        rankings[_communityId][_weekNumber][_groupId][msg.sender] = Ranking(_ranking);
        emit RankingSubmitted(_communityId, _weekNumber, _groupId, msg.sender);
    }

    function determineConsensus(uint256 _communityId, uint256 _weekNumber, uint256 _groupId) public {
        ICommunityGovernanceContributions.Group[] memory groups = contributionsContract.getGroupsForWeek(_communityId, _weekNumber);
        require(_groupId < groups.length, "Invalid group ID");
        ICommunityGovernanceContributions.Group memory group = groups[_groupId];
        require(group.members.length > 0, "Group does not exist");
        require(allMembersSubmitted(_communityId, _weekNumber, _groupId, group), "Not all members have submitted rankings");

        uint256 groupSize = group.members.length;
        uint256[] memory transientScores = new uint256[](groupSize);

        for (uint256 i = 0; i < groupSize; i++) {
            transientScores[i] = calculateTransientScore(_communityId, _weekNumber, _groupId, i, group);
            emit DebugLog("Transient score for member", transientScores[i]);
        }

        uint256[] memory consensusRanking = sortByScore(transientScores);
        consensusRankings[_communityId][_weekNumber][_groupId] = ConsensusRanking(consensusRanking, transientScores, block.timestamp);
        emit ConsensusReached(_communityId, _weekNumber, _groupId, consensusRanking);
    }

    function calculateTransientScore(uint256 _communityId, uint256 _weekNumber, uint256 _groupId, uint256 memberIndex, ICommunityGovernanceContributions.Group memory group) private view returns (uint256) {
        uint256[] memory memberRankings = new uint256[](group.members.length);
        for (uint256 i = 0; i < group.members.length; i++) {
            memberRankings[i] = rankings[_communityId][_weekNumber][_groupId][group.members[i]].rankedScores[memberIndex];
        }

        uint256 meanRanking = calculateMean(memberRankings);
        uint256 variance = calculateVariance(memberRankings);
        uint256 maxVariance = calculateMaxVariance(group.members.length);
        
        uint256 consensusTerm;
        if (maxVariance == 0) {
            consensusTerm = SCALE;
        } else {
            consensusTerm = SCALE - ((variance * SCALE) / maxVariance);
        }

        return (meanRanking * consensusTerm) / SCALE;
    }

    function calculateMean(uint256[] memory values) private pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < values.length; i++) {
            sum += values[i];
        }
        return (sum * SCALE) / values.length;
    }

    function calculateVariance(uint256[] memory values) private pure returns (uint256) {
        uint256 mean = calculateMean(values);
        uint256 sumSquaredDiff = 0;
        for (uint256 i = 0; i < values.length; i++) {
            int256 diff = int256(values[i] * SCALE) - int256(mean);
            sumSquaredDiff += uint256(diff * diff) / SCALE;
        }
        return sumSquaredDiff / values.length;
    }

    function calculateMaxVariance(uint256 groupSize) private pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 x = 1; x < groupSize; x++) {
            sum += x * SCALE / 2;
        }
        return (groupSize * sum) / (groupSize - 1);
    }
/*
    function sortByScore(uint256[] memory _scores) private pure returns (uint256[] memory) {
        uint256[] memory indices = new uint256[](_scores.length);
        for (uint256 i = 0; i < indices.length; i++) {
            indices[i] = i;
        }

        for (uint256 i = 0; i < _scores.length - 1; i++) {
            for (uint256 j = i + 1; j < _scores.length; j++) {
                if (_scores[i] < _scores[j]) {
                    (_scores[i], _scores[j]) = (_scores[j], _scores[i]);
                    (indices[i], indices[j]) = (indices[j], indices[i]);
                }
            }
        }

        uint256[] memory finalRanking = new uint256[](_scores.length);
        for (uint256 i = 0; i < finalRanking.length; i++) {
            finalRanking[indices[i]] = _scores.length - i;
        }

        return finalRanking;
    }
*/
function sortByScore(uint256[] memory _scores) private pure returns (uint256[] memory) {
    uint256[] memory indices = new uint256[](_scores.length);
    for (uint256 i = 0; i < indices.length; i++) {
        indices[i] = i;
    }

    for (uint256 i = 0; i < _scores.length - 1; i++) {
        for (uint256 j = i + 1; j < _scores.length; j++) {
            if (_scores[indices[i]] < _scores[indices[j]]) {
                (indices[i], indices[j]) = (indices[j], indices[i]);
            }
        }
    }

    uint256[] memory finalRanking = new uint256[](_scores.length);
    for (uint256 i = 0; i < finalRanking.length; i++) {
        finalRanking[indices[i]] = _scores.length - i;
    }

    return finalRanking;
}
    function isPartOfGroup(ICommunityGovernanceContributions.Group memory group, address _member) private pure returns (bool) {
        for (uint256 i = 0; i < group.members.length; i++) {
            if (group.members[i] == _member) return true;
        }
        return false;
    }

    function allMembersSubmitted(uint256 _communityId, uint256 _weekNumber, uint256 _groupId, ICommunityGovernanceContributions.Group memory group) private view returns (bool) {
        for (uint256 i = 0; i < group.members.length; i++) {
            if (rankings[_communityId][_weekNumber][_groupId][group.members[i]].rankedScores.length == 0) {
                return false;
            }
        }
        return true;
    }

    // Getter functions
    function getConsensusRanking(uint256 _communityId, uint256 _weekNumber, uint256 _groupId) public view returns (uint256[] memory rankedScores, uint256[] memory transientScores, uint256 timestamp) {
        ConsensusRanking storage consensusRanking = consensusRankings[_communityId][_weekNumber][_groupId];
        return (consensusRanking.rankedScores, consensusRanking.transientScores, consensusRanking.timestamp);
    }

    function getRanking(uint256 _communityId, uint256 _weekNumber, uint256 _groupId, address _user) public view returns (uint256[] memory) {
        return rankings[_communityId][_weekNumber][_groupId][_user].rankedScores;
    }

    function getTransientScores(uint256 _communityId, uint256 _weekNumber, uint256 _groupId) public view returns (address[] memory, uint256[] memory) {
        ICommunityGovernanceContributions.Group[] memory groups = contributionsContract.getGroupsForWeek(_communityId, _weekNumber);
        require(_groupId < groups.length, "Invalid group ID");
        ICommunityGovernanceContributions.Group memory group = groups[_groupId];
        uint256 groupSize = group.members.length;
        address[] memory members = new address[](groupSize);
        uint256[] memory scores = new uint256[](groupSize);

        for (uint256 i = 0; i < groupSize; i++) {
            members[i] = group.members[i];
            scores[i] = calculateTransientScore(_communityId, _weekNumber, _groupId, i, group);
        }

        return (members, scores);
    }
}