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
import {destinationAirdrop} from "../src/chainlink/destinationAirdrop.sol";
import {airdropFuji} from "../src/airdropFuji.sol";

import {HelperFunction} from "./HelperFunction.sol";
import {dIBTAETF} from "../src/chainlink/dIBTAETF.sol";
import {IGetTslaReturnTypes} from "../src/interfaces/IGetTslaReturnTypes.sol";

//tba import
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

//0 sepolia -- 2 Fuji -- 4 Amoy
contract DeployDestination is Script, Helper {
    Helper public config;

    hypnosPoint public hypnospoint;
    ERC1967Proxy public hypnospointProxy;

    betUSD public betusd;
    ERC1967Proxy public betUSDProxy;
    
    airdropFuji public airdropfuji;
    ERC1967Proxy public airdropFujiProxy;
    address public owner;

    bytes32 public salt = bytes32("PoolFuji");
    //forge script ./script/crossChainGame.s.sol:DeployDestination -vvv --broadcast --rpc-url sepolia --sig "run(uint8)" -- 0 --verify -vvvv

    function run(SupportedNetworks destination) external {
        //destination 4 deve ser na polygon amoy
        config = new Helper();

        (, uint256 key) = config.activeNetworkConfig();
        owner = vm.addr(key);

        vm.startBroadcast(key);

        (address router,,,) = getConfigFromNetwork(destination);

        //HypnosPoint in Sepolia for CCIP

        // hypnosPoint hypnospointlementation = new hypnosPoint{salt: salt}();
        // bytes memory init = abi.encodeWithSelector(hypnosPoint.initialize.selector, owner, 100e18);
        // hypnospointProxy = new ERC1967Proxy{salt: salt}(address(hypnospointlementation), init);
        // hypnospoint = hypnosPoint(payable(hypnospointProxy));

        // console.log(
        //     "hypnosPoint deployed on ",
        //     networks[destination],
        //     "with address Proxy: ",
        //     address(hypnospoint) //
        // );

        // destinationHypnosPoint destinationMinter = new destinationHypnosPoint{salt: salt}(
        //     router, //pass 4
        //     address(hypnospoint)
        // ); //esse vai ser o endereco que iremmos interagir para

        // console.log(
        //     "destinationHypnosPoint deployed on ",
        //     networks[destination],
        //     "with address Proxy: ",
        //     address(destinationMinter)
        // );

        // hypnospoint.transferOwnership(address(destinationMinter));
        // address minter = hypnospoint.owner();

        // console.log("Minter role granted hypnosPoint to: ", minter);

        // //BetUSD in Sepolia for CCIP

        // betUSD betUSDintlementation = new betUSD{salt: salt}();
        // bytes memory initBUSD = abi.encodeWithSelector(betUSD.initialize.selector, owner);
        // betUSDProxy = new ERC1967Proxy{salt: salt}(address(betUSDintlementation), initBUSD);
        // betusd = betUSD(payable(betUSDProxy));

        // console.log(
        //     "betUSDProxy deployed on ",
        //     networks[destination],
        //     "with address Proxy: ",
        //     address(betusd) //
        // );

        // destinationBetUSD destinationMinterUSD = new destinationBetUSD{salt: salt}(
        //     router, //pass 4
        //     address(betusd)
        // ); //esse vai ser o endereco que iremmos interagir para

        // console.log(
        //     "destinationbetusd deployed on ",
        //     networks[destination],
        //     "with address Proxy: ",
        //     address(destinationMinterUSD)
        // );

        // betusd.transferOwnership(address(destinationMinterUSD));
        // address minterUSD = betusd.owner();

        // console.log("Minter role BetUSD granted to: ", minterUSD);

        /*
        hypnosPoint deployed on  Ethereum Sepolia with address Proxy:  0x8083aC02ba0bdc3C8409A7A16D3CeBB2875921b2
  destinationHypnosPoint deployed on  Ethereum Sepolia with address Proxy:  0xb8618b26B69939E4f70b0878C97a1b8eC3CC269f
  Minter role granted hypnosPoint to:  0xb8618b26B69939E4f70b0878C97a1b8eC3CC269f
  betUSDProxy deployed on  Ethereum Sepolia with address Proxy:  0x115979034FE9ff8DEef367BE4205BE4E2e42e51a
  destinationbetusd deployed on  Ethereum Sepolia with address Proxy:  0x0C7F40890c8d8753345426F37cCE98D6E995A147
  Minter role BetUSD granted to:  0x0C7F40890c8d8753345426F37cCE98D6E995A147

        */



        //forge script ./script/CroosChainGame.s.sol:DeployDestination -vvv --broadcast --rpc-url fuji --sig "run(uint8)" -- 2 --verify -vvvv

        //Airdrop in Fuji for CCIP

        hypnosPoint hypnospointlementation = new hypnosPoint{salt: salt}();
        bytes memory init = abi.encodeWithSelector(hypnosPoint.initialize.selector, owner, 100e18);
        hypnospointProxy = new ERC1967Proxy{salt: salt}(address(hypnospointlementation), init);
        hypnospoint = hypnosPoint(payable(hypnospointProxy));
        

        airdropFuji airdropFujiintlementation = new airdropFuji{salt: salt}();
        bytes memory initAirdrop = abi.encodeWithSelector(airdropFuji.initialize.selector, 
        owner, address(hypnospoint));
        airdropFujiProxy = new ERC1967Proxy{salt: salt}(address(airdropFujiintlementation), initAirdrop);
        airdropfuji = airdropFuji(payable(airdropFujiProxy));

        console.log(
            "airdropFujiProxy deployed on ",
            networks[destination],
            "with address Proxy: ",
            address(airdropfuji) //
        );

        destinationAirdrop destinationMinterAirdrop = new destinationAirdrop{salt: salt}(
            router, //pass 2
            address(airdropfuji)
        ); //esse vai ser o endereco que iremmos interagir para

        console.log(
            "destinationairdrop deployed on ",
            networks[destination],
            "with address Proxy: ",
            address(destinationMinterAirdrop)
        );

        airdropfuji.transferOwnership(address(destinationMinterAirdrop));
        address minterAirdrop = airdropfuji.owner();

        console.log("Minter role airdropfuji granted to: ", minterAirdrop);
       console.log("Hypnos:", address(hypnospoint));

        vm.stopBroadcast();
        

        /*

  == Logs ==
  airdropFujiProxy deployed on  Avalanche Fuji with address Proxy:  0x331C21d2B2A3Cf551fc73f6592874178De9dDb61
  destinationairdrop deployed on  Avalanche Fuji with address Proxy:  0x4afa88E1DC522F190d2E33C4d4DD347E993C5Db8
  Minter role airdropfuji granted to:  0x4afa88E1DC522F190d2E33C4d4DD347E993C5Db8
  Hypnos: 0xA64a2044D3d1247a90439A458cD0e37a359dA6d2
        */
    }
 
}