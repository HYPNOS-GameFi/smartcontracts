// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;


/// -----------------------------------------------------------------------
///                                 Imports
/// -----------------------------------------------------------------------

import { ERC721AUpgradeable } from "lib/ERC721A-Upgradeable/contracts/ERC721AUpgradeable.sol";
import { UUPSUpgradeable } from "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SecurityUpgradeable } from "./security/SecurityUpgradeable.sol";



contract HYPNOS_gameFi is ERC721AUpgradeable, 
UUPSUpgradeable,SecurityUpgradeable{

/// -----------------------------------------------------------------------
///                                 Events
/// -----------------------------------------------------------------------

event challengeOpen(address indexed _user, uint256 indexed _tokenId, challengeType _type, challengeChoice _choice, bytes32 indexed _id);
event challengeAccepted(address indexed _user, uint256 indexed _tokenId, bytes32 indexed _id);
event challengeFinalized(bytes32 indexed _id);
event updatedPoints(address indexed _address, uint256 indexed _points);
event updatedChallengePoints(bytes32 indexed _id, uint256 _points1, address _address1,uint256 _points2, address _address2);
event betedOnChallenge(address indexed _address, uint256 indexed _amount, uint256 _tokenId, bytes32 indexed _id);

/// -----------------------------------------------------------------------
///                                 Error
/// -----------------------------------------------------------------------

error NotEnoughForShipPurchase(address _buyer, uint256 _value);
error PointsNotApproved(address _buyer, uint256 _tokenIds);
error AlreadyChallenged(address _user,uint256 _token);
error NotOwner(address _user,uint256 _token);
error NonExistingChallenge(bytes32 id);
error ChallengeIsNotActive(bytes32 id);
error ChallengeIsActive(bytes32 id);
error NotInChallenge(bytes32 id, uint256 _tokenId);
error NotAllowed(address _address);

/// -----------------------------------------------------------------------
///                                 Struct
/// -----------------------------------------------------------------------

struct basicPower{
    uint256 _life;
    uint256 _strenght;
}

struct ShipInfo{
    bool _onChallenge;
    bytes32 _challengeID;
    uint256 _extraLife;
    uint256 _extraStrength;
}

struct challenge{
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
    mapping (address => bool) userClaimed; //math to do is total pooled on (pooledAmount/winner)*totalprizepool = (pooledAmount*totalprizepool/winner)
    mapping (address => deposit) userDeposits;
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

enum shipClass{
    _level1,
    _level2,
    _level3,
    _level4
}

enum challengeType{
    _points,
    _pointsCash
}

/// -----------------------------------------------------------------------
///                                 Storage
/// -----------------------------------------------------------------------


uint256[3] public DURATIONS = [12 hours, 24 hours, 48 hours];
string public s_baseUri;
uint256 public s_maxSupply;
uint256[4] public s_classPrice;
uint256 public s_takerFee;

IERC20 public betPayment;

mapping (shipClass => basicPower) public powerClass;
mapping (address user => mapping(uint256 tokenId => ShipInfo info)) public shipInfo;
mapping (uint256 tokenId => string metadata) public _tokenUri;
mapping(bytes32 challengeID => challenge challengeInfo) public challenges;
mapping (address user => uint256 points) public points;
mapping (address addressCaller => bool allowed) public allowed;


/// -----------------------------------------------------------------------
///                                 Constructor
/// -----------------------------------------------------------------------

constructor(){
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
        uint256 takerFee,
        uint256[4] memory priceClass
    ) external initializerERC721A initializer {
        __ERC721A_init(name_, symbol_);
        __Security_init(owner_);

        s_baseUri = baseURI_;
        s_maxSupply = maxSupply_;
        s_takerFee = takerFee;

        betPayment = IERC20(paymentToken);

        s_classPrice= priceClass;
    }

/// -----------------------------------------------------------------------
///                                 Public
/// -----------------------------------------------------------------------

function mintClass( shipClass _class) public payable{
    if (msg.value != s_classPrice[uint8(_class)]){
        revert NotEnoughForShipPurchase(msg.sender, msg.value);
    }
    ERC721AUpgradeable._mint(msg.sender, 1);
}

function randomizeClass( uint256 _tokenId) public payable{
    _burn(_tokenId);
    points[msg.sender] = 0;
    ///@note implement VRF here
    ERC721AUpgradeable._mint(msg.sender, 1 /*VRF VALUE*/);
}

function openChallenge(uint256 _tokenId, challengeType _type, challengeChoice _duration) public returns(bytes32 id) {
    if(ownerOf(_tokenId) != msg.sender)
    revert NotOwner(msg.sender,_tokenId);

    id = keccak256(abi.encode(msg.sender,_tokenId));

    if(shipInfo[msg.sender][_tokenId]._onChallenge || challenges[id]._firstChallenger != address(0))
    revert AlreadyChallenged(msg.sender,_tokenId);

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
    if(ownerOf(_tokenId) != msg.sender)
    revert NotOwner(msg.sender,_tokenId);

    if(shipInfo[msg.sender][_tokenId]._onChallenge || 
    challenges[_id]._firstChallenger == msg.sender || 
    challenges[_id]._secondChallenger == msg.sender)
    revert AlreadyChallenged(msg.sender,_tokenId);

    if(challenges[_id]._firstChallenger == address(0))
    revert NonExistingChallenge(_id);

    if(challenges[_id]._secondChallenger != address(0))
    revert ChallengeIsActive(_id);

    shipInfo[msg.sender][_tokenId]._onChallenge = true;
    shipInfo[msg.sender][_tokenId]._challengeID = _id;
    challenges[_id]._secondChallenger = msg.sender;
    challenges[_id]._tokenIdC2 = _tokenId;
    challenges[_id]._challengeTimestamp = block.timestamp + DURATIONS[uint8(challenges[_id]._duration)];

    emit challengeAccepted(msg.sender, _tokenId, _id);
}


// ----------------------------------------------------------------

// play challenge

function playChallenge(uint256 _tokenId, bytes32 _id, uint256 _points) public returns (bool){
    _checkAllowed(msg.sender);

    if(challenges[_id]._finalized)
    revert ChallengeIsNotActive(_id);

    if(challenges[_id]._firstChallenger == address(0))
    revert NonExistingChallenge(_id);

    if(challenges[_id]._challengeTimestamp < block.timestamp){
        challenges[_id]._finalized = true;
        emit challengeFinalized(_id);
        if(challenges[_id]._type == challengeType._pointsCash){
            uint256 _aux = ((challenges[_id]._totalAmount1 + challenges[_id]._totalAmount2) * s_takerFee)/10000;
            _distributeBet(_aux);
            challenges[_id]._totalAmount1 = (challenges[_id]._totalAmount1 * s_takerFee)/10000;
            challenges[_id]._totalAmount2 = (challenges[_id]._totalAmount2 * s_takerFee)/10000;
        }else if  (challenges[_id]._firstChallengerPoints > challenges[_id]._secondChallengerPoints){
            points[challenges[_id]._firstChallenger] += challenges[_id]._firstChallengerPoints + challenges[_id]._secondChallengerPoints;
            emit updatedPoints(challenges[_id]._firstChallenger, points[challenges[_id]._firstChallenger]);
        }else{
            points[challenges[_id]._secondChallenger] += challenges[_id]._firstChallengerPoints + challenges[_id]._secondChallengerPoints;
            emit updatedPoints(challenges[_id]._secondChallenger, points[challenges[_id]._secondChallenger]);
        }

        return false;
    }
    
    if(challenges[_id]._tokenIdC1 == _tokenId){
        challenges[_id]._firstChallengerPoints += _points;
    }else if(challenges[_id]._tokenIdC2 == _tokenId){
        challenges[_id]._secondChallengerPoints += _points;
    }else{
        revert NotInChallenge(_id, _tokenId);
    }
    
    emit updatedChallengePoints(_id,  challenges[_id]._firstChallengerPoints, challenges[_id]._firstChallenger, challenges[_id]._secondChallengerPoints, challenges[_id]._secondChallenger);
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
    //@note don't let people bet on type points

    if(challenges[_id]._finalized)
    revert ChallengeIsNotActive(_id);

    if(challenges[_id]._firstChallenger == address(0))
    revert NonExistingChallenge(_id);

    require(_amount > 100, "Hypnos: Amount has to be greater than 100");

    bool success = betPayment.transferFrom(msg.sender,address(this),_amount);
    require(success, "Hypnos: betOnChallenge transfer failed");

    if(challenges[_id]._tokenIdC1 == _tokenId){
        challenges[_id]._totalAmount1 += _amount;
        challenges[_id].userDeposits[msg.sender]._amount1 += _amount;
    }else if(challenges[_id]._tokenIdC2 == _tokenId){
        challenges[_id]._totalAmount2 += _amount;
        challenges[_id].userDeposits[msg.sender]._amount2 += _amount;
    }else{
        revert NotInChallenge(_id, _tokenId);
    }

    emit betedOnChallenge(msg.sender, _amount, _tokenId, _id);
}

//claim bet
function claimBet(bytes32 _id) public {
    if(!challenges[_id]._finalized)
    revert ChallengeIsActive(_id);

    if(challenges[_id]._firstChallenger == address(0))
    revert NonExistingChallenge(_id);

    uint256 _aux;

    if  (challenges[_id]._firstChallengerPoints > challenges[_id]._secondChallengerPoints){
        require(challenges[_id].userDeposits[msg.sender]._amount1 > 100, "Hypnos: not enough betted");
        _aux = (challenges[_id].userDeposits[msg.sender]._amount1 * (challenges[_id]._totalAmount1 + challenges[_id]._totalAmount2))/ challenges[_id]._totalAmount1;
        // ( user bet side amount / side amount total ) * totalPooled(side 1 total + side 2 total)
    } else {
        require(challenges[_id].userDeposits[msg.sender]._amount2 > 100, "Hypnos: not enough betted");
        _aux = (challenges[_id].userDeposits[msg.sender]._amount2 * (challenges[_id]._totalAmount1 + challenges[_id]._totalAmount2))/ challenges[_id]._totalAmount2;
    }

    challenges[_id].userClaimed[msg.sender] = true;
    require(betPayment.transfer(msg.sender,_aux),"Hypnos: Claim Bet transfer failed");
}


//check if tokenId in a challenge
function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal view override {
        require(!shipInfo[from][startTokenId]._onChallenge, "Hypnos: Transfer not possible, this token id is on a challenge");
    }




/// -----------------------------------------------------------------------
///                                 Getter
/// -----------------------------------------------------------------------

function getUserDeposits(address _address, bytes32 _id) public view returns(uint256,uint256){
    return (challenges[_id].userDeposits[_address]._amount1,challenges[_id].userDeposits[_address]._amount2);
}

/// -----------------------------------------------------------------------
///                                 Internal
/// -----------------------------------------------------------------------

function _checkAllowed(address _address) internal view {
    if (!allowed[_address])
    revert NotAllowed(_address);
}

//distribute bet

function _distributeBet(uint256 _tratedAmount) internal{
    //@note insert CCIP for pool with automate
}

function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


/// -----------------------------------------------------------------------
///                                 Controller
/// -----------------------------------------------------------------------

function allowAddress(address _address) public onlyOwner {
    allowed[_address] = true;
}



}