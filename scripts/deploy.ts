import { ethers, network } from "hardhat";
import { getAddresses } from "../utils/const";

async function main() {
  // deploy Cross Chain Router Contract
  const CrossChainRouter = await ethers.getContractFactory("CrossChainRouter");

  const chainId = network.config.chainId;

  if (chainId === undefined) {
    throw new Error("chainId invalid");
  }

  const [outbox, payMaster, connext, lz] = getAddresses(network.name)

  const crossChainRouter = await CrossChainRouter.deploy(connext, outbox, payMaster, lz)

  await crossChainRouter.deployed();
  console.log(`CrossChainRouter deployed to ${crossChainRouter.address}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
