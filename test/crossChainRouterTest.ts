import { ethers, network } from "hardhat";
import LZ from "../constants/lzEndpoints.json"
import CHAIN_ID from "../constants/lzChainIds.json"
import DEPLOYMENTS from "../constants/deployments.json"
import ABI from "../artifacts/contracts/CrossChainRouter.sol/CrossChainRouter.json"
import { BigNumber } from "ethers";
import {
  AxelarQueryAPI,
  Environment,
  EvmChain,
  GasToken,
} from "@axelar-network/axelarjs-sdk";
import { formatEther, parseEther } from "ethers/lib/utils";
import LZABI from "../constants/abis/lzEndpointABI.json"


const SRC_CONTRACT = "0xe12a50e25CDbA8c5Ba40474dbB09b9400252d180"
const DST_CONTRACT = "0x9D90ab3CD834EaA3bf327057A1b5ae8Da862273b"

// moonbase to optimism-goerli
async function main() {
  const [owner] = await ethers.getSigners()

  const crossChainRouter = await ethers.getContractAt("CrossChainRouterSample", SRC_CONTRACT);
  const endpointAddress = LZ[network.name as keyof typeof LZ]
  const receiver = DEPLOYMENTS["arbitrum-goerli"]
  const sender = DEPLOYMENTS["optimism-goerli"]
  const remoteChainId = CHAIN_ID["arbitrum-goerli"]
  const endpoint = await ethers.getContractAt(
    ABI.abi,
    sender,
    owner
  )

  // const lzEndpoint = await ethers.getContractAt(
  //   LZABI,
  //   endpointAddress,
  //   owner
  // )

  // // const srcAddress = await endpoint.getTrustedRemoteAddress(421613)
  // let remoteAndLocal = ethers.utils.solidityPack(
  //   ['address', 'address'],
  //   [sender, receiver]
  // )

  // const amount = ethers.utils.parseEther('1')

  // const c = ethers.utils.defaultAbiCoder.encode(["uint256", "address"], [amount, owner.address]);
  // const callData = ethers.utils.defaultAbiCoder.encode(["uint256", "bytes"], [2, c]);
  // const payload = ethers.utils.defaultAbiCoder.encode(["address", "bytes"], ["0xdBAe05cC50a5e1Ac81fDdc4f81b7Ec8e6F3cf0D9", callData]);

  // console.log(payload);

  // let lzTx = await lzEndpoint.retryPayload(
  //   CHAIN_ID["optimism-goerli"],
  //   remoteAndLocal,
  //   payload,
  //   { gasLimit: 2000000 }
  // )

  // await lzTx.wait()
  // console.log(lzTx)

  const chainId = network.config.chainId;

  if (chainId === undefined) {
    throw new Error("chainId invalid");
  }

  // const callData = ethers.utils.defaultAbiCoder.encode(["string"], ["Hello World"]);
  // const payload = ethers.utils.defaultAbiCoder.encode(["address", "bytes"], [receiver, callData]);

  // const fees: BigNumber[] = await endpoint.estimateSendFee(remoteChainId, payload, false)
  // const fee: BigNumber = fees[0]
  // console.log(`fees is the message fee in wei: ${fees[0]}`)

  const sdk = new AxelarQueryAPI({
    environment: Environment.TESTNET,
  });

  let fee = await sdk.estimateGasFee(
    EvmChain.MOONBEAM,
    EvmChain.POLYGON,
    GasToken.GLMR
  );
  console.log(formatEther(fee))


  const tx = await crossChainRouter.send(4, 80001, fee, DST_CONTRACT, { gasLimit: 2000000, value: fee })

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