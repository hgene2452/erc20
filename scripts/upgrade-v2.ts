import hre from "hardhat";
const { ethers } = hre;

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Upgrader (EOA):", deployer.address);

  // 이미 배포된 주소들
  const PROXY_ADDRESS = "0x68cA0915D6EbfA64B457d87721e88349ca882807";
  const PROXY_ADMIN_ADDRESS = "0x959bA8ec3288bbe3832f24Ccd76e5503Da3Df455";

  // (0) ProxyAdmin / Proxy 상태 점검
  const proxyAdmin = await ethers.getContractAt("ProxyAdmin", PROXY_ADMIN_ADDRESS, deployer);

  const adminOwner = await proxyAdmin.owner();
  console.log("ProxyAdmin.owner():", adminOwner);

  if (adminOwner.toLowerCase() !== deployer.address.toLowerCase()) {
    throw new Error(`ProxyAdmin owner mismatch. deployer=${deployer.address}, owner=${adminOwner}`);
  }

  // 프록시의 admin 슬롯이 ProxyAdmin인지 확인 (ERC1967Storage ABI 사용)
  const proxyAsErc1967 = await ethers.getContractAt("ERC1967Storage", PROXY_ADDRESS);
  const proxyAdminSlot = await proxyAsErc1967.getAdmin();
  console.log("Proxy.getAdmin():", proxyAdminSlot);

  if (proxyAdminSlot.toLowerCase() !== PROXY_ADMIN_ADDRESS.toLowerCase()) {
    throw new Error(
      `Proxy admin slot mismatch. expected=${PROXY_ADMIN_ADDRESS}, actual=${proxyAdminSlot}`
    );
  }

  // (1) Deploy MyERC20V2 implementation
  const MyERC20V2 = await ethers.getContractFactory("MyERC20V2", deployer);
  const implV2 = await MyERC20V2.deploy();
  await implV2.waitForDeployment();

  const implV2Addr = await implV2.getAddress();
  console.log("MyERC20V2 deployed:", implV2Addr);

  // (2) Encode initializeV2(bool)
  const initV2Data = MyERC20V2.interface.encodeFunctionData("initializeV2", [
    true, // whitelistEnabled = true
  ]);

  // (3) Upgrade via ProxyAdmin.upgradeAndCall
  console.log("Upgrading proxy to V2...");

  const tx = await proxyAdmin.upgradeAndCall(PROXY_ADDRESS, implV2Addr, initV2Data);
  console.log("Upgrade tx:", tx.hash);

  await tx.wait();
  console.log("Proxy upgraded to V2!");

  // (4) Verify behavior by attaching V2 ABI to proxy address
  const tokenV2 = await ethers.getContractAt("MyERC20V2", PROXY_ADDRESS, deployer);

  console.log("Token name        :", await tokenV2.name());
  console.log("Whitelist enabled :", await tokenV2.whitelistEnabled());
  console.log("Owner             :", await tokenV2.owner());

  // (선택) implementation 슬롯도 다시 확인
  const implNow = await proxyAsErc1967.getImplementation();
  console.log("Proxy.getImplementation():", implNow);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
