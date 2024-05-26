// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Helper} from "./Helpers.s.sol";
import {HYPNOS_gameFi} from "../src/mainGame.sol";
import {pool} from "../src/pool.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SubscriptionAPI} from "@chainlink/contracts/src/v0.8/vrf/dev/SubscriptionAPI.sol";

import {hypnosPoint} from "../src/hypnosPoint.sol";
import {destinationHypnosPoint} from "../src/chainlink/destinationHypnosPoint.sol";

//tba import
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


contract DeployDestination is Script, Helper {

    hypnosPoint public hypnospoint;
    ERC1967Proxy public hypnospointProxy;
    address public owner;

     bytes32 public salt = bytes32("Hypnos");
    //forge script ./script/DeployGame.s.sol:DeployDestination -vvv --broadcast --rpc-url amoy --sig "run(uint8)" -- 4 --verify -vvvv
    function run(SupportedNetworks destination) external { //destination 4 deve ser na polygon amoy
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (address router, , , ) = getConfigFromNetwork(destination);

        //hypnosPoint HypnosPointContract = new hypnosPoint();

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

        destinationHypnosPoint destinationMinter = new destinationHypnosPoint(
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

        console.log("Minter role granted to: ", minter);

        vm.stopBroadcast();
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

    bytes32 public keyHash =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    address public vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    uint256 public subscriptionId =
        86066367899265651094365220000614482092166546892613257493279963569089616398365;

    
    address _priceFeed = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;//change address
    uint256 updateInterval = 15; //change value

    bytes32 public salt = bytes32("PoolGame");
    function run() public {
        config = new Helper();

        (, uint256 key) = config.activeNetworkConfig();
        owner = vm.addr(key);

        vm.startBroadcast(key);

        if (deployMock) {
            mock = new ERC20Mock();
        }

        pool poolContractImplementation = new pool{salt: salt}();
        bytes memory initPool = abi.encodeWithSelector(
            pool.initialize.selector,
            owner,
            address(_priceFeed),
            updateInterval
        );
        poolProxy = new ERC1967Proxy{salt: salt}(
            address(poolContractImplementation),
            initPool
        );
        poolContract = pool(payable(poolProxy));


        game = new HYPNOS_gameFi(vrfCoordinator, keyHash, subscriptionId);

        bytes memory init = abi.encodeWithSelector(
            HYPNOS_gameFi.initialize.selector,
            owner,
            baseURI_,
            name_,
            symbol_,
            maxSupply_,
            address(mock),
            address(mock), //change HypnosPoint
            address(poolContract),
            takerFee,
            priceClass,
            types
        );

        game = HYPNOS_gameFi(address(new ERC1967Proxy(address(game), init)));

        if (addComsumer) {
            SubscriptionAPI(vrfCoordinator).addConsumer(
                subscriptionId,
                address(game)
            );
        }

        vm.stopBroadcast();

        console.log("address:", address(game));
        console.log("PoolContract-Proxy:", address(poolContract));
    }
}
