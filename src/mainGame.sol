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
import "@chainlink/contracts/src/v0.8/automation/KeeperCompatible.sol";

contract HYPNOS_gameFi is
    ERC721AUpgradeable,
    UUPSUpgradeable,
    SecurityUpgradeable,
    VRFConsumerBaseV2,
    KeeperCompatibleInterface
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
        bytes32 indexed _id
    );
    event challengeAccepted(address indexed _user, uint256 indexed _tokenId, bytes32 indexed _id);
    event challengeFinalized(bytes32 indexed _id);
    event updatedPoints(address indexed _address, uint256 indexed _points);
    event updatedChallengePoints(
        bytes32 indexed _id, uint256 _points1, address _address1, uint256 _points2, address _address2
    );
    event betedOnChallenge(address indexed _address, uint256 indexed _amount, uint256 _tokenId, bytes32 indexed _id);
    event MessageSent(bytes32 messageId);

    /// -----------------------------------------------------------------------
    ///                                 Error
    /// -----------------------------------------------------------------------

    error NotEnoughForShipPurchase(address _buyer, uint256 _value);
    error PointsNotApproved(address _buyer, uint256 _tokenIds);
    error AlreadyChallenged(address _user, uint256 _token);
    error NotOwner(address _user, uint256 _token);
    error NonExistingChallenge(bytes32 id);
    error ChallengeIsNotActive(bytes32 id);
    error ChallengeIsActive(bytes32 id);
    error NotInChallenge(bytes32 id, uint256 _tokenId);
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
        bytes32 _challengeID;
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

    uint256[3] public DURATIONS = [12 hours, 24 hours, 48 hours];
    string[4] public TYPES;
    string public s_baseUri;
    uint256 public s_maxSupply;
    uint256[4] public s_classPrice;
    uint256 public s_takerFee;

    address public betPayment;
    address public hypnosPoint;
    address public pool;

    mapping(shipClass => basicPower) public powerClass;
    mapping(address user => mapping(uint256 tokenId => ShipInfo info)) public shipInfo;
    mapping(uint256 tokenId => string metadata) public _tokenUri;
    mapping(bytes32 challengeID => challenge challengeInfo) public challenges;
    mapping(address user => uint256 points) public points;
    mapping(address addressCaller => bool allowed) public allowed;

    IVRFCoordinatorV2Plus immutable COORDINATOR;
    bytes32 public immutable i_keyHash;
    uint256 public immutable i_subscriptionId;
    uint32 public immutable i_callbackGasLimit = 100000;
    uint16 public immutable i_requestConfirmations = 3;
    uint32 public immutable i_numWords = 1;
    mapping(uint256 requestId => RequestStatus request) public s_requests;

    address constant routerEthereumSepolia = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    uint64 constant chainIdAmoy = 16281711391670634445;
    address constant linkEthereumSepolia = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    uint256 public /*immutable*/ interval;
    uint256 public lastTimeStamp;

    /// -----------------------------------------------------------------------
    ///                                 Constructor
    /// -----------------------------------------------------------------------

    constructor(address _vrfCoordinator, bytes32 keyHash, uint256 subscriptionId) VRFConsumerBaseV2(_vrfCoordinator) {
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
        address paymentToken,
        address hypnosPoint_,
        uint256 updateInterval,
        address pool_,
        uint256 takerFee,
        uint256[4] memory priceClass,
        string[4] memory typesUri
    ) external initializerERC721A initializer {
        __ERC721A_init(name_, symbol_);
        __Security_init(owner_);

        s_baseUri = baseURI_;
        s_maxSupply = maxSupply_;
        s_takerFee = takerFee;

        betPayment = paymentToken;
        hypnosPoint = hypnosPoint_;
        pool = pool_;

        s_classPrice = priceClass;
        TYPES = typesUri;

        interval = updateInterval;
        lastTimeStamp = block.timestamp;
    }

    /// -----------------------------------------------------------------------
    ///                                 Public
    /// -----------------------------------------------------------------------

    function mintClass(shipClass _class) public payable {
        if (msg.value != s_classPrice[uint8(_class)]) {
            revert NotEnoughForShipPurchase(msg.sender, msg.value);
        }

        ERC721AUpgradeable._mint(msg.sender, 1);

        _vrfRandomizeClass(_nextTokenId() - 1);
    }

    function randomizeClass(uint256 _tokenId) public payable {
        _burn(_tokenId);
        points[msg.sender] = 0;

        ERC721AUpgradeable._mint(msg.sender, 1 /*VRF VALUE*/ );

        _vrfRandomizeClass(_nextTokenId() - 1);
    }

    function openChallenge(uint256 _tokenId, challengeType _type, challengeChoice _duration)
        public
        returns (bytes32 id)
    {
        if (ownerOf(_tokenId) != msg.sender) {
            revert NotOwner(msg.sender, _tokenId);
        }

        id = keccak256(abi.encode(msg.sender, _tokenId));

        if (shipInfo[msg.sender][_tokenId]._onChallenge || challenges[id]._firstChallenger != address(0)) {
            revert AlreadyChallenged(msg.sender, _tokenId);
        }

        shipInfo[msg.sender][_tokenId]._onChallenge = true;
        shipInfo[msg.sender][_tokenId]._challengeID = id;
        challenges[id]._firstChallenger = msg.sender;
        challenges[id]._tokenIdC1 = _tokenId;
        challenges[id]._duration = _duration;
        challenges[id]._type = _type;

        emit challengeOpen(msg.sender, _tokenId, _type, _duration, id);

        // the graph => challengeOpened (_user, _tokenId, _type, _choice, id) => list -
        // pickChallenge (_user, _tokenId, _type, _choice, id)
    }

    function pickChallenge(bytes32 _id, uint256 _tokenId) public {
        if (ownerOf(_tokenId) != msg.sender) {
            revert NotOwner(msg.sender, _tokenId);
        }

        if (
            shipInfo[msg.sender][_tokenId]._onChallenge || challenges[_id]._firstChallenger == msg.sender
                || challenges[_id]._secondChallenger == msg.sender
        ) revert AlreadyChallenged(msg.sender, _tokenId);

        if (challenges[_id]._firstChallenger == address(0)) {
            revert NonExistingChallenge(_id);
        }

        if (challenges[_id]._secondChallenger != address(0)) {
            revert ChallengeIsActive(_id);
        }

        shipInfo[msg.sender][_tokenId]._onChallenge = true;
        shipInfo[msg.sender][_tokenId]._challengeID = _id;
        challenges[_id]._secondChallenger = msg.sender;
        challenges[_id]._tokenIdC2 = _tokenId;
        challenges[_id]._challengeTimestamp = block.timestamp + DURATIONS[uint8(challenges[_id]._duration)];

        emit challengeAccepted(msg.sender, _tokenId, _id);
    }

    // ----------------------------------------------------------------

    // play challenge

    function playChallenge(uint256 _tokenId, bytes32 _id, uint256 _points) public returns (bool) {
        _checkAllowed(msg.sender);

        if (challenges[_id]._finalized) revert ChallengeIsNotActive(_id);

        if (challenges[_id]._firstChallenger == address(0)) {
            revert NonExistingChallenge(_id);
        }

        if (challenges[_id]._challengeTimestamp < block.timestamp) {
            challenges[_id]._finalized = true;
            emit challengeFinalized(_id);

            uint256 _aux = ((challenges[_id]._totalAmount1 + challenges[_id]._totalAmount2) * s_takerFee) / 10000;

            if (challenges[_id]._type == challengeType._pointsCash) {
                _distributeBet(_aux, pool);
                challenges[_id]._totalAmount1 = (challenges[_id]._totalAmount1 * (10000 - s_takerFee)) / 10000;
                challenges[_id]._totalAmount2 = (challenges[_id]._totalAmount2 * (10000 - s_takerFee)) / 10000;
            }

            if (challenges[_id]._firstChallengerPoints > challenges[_id]._secondChallengerPoints) {
                points[challenges[_id]._firstChallenger] +=
                    challenges[_id]._firstChallengerPoints + challenges[_id]._secondChallengerPoints;
                emit updatedPoints(challenges[_id]._firstChallenger, points[challenges[_id]._firstChallenger]);
            } else {
                points[challenges[_id]._secondChallenger] +=
                    challenges[_id]._firstChallengerPoints + challenges[_id]._secondChallengerPoints;
                emit updatedPoints(challenges[_id]._secondChallenger, points[challenges[_id]._secondChallenger]);
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

    function betOnChallenge(bytes32 _id, uint256 _amount, uint256 _tokenId) public {
        if (challenges[_id]._type != challengeType._pointsCash) {
            revert CannotBetOnThisType();
        }

        if (challenges[_id]._finalized) revert ChallengeIsNotActive(_id);

        if (challenges[_id]._firstChallenger == address(0)) {
            revert NonExistingChallenge(_id);
        }

        require(_amount > 100, "Hypnos: Amount has to be greater than 100");

        bool success = ERC20Upgradeable(betPayment).transferFrom(msg.sender, address(this), _amount);
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

        emit betedOnChallenge(msg.sender, _amount, _tokenId, _id);
    }

    //claim bet
    function claimBet(bytes32 _id) public {
        if (!challenges[_id]._finalized) revert ChallengeIsActive(_id);

        if (challenges[_id]._firstChallenger == address(0)) {
            revert NonExistingChallenge(_id);
        }

        uint256 _aux;

        if (challenges[_id]._firstChallengerPoints > challenges[_id]._secondChallengerPoints) {
            require(challenges[_id].userDeposits[msg.sender]._amount1 > 100, "Hypnos: not enough betted");
            _aux = (
                (
                    ((challenges[_id].userDeposits[msg.sender]._amount1 * (10000 - s_takerFee)) / 10000)
                        * (challenges[_id]._totalAmount1 + challenges[_id]._totalAmount2)
                ) / challenges[_id]._totalAmount1
            );
            // ( user bet side amount / side amount total ) * totalPooled(side 1 total + side 2 total)
        } else {
            require(challenges[_id].userDeposits[msg.sender]._amount2 > 100, "Hypnos: not enough betted");
            _aux = (
                (
                    ((challenges[_id].userDeposits[msg.sender]._amount2 * (10000 - s_takerFee)) / 10000)
                        * (challenges[_id]._totalAmount1 + challenges[_id]._totalAmount2)
                ) / challenges[_id]._totalAmount2
            );
        }

        challenges[_id].userClaimed[msg.sender] = true;
        require(ERC20Upgradeable(betPayment).transfer(msg.sender, _aux), "Hypnos: Claim Bet transfer failed");
    }

    //check if tokenId in a challenge
    function _beforeTokenTransfers(address from, address, /* to */ uint256 startTokenId, uint256 /* quantity */ )
        internal
        view
        override
    {
        require(
            !shipInfo[from][startTokenId]._onChallenge, "Hypnos: Transfer not possible, this token id is on a challenge"
        );
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;

        uint8 randomType = uint8(_randomWords[0] % 4);
        _tokenUri[s_requests[_requestId].tokenId] = TYPES[randomType];

        emit RequestFulfilled(_requestId, _randomWords);
    }

    /// -----------------------------------------------------------------------
    ///                                 Getter
    /// -----------------------------------------------------------------------

    function getUserDeposits(address _address, bytes32 _id) public view returns (uint256, uint256) {
        return (challenges[_id].userDeposits[_address]._amount1, challenges[_id].userDeposits[_address]._amount2);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) _revert(URIQueryForNonexistentToken.selector);

        return string(abi.encodePacked(s_baseUri, _tokenUri[tokenId]));
    }

    /// -----------------------------------------------------------------------
    ///                                 Internal
    /// -----------------------------------------------------------------------

    function _checkAllowed(address _address) internal view {
        if (!allowed[_address]) revert NotAllowed(_address);
    }

    //distribute bet

    function _distributeBet(uint256 _tratedAmount, address to) public {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(hypnosPoint),
            data: abi.encodeWithSignature("mint(address,uint256)", to, _tratedAmount),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(linkEthereumSepolia)
        });

        uint256 fee = IRouterClient(routerEthereumSepolia).getFee(chainIdAmoy, message);

        bytes32 messageId;
        LinkTokenInterface(linkEthereumSepolia).approve(routerEthereumSepolia, fee);
        messageId = IRouterClient(routerEthereumSepolia).ccipSend(chainIdAmoy, message);
        emit MessageSent(messageId);

        Client.EVM2AnyMessage memory messageBet = Client.EVM2AnyMessage({
            receiver: abi.encode(betPayment),
            data: abi.encodeWithSignature("mint(address,uint256)", to, _tratedAmount),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: address(linkEthereumSepolia)
        });
        uint256 feeBet = IRouterClient(routerEthereumSepolia).getFee(chainIdAmoy, messageBet);

        bytes32 messageIdBet;
        LinkTokenInterface(linkEthereumSepolia).approve(routerEthereumSepolia, feeBet);
        messageIdBet = IRouterClient(routerEthereumSepolia).ccipSend(chainIdAmoy, messageBet);
        emit MessageSent(messageId);
        emit MessageSent(messageIdBet);
    }

    function withdraw(address beneficiary) public onlyOwner {
        uint256 amount = address(this).balance;
        (bool sent,) = beneficiary.call{value: amount}("");
        if (!sent) revert FailedToWithdrawEth(msg.sender, beneficiary, amount);
    }

    function withdrawToken(address beneficiary, address token) public onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(beneficiary, amount);
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

        s_requests[requestId] = RequestStatus({fulfilled: false, exists: true, tokenId: tokenId});
    }

    /// -----------------------------------------------------------------------
    /// Chainlink Automate
    /// -----------------------------------------------------------------------

    /**
     * @notice Sets new base URI for the NFT collection.
     */
    function checkUpkeep(bytes calldata /* checkData */ )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/ )
    {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(bytes calldata /*performData*/ ) external override {
        if ((block.timestamp - lastTimeStamp) > interval) {
            lastTimeStamp = block.timestamp;

            ////@dev TODO implementar o logica das skills com automate
            //     int latestSkills = getLatesSkills();

            //     if(latestSkills == currentPrice){ //change for currentSkills
            //         return;
            //     }
            //     if(latestSkills < currentPrice){
            //         //bear
            //         updateAllTokenUris("basic");
            //     } else {
            //         ///bull
            //         updateAllTokenUris("luxo");
            //     }

            // currentPrice = latestSkills;
            // } else {
            // interval nor elapsed. intervalo não decorrido. No upkeep
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// -----------------------------------------------------------------------
    ///                                 Controller
    /// -----------------------------------------------------------------------

    function allowAddress(address _address) public onlyOwner {
        allowed[_address] = true;
    }
}
