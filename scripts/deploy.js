const { BigNumber } = require("ethers")
const { ethers, upgrades } = require("hardhat")

async function main() {
    // We get the contract to deploy
    const Xeth = await ethers.getContractFactory("XETH")
    const Xlocker = await ethers.getContractFactory("XLOCKER")

    const xeth = await Xeth.deploy()
    await xeth.deployed()
    console.log("xeth deployed to:", xeth.address)

    const xlocker = await upgrades.deployProxy(Xlocker, [xeth.address, "0xb63c4F8eCBd1ab926Ed9Cb90c936dffC0eb02cE2", BigNumber.from("1000000000000000000000000"), BigNumber.from("1000000000000000000000000000000")])
    await xlocker.deployed()
    console.log("xlocker deployed to:", xlocker.address)

    await xeth.transferXlocker(xlocker.address)
    console.log("xlocker permission on xeth transferred")
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    });
  