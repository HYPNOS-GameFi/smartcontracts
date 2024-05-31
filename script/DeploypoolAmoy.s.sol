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
            address(0x44bE502B660605aea4cC3837e315CDaE7c3A95eC), // BetUSD CCIP create
            address(0xdF11fbE9C288EA58b4E2Fb6Da03f571710B48129), // HypnosPoint CCIP create
            vm.addr(key) //address buyer ETHER
        );
        poolProxy = new ERC1967Proxy(address(poolContractImplementation), initPool);
        poolContract = poolAmoy(payable(poolProxy));

        
        vm.stopBroadcast();
        console.log("address Implementation:", address(poolContractImplementation));
        console.log("address Proxy:", address(poolContract));
        //== Logs ==
// == Logs ==
//   address Implementation: 0xD874FbA91045f3FAE6FFC7aee24724DaDc8C9EBe
//   address Proxy: 0xd6A18bEE62E617107942f2EF59d73d153c1E92c1
    }
}
