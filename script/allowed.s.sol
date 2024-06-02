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

contract Deploy is Script {
    Helper public config;
    ERC1967Proxy public gameProxy;
    HYPNOS_gameFi public game;
    ERC1967Proxy public paymentProxy;
    betUSD public payment;
    bool public deployMock = true;
    bool addComsumer = true;
    address public owner;


    function run() public {
        config = new Helper();

        (, uint256 key) = config.activeNetworkConfig();
        owner = vm.addr(key);

        address[] memory addresses = new address[](5);
        addresses[0] = address(0x53A285371178c07b8929C11b4540aa48ACbcCFD6);//id 16436aef-2722-4245-91e9-547654c9fc9d
        addresses[1] = address(0xB999DDAd0d3016853Bd9382DE592113833962b84);//id 355e27d3-24d9-4318-b381-6ce377c66b8d
        addresses[2] = address(0x6eAC7E54a00021ec87a836b27ff3005976d8176D);//id b83e7d9a-ade4-4f2a-a8af-4ff17f45e528
        addresses[3] = address(0x1d25dc28ECd93cDE0D7CF6f695d4Ab8F3dcbbe2F);//id 8dbbaae5-08e9-45f7-8173-5f4bffa3cadb
        addresses[4] = address(0x0022294cb8ADe131beAC413A154f5ae2634f499d);//id 88db8f17-a023-4b27-ba30-26843c92e618

        vm.startBroadcast(key);


        for (uint256 i = 0; i < addresses.length; i++) {
            address recipient = addresses[i];
           HYPNOS_gameFi(0xeC0b52dA681658a2627cC89B0e20bC74f424C2bE).allowAddress(recipient);
        }

        vm.stopBroadcast();

}

}