const GovernanceRewarding = artifacts.require("GovernanceRewarding");
const ReputationToken = artifacts.require("ReputationToken"); // TODO: Implement ReputationToken
const GovernanceToken = artifacts.require("GovernanceToken");
const UtilityStaking = artifacts.require("UtilityStaking");

module.exports = async function (deployer) {
  await deployer.deploy(ReputationToken);
  await deployer.deploy(GovernanceToken);
  await deployer.deploy(UtilityStaking, GovernanceToken.address);

  const repToken = await ReputationToken.deployed();
  const govToken = await GovernanceToken.deployed();
  const staking = await UtilityStaking.deployed();

  await deployer.deploy(
    GovernanceRewarding,
    repToken.address,
    govToken.address,
    staking.address
  );
};
