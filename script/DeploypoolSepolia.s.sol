// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "./Helpers.s.sol";
import {HYPNOS_gameFi} from "../src/mainGame.sol";
import {poolSepolia} from "../src/poolSepolia.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SubscriptionAPI} from "@chainlink/contracts/src/v0.8/vrf/dev/SubscriptionAPI.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


contract Deploy is Script {
    Helper public config;
    ERC1967Proxy public poolProxy;
    poolSepolia public poolContract;

    address public owner;
    
    uint256 updateInterval = 15; //change value

    function run() public {
        config = new Helper();

        (, uint256 key) = config.activeNetworkConfig();
        owner = vm.addr(key);

        vm.startBroadcast(key);

        poolSepolia poolContractImplementation = new poolSepolia();
        bytes memory initPool = abi.encodeWithSelector(
            poolSepolia.initialize.selector,
            vm.addr(key),
            updateInterval,
            address(0x8083aC02ba0bdc3C8409A7A16D3CeBB2875921b2), // HypnosPoint CCIP create in Sepolia 
            address(0x115979034FE9ff8DEef367BE4205BE4E2e42e51a), // BetUsd CCIP create in Sepolia
            vm.addr(key) //address buyer ETHER 
        );
        poolProxy = new ERC1967Proxy(address(poolContractImplementation), initPool);
        poolContract = poolSepolia(payable(poolProxy));

        
        vm.stopBroadcast();
        console.log("address Implementation:", address(poolContractImplementation));
        console.log("address Proxy:", address(poolContract));
        //== Sepolia:
// == Logs ==
//   address Implementation: 0x0FEB4C45EC26fbc336B541F1Fa72281CF57c21d4
//   address Proxy: 0x99A8D5e6c7D88218F9234a73f792fb1c3665642E
    }
}
