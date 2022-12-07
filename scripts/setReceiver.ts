import { ethers, network } from "hardhat";

const SRC_CONTRACT = "0xAEb90fCD11B8d917699e40F5aFA239623376e362"
const RECEIVERS = [{ chainId: 420, address: "0xAEb90fCD11B8d917699e40F5aFA239623376e362" }, { chainId: 1287, address: "0x65E7F203dF46cFcD33904F012FfFdd1Ea63bA0A5" }]

async function main() {
  const router = await ethers.getContractAt("CrossChainRouter", SRC_CONTRACT);

  const chainId = network.config.chainId;

  if (chainId === undefined) {
    throw new Error("chainId invalid");
  }

  for (let index = 0; index < RECEIVERS.length; index++) {
    const receiver = RECEIVERS[index];
    if (chainId !== receiver.chainId) {
      const tx = await router.setReceiver(receiver.address, receiver.chainId, { gasLimit: 10000000 });
      console.log('setting  receiver...')
      await tx.wait()
      console.log('complete set');
      await sleep(1000)
    }
  }

  // const receiver = RECEIVERS[1];
  // const tx = await router.setReceiver(receiver.address, receiver.chainId);
  // console.log('setting  receiver...')
  // await tx.wait()
  // console.log('complete set');
  // await sleep(1000)
}

const sleep = (ms: number) => {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
