const { ethers, upgrades } = require("hardhat");
const XlockerAddress = "0xAA13f1Fc73baB751Da08930007D4D847EeEafAA2";

async function main() {
    const Xeth = await ethers.getContractFactory("XETH")
    const Xlocker = await upgrades.upgradeProxy(XlockerAddress, Xlocker);
    console.log("xlocker upgraded");
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    });
  