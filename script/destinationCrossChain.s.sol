// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "./Helpers.s.sol";
import {HYPNOS_gameFi} from "../src/mainGame.sol";
import {pool} from "../src/pool.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SubscriptionAPI} from "@chainlink/contracts/src/v0.8/vrf/dev/SubscriptionAPI.sol";

import {hypnosPoint} from "../src/hypnosPoint.sol";
import {betUSD} from "../src/betUSD.sol";
import {destinationHypnosPoint} from "../src/chainlink/destinationHypnosPoint.sol";
import {destinationBetUSD} from "../src/chainlink/destinationBetUSD.sol";

//tba import
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDestination is Script, Helper {

    Helper public config;
    hypnosPoint public hypnospoint;
    ERC1967Proxy public hypnospointProxy;
    betUSD public betusd;
    ERC1967Proxy public betUSDProxy;
    address public owner;

     bytes32 public salt = bytes32("HypnosAndBetUSD");
    //forge script ./script/DeployGame.s.sol:DeployDestination -vvv --broadcast --rpc-url amoy --sig "run(uint8)" -- 4 --verify -vvvv
    function run(SupportedNetworks destination) external { //destination 4 deve ser na polygon amoy
        config = new Helper();

        (, uint256 key) = config.activeNetworkConfig();
        owner = vm.addr(key);

        vm.startBroadcast(key);

        (address router, , , ) = getConfigFromNetwork(destination);

        //HypnosPoint in AMOY for CCIP

        hypnosPoint hypnospointlementation = new hypnosPoint{salt: salt}();
        bytes memory init = abi.encodeWithSelector(
            hypnosPoint.initialize.selector,
            owner,
            100e18
        );
        hypnospointProxy = new ERC1967Proxy{salt: salt}(
            address(hypnospointlementation),
            init
        );
        hypnospoint = hypnosPoint(payable(hypnospointProxy));

        console.log(
            "hypnosPoint deployed on ",
            networks[destination],
            "with address Proxy: ",
            address(hypnospoint) //
        );

        destinationHypnosPoint destinationMinter = new destinationHypnosPoint{salt: salt}(
            router,//pass 4
            address(hypnospoint)
        ); //esse vai ser o endereco que iremmos interagir para

        console.log(
            "destinationHypnosPoint deployed on ",
            networks[destination],
            "with address Proxy: ",
            address(destinationMinter)
        );

        hypnospoint.transferOwnership(address(destinationMinter));
        address minter = hypnospoint.owner();

        console.log("Minter role granted hypnosPoint to: ", minter);

        //BetUSD in AMOY for CCIP

        betUSD betUSDintlementation = new betUSD{salt: salt}();
        bytes memory initBUSD = abi.encodeWithSelector(
            betUSD.initialize.selector,
            owner
        );
        betUSDProxy = new ERC1967Proxy{salt: salt}(
            address(betUSDintlementation),
            initBUSD
        );
        betusd = betUSD(payable(betUSDProxy));

        console.log(
            "betUSDProxy deployed on ",
            networks[destination],
            "with address Proxy: ",
            address(betusd) //
        );

        destinationBetUSD destinationMinterUSD = new destinationBetUSD{salt: salt}(
            router,//pass 4
            address(betusd)
        ); //esse vai ser o endereco que iremmos interagir para

        console.log(
            "destinationbetusd deployed on ",
            networks[destination],
            "with address Proxy: ",
            address(destinationMinterUSD)
        );

        betusd.transferOwnership(address(destinationMinterUSD));
        address minterUSD = betusd.owner();

        console.log("Minter role BetUSD granted to: ", minterUSD);

        vm.stopBroadcast();
    }

    /*
  AMOY
  == Logs ==
  hypnosPoint deployed on  Polygon Amoy with address Proxy:  0xdF11fbE9C288EA58b4E2Fb6Da03f571710B48129
  destinationHypnosPoint deployed on  Polygon Amoy with address Proxy:  0xF90d22a0a22E85a349cbab43325267F360FE210E
  Minter role granted hypnosPoint to:  0xF90d22a0a22E85a349cbab43325267F360FE210E
  betUSDProxy deployed on  Polygon Amoy with address Proxy:  0x44bE502B660605aea4cC3837e315CDaE7c3A95eC
  destinationbetusd deployed on  Polygon Amoy with address Proxy:  0x6b022ACfAA62c3660B1eB163f557E93D8b246041
  Minter role BetUSD granted to:  0x6b022ACfAA62c3660B1eB163f557E93D8b246041
  */
}