// scripts/upgrade-v2.ts
// - 이미 배포된 TransparentUpgradeableProxy(=토큰 주소)를 V1 → V2 구현 컨트랙트로 업그레이드한다.
// - 업그레이드는 "프록시 admin" 권한이 있어야 가능하며, 여기서는 ProxyAdmin(컨트랙트)이 admin 역할을 한다.
// - 업그레이드와 동시에 initializeV2(true)를 delegatecall로 실행해서 V2의 신규 상태(whitelistEnabled)를 초기화한다.
import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  const net = await ethers.provider.getNetwork();
  console.log("chainId:", net.chainId.toString());
  console.log("Upgrader (EOA):", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  const maxFeePerGas = ethers.parseUnits("30", "gwei");
  const maxPriorityFeePerGas = ethers.parseUnits("2", "gwei");
  console.log("using gas:", {
    maxFeePerGas: maxFeePerGas.toString(),
    maxPriorityFeePerGas: maxPriorityFeePerGas.toString(),
  });

  const PROXY_ADDRESS = "0x8D4D0b5adA7E5311B591D0ed64433E2889562183";
  const PROXY_ADMIN_ADDRESS = "0x081E3Ed1218c2c005A2399b07DC8C732Df32Eed1";

  // (0) ProxyAdmin 소유자 확인
  const proxyAdmin = await ethers.getContractAt("ProxyAdmin", PROXY_ADMIN_ADDRESS, deployer);
  const adminOwner = await proxyAdmin.owner();
  console.log("ProxyAdmin.owner():", adminOwner);

  if (adminOwner.toLowerCase() !== deployer.address.toLowerCase()) {
    throw new Error(`ProxyAdmin owner mismatch. deployer=${deployer.address}, owner=${adminOwner}`);
  }

  // (1) Deploy MyERC20V2 implementation
  const MyERC20V2 = await ethers.getContractFactory("MyERC20V2");
  const implV2 = await MyERC20V2.deploy({
    maxFeePerGas,
    maxPriorityFeePerGas,
  });
  console.log("implV2 tx:", implV2.deploymentTransaction()?.hash);

  await implV2.waitForDeployment();
  const implV2Addr = await implV2.getAddress();
  console.log("MyERC20V2 deployed:", implV2Addr);

  // (2) Encode initializeV2(true)
  const initV2Data = MyERC20V2.interface.encodeFunctionData("initializeV2", [true]);

  // (3) Upgrade via ProxyAdmin.upgradeAndCall
  console.log("Upgrading proxy to V2...");
  const tx = await proxyAdmin.upgradeAndCall(
    PROXY_ADDRESS, // address로 넣어도 ABI상 OK
    implV2Addr,
    initV2Data,
    {
      maxFeePerGas,
      maxPriorityFeePerGas,
    }
  );

  console.log("upgrade tx:", tx.hash);
  await tx.wait();
  console.log("Proxy upgraded to V2");

  // (4) Verify via V2 ABI on proxy address
  const tokenV2 = await ethers.getContractAt("MyERC20V2", PROXY_ADDRESS, deployer);

  console.log("Token name        :", await tokenV2.name());
  console.log("Token symbol      :", await tokenV2.symbol());
  console.log("Owner             :", await tokenV2.owner());
  console.log("Whitelist enabled :", await tokenV2.whitelistEnabled());

  // (5) Quick whitelist behavior check (optional)
  // 기본 whitelistEnabled=true인데, whitelist에 deployer가 안 들어있으면 transfer가 막히는게 정상
  // 아래는 상태만 찍어봄
  const meWhitelisted = await tokenV2.isWhitelisted(deployer.address);
  console.log("Deployer whitelisted?:", meWhitelisted);

  console.log("\n=== RESULT ===");
  console.log("PROXY            =", PROXY_ADDRESS);
  console.log("PROXY_ADMIN      =", PROXY_ADMIN_ADDRESS);
  console.log("IMPLEMENTATION_V2=", implV2Addr);
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
