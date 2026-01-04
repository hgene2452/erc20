// scripts/deploy-v1.ts
// - Implementation(MyERC20V1) 배포
// - ProxyAdmin 배포
// - initialize calldata 인코딩
// - TransparentUpgradeableProxy 배포하면서 initialize를 delegatecall로 실행
// - 프록시 주소를 토큰 주소처럼 사용해서 상태 확인
import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deployer:", deployer.address);
  console.log("Balance :", (await ethers.provider.getBalance(deployer.address)).toString());

  // 1) Implementation 배포 (MyERC20V1)
  // - 업그레이더블 구조에서 Implementation은 "로직 코드" 역할
  // - 실제 토큰 상태(이름, 심볼, 소유자, 잔고 등)는 프록시에 저장된다
  const MyERC20V1 = await ethers.getContractFactory("MyERC20V1");
  const implV1 = await MyERC20V1.deploy();
  await implV1.waitForDeployment();

  const implV1Addr = await implV1.getAddress();
  console.log("MyERC20V1 (implementation) deployed:", implV1Addr);

  // 2) ProxyAdmin 배포
  const ProxyAdmin = await ethers.getContractFactory("ProxyAdmin");
  const proxyAdmin = await ProxyAdmin.deploy(deployer.address);
  await proxyAdmin.waitForDeployment();

  const proxyAdminAddr = await proxyAdmin.getAddress();
  console.log("ProxyAdmin deployed:", proxyAdminAddr);

  // 3) initialize calldata 인코딩
  const name = "MyProxyToken";
  const symbol = "MPTK";
  const decimals = 18;
  const initialSupplyWhole = 1_000_000;
  const owner = deployer.address;

  const initData = MyERC20V1.interface.encodeFunctionData("initialize", [
    name,
    symbol,
    decimals,
    initialSupplyWhole,
    owner,
  ]);

  // 4) TransparentUpgradeableProxy 배포
  // - proxy가 ERC1967 슬롯에 impl/admin 저장
  // - proxy가 implementation으로 delegatecall(data) 수행
  // - initialize 로직이 "proxy storage"에 실행 결과를 기록
  const TransparentUpgradeableProxy = await ethers.getContractFactory(
    "TransparentUpgradeableProxy"
  );
  const proxy = await TransparentUpgradeableProxy.deploy(implV1Addr, proxyAdminAddr, initData);
  await proxy.waitForDeployment();

  const proxyAddr = await proxy.getAddress();
  console.log("TransparentUpgradeableProxy deployed:", proxyAddr);

  // 5) proxy 주소를 "MyERC20V1 ABI"로 붙여서 토큰처럼 사용
  const token = MyERC20V1.attach(proxyAddr);

  console.log("Token(name)  :", await token.name());
  console.log("Token(symbol):", await token.symbol());
  console.log("Token(decimals):", await token.decimals());
  console.log("Token(owner) :", await token.owner());
  console.log("Token(totalSupply):", (await token.totalSupply()).toString());
  console.log("Deployer(balance):", (await token.balanceOf(deployer.address)).toString());

  // 6) (디버깅) ERC1967 슬롯 값 확인
  const proxyAsErc1967 = await ethers.getContractAt("ERC1967Storage", proxyAddr);
  console.log("Proxy.getImplementation():", await proxyAsErc1967.getImplementation());
  console.log("Proxy.getAdmin():", await proxyAsErc1967.getAdmin());

  console.log("\n=== RESULT ===");
  console.log("IMPLEMENTATION_V1 =", implV1Addr);
  console.log("PROXY_ADMIN       =", proxyAdminAddr);
  console.log("PROXY (TOKEN ADDR)=", proxyAddr);
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
