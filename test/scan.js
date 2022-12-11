import { createClient } from '@layerzerolabs/scan-client';

// moonbase to optimism-goerli
async function main() {
  const client = createClient('testnet');

  client
    .getMessagesBySrcTxHash('0x407760ed431cd184f50a8dd9d7cd5bf377b28ddb293852a6d8f3b72afe38dabd')
    .then((result) => {
      console.log(result.messages);
    });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
