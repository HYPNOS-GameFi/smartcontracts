// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCIPReceiver} from "@ccip/ccip/applications/CCIPReceiver.sol";
import {Client} from "@ccip/ccip/libraries/Client.sol";
import {airdropFuji} from "../airdropFuji.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
///Deploy this contract in Amoy -- 
contract destinationAirdrop is CCIPReceiver {
    airdropFuji airdrop;

    event MintCallSuccessfull();

    constructor(address router, address farmAddress) CCIPReceiver(router) {
        airdrop = airdropFuji(farmAddress);
    }


    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        (bool success, ) = address(airdrop).call(message.data);
        require(success);
        emit MintCallSuccessfull();
    }
}