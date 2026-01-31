const { ethers } = require('hardhat');

async function main() {
    const [deployer] = await ethers.getSigners();
    
    console.log("Deploying BitClaw Protocol with account:", deployer.address);
    console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()));
    
    // Deploy the contract
    const BitClawProtocol = await ethers.getContractFactory("BitClawProtocol");
    const bitclaw = await BitClawProtocol.deploy();
    
    await bitclaw.deployed();
    
    console.log("✅ BitClaw Protocol deployed to:", bitclaw.address);
    
    // Bootstrap initial liquidity (1% of max supply = 210,000 BITCLAW)
    const bootstrapAmount = ethers.utils.parseEther("210000");
    await bitclaw.bootstrapLiquidity(deployer.address, bootstrapAmount);
    
    console.log("✅ Bootstrap liquidity minted:", ethers.utils.formatEther(bootstrapAmount), "BITCLAW");
    
    // Verify contract deployment
    console.log("\n📊 Contract Details:");
    console.log("Name:", await bitclaw.name());
    console.log("Symbol:", await bitclaw.symbol());
    console.log("Max Supply:", ethers.utils.formatEther(await bitclaw.MAX_SUPPLY()));
    console.log("Initial Daily Reward:", ethers.utils.formatEther(await bitclaw.getCurrentRewardRate()));
    console.log("Total Minted:", ethers.utils.formatEther(await bitclaw.totalMinted()));
    
    // Contract verification info
    console.log("\n🔗 Verification Info:");
    console.log("Network: Base");
    console.log("Contract Address:", bitclaw.address);
    console.log("Deployer:", deployer.address);
    
    // Save deployment info
    const deploymentInfo = {
        contractAddress: bitclaw.address,
        deployerAddress: deployer.address,
        network: "base",
        blockNumber: await ethers.provider.getBlockNumber(),
        timestamp: new Date().toISOString(),
        maxSupply: "21000000",
        bootstrapAmount: "210000",
        initialDailyReward: "100"
    };
    
    console.log("\n💾 Deployment Complete!");
    console.log("Save this info:", JSON.stringify(deploymentInfo, null, 2));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    });