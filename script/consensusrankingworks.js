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
        // Create a random ranking of group members (scores from 1 to 6)
        let ranking = Array.from({length: groupMembers.length}, (_, i) => i + 1);
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
        const debugLogs = result.events.DebugLog || [];
        (Array.isArray(debugLogs) ? debugLogs : [debugLogs]).forEach(event => {
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
        consensusRanking.forEach((rank, index) => {
          console.log(`${index + 1}. ${groupMembers[index]} (Rank: ${rank})`);
        });

      } catch (error) {
        console.error('Error in determineAndLogConsensus:', error.message);
        if (error.receipt) {
          console.error('Transaction receipt:', error.receipt);
        }
      }
    }

    // Run the test
    await submitRankings();
    await determineAndLogConsensus();

    console.log('\nScript execution completed successfully.');
  } catch (error) {
    console.error('An error occurred:', error);
  }
})();