const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")

const BASE_FEE = ethers.parseEther("0.25") //025 is the premium. It costs 0.25link
const GAS_PRICE_LINK = 1e9 //link per gas. calculated alue based on the gas price of the chain

//eth price got sky rocketed , so gas price would be to high
//chainlink nodes pay the gas fees to give us randomnes & do external execution
// so the price of requests change based on the price of gas

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    const args = [BASE_FEE, GAS_PRICE_LINK]

    if (developmentChains.includes(network.name)) {
        log("local ntw detected! deploying mocks...")
        //deploying a mock vrfcoordinator...

        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: args,
        })
        log("mock deployed!")
        log("-----------------------------")
    }
}

module.exports.tags = ["all", "mokcs"]
