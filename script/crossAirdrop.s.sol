// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import "./Helpers.s.sol";
import {airdropFarm} from "../src/airdropFarm.sol";
import {DestinationMinter} from "../src/chainlink/DestinationMinter.sol";
import {SourceMinter} from "../src/chainlink/SourceMinter.sol";

//tba import
import {ReferenceERC6551Registry} from "../src/ERC6551/ReferenceERC6551Registry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


contract DeployDestination is Script, Helper {
    function run(SupportedNetworks destination) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (address router, , , ) = getConfigFromNetwork(destination);

        airdropFarm AidropContract = new airdropFarm();

        console2.log(
            "MyNFT deployed on ",
            networks[destination],
            "with address: ",
            address(AidropContract)
        );

        DestinationMinter destinationMinter = new DestinationMinter(
            router,
            address(AidropContract)
        );

        console2.log(
            "DestinationMinter deployed on ",
            networks[destination],
            "with address: ",
            address(destinationMinter)
        );

        AidropContract.transferOwnership(address(destinationMinter));
        address minter = AidropContract.owner();

        console2.log("Minter role granted to: ", minter);

        vm.stopBroadcast();
    }
}

contract DeploySource is Script, Helper {

    /* solhint-disable var-name-mixedcase, private-vars-leading-underscore */
    string[] public contractsToDeploy = [
        "Management",
        "RWACar",
        "RWARealstate",
        "BorrowAndStake",
        "ConnexusCard",
        "UtilityConnexus",
        "CardTBA",
        "ERC6551Registry"
    ];

    function run(SupportedNetworks source) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (address router, address link, , ) = getConfigFromNetwork(source);

        SourceMinter sourceMinter = new SourceMinter(router, link);

        console2.log(
            "SourceMinter deployed on ",
            networks[source],
            "with address: ",
            address(sourceMinter)
        );

        vm.stopBroadcast();
    }
}

contract Mint is Script, Helper {
    function run(
        address payable sourceMinterAddress,
        SupportedNetworks destination,
        address destinationMinterAddress,
        SourceMinter.PayFeesIn payFeesIn
    ) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (, , , uint64 destinationChainId) = getConfigFromNetwork(destination);

        SourceMinter(sourceMinterAddress).mint(
            destinationChainId,
            destinationMinterAddress,
            payFeesIn
        );

        vm.stopBroadcast();
    }
}