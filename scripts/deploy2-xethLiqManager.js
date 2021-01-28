const { BigNumber } = require("ethers");
const { ethers, upgrades } = require("hardhat");

const addresses = {
  xeth: "0xA2F864C1c1a27f257c10FfBCFAeCa252B5610B4b",
  router: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
  factory: "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
}

async function main() {
    // We get the contract to deploy
    const XethLiqManager = await ethers.getContractFactory("XethLiqManager");

    const xeth = await ethers.getContractAt("XETH",addresses.xeth);

    console.log("Deploying xethLiqManager...");
    const xethLiqManager = await upgrades.deployProxy(XethLiqManager, [
      addresses.xeth,
      addresses.router,
      addresses.factory,
      "2500",
      BigNumber.from("1000000000000000000000")
    ]);
    await xethLiqManager.deployed();
    console.log("xethLiqManager deployed to:", xethLiqManager.address);

    console.log("Granting xethLiqManager mint role...");
    await xeth.grantXethLockerRole(xethLiqManager.address);

    console.log("Waiting 5 minutes...")
    await (()=> new Promise ((resolve)=>setTimeoute(resolve,300000)))();

    console.log("Initializing pair...");
    await xethLiqManager.initializePair();
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    });
  