const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  const supply = 20000; // 20,000 tokens each

  const Token = await hre.ethers.getContractFactory("CBLToken");

  const cbl = await Token.deploy("CBL Token", "CBL", supply);
  await cbl.waitForDeployment();
  console.log("✅ CBL Token deployed at:", await cbl.getAddress());

  const tkn2 = await Token.deploy("Token Two", "TKN2", supply);
  await tkn2.waitForDeployment();
  console.log("✅ Token Two deployed at:", await tkn2.getAddress());

  const tkn3 = await Token.deploy("Token Three", "TKN3", supply);
  await tkn3.waitForDeployment();
  console.log("✅ Token Three deployed at:", await tkn3.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
