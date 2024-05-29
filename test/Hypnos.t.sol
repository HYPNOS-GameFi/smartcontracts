// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {HYPNOS_gameFi} from "../src/mainGame.sol";
import {Mock} from "./utils/mockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC721AUpgradeable} from "lib/ERC721A-Upgradeable/contracts/IERC721AUpgradeable.sol";
import {SubscriptionAPI} from "@chainlink/contracts/src/v0.8/vrf/dev/SubscriptionAPI.sol";
import {Helper} from "../script/Helpers.s.sol";

contract HypnosTest is Test {
    HYPNOS_gameFi public game;
    Mock public payment;
    ERC1967Proxy public uups;
    Helper config;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public fullUser = makeAddr("fullUser");

    string baseURI_ = "hypnos game base uri";
    string name_ = "hypnos game name";
    string symbol_ = "HYPNOS";
    uint256 maxSupply_ = 1000000000;
    uint256 takerFee = 2000;
    uint256[4] priceClass = [1 ether, 2 ether, 3 ether, 4 ether];
    string[4] types = ["type1", "type2", "type3", "type4"];

    bytes32 public keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    address public vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    uint256 public subscriptionId = 86066367899265651094365220000614482092166546892613257493279963569089616398365;

    function setUp() public {
        config = new Helper();
        (, uint256 key) = config.activeNetworkConfig();

        payment = new Mock("betpayment", "PIX");

        vm.startBroadcast(key);

        game = new HYPNOS_gameFi(vrfCoordinator, keyHash, subscriptionId);
        bytes memory init = abi.encodeWithSelector(
            HYPNOS_gameFi.initialize.selector,
            owner,
            baseURI_,
            name_,
            symbol_,
            maxSupply_,
            address(payment),
            takerFee,
            priceClass,
            types
        );

        game = HYPNOS_gameFi(address(new ERC1967Proxy(address(game), init)));

        SubscriptionAPI(vrfCoordinator).addConsumer(subscriptionId, address(game));

        vm.stopBroadcast();

        vm.prank(owner, owner);
        game.allowAddress(owner);
        deal(owner, 100 ether);
        deal(user, 100 ether);
        deal(fullUser, 100 ether);
    }

    function test_mints() public {
        vm.startPrank(owner, owner);
        game.mintClass{value: 1 ether}(HYPNOS_gameFi.shipClass._level1);
        assertEq(game.balanceOf(owner), 1);
        game.mintClass{value: 1 ether}(HYPNOS_gameFi.shipClass._level1);
        assertEq(game.balanceOf(owner), 2);

        game.randomizeClass(0);
        assertEq(game.balanceOf(owner), 2);

        vm.expectRevert(IERC721AUpgradeable.OwnerQueryForNonexistentToken.selector);
        assertEq(game.ownerOf(0), address(0));

        vm.roll(block.number + 2);
        string memory tokenUri = game.tokenURI(1);
        console.log("tokenURI:", tokenUri);

        vm.stopPrank();
    }

    function test_openChallenge() public returns (bytes32 _id) {
        test_mints();
        vm.startPrank(owner, owner);
        _id = game.openChallenge(1, HYPNOS_gameFi.challengeType._pointsCash, HYPNOS_gameFi.challengeChoice._12Hours);
        assertEq(keccak256(abi.encode(owner, 1)), _id);
        vm.stopPrank();
    }

    function test_enterChallenge() public returns (bytes32 _id) {
        _id = test_openChallenge();
        vm.startPrank(user, user);
        game.mintClass{value: 1 ether}(HYPNOS_gameFi.shipClass._level1);
        game.pickChallenge(_id, 3);
        (bool _onChallenge,,,) = game.shipInfo(user, 3);
        assertEq(_onChallenge, true);
        vm.stopPrank();
    }

    function test_playPoints() public {
        test_mints();
        vm.startPrank(owner, owner);
        assertEq(game.points(owner), 0);
        game.playPoints(2, 100);
        assertEq(game.points(owner), 100);
        vm.stopPrank();
    }

    function test_playChallenge() public returns (bytes32 _id) {
        _id = test_enterChallenge();
        vm.startPrank(owner, owner);
        assertEq(game.points(user), 0);
        game.playChallenge(3, _id, 100);
        assertEq(game.points(user), 0);
        (,,, uint256 _points1,,, uint256 _points2,,,,,) = game.challenges(_id);
        assertEq(_points1, 0);
        assertEq(_points2, 100);
        vm.stopPrank();
    }

    function test_bet() public returns (bytes32 _id) {
        _id = test_playChallenge();
        vm.startPrank(fullUser, fullUser);
        payment.mint(fullUser, 10 ether);
        payment.approve(address(game), 10 ether);
        game.betOnChallenge(_id, 1 ether, 3);
        (uint256 _amount1, uint256 _amount2) = game.getUserDeposits(fullUser, _id);
        assertEq(_amount2, 1 ether);
        // console.log(_amount1,_amount2);
        vm.stopPrank();

        vm.startPrank(owner, owner);
        payment.mint(owner, 10 ether);
        payment.approve(address(game), 10 ether);
        game.betOnChallenge(_id, 1 ether, 1);
        (_amount1, _amount2) = game.getUserDeposits(owner, _id);
        assertEq(_amount1, 1 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 days);

        vm.startPrank(owner, owner);
        assertEq(game.points(user), 0);
        game.playChallenge(3, _id, 100);
        vm.stopPrank();

        (bool _finalized,,,,,,,,,,,) = game.challenges(_id);
        // assertEq(game.points(user),200);

        assertEq(_finalized, true);
    }

    function test_claimBet() public {
        bytes32 _id = test_bet();
        vm.startPrank(fullUser, fullUser);
        assertEq(payment.balanceOf(fullUser), 9 ether);
        game.claimBet(_id);
        assertEq(payment.balanceOf(fullUser), 10.6 ether);
        vm.stopPrank();
    }
}
