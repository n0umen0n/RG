(async () => {
  try {
    console.log('Starting script execution...');

    const accounts = await web3.eth.getAccounts();
    console.log('Accounts loaded:', accounts.length, 'accounts available');

    // Deploy CommunityGovernanceProfiles contract
    console.log('Deploying CommunityGovernanceProfiles contract...');
    const profilesMetadataContent = await remix.call('fileManager', 'getFile', 'contracts/artifacts/CommunityGovernanceProfiles.json');
    const profilesMetadata = JSON.parse(profilesMetadataContent);

    let profilesContract = new web3.eth.Contract(profilesMetadata.abi);
    profilesContract = profilesContract.deploy({
      data: profilesMetadata.data.bytecode.object,
      arguments: []
    });

    const profilesGasEstimate = await profilesContract.estimateGas({ from: accounts[0] });
    let communityGovernanceProfiles = await profilesContract.send({
      from: accounts[0],
      gas: Math.max(profilesGasEstimate * 2, 8000000),
      gasPrice: '30000000000'
    });

    console.log('CommunityGovernanceProfiles deployed at:', communityGovernanceProfiles.options.address);

    // Configure CommunityGovernanceProfiles
    console.log('Configuring CommunityGovernanceProfiles...');

    // Create three communities
    const communities = [
      { name: "Tech Enthusiasts", description: "A community for tech lovers", imageUrl: "https://example.com/tech.jpg" },
      { name: "Green Earth", description: "Environmentally conscious group", imageUrl: "https://example.com/earth.jpg" },
      { name: "Book Club", description: "For avid readers", imageUrl: "https://example.com/book.jpg" }
    ];

    for (let i = 0; i < communities.length; i++) {
      const { name, description, imageUrl } = communities[i];
      await communityGovernanceProfiles.methods.createCommunity(name, description, imageUrl).send({ from: accounts[0], gas: 3000000 });
      console.log(`Community created: ${name}`);
    }

    // Add members to each community
    const maxMembersPerCommunity = 14; // Adjusted based on the error
    const membersNeedingApproval = {};

    for (let communityId = 1; communityId <= communities.length; communityId++) {
      membersNeedingApproval[communityId] = [];
      
      for (let j = 1; j <= maxMembersPerCommunity; j++) {
        const memberAccount = accounts[j % accounts.length]; // Use available accounts cyclically
        const username = `User${communityId}_${j}`;
        const userDescription = `Member of community ${communityId}`;
        const profilePicUrl = `https://example.com/user${communityId}_${j}.jpg`;

        try {
          await communityGovernanceProfiles.methods.createProfileAndJoinCommunity(
            username,
            userDescription,
            profilePicUrl,
            communityId
          ).send({ from: memberAccount, gas: 3000000 });

          console.log(`Added ${username} to community ${communityId}`);

          // Members after the 5th need approval
          if (j > 5) {
            membersNeedingApproval[communityId].push(memberAccount);
          }
        } catch (error) {
          console.log(`Failed to add ${username} to community ${communityId}. Reason: ${error.message}`);
          break; // Stop adding members to this community
        }
      }
    }

    // Approve users
    for (let communityId = 1; communityId <= communities.length; communityId++) {
      const approvers = accounts.slice(1, 3); // Use the second and third accounts as approvers
      
      for (const memberToApprove of membersNeedingApproval[communityId]) {
        for (const approver of approvers) {
          await communityGovernanceProfiles.methods.approveUser(memberToApprove, communityId)
            .send({ from: approver, gas: 3000000 });
          console.log(`User ${memberToApprove} approved by ${approver} in community ${communityId}`);
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

    const contributionsGasEstimate = await contributionsContract.estimateGas({ from: accounts[0] });
    let communityGovernanceContributions = await contributionsContract.send({
      from: accounts[0],
      gas: Math.max(contributionsGasEstimate * 2, 8000000),
      gasPrice: '30000000000'
    });

    console.log('CommunityGovernanceContributions deployed at:', communityGovernanceContributions.options.address);

    // Function to submit contributions
    async function submitContributions(communityId, numContributions) {
      console.log(`\nSubmitting ${numContributions} contributions for community ${communityId}`);
      const communityMembers = (await communityGovernanceProfiles.methods.getCommunityMembers(communityId).call())[0];
      for (let i = 0; i < numContributions && i < communityMembers.length; i++) {
        const contributor = communityMembers[i];
        const contribution = [{
          name: `Contribution ${i + 1}`,
          description: `Description for contribution ${i + 1}`,
          links: [`https://example.com/contribution${i + 1}`]
        }];

        try {
          await communityGovernanceContributions.methods.submitContributions(communityId, contribution)
            .send({ from: contributor, gas: 3000000 });
          console.log(`Contribution submitted by ${contributor}`);
        } catch (error) {
          console.log(`Failed to submit contribution for ${contributor}. Reason: ${error.message}`);
        }
      }
    }

    // Submit contributions for each community
    await submitContributions(1, 16);
    await submitContributions(2, 8);
    await submitContributions(3, 12);

    // Function to create groups and log their details
    async function createAndLogGroups(communityId) {
      console.log(`\nCreating groups for community ${communityId}:`);
      
      try {
        await communityGovernanceContributions.methods.createGroupsForCurrentWeek(communityId).send({ from: accounts[0], gas: 3000000 });
        
        // Log group creation details
        const groupCount = await communityGovernanceContributions.methods.getGroupCount().call();
        console.log(`Total groups created: ${groupCount}`);

        const detailedInfo = await communityGovernanceContributions.methods.getDetailedGroupInfo().call();
        const groupIds = detailedInfo[0];
        const groupSizes = detailedInfo[1];

        for (let i = 0; i < groupCount; i++) {
          console.log(`Group ${groupIds[i]}: ${groupSizes[i]} members`);
          
          console.log('Members:');
          const members = await communityGovernanceContributions.methods.getGroupMembers(i).call();
          members.forEach(member => console.log(`  ${member}`));
        }

        const lastRoomSizes = await communityGovernanceContributions.methods.getLastRoomSizes().call();
        console.log('Last room sizes:', lastRoomSizes);

        // Get and log weekly contributors
        const eventCount = await communityGovernanceProfiles.methods.getCommunityProfile(communityId).call();
        const currentWeek = eventCount[4];
        const weeklyContributors = await communityGovernanceContributions.methods.getWeeklyContributors(communityId, currentWeek).call();
        console.log(`Weekly contributors for community ${communityId}, week ${currentWeek}:`, weeklyContributors);
      } catch (error) {
        console.log(`Failed to create groups for community ${communityId}. Reason: ${error.message}`);
      }
    }

    // Create groups for each community
    for (let communityId = 1; communityId <= communities.length; communityId++) {
      await createAndLogGroups(communityId);
    }

    console.log('Script execution completed successfully.');

  } catch (e) {
    console.error('Error:', e.message);
    console.error('Error stack:', e.stack);
  }
})();