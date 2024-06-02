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
    ERC1967Proxy public paymentProxy;
    betUSD public payment;
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

    // // Sepolia
    // bytes32 public keyHash =
    //     0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    // address public vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    // uint256 public subscriptionId =
    //     96567368677880215435170564852330740244166011897832844594320589257713968911176;

    // Amoy
    bytes32 public keyHash =
        0x816bedba8a50b294e5cbd47842baf240c2385f2eaf719edbd4f250a137a8c899;
    address public vrfCoordinator = 0x343300b5d84D444B2ADc9116FEF1bED02BE49Cf2;
    uint256 public subscriptionId =
        51993705499517109063832034032218776670133583656275697804326118989428630673606;

    function run() public {
        config = new Helper();

        (, uint256 key) = config.activeNetworkConfig();
        owner = vm.addr(key);

        vm.startBroadcast(key);

        ///deploy hipnosPoint and betUSD in Sepolia

        betUSD paymentImplementation = new betUSD();

        bytes memory initPayment = abi.encodeWithSelector(
            betUSD.initialize.selector,
            owner
        );

        paymentProxy = new ERC1967Proxy(
            address(paymentImplementation),
            initPayment
        );
        payment = betUSD(payable(paymentProxy));

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
            address(0x0C7F40890c8d8753345426F37cCE98D6E995A147), // BetUSD Sepolia destination CCIP
            address(0xb8618b26B69939E4f70b0878C97a1b8eC3CC269f), // HypnosPoint Sepolia destination CCIP
            address(0x99A8D5e6c7D88218F9234a73f792fb1c3665642E), //poolGame na Sepolia 
            address(0x8880F777d00303a857eb756dFA789Ce000c3Eac9), ///airdrop in fuji Destination CCIP
            takerFee,
            priceClass,
            types,
            address(payment) //in Amoy
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
        console.log("Payment Proxy:", address(payment));
    }

    /*final contracts:

  == Logs ==
  address implementation: 0x2Bf755cfAB80e0aEdc15beF03ed81ceC8FbcAbba
  game Proxy: 0x3DE5a892F07a8A5c47BcA2fFFDdacFEc8831fFb7
  Payment Proxy: 0xafc76132CbDB10b7C863400ae84fEe648cc38d0c
    */
}
