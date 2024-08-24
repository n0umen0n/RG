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
    const membersPerCommunity = 10;
    const membersNeedingApproval = {};

    for (let communityId = 1; communityId <= communities.length; communityId++) {
      membersNeedingApproval[communityId] = [];
      
      for (let j = 1; j <= membersPerCommunity; j++) {
        const memberAccount = accounts[j % accounts.length]; // Use available accounts cyclically
        const username = `User${communityId}_${j}`;
        const userDescription = `Member of community ${communityId}`;
        const profilePicUrl = `https://example.com/user${communityId}_${j}.jpg`;

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

    // Updated function to create groups and log their details
    async function createAndLogGroups(communityId) {
      console.log(`\nCreating groups for community ${communityId}:`);
      
      // Fetch community members using getCommunityMembers function
      const communityMembersResult = await communityGovernanceProfiles.methods.getCommunityMembers(communityId).call();
      const participants = communityMembersResult[0]; // Assuming the first returned array contains member addresses
      
      if (!participants || participants.length === 0) {
        console.log(`No members found for community ${communityId}. Skipping group creation.`);
        return;
      }
      
      console.log(`Found ${participants.length} participants for community ${communityId}`);
      
      await communityGovernanceContributions.methods.createGroups(participants).send({ from: accounts[0], gas: 3000000 });
      
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