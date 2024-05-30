// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "./Helpers.s.sol";
import {HYPNOS_gameFi} from "../src/mainGame.sol";
import {poolAmoy} from "../src/poolAmoy.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SubscriptionAPI} from "@chainlink/contracts/src/v0.8/vrf/dev/SubscriptionAPI.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


contract Deploy is Script {
    Helper public config;
    ERC1967Proxy public poolProxy;
    poolAmoy public poolContract;

    address public owner;
    
    uint256 updateInterval = 15; //change value

    function run() public {
        config = new Helper();

        (, uint256 key) = config.activeNetworkConfig();
        owner = vm.addr(key);

        vm.startBroadcast(key);

        poolAmoy poolContractImplementation = new poolAmoy();
        bytes memory initPool = abi.encodeWithSelector(
            poolAmoy.initialize.selector,
            vm.addr(key),
            updateInterval,
            address(0x6b022ACfAA62c3660B1eB163f557E93D8b246041), // BetUSD
            address(0xF90d22a0a22E85a349cbab43325267F360FE210E), // HypnosPoint
            vm.addr(key) //address buyer ETHER
        );
        poolProxy = new ERC1967Proxy(address(poolContractImplementation), initPool);
        poolContract = poolAmoy(payable(poolProxy));

        
        vm.stopBroadcast();
        console.log("address Implementation:", address(poolContractImplementation));
        console.log("address Proxy:", address(poolContract));
    }
}
