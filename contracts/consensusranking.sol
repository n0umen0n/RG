// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/**
 * @title CommunityGovernance
 * @dev Manages community creation, membership, and contributions
 * @custom:dev-run-script /script/consensusranking.js
*/
contract SimpleConsensus {
    struct Ranking {
        uint256[] rankedScores;
    }

    struct Group {
        address[] members;
    }

    Group private group;
    mapping(address => Ranking) private rankings;
    uint256[] public consensusRanking;

    event GroupInitialized(address[] members);
    event RankingSubmitted(address indexed submitter, uint256[] ranking);
    event ConsensusReached(uint256[] consensusRanking);
    event DebugLog(string message, uint256 value);

    constructor(address[] memory _members) {
        require(_members.length > 1, "Group must have at least 2 members");
        group.members = _members;
        emit GroupInitialized(_members);
    }

    

    function submitRanking(uint256[] memory _ranking) public {
        require(isGroupMember(msg.sender), "Only group members can submit rankings");
        require(_ranking.length == group.members.length, "Ranking must include all group members");
        
        rankings[msg.sender].rankedScores = _ranking;
        emit RankingSubmitted(msg.sender, _ranking);
    }

    function determineConsensus() public {
        require(allMembersSubmitted(), "Not all members have submitted rankings");

        address[] memory members = group.members;
        uint256[] memory transientScores = new uint256[](members.length);

        for (uint256 i = 0; i < members.length; i++) {
            transientScores[i] = calculateTransientScore(i);
            emit DebugLog("Transient score for member", transientScores[i]);
        }

        consensusRanking = sortByScore(transientScores);
        emit ConsensusReached(consensusRanking);
    }


function calculateTransientScore(uint256 memberIndex) private view returns (uint256) {
    uint256[] memory memberRankings = new uint256[](group.members.length);
    for (uint256 i = 0; i < group.members.length; i++) {
        memberRankings[i] = rankings[group.members[i]].rankedScores[memberIndex];
    }

    uint256 meanRanking = calculateMean(memberRankings);
    uint256 variance = calculateVariance(memberRankings);
    uint256 maxVariance = calculateMaxVariance(group.members.length);
    
    uint256 consensusTerm;
    if (maxVariance == 0) {
        consensusTerm = 1e18;
    } else {
        consensusTerm = 1e18 - ((variance * 1e18) / maxVariance);
    }

    // Use higher precision for multiplication and then scale down
    return (meanRanking * consensusTerm) / 1e18;
}
function calculateMean(uint256[] memory values) private pure returns (uint256) {
    uint256 sum = 0;
    for (uint256 i = 0; i < values.length; i++) {
        sum += values[i];
    }
    return (sum * 1e18) / values.length;
}

    function calculateConsensusTerm(uint256[] memory rankingScores) private pure returns (uint256) {
        uint256 variance = calculateVariance(rankingScores);
        uint256 maxVariance = calculateMaxVariance(rankingScores.length);
        
        if (maxVariance == 0) return 1e18; // Avoid division by zero, return 1 in fixed-point representation
        
        return 1e18 - ((variance * 1e18) / maxVariance); // Use fixed-point arithmetic
    }

function calculateVariance(uint256[] memory values) private pure returns (uint256) {
    uint256 mean = calculateMean(values);
    uint256 sumSquaredDiff = 0;
    for (uint256 i = 0; i < values.length; i++) {
        int256 diff = int256(values[i] * 1e18) - int256(mean);
        sumSquaredDiff += uint256(diff * diff) / 1e18;
    }
    return sumSquaredDiff / values.length;
}

function calculateMaxVariance(uint256 groupSize) private pure returns (uint256) {
    uint256 sum = 0;
    for (uint256 x = 1; x < groupSize; x++) {
        sum += x * 1e18 / 2;
    }
    return (groupSize * sum) / (groupSize - 1);
}
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

    function isGroupMember(address _member) private view returns (bool) {
        for (uint256 i = 0; i < group.members.length; i++) {
            if (group.members[i] == _member) return true;
        }
        return false;
    }

    function allMembersSubmitted() private view returns (bool) {
        for (uint256 i = 0; i < group.members.length; i++) {
            if (rankings[group.members[i]].rankedScores.length == 0) {
                return false;
            }
        }
        return true;
    }

    // Getter functions for testing
    function getGroupMembers() public view returns (address[] memory) {
        return group.members;
    }

    function getRanking(address _member) public view returns (uint256[] memory) {
        return rankings[_member].rankedScores;
    }

    function getConsensusRanking() public view returns (uint256[] memory) {
        return consensusRanking;
    }
}