// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCIPReceiver} from "@ccip/ccip/applications/CCIPReceiver.sol";
import {Client} from "@ccip/ccip/libraries/Client.sol";
import {hypnosPoint} from "../hypnosPoint.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
///Deploy this contract in Amoy -- 
contract destinationHypnosPoint is CCIPReceiver {
    hypnosPoint hypnospoint;

    event MintCallSuccessfull();

    constructor(address router, address farmAddress) CCIPReceiver(router) {
        hypnospoint = hypnosPoint(farmAddress);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        (bool success, ) = address(hypnospoint).call(message.data);
        require(success);
        emit MintCallSuccessfull();
    }
}