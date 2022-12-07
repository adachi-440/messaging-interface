import { ethers, network } from "hardhat";
import LZ from "../constants/lzEndpoints.json"
import CHAIN_ID from "../constants/lzChainIds.json"
import DEPLOYMENTS from "../constants/deployments.json"
import LZABI from "../constants/abis/lzEndpointABI.json"
import { BigNumber } from "ethers";


const SRC_CONTRACT = "0x3226692Ae95c0C28463bCDeE6e9e1c2ee56aD47c"
const DST_CONTRACT = "0x9a98997826cB17cBab915E33F1E8604A11C76b9b"

// moonbase to optimism-goerli
async function main() {
  const [owner] = await ethers.getSigners()

  const crossChainRouter = await ethers.getContractAt("CrossChainRouterSample", SRC_CONTRACT);
  const endpointAddress = LZ[network.name as keyof typeof LZ]
  const receiver = DEPLOYMENTS["optimism-goerli"]
  const sender = DEPLOYMENTS.moonbase
  const remoteChainId = CHAIN_ID["optimism-goerli"]
  const endpoint = await ethers.getContractAt(
    LZABI,
    endpointAddress,
    owner
  )

  const chainId = network.config.chainId;

  if (chainId === undefined) {
    throw new Error("chainId invalid");
  }

  const callData = ethers.utils.defaultAbiCoder.encode(["string"], ["Hello World"]);
  const payload = ethers.utils.defaultAbiCoder.encode(["address", "bytes"], [receiver, callData]);

  const fees: BigNumber[] = await endpoint.estimateFees(remoteChainId, sender, payload, false, "0x")
  const fee: BigNumber = fees[0]
  console.log(`fees is the message fee in wei: ${fee}`)


  const tx = await crossChainRouter.send(3, 420, fee, DST_CONTRACT, { gasLimit: 2000000, value: fee })
  // const tx = await crossChainRouter.send(1, 420, 0, DST_CONTRACT, { gasLimit: 2000000 })

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