/*
(async () => {
  try {
    console.log('Starting script execution...');

    // Get the contract metadata
    const metadataContent = await remix.call('fileManager', 'getFile', 'contracts/artifacts/CommunityGovernance.json');
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

    let communityGovernance = await contract.send({
      from: accounts[0],
      gas: Math.max(gasEstimate * 2, 8000000), // Double the estimate or use 8 million, whichever is larger
      gasPrice: '30000000000'
    });

    console.log('CommunityGovernance deployed at:', communityGovernance.options.address);

    // Updated function to create groups and log their details with debugging information
    async function createAndLogGroups(participantCount) {
      console.log(`\nCreating groups for ${participantCount} participants:`);
      const participants = accounts.slice(0, participantCount);
      
      const createGroupsReceipt = await communityGovernance.methods.createGroups(participants).send({ from: accounts[0], gas: 3000000 });
      
      // Log events
      console.log("Events emitted during group creation:");
      if (createGroupsReceipt.events.RoomSizesCalculated) {
        createGroupsReceipt.events.RoomSizesCalculated.returnValues.sizes.forEach((size, index) => {
          console.log(`Room ${index}: ${size} participants`);
        });
      }
      if (createGroupsReceipt.events.GroupCreated) {
        createGroupsReceipt.events.GroupCreated.forEach(event => {
          console.log(`Group ${event.returnValues.groupId} created with ${event.returnValues.size} members`);
        });
      }

      const groupCount = await communityGovernance.methods.getGroupCount().call();
      console.log(`Total groups created: ${groupCount}`);

      const lastRoomSizes = await communityGovernance.methods.getLastRoomSizes().call();
      console.log("Calculated room sizes:", lastRoomSizes);

      const [groupIds, groupSizes] = await communityGovernance.methods.getDetailedGroupInfo().call();
      console.log("Detailed group info:");
      for (let i = 0; i < groupIds.length; i++) {
        console.log(`Group ${groupIds[i]}: ${groupSizes[i]} members`);
        const groupMembers = await communityGovernance.methods.getGroupMembers(groupIds[i]).call();
        console.log('Members:', groupMembers);
      }
    }

    // Test group creation with different participant counts
    console.log('\n--- Testing Group Creation ---');
    await createAndLogGroups(5);
    await createAndLogGroups(16);
    await createAndLogGroups(39);

    console.log('\n--- Setting up Communities ---');
    // Create three communities
    const communities = [
      { name: "Tech Enthusiasts", description: "A community for tech lovers", imageUrl: "https://example.com/tech.jpg" },
      { name: "Green Earth", description: "Environmentally conscious group", imageUrl: "https://example.com/earth.jpg" },
      { name: "Book Club", description: "For avid readers", imageUrl: "https://example.com/book.jpg" }
    ];

    for (let i = 0; i < communities.length; i++) {
      const { name, description, imageUrl } = communities[i];
      await communityGovernance.methods.createCommunity(name, description, imageUrl).send({ from: accounts[0], gas: 3000000 });
      console.log(`Community created: ${name}`);
    }

    // Add members to each community and submit contributions
    const membersPerCommunity = 10; // Increased to test approval process
    const contributionsSubmitted = new Set();
    const membersNeedingApproval = {};

    for (let communityId = 1; communityId <= communities.length; communityId++) {
      membersNeedingApproval[communityId] = [];
      
      for (let j = 1; j <= membersPerCommunity; j++) {
        const memberAccount = accounts[j % accounts.length]; // Use available accounts cyclically
        const username = `User${communityId}_${j}`;
        const userDescription = `Member of community ${communityId}`;
        const profilePicUrl = `https://example.com/user${communityId}_${j}.jpg`;

        await communityGovernance.methods.createProfileAndJoinCommunity(
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

        // Submit contributions for some members (e.g., every other member)
        if (j % 2 === 0) {
          const contributions = [
            {
              name: `Contribution ${j}`,
              description: `A sample contribution from ${username}`,
              links: [`https://example.com/contribution${j}`]
            }
          ];

          await communityGovernance.methods.submitContributions(
            communityId,
            contributions
          ).send({ from: memberAccount, gas: 3000000 });

          contributionsSubmitted.add(memberAccount);
          console.log(`Contributions submitted by ${username} (${memberAccount}) to community ${communityId}`);
        }
      }
    }

    // Approve users
    for (let communityId = 1; communityId <= communities.length; communityId++) {
      const approvers = accounts.slice(1, 3); // Use the second and third accounts as approvers
      
      for (const memberToApprove of membersNeedingApproval[communityId]) {
        for (const approver of approvers) {
          await communityGovernance.methods.approveUser(memberToApprove, communityId)
            .send({ from: approver, gas: 3000000 });
          console.log(`User ${memberToApprove} approved by ${approver} in community ${communityId}`);
        }
        
        // Check if the user is now approved
        const userData = await communityGovernance.methods.getUserCommunityData(memberToApprove, communityId).call();
        console.log(`User ${memberToApprove} approval status in community ${communityId}: ${userData[3]}`);
      }
    }

    console.log('\nScript execution completed successfully.');
    console.log('Addresses that submitted contributions:');
    contributionsSubmitted.forEach(address => console.log(address));

  } catch (e) {
    console.error('Error:', e.message);
    console.error('Error stack:', e.stack);
  }
})();

*/
(async () => {
  try {
    console.log('Starting script execution...');

    const accounts = await web3.eth.getAccounts();
    console.log('Accounts loaded:', accounts.length, 'accounts available');

    // Helper function to load contract data
    async function loadContractData(fileName) {
      const content = await remix.call('fileManager', 'getFile', `contracts/artifacts/${fileName}`);
      const metadata = JSON.parse(content);
      return {
        abi: metadata.abi,
        bytecode: metadata.data.bytecode.object
      };
    }

    // Helper function to handle contract deployment
    async function deployContract(name, abi, bytecode, args = []) {
      console.log(`Deploying ${name}...`);
      try {
        const contract = new web3.eth.Contract(abi);
        const deployed = await contract.deploy({
          data: '0x' + bytecode,
          arguments: args
        }).send({
          from: accounts[0],
          gas: 6000000,
          gasPrice: '30000000000'
        });
        console.log(`${name} deployed at:`, deployed.options.address);
        return deployed;
      } catch (error) {
        console.error(`Error deploying ${name}:`, error.message);
        throw error;
      }
    }

    // Load and deploy CommunityGovernanceProfiles contract
    const profilesData = await loadContractData('CommunityGovernanceProfiles.json');
    const communityGovernanceProfiles = await deployContract('CommunityGovernanceProfiles', profilesData.abi, profilesData.bytecode);

    // Load and deploy CommunityGovernanceContributions contract
    const contributionsData = await loadContractData('CommunityGovernanceContributions.json');
    const communityGovernanceContributions = await deployContract('CommunityGovernanceContributions', contributionsData.abi, contributionsData.bytecode, [communityGovernanceProfiles.options.address]);

    // Helper function for safe contract method calls
    async function safeContractCall(contract, methodName, ...args) {
      try {
        const method = contract.methods[methodName](...args);
        const gas = await method.estimateGas({from: accounts[0]});
        return await method.send({from: accounts[0], gas: Math.floor(gas * 1.5)});
      } catch (error) {
        console.error(`Error calling ${methodName}:`, error.message);
        throw error;
      }
    }

    // Updated function to create groups and log their details
    async function createAndLogGroups(participantCount) {
      console.log(`\nCreating groups for ${participantCount} participants:`);
      const participants = accounts.slice(0, participantCount);
      
      await safeContractCall(communityGovernanceContributions, 'createGroups', participants);
      
      const groupCount = await communityGovernanceContributions.methods.getGroupCount().call();
      console.log(`Total groups created: ${groupCount}`);

      const lastRoomSizes = await communityGovernanceContributions.methods.getLastRoomSizes().call();
      console.log("Calculated room sizes:", lastRoomSizes);

      try {
        const detailedInfo = await communityGovernanceContributions.methods.getDetailedGroupInfo().call();
        console.log("Detailed group info:", detailedInfo);

        if (Array.isArray(detailedInfo) && detailedInfo.length === 2) {
          const [groupIds, groupSizes] = detailedInfo;
          for (let i = 0; i < groupIds.length; i++) {
            console.log(`Group ${groupIds[i]}: ${groupSizes[i]} members`);
            const groupMembers = await communityGovernanceContributions.methods.getGroupMembers(groupIds[i]).call();
            console.log('Members:', groupMembers);
          }
        } else {
          console.log("Unexpected format for detailed group info:", detailedInfo);
        }
      } catch (error) {
        console.error("Error getting detailed group info:", error.message);
      }

      // Log individual group members
      for (let i = 0; i < groupCount; i++) {
        try {
          const groupMembers = await communityGovernanceContributions.methods.getGroupMembers(i).call();
          console.log(`Group ${i} members:`, groupMembers);
        } catch (error) {
          console.error(`Error getting members for group ${i}:`, error.message);
        }
      }
    }

    // Test group creation with different participant counts
    console.log('\n--- Testing Group Creation ---');
    await createAndLogGroups(5);
    await createAndLogGroups(16);
    await createAndLogGroups(39);

    console.log('\n--- Setting up Communities ---');
    const communities = [
      { name: "Tech Enthusiasts", description: "A community for tech lovers", imageUrl: "https://example.com/tech.jpg" },
      { name: "Green Earth", description: "Environmentally conscious group", imageUrl: "https://example.com/earth.jpg" },
      { name: "Book Club", description: "For avid readers", imageUrl: "https://example.com/book.jpg" }
    ];

    for (const community of communities) {
      await safeContractCall(communityGovernanceProfiles, 'createCommunity', community.name, community.description, community.imageUrl);
      console.log(`Community created: ${community.name}`);
    }

    // Add members to each community and submit contributions
    const membersPerCommunity = 10;
    const contributionsSubmitted = new Set();
    const membersNeedingApproval = {};

    for (let communityId = 1; communityId <= communities.length; communityId++) {
      membersNeedingApproval[communityId] = [];
      
      for (let j = 1; j <= membersPerCommunity; j++) {
        const memberAccount = accounts[j % accounts.length];
        const username = `User${communityId}_${j}`;
        const userDescription = `Member of community ${communityId}`;
        const profilePicUrl = `https://example.com/user${communityId}_${j}.jpg`;

        try {
          // Check if the user has already joined the community
          const userData = await communityGovernanceProfiles.methods.getUserCommunityData(memberAccount, communityId).call();
          if (userData[0].toString() === '0') {
            // User hasn't joined this community yet
            await safeContractCall(communityGovernanceProfiles, 'createProfileAndJoinCommunity', username, userDescription, profilePicUrl, communityId);
            console.log(`Added ${username} to community ${communityId}`);

            if (j > 5) {
              membersNeedingApproval[communityId].push(memberAccount);
            }
          } else {
            console.log(`${username} has already joined community ${communityId}`);
          }
        } catch (error) {
          if (error.message.includes("User not part of this community")) {
            // If this error occurs, it means the user hasn't joined yet, so we can proceed
            await safeContractCall(communityGovernanceProfiles, 'createProfileAndJoinCommunity', username, userDescription, profilePicUrl, communityId);
            console.log(`Added ${username} to community ${communityId}`);

            if (j > 5) {
              membersNeedingApproval[communityId].push(memberAccount);
            }
          } else {
            console.error(`Error checking user status for ${username} in community ${communityId}:`, error.message);
          }
        }

        if (j % 2 === 0) {
          const contributions = [{
            name: `Contribution ${j}`,
            description: `A sample contribution from ${username}`,
            links: [`https://example.com/contribution${j}`]
          }];

          try {
            await safeContractCall(communityGovernanceContributions, 'submitContributions', communityId, contributions);
            contributionsSubmitted.add(memberAccount);
            console.log(`Contributions submitted by ${username} (${memberAccount}) to community ${communityId}`);
          } catch (error) {
            console.error(`Error submitting contribution for ${username} in community ${communityId}:`, error.message);
          }
        }
      }
    }

    // Approve users
    for (let communityId = 1; communityId <= communities.length; communityId++) {
      const approvers = accounts.slice(1, 3);
      
      for (const memberToApprove of membersNeedingApproval[communityId]) {
        for (const approver of approvers) {
          await safeContractCall(communityGovernanceProfiles, 'approveUser', memberToApprove, communityId);
          console.log(`User ${memberToApprove} approved by ${approver} in community ${communityId}`);
        }
        
        const userData = await communityGovernanceProfiles.methods.getUserCommunityData(memberToApprove, communityId).call();
        console.log(`User ${memberToApprove} approval status in community ${communityId}: ${userData[3]}`);
      }
    }

    console.log('\nScript execution completed successfully.');
    console.log('Addresses that submitted contributions:');
    contributionsSubmitted.forEach(address => console.log(address));

  } catch (e) {
    console.error('Error:', e.message);
    console.error('Error stack:', e.stack);
  }
})();