// scripts/deploy-v1.ts
// - Transparent Proxy 구조에서 V1 토큰을 Sepolia에 배포한다.
// - 구현(Implementation) 배포 → 관리자(ProxyAdmin) 배포 → 프록시(TransparentUpgradeableProxy) 배포 + initialize(delegatecall)
// - 최종적으로 "토큰 주소" = 프록시 주소가 된다(상태는 프록시에 저장되고, 로직은 구현 컨트랙트에 있다).
import { ethers } from "hardhat";

async function main() {
  // 현재 네트워크에 연결된 EOA(지갑) 중 첫 번째 signer를 deployer로 사용
  // 이 EOA가 배포 비용을 지불하고, V1 토큰의 owner로도 설정된다
  const [deployer] = await ethers.getSigners();

  const net = await ethers.provider.getNetwork();
  console.log("chainId:", net.chainId.toString()); // Sepolia: 11155111
  console.log("Deployer:", deployer.address);
  console.log("Balance :", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));
  console.log(
    "nonce latest / pending:",
    await ethers.provider.getTransactionCount(deployer.address, "latest"),
    await ethers.provider.getTransactionCount(deployer.address, "pending")
  );

  const maxFeePerGas = ethers.parseUnits("30", "gwei");
  const maxPriorityFeePerGas = ethers.parseUnits("2", "gwei");
  console.log("using gas:", {
    maxFeePerGas: maxFeePerGas.toString(),
    maxPriorityFeePerGas: maxPriorityFeePerGas.toString(),
  });

  // 1) Deploy Implementation (MyERC20V1)
  console.log("before getContractFactory(MyERC20V1)");
  const MyERC20V1 = await ethers.getContractFactory("MyERC20V1");
  console.log("after getContractFactory(MyERC20V1)");

  const implV1 = await MyERC20V1.deploy({
    maxFeePerGas,
    maxPriorityFeePerGas,
  });

  console.log("implV1 tx:", implV1.deploymentTransaction()?.hash);
  await implV1.waitForDeployment();
  const implV1Addr = await implV1.getAddress();
  console.log("MyERC20V1 (implementation) deployed:", implV1Addr);

  // 2) Deploy ProxyAdmin
  const ProxyAdmin = await ethers.getContractFactory("ProxyAdmin");
  const proxyAdmin = await ProxyAdmin.deploy(deployer.address, {
    maxFeePerGas,
    maxPriorityFeePerGas,
  });

  console.log("ProxyAdmin tx:", proxyAdmin.deploymentTransaction()?.hash);
  await proxyAdmin.waitForDeployment();
  const proxyAdminAddr = await proxyAdmin.getAddress();
  console.log("ProxyAdmin deployed:", proxyAdminAddr);

  // 3) Encode initialize calldata
  const name = "MyERC20ProxyToken";
  const symbol = "MEPTK";
  const decimals = 18;
  const initialSupplyWhole = 100;
  const owner = deployer.address;

  const initData = MyERC20V1.interface.encodeFunctionData("initialize", [
    name,
    symbol,
    decimals,
    initialSupplyWhole,
    owner,
  ]);

  // 4) Deploy TransparentUpgradeableProxy with initData
  const TransparentUpgradeableProxy = await ethers.getContractFactory(
    "TransparentUpgradeableProxy"
  );

  const proxy = await TransparentUpgradeableProxy.deploy(implV1Addr, proxyAdminAddr, initData, {
    maxFeePerGas,
    maxPriorityFeePerGas,
  });

  console.log("Proxy tx:", proxy.deploymentTransaction()?.hash);
  await proxy.waitForDeployment();
  const proxyAddr = await proxy.getAddress();
  console.log("TransparentUpgradeableProxy deployed:", proxyAddr);

  // 5) Attach token ABI to proxy and verify state
  const token = await ethers.getContractAt("MyERC20V1", proxyAddr, deployer);

  console.log("Token(name)        :", await token.name());
  console.log("Token(symbol)      :", await token.symbol());
  console.log("Token(decimals)    :", await token.decimals());
  console.log("Token(owner)       :", await token.owner());
  console.log("Token(totalSupply) :", (await token.totalSupply()).toString());
  console.log("Deployer(balance)  :", (await token.balanceOf(deployer.address)).toString());

  console.log("\n=== RESULT ===");
  console.log("IMPLEMENTATION_V1  =", implV1Addr);
  console.log("PROXY_ADMIN        =", proxyAdminAddr);
  console.log("PROXY (TOKEN ADDR) =", proxyAddr);
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
