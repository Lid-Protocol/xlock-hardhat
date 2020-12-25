const { BigNumber } = require("ethers")
const { ethers, upgrades } = require("hardhat")

async function main() {
    // We get the contract to deploy
    const Xeth = await ethers.getContractFactory("XETH")
    const Xlocker = await ethers.getContractFactory("XLOCKER")

    const xeth = await Xeth.deploy()
    await xeth.deployed()
    console.log("xeth deployed to:", xeth.address)

    const xlocker = await upgrades.deployProxy(Xlocker, [xeth.address, "0x4735581201F4cAD63CCa0716AB4ac7D6d9CFB0ed", BigNumber.from("1000000000000000000000000"), BigNumber.from("1000000000000000000000000000000")])
    await xlocker.deployed()
    console.log("xlocker deployed to:", xlocker.address)

    await xeth.grantXethLockerRole(xlocker.address)
    console.log("xlocker permission on xeth granted")
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    });
  