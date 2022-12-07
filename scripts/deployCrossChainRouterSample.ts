import { ethers, network } from "hardhat";
import DEPLOYMENTS from "../constants/deployments.json"

async function main() {
  // deploy Bridge Contract
  const CrossChainRouter = await ethers.getContractFactory("CrossChainRouterSample");

  const chainId = network.config.chainId;

  if (chainId === undefined) {
    throw new Error("chainId invalid");
  }

  const contractAddress = DEPLOYMENTS[network.name as keyof typeof DEPLOYMENTS]
  const crossChainRouter = await CrossChainRouter.deploy(contractAddress);


  await crossChainRouter.deployed();
  console.log(`CrossChainRouterSample deployed to ${crossChainRouter.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
