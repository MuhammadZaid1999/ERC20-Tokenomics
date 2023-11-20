// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
 
  const Token = await hre.ethers.getContractFactory("Token");
  const token = await Token.deploy('UToken', 'UTT');
  await token.deployed();

  const ICO = await hre.ethers.getContractFactory("ICO");
  const ico = await ICO.deploy(token.address);

  console.log(
    `Token deployed to ${token.address}`,
    `ICO deployed to ${ico.address}`
  );
  console.log(await token.approve(ico.address, 100000000000000000n));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
