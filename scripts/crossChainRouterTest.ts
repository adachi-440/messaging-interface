import { ethers, network } from "hardhat";

const SRC_CONTRACT = "0xbfDa94565556979E4dD8A8E77925d8013aF05b69"
const DST_CONTRACT = "0xd737408b3CE7c6559496ea0cAde16A951945356b"

async function main() {
  const crossChainRouter = await ethers.getContractAt("CrossChainRouterSample", SRC_CONTRACT);

  const chainId = network.config.chainId;

  if (chainId === undefined) {
    throw new Error("chainId invalid");
  }

  const callData = ethers.utils.defaultAbiCoder.encode(["string"], ["Hello World"]);
  console.log(callData)

  // const data = ethers.utils.defaultAbiCoder.encode(["address", "bytes"], [DST_CONTRACT, callData])

  // console.log(ethers.utils.defaultAbiCoder.decode(["address", "bytes"], data))

  const tx = await crossChainRouter.send(3, 80001, 0, DST_CONTRACT, { gasLimit: 2000000 });
  console.log('sending message...')
  const result = await tx.wait();
  console.log(result);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
