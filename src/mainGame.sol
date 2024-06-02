// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// -----------------------------------------------------------------------
///                                 Imports
/// -----------------------------------------------------------------------

import {ERC721AUpgradeable} from "lib/ERC721A-Upgradeable/contracts/ERC721AUpgradeable.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20Upgradeable, IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {SecurityUpgradeable} from "./security/SecurityUpgradeable.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {LinkTokenInterface} from "./interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@ccip/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/ccip/libraries/Client.sol";

contract HYPNOS_gameFi is
    ERC721AUpgradeable,
    UUPSUpgradeable,
    SecurityUpgradeable,
    VRFConsumerBaseV2
{
    /// -----------------------------------------------------------------------
    ///                                 Events
    /// -----------------------------------------------------------------------

    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    event challengeOpen(
        address indexed _user,
        uint256 indexed _tokenId,
        challengeType _type,
        challengeChoice _choice,
        uint256 indexed gameid

    );
    event challengeAccepted(
        address indexed _user,
        uint256 indexed _tokenId,
        uint256 indexed gameid
    );
    event challengeFinalized(uint256 indexed gameid, address _winner);
    event updatedPoints(address indexed _address, uint256 indexed _points);
    event updatedChallengePoints(
        uint256 indexed gameid,
        uint256 _points1,
        address _address1,
        uint256 _points2,
        address _address2
    );
    event betedOnChallenge(
        address _address,
        uint256 indexed _totalAmount1,
        uint256 indexed _totalAmount2,
        uint256 _tokenId,
        uint256 indexed gameid
    );
    event MessageSent(bytes32 messageId);

    event ShipsNewStats(uint256[4] lifePoints, uint256[4] attackPoints);

    event shipMinted(uint256 indexed _tokenId, shipClass indexed _shipClass, string _metadata);

    /// -----------------------------------------------------------------------
    ///                                 Error
    /// -----------------------------------------------------------------------

    error NotEnoughForShipPurchase(address _buyer, uint256 _value);
    error PointsNotApproved(address _buyer, uint256 _tokenIds);
    error AlreadyChallenged(address _user, uint256 _token);
    error NotOwner(address _user, uint256 _token);
    error NonExistingChallenge(uint256 id);
    error ChallengeIsNotActive(uint256 id);
    error ChallengeIsActive(uint256 id);
    error NotInChallenge(uint256 id, uint256 _tokenId);
    error NotAllowed(address _address);
    error CannotBetOnThisType();
    error FailedToWithdrawEth(address owner, address target, uint256 value);

    /// -----------------------------------------------------------------------
    ///                                 Struct
    /// -----------------------------------------------------------------------

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256 tokenId;
    }

    struct basicPower {
        uint256 _life;
        uint256 _strenght;
    }

    struct ShipInfo {
        bool _onChallenge;
        uint256 _challengeID;
        uint256 _extraLife;
        uint256 _extraStrength;
    }

    struct challenge {
        bool _finalized;
        address _firstChallenger;
        uint256 _tokenIdC1;
        uint256 _firstChallengerPoints;
        address _secondChallenger;
        uint256 _tokenIdC2;
        uint256 _secondChallengerPoints;
        uint256 _challengeTimestamp;
        challengeChoice _duration;
        challengeType _type;
        mapping(address => bool) userClaimed; //math to do is total pooled on (pooledAmount/winner)*totalprizepool = (pooledAmount*totalprizepool/winner)
        mapping(address => deposit) userDeposits;
        uint256 _totalAmount1;
        uint256 _totalAmount2;
    }

    struct deposit {
        uint256 _amount1;
        uint256 _amount2;
    }

    enum challengeChoice {
        _12Hours,
        _24Hours,
        _48Hours
    }

    enum shipClass {
        _level1,
        _level2,
        _level3,
        _level4
    }

    enum challengeType {
        _points,
        _pointsCash
    }

    /// -----------------------------------------------------------------------
    ///                                 Storage
    /// -----------------------------------------------------------------------

    uint256[3] public DURATIONS = [12 minutes, 24 minutes, 48 minutes];
    string[4] public TYPES;
    string public s_baseUri;
    uint256 public s_maxSupply;
    uint256[4] public s_classPrice;
    uint256 public s_takerFee;

    //assets in Amoy
    address public betPayment;

    ///cross chain CCIP in Sepolia
    address public betUSDSepolia;
    address public hypnosPointSepolia;
    address public airdropFuji;

    address public pool;
    uint256 public s_mintRandomPrice;

    mapping(shipClass => basicPower) public powerClass;
    mapping(address user => mapping(uint256 tokenId => ShipInfo info))
        public shipInfo;
    mapping(uint256 tokenId => string metadata) public _tokenUri;
    mapping(uint256 challengeID => challenge challengeInfo) public challenges;
    mapping(address user => uint256 points) public points;
    mapping(address addressCaller => bool allowed) public allowed;

    // VRF
    IVRFCoordinatorV2Plus immutable COORDINATOR;
    bytes32 public immutable i_keyHash;
    uint256 public immutable i_subscriptionId;
    uint32 public immutable i_callbackGasLimit = 100000;
    uint16 public immutable i_requestConfirmations = 3;
    uint32 public immutable i_numWords = 1;
    uint32 public immutable i_statsNumWords = 8;
    mapping(uint256 requestId => RequestStatus request) public s_requests;
    uint256 public s_lastRequestId;
    uint256 public s_updatePeriod = 5 minutes;
    uint256 public s_lastUpdate;

    uint public s_sumChallengers;

    // CCIP Sepolia
    // address constant routerEthereumSepolia =
    //     0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    // uint64 constant chainIdAmoy = 16281711391670634445;
    // address constant linkEthereumSepolia =
    //     0x779877A7B0D9E8603169DdbD7836e478b4624789;

    // CCIP Amoy
    address constant routerPolygonAmoy =
        0x9C32fCB86BF0f4a1A8921a9Fe46de3198bb884B2;
    uint64 constant chainIdSepolia = 16015286601757825753;
    address constant linkPolygonAmoy =
        0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904;

    uint64 constant chainIdFuji = 14767482510784806043;
    

    /// -----------------------------------------------------------------------
    ///                                 Constructor
    /// -----------------------------------------------------------------------

    constructor(
        address _vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        COORDINATOR = IVRFCoordinatorV2Plus(_vrfCoordinator);
        _disableInitializers();
    }

    /// -----------------------------------------------------------------------
    ///                                 Initialize
    /// -----------------------------------------------------------------------

    function initialize(
        address owner_,
        string memory baseURI_,
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        address betUSDSepolia_,
        address hypnosPointSepolia_,
        address airdropFuji_,
        address pool_,
        uint256 takerFee,
        uint256[4] memory priceClass,
        string[4] memory typesUri,
        address betPaymentAmoy_
    ) external initializerERC721A initializer {
        __ERC721A_init(name_, symbol_);
        __Security_init(owner_);

        s_baseUri = baseURI_;
        s_maxSupply = maxSupply_;
        s_takerFee = takerFee;

        betUSDSepolia = betUSDSepolia_;
        hypnosPointSepolia = hypnosPointSepolia_;
        airdropFuji = airdropFuji_;

        betPayment = betPaymentAmoy_;

        pool = pool_;

        s_classPrice = priceClass;
        TYPES = typesUri;
    }

    /// -----------------------------------------------------------------------
    ///                                 Public
    /// -----------------------------------------------------------------------

    function mintClass(shipClass _class) public payable {
        if (msg.value != s_classPrice[uint8(_class)]) {
            revert NotEnoughForShipPurchase(msg.sender, msg.value);
        }

        ERC721AUpgradeable._mint(msg.sender, 1);
        _tokenUri[_nextTokenId() - 1] = TYPES[uint8(_class)];
        emit shipMinted(_nextTokenId() - 1, _class, _tokenUri[_nextTokenId() - 1]);
    }

    function mintRandomize() public payable {
        if (msg.value != s_mintRandomPrice) {
            revert NotEnoughForShipPurchase(msg.sender, msg.value);
        }

        ERC721AUpgradeable._mint(msg.sender, 1);
        _vrfRandomizeClass(_nextTokenId() - 1);
    }

    function randomizeClass(uint256 _tokenId) public {
        _burn(_tokenId);
        points[msg.sender] = 0;

        ERC721AUpgradeable._mint(msg.sender, 1 /*VRF VALUE*/);

        _vrfRandomizeClass(_nextTokenId() - 1);
    }

    function openChallenge(
        uint256 _tokenId,
        challengeType _type,
        challengeChoice _duration
    ) public returns (uint256 Gameid) {
        if (ownerOf(_tokenId) != msg.sender)
            revert NotOwner(msg.sender, _tokenId);

        s_sumChallengers++;
        //id = keccak256(abi.encode(msg.sender, _tokenId));
        uint256 id = s_sumChallengers + _tokenId;
       
        if (
            shipInfo[msg.sender][_tokenId]._onChallenge ||
            challenges[id]._firstChallenger != address(0)
        ) revert AlreadyChallenged(msg.sender, _tokenId);

        shipInfo[msg.sender][_tokenId]._onChallenge = true;
        shipInfo[msg.sender][_tokenId]._challengeID = id;
        challenges[id]._firstChallenger = msg.sender;
        challenges[id]._tokenIdC1 = _tokenId;
        challenges[id]._duration = _duration;
        challenges[id]._type = _type;

        emit challengeOpen(msg.sender, _tokenId, _type, _duration, id);

        return(id);

        // the graph => challengeOpened (_user, _tokenId, _type, _choice, id) => list -
        // pickChallenge (_user, _tokenId, _type, _choice, id)
    }

    function pickChallenge(uint256 _id, uint256 _tokenId) public {
        if (ownerOf(_tokenId) != msg.sender)
            revert NotOwner(msg.sender, _tokenId);

        if (
            shipInfo[msg.sender][_tokenId]._onChallenge ||
            challenges[_id]._firstChallenger == msg.sender ||
            challenges[_id]._secondChallenger == msg.sender
        ) revert AlreadyChallenged(msg.sender, _tokenId);

        if (challenges[_id]._firstChallenger == address(0))
            revert NonExistingChallenge(_id);

        if (challenges[_id]._secondChallenger != address(0))
            revert ChallengeIsActive(_id);

        shipInfo[msg.sender][_tokenId]._onChallenge = true;
        shipInfo[msg.sender][_tokenId]._challengeID = _id;
        challenges[_id]._secondChallenger = msg.sender;
        challenges[_id]._tokenIdC2 = _tokenId;
        challenges[_id]._challengeTimestamp =
            block.timestamp +
            DURATIONS[uint8(challenges[_id]._duration)];

        emit challengeAccepted(msg.sender, _tokenId, _id);
    }

    // ----------------------------------------------------------------

    // play challenge

    function playChallenge(
        uint256 _tokenId,
        uint256 _id,
        uint256 _points
    ) public returns (bool) {
        _checkAllowed(msg.sender);

        if (challenges[_id]._finalized) revert ChallengeIsNotActive(_id);

        if (challenges[_id]._firstChallenger == address(0))
            revert NonExistingChallenge(_id);

        if (challenges[_id]._challengeTimestamp < block.timestamp) {
            challenges[_id]._finalized = true;

            uint256 _aux = ((challenges[_id]._totalAmount1 +
                challenges[_id]._totalAmount2) * s_takerFee) / 10000;

            if (challenges[_id]._type == challengeType._pointsCash) {
                _distributeBet(_aux, pool);
                challenges[_id]._totalAmount1 =
                    (challenges[_id]._totalAmount1 * (10000 - s_takerFee)) /
                    10000;
                challenges[_id]._totalAmount2 =
                    (challenges[_id]._totalAmount2 * (10000 - s_takerFee)) /
                    10000;
            }

            if (
                challenges[_id]._firstChallengerPoints >
                challenges[_id]._secondChallengerPoints
            ) {
                points[challenges[_id]._firstChallenger] +=
                    challenges[_id]._firstChallengerPoints +
                    challenges[_id]._secondChallengerPoints;
                    emit challengeFinalized(_id,challenges[_id]._firstChallenger);
                emit updatedPoints(
                    challenges[_id]._firstChallenger,
                    points[challenges[_id]._firstChallenger]
                );
            } else {
                points[challenges[_id]._secondChallenger] +=
                    challenges[_id]._firstChallengerPoints +
                    challenges[_id]._secondChallengerPoints;
                    emit challengeFinalized(_id,challenges[_id]._secondChallenger);
                emit updatedPoints(
                    challenges[_id]._secondChallenger,
                    points[challenges[_id]._secondChallenger]
                );
            }

            return false;
        }

        if (challenges[_id]._tokenIdC1 == _tokenId) {
            challenges[_id]._firstChallengerPoints += _points;
        } else if (challenges[_id]._tokenIdC2 == _tokenId) {
            challenges[_id]._secondChallengerPoints += _points;
        } else {
            revert NotInChallenge(_id, _tokenId);
        }

        emit updatedChallengePoints(
            _id,
            challenges[_id]._firstChallengerPoints,
            challenges[_id]._firstChallenger,
            challenges[_id]._secondChallengerPoints,
            challenges[_id]._secondChallenger
        );
        return true;
    }

    // record points
    function playPoints(uint256 _tokenId, uint256 _points) public {
        _checkAllowed(msg.sender);

        points[ownerOf(_tokenId)] += _points;
        emit updatedPoints(ownerOf(_tokenId), points[ownerOf(_tokenId)]);
    }

    //bet on challenge

    function betOnChallenge(
        uint256 _id,
        uint256 _amount,
        uint256 _tokenId
    ) public {
        if (challenges[_id]._type != challengeType._pointsCash)
            revert CannotBetOnThisType();

        if (challenges[_id]._finalized) revert ChallengeIsNotActive(_id);

        if (challenges[_id]._firstChallenger == address(0))
            revert NonExistingChallenge(_id);

        require(_amount > 100, "Hypnos: Amount has to be greater than 100");

        bool success = ERC20Upgradeable(betPayment).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        require(success, "Hypnos: betOnChallenge transfer failed");

        if (challenges[_id]._tokenIdC1 == _tokenId) {
            challenges[_id]._totalAmount1 += _amount;
            challenges[_id].userDeposits[msg.sender]._amount1 += _amount;
        } else if (challenges[_id]._tokenIdC2 == _tokenId) {
            challenges[_id]._totalAmount2 += _amount;
            challenges[_id].userDeposits[msg.sender]._amount2 += _amount;
        } else {
            revert NotInChallenge(_id, _tokenId);
        }

        emit betedOnChallenge(msg.sender, challenges[_id]._totalAmount1,challenges[_id]._totalAmount2, _tokenId, _id);
    }

    //claim bet
    function claimBet(uint256 _id) public {
        if (!challenges[_id]._finalized) revert ChallengeIsActive(_id);

        if (challenges[_id]._firstChallenger == address(0))
            revert NonExistingChallenge(_id);

        uint256 _aux;

        if (
            challenges[_id]._firstChallengerPoints >
            challenges[_id]._secondChallengerPoints
        ) {
            require(
                challenges[_id].userDeposits[msg.sender]._amount1 > 100,
                "Hypnos: not enough betted"
            );
            _aux = ((((challenges[_id].userDeposits[msg.sender]._amount1 *
                (10000 - s_takerFee)) / 10000) *
                (challenges[_id]._totalAmount1 +
                    challenges[_id]._totalAmount2)) /
                challenges[_id]._totalAmount1);
            // ( user bet side amount / side amount total ) * totalPooled(side 1 total + side 2 total)
        } else {
            require(
                challenges[_id].userDeposits[msg.sender]._amount2 > 100,
                "Hypnos: not enough betted"
            );
            _aux = ((((challenges[_id].userDeposits[msg.sender]._amount2 *
                (10000 - s_takerFee)) / 10000) *
                (challenges[_id]._totalAmount1 +
                    challenges[_id]._totalAmount2)) /
                challenges[_id]._totalAmount2);
        }

        challenges[_id].userClaimed[msg.sender] = true;
        require(
            ERC20Upgradeable(betPayment).transfer(msg.sender, _aux),
            "Hypnos: Claim Bet transfer failed"
        );
    }

    //check if tokenId in a challenge
    function _beforeTokenTransfers(
        address from,
        address /* to */,
        uint256 startTokenId,
        uint256 /* quantity */
    ) internal view override {
        require(
            !shipInfo[from][startTokenId]._onChallenge,
            "Hypnos: Transfer not possible, this token id is on a challenge"
        );
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(
            s_requests[_requestId].exists || s_lastRequestId == _requestId,
            "request not found"
        );
        if (s_lastRequestId == _requestId) {
            uint256[4] memory lifeStats;
            uint256[4] memory attackStats;
            for (uint256 i = 0; i < 4; i++) {
                lifeStats[i] = _randomWords[i] % 10;
                attackStats[i] = _randomWords[i + 4] % 10;
            }

            emit ShipsNewStats(lifeStats, attackStats);
        } else {
            s_requests[_requestId].fulfilled = true;

            uint8 randomType = uint8(_randomWords[0] % 4);
            _tokenUri[s_requests[_requestId].tokenId] = TYPES[randomType];
            emit shipMinted(s_requests[_requestId].tokenId, shipClass(uint8(_randomWords[0] % 4)), _tokenUri[s_requests[_requestId].tokenId]);
            emit RequestFulfilled(_requestId, _randomWords);
        }
    }

    function randomizeAircraftStats() public {
        require(
            block.timestamp >= s_lastUpdate + s_updatePeriod,
            "in lock period"
        );

        s_lastUpdate = block.timestamp;

        s_lastRequestId = COORDINATOR.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: i_requestConfirmations,
                callbackGasLimit: i_callbackGasLimit,
                numWords: i_statsNumWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function setUpdatePeriod(uint256 newPeriod) public onlyOwner {
        s_updatePeriod = newPeriod;
    }

    /// -----------------------------------------------------------------------
    ///                                 Getter
    /// -----------------------------------------------------------------------

    function getUserDeposits(
        address _address,
        uint256 _id
    ) public view returns (uint256, uint256) {
        return (
            challenges[_id].userDeposits[_address]._amount1,
            challenges[_id].userDeposits[_address]._amount2
        );
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) _revert(URIQueryForNonexistentToken.selector);

        return string(abi.encodePacked(s_baseUri, _tokenUri[tokenId]));
    }

    /// -----------------------------------------------------------------------
    ///                                 Internal
    /// -----------------------------------------------------------------------

    function _checkAllowed(address _address) internal view {
        if (!allowed[_address]) revert NotAllowed(_address);
    }

    function setAirdrop(address user, uint256 _amount)public{
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(airdropFuji),
            data: abi.encodeWithSignature(
                "setAirdrop(address,uint256)",
                user,
                _amount
            ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(linkPolygonAmoy)
        });

        uint256 fee = IRouterClient(routerPolygonAmoy).getFee(
            chainIdFuji,
            message
        );

        bytes32 messageId;
        LinkTokenInterface(linkPolygonAmoy).approve(
            routerPolygonAmoy,
            fee
        );
        messageId = IRouterClient(routerPolygonAmoy).ccipSend(
            chainIdFuji,
            message
        );
        emit MessageSent(messageId);

    }

    //distribute bet CCIP

    function _distributeBet(uint256 _tratedAmount, address to) public {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(hypnosPointSepolia),
            data: abi.encodeWithSignature(
                "mint(address,uint256)",
                to,
                _tratedAmount
            ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(linkPolygonAmoy)
        });

        uint256 fee = IRouterClient(routerPolygonAmoy).getFee(
            chainIdSepolia,
            message
        );

        bytes32 messageId;
        LinkTokenInterface(linkPolygonAmoy).approve(
            routerPolygonAmoy,
            fee
        );
        messageId = IRouterClient(routerPolygonAmoy).ccipSend(
            chainIdSepolia,
            message
        );

        Client.EVM2AnyMessage memory messageBet = Client.EVM2AnyMessage({
            receiver: abi.encode(betUSDSepolia),
            data: abi.encodeWithSignature(
                "mint(address,uint256)",
                to,
                _tratedAmount
            ),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(linkPolygonAmoy)
        });
        uint256 feeBet = IRouterClient(routerPolygonAmoy).getFee(
            chainIdSepolia,
            messageBet
        );

        bytes32 messageIdBet;
        LinkTokenInterface(linkPolygonAmoy).approve(
            routerPolygonAmoy,
            feeBet
        );
        messageIdBet = IRouterClient(routerPolygonAmoy).ccipSend(
            chainIdSepolia,
            messageBet
        );
        emit MessageSent(messageId);
        emit MessageSent(messageIdBet);
    }

    function withdraw(address beneficiary) public onlyOwner {
        uint256 amount = address(this).balance;
        (bool sent, ) = beneficiary.call{value: amount}("");
        if (!sent) revert FailedToWithdrawEth(msg.sender, beneficiary, amount);
    }

    function withdrawToken(
        address beneficiary,
        address token
    ) public onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(beneficiary, amount);
    }

    function setPriceRandomizeClass(uint256 _price)external{
        s_mintRandomPrice = _price;
    }

    function _vrfRandomizeClass(uint256 tokenId) internal {
        uint256 requestId = COORDINATOR.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: i_requestConfirmations,
                callbackGasLimit: i_callbackGasLimit,
                numWords: i_numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        s_requests[requestId] = RequestStatus({
            fulfilled: false,
            exists: true,
            tokenId: tokenId
        });
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    

    /// -----------------------------------------------------------------------
    ///                                 Controller
    /// -----------------------------------------------------------------------

    function allowAddress(address _address) public onlyOwner {
        allowed[_address] = true;
    }
}
