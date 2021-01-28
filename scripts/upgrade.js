const { ethers, upgrades } = require("hardhat");
const XlockerAddress = "0x45a0A95Df3DAE8A9741328a0b7ce04DF55C22124";
const XethLiqManagerAddress = "0x24a20012D9D1c4f62De50f89cDb7eDDf37385DF5";

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
  