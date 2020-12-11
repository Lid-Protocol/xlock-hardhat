const { ethers, upgrades } = require("hardhat")

async function main() {
    // We get the contract to deploy
    const Xeth = await ethers.getContractFactory("XETH")
    const Xlocker = await ethers.getContractFactory("XLOCKER")

    const xeth = await upgrades.deployProxy(Xeth, [42]);
    await xeth.deployed()
    console.log("xeth deployed to:", xeth.address)

    const xlocker = await upgrades.deployProxy(Xlocker, [42], xeth.address)
    // const xlocker = await Xlocker.deploy(xeth.address)
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
  