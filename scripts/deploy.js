const { ethers } = require("hardhat");

async function main() {
  // 배포에 사용될 계정(= hardhat.config.js의 accounts[0])
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // 잔액 확인 (Sepolia ETH)
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Deployer balance (wei):", balance.toString());
  console.log("Deployer balance (ETH):", ethers.formatEther(balance));

  // 컨트랙트 팩토리 가져오기 (컴파일된 아티팩트 기반)
  const MyERC20 = await ethers.getContractFactory("MyERC20");

  // 배포 파라미터
  const name = "MyToken2";
  const symbol = "MTK2";
  const decimals = 18;
  const initialSupply = 1; // 사람 단위 (1 토큰)
  console.log("Deploy args:", { name, symbol, decimals, initialSupply });

  // 배포 트랜잭션 생성 + 전송
  const token = await MyERC20.deploy(name, symbol, decimals, initialSupply);

  // ethers v6: 배포 완료 대기
  await token.waitForDeployment();

  const addr = await token.getAddress();
  console.log("MyERC20 deployed to:", addr);

  // (선택) 배포 직후 간단 조회
  const totalSupply = await token.totalSupply();
  console.log("totalSupply (base unit):", totalSupply.toString());
  console.log("totalSupply (human):", ethers.formatUnits(totalSupply, decimals));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
