(async () => {
  try {
    console.log('Starting group creation test script...');

    // Get the contract metadata
    const metadataContent = await remix.call('fileManager', 'getFile', 'contracts/artifacts/GroupCreationTest.json');
    console.log('Metadata file content:', metadataContent.substring(0, 100) + '...');

    const metadata = JSON.parse(metadataContent);
    console.log('Metadata parsed successfully');

    const accounts = await web3.eth.getAccounts();
    console.log('Accounts loaded:', accounts.length, 'accounts available');

    // Deploy the contract
    let contract = new web3.eth.Contract(metadata.abi);
    contract = contract.deploy({
      data: metadata.data.bytecode.object,
      arguments: []
    });

    // Estimate gas
    const gasEstimate = await contract.estimateGas({ from: accounts[0] });
    console.log('Estimated gas for deployment:', gasEstimate);

    let groupCreationTest = await contract.send({
      from: accounts[0],
      gas: Math.max(gasEstimate * 2, 8000000), // Double the estimate or use 8 million, whichever is larger
      gasPrice: '30000000000'
    });

    console.log('GroupCreationTest deployed at:', groupCreationTest.options.address);

    // Function to create groups and log their details
    async function createAndLogGroups(participantCount) {
      console.log(`\nCreating groups for ${participantCount} participants:`);
      
      // Generate additional accounts if needed
      while (accounts.length < participantCount) {
        const newAccount = web3.eth.accounts.create();
        accounts.push(newAccount.address);
      }
      
      const participants = accounts.slice(0, participantCount);
      
      const createGroupsReceipt = await groupCreationTest.methods.createGroups(participants).send({ from: accounts[0], gas: 3000000 });
      
      // Log events
      console.log("Events emitted during group creation:");
      if (createGroupsReceipt.events.GroupsCreated) {
        console.log(`Number of groups created: ${createGroupsReceipt.events.GroupsCreated.returnValues.numberOfGroups}`);
      }
      if (createGroupsReceipt.events.GroupSize) {
        Object.values(createGroupsReceipt.events).forEach(event => {
          if (event.event === 'GroupSize') {
            console.log(`Group ${event.returnValues.groupIndex}: ${event.returnValues.size} members`);
          }
        });
      }

      const groupCount = await groupCreationTest.methods.getGroupCount().call();
      console.log(`Total groups created: ${groupCount}`);

      for (let i = 0; i < groupCount; i++) {
        const size = await groupCreationTest.methods.getGroupSize(i).call();
        console.log(`Verified Group ${i} size: ${size}`);
        
        console.log('Members:');
        const members = await groupCreationTest.methods.getGroupMembers(i).call();
        members.forEach(member => console.log(`  ${member}`));
      }
    }

    // Test group creation with different participant counts
    console.log('\n--- Testing Group Creation ---');
    await createAndLogGroups(5);
    await createAndLogGroups(12);
    await createAndLogGroups(16);
    await createAndLogGroups(24);
    await createAndLogGroups(25);
    await createAndLogGroups(39);

    console.log('\nGroup creation test script completed successfully.');

  } catch (e) {
    console.error('Error:', e.message);
    console.error('Error stack:', e.stack);
  }
})();