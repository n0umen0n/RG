(async () => {
  try {
    console.log('Starting script execution...');

    const accounts = await web3.eth.getAccounts();
    console.log('Accounts loaded:', accounts.length, 'accounts available');

    const deployerAccount = accounts[0];
    const groupMembers = accounts.slice(1, 7); // Use 6 accounts as group members
    console.log('Group members:', groupMembers);

    // Deploy SimpleConsensus contract
    console.log('Deploying SimpleConsensus contract...');
    const consensusMetadataContent = await remix.call('fileManager', 'getFile', 'contracts/artifacts/SimpleConsensus.json');
    const consensusMetadata = JSON.parse(consensusMetadataContent);

    let consensusContract = new web3.eth.Contract(consensusMetadata.abi);
    consensusContract = consensusContract.deploy({
      data: consensusMetadata.data.bytecode.object,
      arguments: [groupMembers]
    });

    const consensusGasEstimate = await consensusContract.estimateGas({ from: deployerAccount });
    let simpleConsensus = await consensusContract.send({
      from: deployerAccount,
      gas: Math.ceil(consensusGasEstimate * 1.2),
      gasPrice: '30000000000'
    });

    console.log('SimpleConsensus deployed at:', simpleConsensus.options.address);

    // Verify group members
    const contractGroupMembers = await simpleConsensus.methods.getGroupMembers().call();
    console.log('Contract group members:', contractGroupMembers);

    // Function to submit rankings
    async function submitRankings() {
      console.log('\nSubmitting rankings');
      for (let i = 0; i < groupMembers.length; i++) {
        const member = groupMembers[i];
        // Create a random ranking of group members
        let ranking = [...groupMembers];
        ranking.sort(() => Math.random() - 0.5);

        try {
          const gasEstimate = await simpleConsensus.methods.submitRanking(ranking).estimateGas({ from: member });
          const result = await simpleConsensus.methods.submitRanking(ranking)
            .send({ from: member, gas: Math.ceil(gasEstimate * 1.2) });
          console.log(`Ranking submitted by ${member}:`, ranking);
          console.log('Transaction hash:', result.transactionHash);
        } catch (error) {
          console.log(`Failed to submit ranking for ${member}. Reason:`, error.message);
        }
      }
    }

    // Function to determine consensus and log results
    async function determineAndLogConsensus() {
      console.log('\nDetermining consensus');
      try {
        const gasEstimate = await simpleConsensus.methods.determineConsensus().estimateGas({ from: deployerAccount });
        const result = await simpleConsensus.methods.determineConsensus()
          .send({ from: deployerAccount, gas: Math.ceil(gasEstimate * 1.2) });
        console.log('Consensus determination completed. Transaction hash:', result.transactionHash);

        // Log debug events
        console.log('\nDebug Logs:');
        const debugLogs = Array.isArray(result.events.DebugLog) ? result.events.DebugLog : [result.events.DebugLog];
        debugLogs.forEach(event => {
          console.log(`${event.returnValues.message}: ${event.returnValues.value}`);
        });

        // Log individual rankings
        console.log('\nIndividual Rankings:');
        for (const member of groupMembers) {
          const ranking = await simpleConsensus.methods.getRanking(member).call();
          console.log(`${member}: ${ranking.join(', ')}`);
        }

        // Log consensus ranking
        const consensusRanking = await simpleConsensus.methods.getConsensusRanking().call();
        console.log('\nFinal Consensus Ranking:', consensusRanking);
        console.log('Consensus Ranking (detailed):');
        consensusRanking.forEach((address, index) => {
          console.log(`${index + 1}. ${address || 'undefined'}`);
        });

        // Create expected ranking based on scores
        const scores = debugLogs
          .filter(event => event.returnValues.message === "Score for member")
          .map((event, index) => ({
            address: groupMembers[index],
            score: parseInt(event.returnValues.value)
          }));

        const expectedRanking = scores
          .sort((a, b) => b.score - a.score || b.address.localeCompare(a.address))
          .map(item => item.address);

        console.log('\nExpected Ranking (based on scores):', expectedRanking);
        console.log('Expected Ranking (detailed):');
        expectedRanking.forEach((address, index) => {
          console.log(`${index + 1}. ${address || 'undefined'}`);
        });

        console.log('Consensus Ranking Correct:', arraysEqual(consensusRanking, expectedRanking) ? 'Yes' : 'No');

      } catch (error) {
        console.error('Error in determineAndLogConsensus:', error.message);
        if (error.receipt) {
          console.error('Transaction receipt:', error.receipt);
        }
      }
    }

    // Helper function to compare arrays
    function arraysEqual(a, b) {
      if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) {
        console.log('Arrays are not equal (length mismatch or not arrays)');
        return false;
      }
      for (let i = 0; i < a.length; i++) {
        if (!a[i] || !b[i] || a[i].toLowerCase() !== b[i].toLowerCase()) {
          console.log(`Mismatch at index ${i}: ${a[i]} !== ${b[i]}`);
          return false;
        }
      }
      return true;
    }

    // Run the test
    await submitRankings();
    await determineAndLogConsensus();

    console.log('\nScript execution completed successfully.');
  } catch (error) {
    console.error('An error occurred:', error);
  }
})();