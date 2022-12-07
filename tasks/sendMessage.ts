/* eslint-disable prettier/prettier */
import { ethers, network } from "hardhat";
import { task } from "hardhat/config";
import DEPLOYMENTS from "../constants/deployments.json"
import CHAIN_ID from "../constants/lzChainIds.json"


// chainid = Destination Chain IDs defined by Router. Eg: Polygon, Fantom and BSC are assigned chain IDs 1, 2, 3.
// nchainid = Actual Destination Chain IDs
task(
  "sendMessage",
  "setTrustedRemote(chainId, sourceAddr) to enable inbound/outbound messages with your other contracts",
).addParam("targetNetwork", "the target network to set as a trusted remote")
  // .addParam<string>("nchainid", "Remote ChainID", "", types.string)
  .setAction(async (taskArgs, hre): Promise<null> => {
    const localContractAddress = DEPLOYMENTS[network.name as keyof typeof DEPLOYMENTS]
    const remoteContractAddress = DEPLOYMENTS[taskArgs.targetNetwork as keyof typeof DEPLOYMENTS]
    const remoteChainId = 420

    const remoteAndLocal = hre.ethers.utils.solidityPack(
      ['address', 'address'],
      [remoteContractAddress, localContractAddress]
    )

    const crossChainRouter = await ethers.getContractAt("CrossChainRouter", localContractAddress);

    // try {
    //   let tx = await (await crossChainRouter.sendMessage(3, remoteChainId, 0, )).wait()
    //   console.log(`✅ [${hre.network.name}] setTrustedRemote(${remoteChainId}, ${remoteAndLocal})`)
    //   console.log(` tx: ${tx.transactionHash}`)
    // } catch (e: any) {
    //   if (e.error.message.includes("The chainId + address is already trusted")) {
    //     console.log("*source already set*")
    //   } else {
    //     console.log(`❌ [${hre.network.name}] setTrustedRemote(${remoteChainId}, ${remoteAndLocal})`)
    //   }
    // }
    return null;
  });