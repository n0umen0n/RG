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
    console.log('Group members match:', JSON.stringify(groupMembers) === JSON.stringify(contractGroupMembers));
/*
async function submitRankings() {
  console.log('\nSubmitting rankings');
  const allRankings = [];
  for (let i = 0; i < groupMembers.length; i++) {
    const member = groupMembers[i];
    // Create a random ranking of group members
    let ranking = groupMembers.map((_, index) => ({ index, value: Math.random() }))
      .sort((a, b) => a.value - b.value)
      .map((item, index) => item.index + 1);
    allRankings.push(ranking);

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
  return allRankings;
}
*/

    // Function to submit rankings
    async function submitRankings() {
      console.log('\nSubmitting rankings');
      const allRankings = [];
      for (let i = 0; i < groupMembers.length; i++) {
        const member = groupMembers[i];
        // Create a random ranking of group members (scores from 1 to 6)
        let ranking = Array.from({length: groupMembers.length}, (_, i) => i + 1);
        ranking.sort(() => Math.random() - 0.5);
        allRankings.push(ranking);

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
      return allRankings;
    }

    // Helper function to calculate variance (for verification)
    function calculateVariance(values) {
      const mean = values.reduce((a, b) => a + b, 0) / values.length;
      return values.reduce((sq, n) => sq + Math.pow(n - mean, 2), 0) / values.length;
    }

function calculateMaxVariance(groupSize) {
  let sum = 0;
  for (let x = 1; x < groupSize; x++) {
    sum += x / 2;
  }
  return (groupSize * sum) / (groupSize - 1);
}

// Function to determine consensus and log results
async function determineAndLogConsensus(allRankings) {
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
    for (let i = 0; i < groupMembers.length; i++) {
      const member = groupMembers[i];
      const ranking = await simpleConsensus.methods.getRanking(member).call();
      console.log(`${member}: ${ranking.join(', ')}`);
      console.log(`Ranking matches submitted: ${JSON.stringify(ranking) === JSON.stringify(allRankings[i])}`);
    }

    // Calculate and log transient scores
    console.log('\nCalculating Transient Scores:');
    const transientScores = [];
    for (let i = 0; i < groupMembers.length; i++) {
      const memberRankings = allRankings.map(ranking => ranking[i]);
      const mean = memberRankings.reduce((a, b) => a + b, 0) / memberRankings.length;
      const variance = calculateVariance(memberRankings);
      const maxVariance = calculateMaxVariance(groupMembers.length);
      const consensusTerm = 1 - (variance / maxVariance);
      const transientScore = mean * consensusTerm;
      transientScores.push(transientScore);
      console.log(`Member ${i + 1}:`);
      console.log(`  Rankings: ${memberRankings.join(', ')}`);
      console.log(`  Mean: ${mean}`);
      console.log(`  Variance: ${variance}`);
      console.log(`  Max Variance: ${maxVariance}`);
      console.log(`  Consensus Term: ${consensusTerm}`);
      console.log(`  Transient Score: ${transientScore}`);
    }

    // Log consensus ranking
    const consensusRanking = await simpleConsensus.methods.getConsensusRanking().call();
    console.log('\nFinal Consensus Ranking:', consensusRanking);
    console.log('Consensus Ranking (detailed):');
    consensusRanking.forEach((rank, index) => {
      console.log(`${index + 1}. ${groupMembers[index]} (Rank: ${rank}, Transient Score: ${transientScores[index]})`);
    });

    // Verify consensus ranking
    const expectedRanking = transientScores
      .map((score, index) => ({ score, index }))
      .sort((a, b) => b.score - a.score)
      .map((item, index) => ({ member: groupMembers[item.index], rank: groupMembers.length - index }));
    
    console.log('\nVerifying Consensus Ranking:');
    let rankingCorrect = true;
    for (let i = 0; i < groupMembers.length; i++) {
      const expected = expectedRanking[i];
      const actual = consensusRanking[groupMembers.indexOf(expected.member)];
      console.log(`Member: ${expected.member}`);
      console.log(`  Expected Rank: ${expected.rank}`);
      console.log(`  Actual Rank: ${actual}`);
      console.log(`  Correct: ${expected.rank === parseInt(actual)}`);
      if (expected.rank !== parseInt(actual)) {
        rankingCorrect = false;
      }
    }
    console.log(`\nOverall Consensus Ranking Correct: ${rankingCorrect}`);

  } catch (error) {
    console.error('Error in determineAndLogConsensus:', error.message);
    if (error.receipt) {
      console.error('Transaction receipt:', error.receipt);
    }
  }
}

    // Run the test
    const allRankings = await submitRankings();
    await determineAndLogConsensus(allRankings);

    console.log('\nScript execution completed successfully.');
  } catch (error) {
    console.error('An error occurred:', error);
  }
})();