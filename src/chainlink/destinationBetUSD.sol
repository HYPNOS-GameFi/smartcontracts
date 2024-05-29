// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCIPReceiver} from "@ccip/ccip/applications/CCIPReceiver.sol";
import {Client} from "@ccip/ccip/libraries/Client.sol";
import {betUSD} from "../betUSD.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
///Deploy this contract in Amoy --
contract destinationBetUSD is CCIPReceiver {
    betUSD betusd;

    event MintCallSuccessfull();

    constructor(address router, address farmAddress) CCIPReceiver(router) {
        betusd = betUSD(farmAddress);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        (bool success,) = address(betusd).call(message.data);
        require(success);
        emit MintCallSuccessfull();
    }
}
