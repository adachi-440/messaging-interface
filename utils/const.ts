export const OUTBOX_GOERLI = "0xDDcFEcF17586D08A5740B7D91735fcCE3dfe3eeD"
export const OUTBOX_MUMBAI = "0xe17c37212d785760E8331D4A4395B17b34Ba8cDF"
export const OUTBOX_MOONBASE = "0x54148470292C24345fb828B003461a9444414517"
export const INBOX_GOERLI = "0x666a24F62f7A97BA33c151776Eb3D9441a059eB8"
export const INBOX_MUMBAI = "0x934809a3a89CAdaB30F0A8C703619C3E02c37616"
export const INBOX_MOONBASE = "0x98AAE089CaD930C64a76dD2247a2aC5773a4B8cE"
export const GASPAYMASTER_GOERRI = "0x44b764045BfDC68517e10e783E69B376cef196B2"
export const GASPAYMASTER_MUMBAI = "0x9A27744C249A11f68B3B56f09D280599585DFBb8"
export const GASPAYMASTER_MOONBASE = "0xeb6f11189197223c656807a83B0DD374f9A6dF44"
export const CONNEXT_GOERRI = "0xb35937ce4fFB5f72E90eAD83c10D33097a4F18D2"
export const CONNEXT_MUMBAI = "0xa2F2ed226d4569C8eC09c175DDEeF4d41Bab4627"
export const CROSS_CHAIN_ROUTER_GOERRI = "0x96C106F735197e1B5027711189AC2bCa01eA3d78"
export const CROSS_CHAIN_ROUTER_MUMBAI = "0x78a1479986355E6783cB6631e101C0283910879e"
export const CROSS_CHAIN_ROUTER_MOONBASE = "0xc6f90e98c6f991F32b8a2D051C2C782445f52ef6"
export const DOMAIN_GOERLI = 5
export const DOMAIN_MUMBAI = 80001
export const DOMAIN_MOONBASE = "0x6d6f2d61"
const NONE_ADDRESS = "0x0000000000000000000000000000000000000000"

export const getAddresses = (chainId: number): [string, string, number | string] => {
  if (chainId === 5) {
    return [CROSS_CHAIN_ROUTER_GOERRI, INBOX_GOERLI, DOMAIN_GOERLI]
  } else if (chainId === 80001) {
    return [CROSS_CHAIN_ROUTER_MUMBAI, INBOX_MUMBAI, DOMAIN_MUMBAI]
  } else {
    return [CROSS_CHAIN_ROUTER_GOERRI, INBOX_MOONBASE, DOMAIN_MOONBASE]
  }
}

// address _connext, address _outbox, address _gasPaymaster
export const getAddressesForCrossChainRoter = (chainId: number) => {
  if (chainId == 5) {
    return [CONNEXT_GOERRI, OUTBOX_GOERLI, GASPAYMASTER_GOERRI]
  } else if (chainId == 80001) {
    return [CONNEXT_MUMBAI, OUTBOX_MUMBAI, GASPAYMASTER_MUMBAI]
  } else if (chainId == 1287) {
    return [NONE_ADDRESS, OUTBOX_MOONBASE, GASPAYMASTER_MOONBASE]
  } else {
    return [NONE_ADDRESS, NONE_ADDRESS, NONE_ADDRESS]
  }
}