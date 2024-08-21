const CactusLaunchpad = artifacts.require("CactusLaunchpad");

module.exports = async function (deployer) {
  await deployer.deploy(CactusLaunchpad, '0x649a339B8FC3A8bA0A03255c00fDC5D969684074', '0x186506Ce0E71D7E5EC07AD8B023c10F1A401cC5a');
};