const UtilityToken = artifacts.require("UtilityToken");

module.exports = function (deployer) {
  deployer.deploy(UtilityToken).then(function (instance) {
    console.log("UtilityToken deployed at address:", instance.address);
  });
};
