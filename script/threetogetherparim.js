(async () => {
  try {
    console.log('Starting script execution...');

    const accounts = await web3.eth.getAccounts();
    console.log('Accounts loaded:', accounts.length, 'accounts available');

    const deployerAccount = accounts[0];
    const usableAccounts = accounts.filter(account => account !== deployerAccount);

    // Deploy CommunityGovernanceProfiles contract
    console.log('Deploying CommunityGovernanceProfiles contract...');
    const profilesMetadataContent = await remix.call('fileManager', 'getFile', 'contracts/artifacts/CommunityGovernanceProfiles.json');
    const profilesMetadata = JSON.parse(profilesMetadataContent);

    let profilesContract = new web3.eth.Contract(profilesMetadata.abi);
    profilesContract = profilesContract.deploy({
      data: profilesMetadata.data.bytecode.object,
      arguments: []
    });

    const profilesGasEstimate = await profilesContract.estimateGas({ from: deployerAccount });
    let communityGovernanceProfiles = await profilesContract.send({
      from: deployerAccount,
      gas: Math.max(profilesGasEstimate * 2, 8000000),
      gasPrice: '30000000000'
    });

    console.log('CommunityGovernanceProfiles deployed at:', communityGovernanceProfiles.options.address);

    // Configure CommunityGovernanceProfiles
    console.log('Configuring CommunityGovernanceProfiles...');

    // Create three communities
    const communities = [
      { name: "Tech Enthusiasts", description: "A community for tech lovers", imageUrl: "https://example.com/tech.jpg", memberCount: 7 },
      { name: "Green Earth", description: "Environmentally conscious group", imageUrl: "https://example.com/earth.jpg", memberCount: 16 },
      { name: "Book Club", description: "For avid readers", imageUrl: "https://example.com/book.jpg", memberCount: 23 }
    ];

    for (let i = 0; i < communities.length; i++) {
      const { name, description, imageUrl } = communities[i];
      await communityGovernanceProfiles.methods.createCommunity(name, description, imageUrl).send({ from: deployerAccount, gas: 3000000 });
      console.log(`Community created: ${name}`);
    }

    // Add members to each community
    const membersNeedingApproval = {};

    for (let communityId = 1; communityId <= communities.length; communityId++) {
      const memberCount = communities[communityId - 1].memberCount;
      membersNeedingApproval[communityId] = [];
      
      for (let j = 0; j < memberCount; j++) {
        const memberAccount = usableAccounts[j % usableAccounts.length];
        const username = `User${communityId}_${j + 1}`;
        const userDescription = `Member of community ${communityId}`;
        const profilePicUrl = `https://example.com/user${communityId}_${j + 1}.jpg`;

        try {
          await communityGovernanceProfiles.methods.createProfileAndJoinCommunity(
            username,
            userDescription,
            profilePicUrl,
            communityId
          ).send({ from: memberAccount, gas: 3000000 });

          console.log(`Added ${username} (${memberAccount}) to community ${communityId}`);

          // Members after the 5th need approval
          if (j >= 5) {
            membersNeedingApproval[communityId].push(memberAccount);
          }
        } catch (error) {
          console.log(`Failed to add ${username} to community ${communityId}. Reason: ${error.message}`);
        }
      }
    }

    // Approve users
    for (let communityId = 1; communityId <= communities.length; communityId++) {
      const approvers = usableAccounts.slice(0, 2); // Use the first two accounts as approvers
      
      for (const memberToApprove of membersNeedingApproval[communityId]) {
        for (const approver of approvers) {
          try {
            await communityGovernanceProfiles.methods.approveUser(memberToApprove, communityId)
              .send({ from: approver, gas: 3000000 });
            console.log(`User ${memberToApprove} approved by ${approver} in community ${communityId}`);
          } catch (error) {
            console.log(`Failed to approve user ${memberToApprove} by ${approver} in community ${communityId}. Reason: ${error.message}`);
          }
        }
        
        // Check if the user is now approved
        const userData = await communityGovernanceProfiles.methods.getUserCommunityData(memberToApprove, communityId).call();
        console.log(`User ${memberToApprove} approval status in community ${communityId}: ${userData[3]}`);
      }
    }

    // Deploy CommunityGovernanceContributions contract
    console.log('Deploying CommunityGovernanceContributions contract...');
    const contributionsMetadataContent = await remix.call('fileManager', 'getFile', 'contracts/artifacts/CommunityGovernanceContributions.json');
    const contributionsMetadata = JSON.parse(contributionsMetadataContent);

    let contributionsContract = new web3.eth.Contract(contributionsMetadata.abi);
    contributionsContract = contributionsContract.deploy({
      data: contributionsMetadata.data.bytecode.object,
      arguments: [communityGovernanceProfiles.options.address]
    });

    const contributionsGasEstimate = await contributionsContract.estimateGas({ from: deployerAccount });
    let communityGovernanceContributions = await contributionsContract.send({
      from: deployerAccount,
      gas: Math.max(contributionsGasEstimate * 2, 8000000),
      gasPrice: '30000000000'
    });

    console.log('CommunityGovernanceContributions deployed at:', communityGovernanceContributions.options.address);

    // Deploy CommunityGovernanceRankings contract
    console.log('Deploying CommunityGovernanceRankings contract...');
    const rankingsMetadataContent = await remix.call('fileManager', 'getFile', 'contracts/artifacts/CommunityGovernanceRankings.json');
    const rankingsMetadata = JSON.parse(rankingsMetadataContent);

    let rankingsContract = new web3.eth.Contract(rankingsMetadata.abi);
    rankingsContract = rankingsContract.deploy({
      data: rankingsMetadata.data.bytecode.object,
      arguments: [communityGovernanceContributions.options.address]
    });

    const rankingsGasEstimate = await rankingsContract.estimateGas({ from: deployerAccount });
    let communityGovernanceRankings = await rankingsContract.send({
      from: deployerAccount,
      gas: Math.max(rankingsGasEstimate * 2, 8000000),
      gasPrice: '30000000000'
    });

    console.log('CommunityGovernanceRankings deployed at:', communityGovernanceRankings.options.address);

    async function submitContributions(communityId, targetContributions) {
  console.log(`\nSubmitting contributions for community ${communityId}`);
  const communityMembers = (await communityGovernanceProfiles.methods.getCommunityMembers(communityId).call())[0];
  let successfulContributions = 0;

  for (let i = 0; i < communityMembers.length && successfulContributions < targetContributions; i++) {
    const contributor = communityMembers[i];
    if (contributor === deployerAccount) {
      console.log(`Skipping deployer account ${contributor}`);
      continue; // Skip the deployer account
    }

    const contribution = [{
      name: `Contribution ${successfulContributions + 1}`,
      description: `Description for contribution ${successfulContributions + 1}`,
      links: [`https://example.com/contribution${successfulContributions + 1}`]
    }];

    try {
      // Check if the user is approved in the community
      const userData = await communityGovernanceProfiles.methods.getUserCommunityData(contributor, communityId).call();
      if (!userData[3]) {
        console.log(`Skipping contribution for ${contributor} as they are not approved in the community.`);
        continue;
      }

      console.log(`Attempting to submit contribution for ${contributor}`);
      await communityGovernanceContributions.methods.submitContributions(communityId, contribution)
        .send({ from: contributor, gas: 3000000 });
      console.log(`Contribution submitted by ${contributor}`);
      successfulContributions++;
    } catch (error) {
      console.log(`Failed to submit contribution for ${contributor}. Reason: ${error.message}`);
      if (error.message.includes("already contributed")) {
        console.log(`${contributor} has already contributed this week.`);
      } else {
        console.log('Error details:', JSON.stringify(error, null, 2));
      }
    }
  }

  console.log(`Successfully submitted ${successfulContributions} contributions for community ${communityId}`);
}
    // Submit contributions for each community
    await submitContributions(1, 7);
    await submitContributions(2, 16);
    await submitContributions(3, 23);

    // Function to create groups and log their details
    async function createAndLogGroups(communityId) {
      console.log(`\nCreating groups for community ${communityId}:`);
      
      try {
        await communityGovernanceContributions.methods.createGroupsForCurrentWeek(communityId).send({ from: deployerAccount, gas: 3000000 });
        
        // Log group creation details
        const eventCount = await communityGovernanceProfiles.methods.getCommunityProfile(communityId).call();
        const currentWeek = eventCount[4];
        const groups = await communityGovernanceContributions.methods.getGroupsForWeek(communityId, currentWeek).call();

        console.log(`Total groups created: ${groups.length}`);

        for (let i = 0; i < groups.length; i++) {
          console.log(`Group ${i}: ${groups[i].members.length} members`);
          console.log('Members:', groups[i].members);
        }

        // Get and log weekly contributors
        const weeklyContributors = await communityGovernanceContributions.methods.getWeeklyContributors(communityId, currentWeek).call();
        console.log(`Weekly contributors for community ${communityId}, week ${currentWeek}:`, weeklyContributors);
        console.log(`Number of contributors: ${weeklyContributors.length}`);
      } catch (error) {
        console.log(`Failed to create groups for community ${communityId}. Reason: ${error.message}`);
        console.log('Error details:', JSON.stringify(error, null, 2));
      }
    }

    // Create groups for each community
    for (let communityId = 1; communityId <= communities.length; communityId++) {
      await createAndLogGroups(communityId);
    }

    async function submitRankings(communityId) {
      console.log(`\nSubmitting rankings for community ${communityId}`);
      const eventCount = await communityGovernanceProfiles.methods.getCommunityProfile(communityId).call();
      const currentWeek = eventCount[4];
      const groups = await communityGovernanceContributions.methods.getGroupsForWeek(communityId, currentWeek).call();

      for (let groupId = 0; groupId < groups.length; groupId++) {
        const members = groups[groupId].members;
        for (const member of members) {
          try {
            // Create a random ranking of group members (as an array of addresses)
            let ranking = [...members];
            ranking.sort(() => Math.random() - 0.5);

            await communityGovernanceRankings.methods.submitRanking(communityId, currentWeek, groupId, ranking)
              .send({ from: member, gas: 3000000 });
            console.log(`Ranking submitted by ${member} for group ${groupId}`);
          } catch (error) {
            console.log(`Failed to submit ranking for ${member} in group ${groupId}. Reason: ${error.message}`);
            console.log('Error details:', JSON.stringify(error, null, 2));
          }
        }
      }
    }

    // Submit rankings for each community
    for (let communityId = 1; communityId <= communities.length; communityId++) {
      await submitRankings(communityId);
    }

    // Function to determine consensus
    async function determineConsensus(communityId) {
      console.log(`\nDetermining consensus for community ${communityId}`);
      const eventCount = await communityGovernanceProfiles.methods.getCommunityProfile(communityId).call();
      const currentWeek = eventCount[4];
      const groups = await communityGovernanceContributions.methods.getGroupsForWeek(communityId, currentWeek).call();

      for (let groupId = 0; groupId < groups.length; groupId++) {
        try {
          await communityGovernanceRankings.methods.determineConsensus(communityId, currentWeek, groupId)
            .send({ from: deployerAccount, gas: 3000000 });
          console.log(`Consensus determined for group ${groupId}`);

          // Get and log consensus ranking
          const consensusRanking = await communityGovernanceRankings.methods.getConsensusRanking(communityId, currentWeek, groupId).call();
          console.log(`Consensus ranking for group ${groupId}:`);
          console.log('Members:', consensusRanking[0]);
          console.log('Transient Scores:', consensusRanking[1]);
          console.log('Timestamp:', consensusRanking[2]);
          console.log('Final Ranking:');
          for (let i = 0; i < consensusRanking[0].length; i++) {
            console.log(`  ${i + 1}. ${consensusRanking[0][i]} - Score: ${consensusRanking[1][i]}`);
          }
          console.log('\n');
        } catch (error) {
          console.log(`Failed to determine consensus for group ${groupId}. Reason: ${error.message}`);
          console.log('Error details:', JSON.stringify(error, null, 2));
        }
      }
    }

    // Determine consensus for each community
    for (let communityId = 1; communityId <= communities.length; communityId++) {
      await determineConsensus(communityId);
    }

    console.log('Script execution completed successfully.');

  } catch (e) {
    console.error('Error:', e.message);
    console.error('Error stack:', e.stack);
  }
})();