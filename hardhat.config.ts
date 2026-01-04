// hardhat.config.ts: Hardhat이 프로젝트를 컴파일하고 배포하는데 필요한 설정 파일
import { HardhatUserConfig } from "hardhat/config";

import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "",
      accounts: [process.env.PRIVATE_KEY, process.env.PRIVATE_KEY_SPENDER].filter(
        Boolean
      ) as string[],
    },
  },
};

export default config;
