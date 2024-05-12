const GovernanceToken = artifacts.require("GovernanceToken");

module.exports = function (deployer) {
  deployer.deploy(GovernanceToken).then(function (instance) {
    console.log("GovernanceToken deployed at address:", instance.address);
  });
};
