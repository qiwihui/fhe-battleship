import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const FHEBattleShip = await deploy("FHEBattleShip", {
    from: deployer,
    log: true,
  });

  console.log(`FHEBattleShip contract: `, FHEBattleShip.address);
};
export default func;
func.id = "deploy_fheBattleShip"; // id required to prevent reexecution
func.tags = ["FHEBattleShip"];
