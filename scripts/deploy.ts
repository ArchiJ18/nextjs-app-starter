import { ethers } from "hardhat";

async function main(): Promise<void> {
  console.log("Deploying BettingPlatform contract...");

  try {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const BettingPlatform = await ethers.getContractFactory("BettingPlatform");
    const bettingPlatform = await BettingPlatform.deploy();
    await bettingPlatform.waitForDeployment();

    const address = await bettingPlatform.getAddress();
    console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());
    console.log(`BettingPlatform deployed to: ${address}`);
  } catch (error) {
    console.error("Error deploying contract:", error);
    throw error;
  }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
      console.error(error);
      process.exit(1);
    });
}

export default main;
