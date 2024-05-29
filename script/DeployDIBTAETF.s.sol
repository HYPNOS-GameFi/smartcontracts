// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelperFunction} from "./HelperFunction.sol";
import {dIBTAETF} from "../src/chainlink/dIBTAETF.sol";
import {IGetTslaReturnTypes} from "../src/interfaces/IGetTslaReturnTypes.sol";

contract DeployDIBTAETF is Script {
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
