const { ethers, upgrades } = require("hardhat");
const XlockerAddress = "0xAA13f1Fc73baB751Da08930007D4D847EeEafAA2";
const XethLiqManagerAddress = "0xddeffEf1230b33deCb43DcD52445a05F01077e9a";

async function main() {
    console.log("Upgrading xlocker..")
    const XLOCKER = await ethers.getContractFactory("XLOCKER")
    const Xlocker = await upgrades.upgradeProxy(XlockerAddress, XLOCKER);
    console.log("xlocker upgraded");

    console.log("Upgrading XethLiqManager..");
    const XethLiqManager = await ethers.getContractFactory("XethLiqManager");
    const xethLiqManager = await upgrades.upgradeProxy(XethLiqManagerAddress, XethLiqManager);
    console.log("XethLiqManager upgraded");
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    });
  