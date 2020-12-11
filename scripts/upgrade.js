const { ethers, upgrades } = require("hardhat")

async function main() {
    // const BoxV2 = await ethers.getContractFactory("BoxV2");
    // const box = await upgrades.upgradeProxy(BOX_ADDRESS, BoxV2);
    // console.log("Box upgraded");
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    });
  