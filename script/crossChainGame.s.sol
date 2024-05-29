// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import "./Helpers.s.sol";
import {hypnosPoint} from "../src/hypnosPoint.sol";
import {destinationHypnosPoint} from "../src/chainlink/destinationHypnosPoint.sol";
import {SourceMinter} from "../src/chainlink/SourceMinter.sol";

//tba import
import {ReferenceERC6551Registry} from "../src/ERC6551/ReferenceERC6551Registry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDestination is Script, Helper {
    //forge script ./script/crossAirdrop.s.sol:DeployDestination -vvv --broadcast --rpc-url amoy --sig "run(uint8)" -- 4 --verify -vvvv
    function run(SupportedNetworks destination) external {
        //destination 4 deve ser na polygon amoy
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (address router,,,) = getConfigFromNetwork(destination);

        hypnosPoint HypnosPointContract = new hypnosPoint();

        console2.log(
            "hypnosPoint deployed on ",
            networks[destination],
            "with address: ",
            address(HypnosPointContract) //
        );

        destinationHypnosPoint destinationMinter = new destinationHypnosPoint(
            router, //pass 4
            address(HypnosPointContract)
        ); //esse vai ser o endereco que iremmos interagir para

        console2.log(
            "destinationHypnosPoint deployed on ", networks[destination], "with address: ", address(destinationMinter)
        );

        HypnosPointContract.transferOwnership(address(destinationMinter));
        address minter = HypnosPointContract.owner();

        console2.log("Minter role granted to: ", minter);

        vm.stopBroadcast();
    }
}

contract DeploySource is Script, Helper {
    ///forge script ./script/crossAirdrop.s.sol:DeploySource -vvv --broadcast --rpc-url sepolia --sig "run(uint8)" -- 0

    /* solhint-disable var-name-mixedcase, private-vars-leading-underscore */

    ///financiar o contrato de SourceMinter na Sepolia com LINK para ele conseguir mintar na AMOY
    function run(SupportedNetworks source) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (address router, address link,,) = getConfigFromNetwork(source);

        SourceMinter sourceMinter = new SourceMinter(router, link);

        console2.log("SourceMinter deployed on ", networks[source], "with address: ", address(sourceMinter));

        vm.stopBroadcast();
    }
}

contract Mint is Script, Helper {
    ///forge script ./script/crossAirdrop.s.sol:Mint -vvv --broadcast --rpc-url sepolia --sig "run(address,uint8,address,uint8)" -- <SourceMinter na sepolia> 4 <Destinator in Amoy> 1 <endereco para onde vai> 10
    function run(
        address payable sourceMinterAddress,
        SupportedNetworks destination, //4 Amoy
        address destinationMinterAddress,
        SourceMinter.PayFeesIn payFeesIn, // 1 LINK
        address to,
        uint256 amount
    ) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (,,, uint64 destinationChainId) = getConfigFromNetwork(destination);

        SourceMinter(sourceMinterAddress).mint(destinationChainId, destinationMinterAddress, payFeesIn, to, amount);

        vm.stopBroadcast();
    }
}
