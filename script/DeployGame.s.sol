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

import {HelperFunction} from "./HelperFunction.sol";
import {dIBTAETF} from "../src/chainlink/dIBTAETF.sol";
import {IGetTslaReturnTypes} from "../src/interfaces/IGetTslaReturnTypes.sol";

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

    function run(SupportedNetworks destination) external {
        //destination 4 deve ser na polygon amoy
        config = new Helper();

        (, uint256 key) = config.activeNetworkConfig();
        owner = vm.addr(key);

        vm.startBroadcast(key);

        (address router,,,) = getConfigFromNetwork(destination);

        //HypnosPoint in AMOY for CCIP

        hypnosPoint hypnospointlementation = new hypnosPoint{salt: salt}();
        bytes memory init = abi.encodeWithSelector(hypnosPoint.initialize.selector, owner, 100e18);
        hypnospointProxy = new ERC1967Proxy{salt: salt}(address(hypnospointlementation), init);
        hypnospoint = hypnosPoint(payable(hypnospointProxy));

        console.log(
            "hypnosPoint deployed on ",
            networks[destination],
            "with address Proxy: ",
            address(hypnospoint) //
        );

        destinationHypnosPoint destinationMinter = new destinationHypnosPoint{salt: salt}(
            router, //pass 4
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
        bytes memory initBUSD = abi.encodeWithSelector(betUSD.initialize.selector, owner);
        betUSDProxy = new ERC1967Proxy{salt: salt}(address(betUSDintlementation), initBUSD);
        betusd = betUSD(payable(betUSDProxy));

        console.log(
            "betUSDProxy deployed on ",
            networks[destination],
            "with address Proxy: ",
            address(betusd) //
        );

        destinationBetUSD destinationMinterUSD = new destinationBetUSD{salt: salt}(
            router, //pass 4
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

contract DeployIBTAETF is Script {
    dIBTAETF public ibtaetf;
    string constant alpacaMintSource = "./functions/sources/alpacaBalance.js";
    string constant alpacaRedeemSource = "./functions/sources/alpacaBalance.js";

    function run() external {
        // Get params
        IGetTslaReturnTypes.GetTslaReturnType memory tslaReturnType = getdTslaRequirements();

        // Actually deploy
        vm.startBroadcast();
        deploydIBTAETF(
            tslaReturnType.subId,
            tslaReturnType.mintSource,
            tslaReturnType.redeemSource,
            tslaReturnType.functionsRouter,
            tslaReturnType.donId,
            tslaReturnType.ibtaFeed,
            tslaReturnType.usdcFeed,
            tslaReturnType.redemptionCoin,
            tslaReturnType.secretVersion,
            tslaReturnType.secretSlot
        );

        console.log("dIBTAETF", address(ibtaetf));
        vm.stopBroadcast();
    }

    function getdTslaRequirements() public returns (IGetTslaReturnTypes.GetTslaReturnType memory) {
        HelperFunction helperFunction = new HelperFunction();
        (
            address ibtaFeed,
            address usdcFeed, /*address ethFeed*/
            ,
            address functionsRouter,
            bytes32 donId,
            uint64 subId,
            address redemptionCoin,
            ,
            ,
            ,
            uint64 secretVersion,
            uint8 secretSlot
        ) = helperFunction.activeNetworkConfig();

        if (
            ibtaFeed == address(0) || usdcFeed == address(0) || functionsRouter == address(0) || donId == bytes32(0)
                || subId == 0
        ) {
            revert("something is wrong");
        }
        string memory mintSource = vm.readFile(alpacaMintSource);
        string memory redeemSource = vm.readFile(alpacaRedeemSource);
        return IGetTslaReturnTypes.GetTslaReturnType(
            subId,
            mintSource,
            redeemSource,
            functionsRouter,
            donId,
            ibtaFeed,
            usdcFeed,
            redemptionCoin,
            secretVersion,
            secretSlot
        );
    }

    function deploydIBTAETF(
        uint64 subId,
        string memory mintSource,
        string memory redeemSource,
        address functionsRouter,
        bytes32 donId,
        address ibtaFeed,
        address usdcFeed,
        address redemptionCoin,
        uint64 secretVersion,
        uint8 secretSlot
    ) public returns (dIBTAETF) {
        dIBTAETF dIbtaETF = new dIBTAETF(
            subId,
            mintSource,
            redeemSource,
            functionsRouter,
            donId,
            ibtaFeed,
            usdcFeed,
            redemptionCoin,
            secretVersion,
            secretSlot
        );
        return dIbtaETF;
    }
}

contract DeployGame is Script {
    Helper public config;
    ERC1967Proxy public poolProxy;
    HYPNOS_gameFi public game;

    pool public poolContract;
    ERC20Mock public mock;
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

    bytes32 public keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    address public vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    uint256 public subscriptionId = 86066367899265651094365220000614482092166546892613257493279963569089616398365;

    address _priceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306; //--ETH/US sepolia;
    uint256 updateInterval = 15; //15 seconds

    bytes32 public salt = bytes32("PoolGame10");

    function run() public {
        config = new Helper();

        (, uint256 key) = config.activeNetworkConfig();
        owner = vm.addr(key);

        vm.startBroadcast(key);
        pool poolContractImplementation = new pool{salt: salt}();
        bytes memory initPool = abi.encodeWithSelector(
            pool.initialize.selector,
            owner,
            updateInterval,
            address(0x6b022ACfAA62c3660B1eB163f557E93D8b246041), // BetUSD
            address(0xF90d22a0a22E85a349cbab43325267F360FE210E), // HypnosPoint
            owner, //address buyer ETHER
            owner //address buyer ETF Gov
        );
        poolProxy = new ERC1967Proxy{salt: salt}(address(poolContractImplementation), initPool);
        poolContract = pool(payable(poolProxy));

        // game = new HYPNOS_gameFi(vrfCoordinator, keyHash, subscriptionId);

        // bytes memory init = abi.encodeWithSelector(
        //     HYPNOS_gameFi.initialize.selector,
        //     owner,
        //     baseURI_,
        //     name_,
        //     symbol_,
        //     maxSupply_,
        //     address(0x6b022ACfAA62c3660B1eB163f557E93D8b246041), // BetUSD
        //     address(0xF90d22a0a22E85a349cbab43325267F360FE210E), // HypnosPoint
        //     updateInterval,
        //     address(poolContract),
        //     takerFee,
        //     priceClass,
        //     types
        // );

        //game = HYPNOS_gameFi(address(new ERC1967Proxy(address(game), init)));

        // if (addComsumer) {
        //     SubscriptionAPI(vrfCoordinator).addConsumer(
        //         subscriptionId,
        //         address(game)
        //     );
        // }

       // console.log("address:", address(game));
       console.log("PoolContract-Implemantation:", address(poolContract));
        console.log("PoolContract-Proxy:", address(poolContract));
        vm.stopBroadcast();
    }

    /*== Logs ==
        address: 0xFeB9A82dC19c4e7B025ea2d5A8eBA691E955B85f
        PoolContract-Proxy: 0xEA330f4C1FcDE1BbC4Cc13c18573307C4dCA3476*/
}
