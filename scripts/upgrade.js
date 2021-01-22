const { ethers, upgrades } = require("hardhat");
const XlockerAddress = "0xAA13f1Fc73baB751Da08930007D4D847EeEafAA2";

async function main() {
    console.log("Upgrading xlocker..")
    const XLOCKER = await ethers.getContractFactory("XLOCKER")
    const Xlocker = await upgrades.upgradeProxy(XlockerAddress, XLOCKER);
    console.log("xlocker upgraded");
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    });
  