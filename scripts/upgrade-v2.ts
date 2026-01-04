import hre from "hardhat";
const { ethers } = hre;

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Upgrader (EOA):", deployer.address);

  // 이미 배포된 주소들
  const PROXY_ADDRESS = "0x68cA0915D6EbfA64B457d87721e88349ca882807"; // 프록시 주소
  const PROXY_ADMIN_ADDRESS = "0x959bA8ec3288bbe3832f24Ccd76e5503Da3Df455"; // ProxyAdmin 주소

  // Deploy MyERC20V2 implementation
  const MyERC20V2 = await ethers.getContractFactory("MyERC20V2");
  const implV2 = await MyERC20V2.deploy();
  await implV2.waitForDeployment();

  const implV2Addr = await implV2.getAddress();
  console.log("MyERC20V2 deployed:", implV2Addr);

  // Encode initializeV2(bool)
  const initV2Data = MyERC20V2.interface.encodeFunctionData(
    "initializeV2",
    [true] // whitelistEnabled = true
  );

  // ProxyAdmin.upgradeAndCall()
  const ProxyAdmin = await ethers.getContractAt("ProxyAdmin", PROXY_ADMIN_ADDRESS);

  console.log("Upgrading proxy to V2...");

  const tx = await ProxyAdmin.upgradeAndCall(PROXY_ADDRESS, implV2Addr, initV2Data);

  await tx.wait();

  console.log("Proxy upgraded to V2!");
  console.log("Implementation (V2):", implV2Addr);

  // Attach V2 ABI to proxy & verify
  const tokenV2 = await ethers.getContractAt("MyERC20V2", PROXY_ADDRESS);

  console.log("Token name        :", await tokenV2.name());
  console.log("Whitelist enabled :", await tokenV2.whitelistEnabled());
  console.log("Owner             :", await tokenV2.owner());
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
