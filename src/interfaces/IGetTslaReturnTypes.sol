// SPDX-License-Identifier: MIt
pragma solidity 0.8.23;

interface IGetTslaReturnTypes {
    struct GetTslaReturnType {
        uint64 subId;
        string mintSource;
        string redeemSource;
        address functionsRouter;
        bytes32 donId;
        address ibtaFeed;
        address usdcFeed;
        address redemptionCoin;
        uint64 secretVersion;
        uint8 secretSlot;
    }
}
