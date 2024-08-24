(async () => {
  try {
    console.log('Starting script execution...');

    // Get the contract metadata
    const metadataContent = await remix.call('fileManager', 'getFile', 'contracts/artifacts/CommunityGovernanceProfiles.json');
    console.log('Metadata file content:', metadataContent.substring(0, 100) + '...');

    const metadata = JSON.parse(metadataContent);
    console.log('Metadata parsed successfully');

    const accounts = await web3.eth.getAccounts();
    console.log('Accounts loaded:', accounts.length, 'accounts available');

    // Deploy the contract with increased gas limit
    let contract = new web3.eth.Contract(metadata.abi);
    contract = contract.deploy({
      data: metadata.data.bytecode.object,
      arguments: []
    });

    // Estimate gas
    const gasEstimate = await contract.estimateGas({ from: accounts[0] });
    console.log('Estimated gas:', gasEstimate);

    let communityGovernanceProfiles = await contract.send({
      from: accounts[0],
      gas: Math.max(gasEstimate * 2, 8000000), // Double the estimate or use 8 million, whichever is larger
      gasPrice: '30000000000'
    });

    console.log('CommunityGovernanceProfiles deployed at:', communityGovernanceProfiles.options.address);

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

    console.log('Script execution completed successfully.');

  } catch (e) {
    console.error('Error:', e.message);
    console.error('Error stack:', e.stack);
  }
})();