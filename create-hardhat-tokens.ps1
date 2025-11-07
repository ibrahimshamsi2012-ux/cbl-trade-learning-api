# create-hardhat-tokens.ps1
$root = "$HOME\Desktop\cbl-trade-learning-sepolia"
$backend = Join-Path $root "backend"
Set-Location $backend

# Install hardhat stack (local usage only)
npm install --legacy-peer-deps --save-dev hardhat @nomicfoundation/hardhat-toolbox dotenv @openzeppelin/contracts

# If hardhat not initialized, init
if (-not (Test-Path "hardhat.config.js")) {
  npx hardhat init --force
}

# Ensure Hardhat config is local-only and commonjs
@'
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
module.exports = {
  solidity: "0.8.24",
  networks: {
    hardhat: { chainId: 1337 }
  }
};
'@ | Set-Content -Path (Join-Path $backend "hardhat.config.js") -Encoding UTF8

# Create contracts folder
if (-not (Test-Path "contracts")) { New-Item -ItemType Directory -Name contracts | Out-Null }

# Write clean solidity file (no BOM)
@'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CBLToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }
}
'@ | Set-Content -Path (Join-Path $backend "contracts/CBLToken.sol") -Encoding Ascii

# Create scripts folder if missing
if (-not (Test-Path "scripts")) { New-Item -ItemType Directory -Name scripts | Out-Null }

# Write deploy script (CommonJS style for compatibility)
@'
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  const supply = 20000;

  const Token = await hre.ethers.getContractFactory("CBLToken");

  const cbl = await Token.deploy("CBL Token", "CBL", supply);
  await cbl.waitForDeployment ? await cbl.waitForDeployment() : await cbl.deployed();
  console.log("CBL:", cbl.address);

  const tkn2 = await Token.deploy("Token Two", "TKN2", supply);
  await tkn2.waitForDeployment ? await tkn2.waitForDeployment() : await tkn2.deployed();
  console.log("TKN2:", tkn2.address);

  const tkn3 = await Token.deploy("Token Three", "TKN3", supply);
  await tkn3.waitForDeployment ? await tkn3.waitForDeployment() : await tkn3.deployed();
  console.log("TKN3:", tkn3.address);
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
'@ | Set-Content -Path (Join-Path $backend "scripts/deploy.js") -Encoding UTF8

# Compile and deploy to local Hardhat network
npx hardhat clean
npx hardhat compile
# Deploy to ephemeral hardhat network (run script using built-in network)
npx hardhat run scripts/deploy.js --network hardhat
