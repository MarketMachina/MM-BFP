const UtilityStaking = artifacts.require("UtilityStaking");
const UtilityToken = artifacts.require("UtilityToken");

module.exports = async function (deployer) {
  await deployer.deploy(UtilityToken);
  const utilityToken = await UtilityToken.deployed();
  await deployer.deploy(UtilityStaking, utilityToken.address);
};
