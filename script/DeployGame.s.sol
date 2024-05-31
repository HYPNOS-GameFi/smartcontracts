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

contract DeployGame is Script {
    Helper public config;
    ERC1967Proxy public gameProxy;
    HYPNOS_gameFi public game;
    bool public deployMock = true;
    bool addComsumer = true;

    address public owner;
    string baseURI_ = "www.baseuri.com/";
    string name_ = "Hypnos Aircraft Game";
    string symbol_ = "HYPNOS";
    uint256 maxSupply_ = 1000000000;
    uint256 takerFee = 2000;
    uint256[4] priceClass = [0, 0, 0, 0];
    string[4] types = ["type1", "type2", "type3", "type4"];

    bytes32 public keyHash =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    address public vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    uint256 public subscriptionId =
        96567368677880215435170564852330740244166011897832844594320589257713968911176;

    function run() public {
        config = new Helper();

        (, uint256 key) = config.activeNetworkConfig();
        owner = vm.addr(key);

        vm.startBroadcast(key);

        HYPNOS_gameFi gameimplemantation = new HYPNOS_gameFi(
            vrfCoordinator,
            keyHash,
            subscriptionId
        );

        bytes memory init = abi.encodeWithSelector(
            HYPNOS_gameFi.initialize.selector,
            owner,
            baseURI_,
            name_,
            symbol_,
            maxSupply_,
            address(0x6b022ACfAA62c3660B1eB163f557E93D8b246041), // BetUSD moy destination CCIP
            address(0xF90d22a0a22E85a349cbab43325267F360FE210E), // HypnosPoint Polygon Amoy destination CCIP
            address(0xFf3dcCC06fa00CD2AD821B6843FAcd0AF0504bE3), //poolGame na polygonAmoy destination CCIP
            takerFee,
            priceClass,
            types
        );

        gameProxy = new ERC1967Proxy(address(gameimplemantation), init);

        //game = HYPNOS_gameFi(address(new ERC1967Proxy(address(game), init)));
        game = HYPNOS_gameFi(payable(gameProxy));

        if (addComsumer) {
            SubscriptionAPI(vrfCoordinator).addConsumer(
                subscriptionId,
                address(game)
            );
        }

        vm.stopBroadcast();

        console.log("address implementation:", address(gameimplemantation));
        console.log("game Proxy:", address(game));
    }
}
