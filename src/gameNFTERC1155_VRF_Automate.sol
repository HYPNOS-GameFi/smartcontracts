// SPDX-License-Identifier: MIT
/*solhint-disable compiler-version */
pragma solidity 0.8.23;


/// -----------------------------------------------------------------------
/// Imports
/// -----------------------------------------------------------------------

//  ==========  External imports  ==========

import { ERC1155Upgradeable, IERC1155, IERC1155MetadataURI} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { ERC1155URIStorageUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";


//  ==========  Chainlink imports  ==========

// This import includes functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/automation/KeeperCompatible.sol";

import {IPriceAgregadorV3} from "./interfaces/IPriceAgregadorV3.sol";

//  ==========  Internal imports  ==========

import "./security/SecurityUpgradeable.sol";


/// -----------------------------------------------------------------------
/// Contract
/// -----------------------------------------------------------------------

/**
 * @title 
 * @author Hypnos Team.
 * @custom:revisors G-Deps and Afonso Dalvi (@Afonsodalvi).
 * @custom:revision-id 1
 */
contract gameNFTERC1155_VRF_Automate is ERC1155URIStorageUpgradeable, SecurityUpgradeable, UUPSUpgradeable, KeeperCompatible {
    /// -----------------------------------------------------------------------
    /// Libraries
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Custom errors
    /// -----------------------------------------------------------------------

    /**
     * @dev Error for when the max supply amount is reached.
     * @param supply: uint256 value for resultant supply.
     */
    error MaxSupplyReached(uint256 supply);

    /// -----------------------------------------------------------------------
    /// State variables
    /// -----------------------------------------------------------------------

    /* solhint-disable var-name-mixedcase */
    string private s_name;
    string private s_symbol;
    mapping(uint256 => uint256) s_maxSupplyForId;
    mapping(uint256 => uint256) s_totalSupply;

     //chainlink
    IPriceAgregadorV3 public priceFeed; //price real time Safra token
    int256 public currentPrice;

     uint public /*immutable*/ interval;
    uint public lastTimeStamp;
    event TokenUpdated(string URI);
    

    uint256[50] private __gap;

    /// -----------------------------------------------------------------------
    /// Initializer/constructor
    /// -----------------------------------------------------------------------

    /**
     * @dev Constructor with {_disableInitializers} internal function from {UUPSUpgradeable}
     * proxy smart contract. This function disables initializer function calls in the implementation
     * contract.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes this smart contract.
     * @dev This function is required so that the upgradeable proxy is functional.
     * @dev Callable only once.
     * @dev Uses two initializer: `initializer1155` from {ERC1155Upgradeable} and
     * `initializer` from OpenZeppelin's {OwnableUpgradeable}.
     * @param initialOwner: owner of this smart contract.
     * @param _name: name of this smart contract.
     * @param _symbol: symbol of this smart contract.
     * @param uri_: Project URI.
     */
    function initialize(
        address initialOwner,
        string memory _name,
        string memory _symbol,
        string memory uri_,
        address _priceFeed,
        uint256 updateInterval
    ) external initializer {
        s_name = _name;
        s_symbol = _symbol;
        __ERC1155URIStorage_init();
        _setBaseURI(uri_);
        __Security_init(initialOwner);

        ///@dev Chainlink information above
        //sets the keepers update interval
        interval = updateInterval;
        lastTimeStamp = block.timestamp;

        // the value of the Safra is updated from the interface contract, 
        //which is updated in real time with the values of the tokenized Safra
        priceFeed = IPriceAgregadorV3(_priceFeed);
        currentPrice = getLatestPrice();
    }

    /// -----------------------------------------------------------------------
    /// State-change internal/private functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Mints token.
     * @param to: address to which the token will be minted.
     * @param tokenId: token ID to mint.
     * @param value: amount of tokens to mint.
     */
    function mint(address to, uint256 tokenId, uint256 value, string memory _uri) external nonReentrant {
        
        if (s_maxSupplyForId[tokenId]>0){
        if (s_totalSupply[tokenId] + value > s_maxSupplyForId[tokenId]) 
            revert MaxSupplyReached(s_maxSupplyForId[tokenId]);
        }
        _setURI(tokenId,_uri);
        __whenNotPaused();

        _mint(to, tokenId, value, "");
    }

    /**
     * @notice Mints token.
     * @param to: address to which the token will be minted.
     * @param tokenId: token ID to mint.
     * @param value: amount of tokens to mint.
     */
    function superMint(address to, uint256 tokenId, uint256 value, string memory _uri) external nonReentrant {
        
        __whenNotPaused();
        if (s_maxSupplyForId[tokenId]>0){
        if (s_totalSupply[tokenId] + value > s_maxSupplyForId[tokenId]) 
            revert MaxSupplyReached(s_maxSupplyForId[tokenId]);
        }
        
        _setURI(tokenId,_uri);
        s_totalSupply[tokenId] += value;
        _mint(to, tokenId, value, "");
    }


    /**
     * @notice Mints a batch of tokens.
     * @param to: address to which the tokens will be minted.
     * @param tokenIds: array of token IDs to mint.
     * @param values: array of amounts of tokens to mint.
     */
    function mintBatch(
        address to,
        uint256[] calldata tokenIds,
        uint256[] calldata values
    ) external nonReentrant {
     
        __whenNotPaused();

        maxSupplyReached(tokenIds, values);

        for (uint256 i = 0; i < tokenIds.length; i++) {
        s_totalSupply[tokenIds[i]] += values[i];
         }
        _mintBatch(to, tokenIds, values, "");
    }

    /**
     * @notice Mints a batch of tokens.
     * @param to: address to which the tokens will be minted.
     * @param tokenIds: array of token IDs to mint.
     * @param values: array of amounts of tokens to mint.
     */
    function superMintBatch(address to, uint256[] calldata tokenIds, uint256[] calldata values) external nonReentrant {
        
        __whenNotPaused();
        
        maxSupplyReached(tokenIds, values);

        for (uint256 i = 0; i < tokenIds.length; i++) {
        s_totalSupply[tokenIds[i]] += values[i];
         }

        _mintBatch(to, tokenIds, values, "");
    }

    /// -----------------------------------------------------------------------
    /// Set functions by owner or backend
    /// -----------------------------------------------------------------------

    function setMaxSupplyForId(uint256[] calldata ids, uint256[] calldata maxSupplys) public {
    require(ids.length == maxSupplys.length, "Os arrays de ids e maxSupplys devem ter o mesmo tamanho");

    for (uint256 i = 0; i < ids.length; i++) {
        s_maxSupplyForId[ids[i]] = maxSupplys[i];
    }
}

    function setTokenUri(uint tokenId, string memory _uri)external {
        __onlyOwner();
        _setURI(tokenId,_uri);
    }

    /// -----------------------------------------------------------------------
    /// View internal/private functions
    /// -----------------------------------------------------------------------

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Authorizes smart contract upgrade (required by {UUPSUpgradeable}).
     * @dev Only contract owner or backend can call this function.
     * @dev Won't work if contract is paused.
     */
    function _authorizeUpgrade(address /*newImplementation*/) internal view virtual override(UUPSUpgradeable) {
        __onlyOwner();
        __whenNotPaused();
    }

    function maxSupplyReached(uint256[] calldata tokenIds, uint256[] calldata value)internal view{
        for (uint256 i = 0; i < tokenIds.length; i++) {
        if(s_maxSupplyForId[tokenIds[i]]>0){
        if (s_totalSupply[tokenIds[i]] + value[i] > s_maxSupplyForId[tokenIds[i]]) 
            revert MaxSupplyReached(s_maxSupplyForId[tokenIds[i]]);
        }
        }
    }

    /// -----------------------------------------------------------------------
    /// Chainlink functions
    /// -----------------------------------------------------------------------

     /**
     * @notice Sets new base URI for the NFT collection.
     */
     function checkUpkeep(bytes calldata /* checkData */) external view override returns(bool upkeepNeeded, bytes memory /*performData*/) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(bytes calldata /*performData*/) external override {
        if ((block.timestamp - lastTimeStamp) > interval){
            lastTimeStamp = block.timestamp;

            int latestPrice = getLatestPrice(); 

            if(latestPrice == currentPrice){
                return;
            } 
            if(latestPrice < currentPrice){
                //bear
                updateAllTokenUris("basic");
            } else {
                ///bull
                updateAllTokenUris("luxo");
            }

        currentPrice = latestPrice;
        } else {
            // interval nor elapsed. intervalo não decorrido. No upkeep

        }
    }

    function getLatestPrice() public view returns(int256){
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price; //decimals detail: https://docs.chain.link/docs/data-feeds/price-feeds/addresses/
    } // example price return 3034715771688


    

    ///@dev insert in here update the power of NFT
     function updateAllTokenUris(string memory trend) internal{
        if(compareStrings("basic", trend)){
               // _setBaseURI(SafraMedium);
        }else {
              //  _setBaseURI(SafraHype);
        }

        emit TokenUpdated(trend);
    }

    /// -----------------------------------------------------------------------
    /// Helpers chainlink functions
    /// -----------------------------------------------------------------------

    
    function compareStrings(string memory a, string memory b) internal pure returns(bool){
        return (keccak256(abi.encodePacked(a)) ==  keccak256(abi.encodePacked(b)));
    }

    function setInterval(uint256 newInterval)public onlyOwner{
        interval = newInterval;
    }

    function setPriceFeed(address newFeed) public onlyOwner{
        priceFeed = IPriceAgregadorV3(newFeed);
    }


     /// -----------------------------------------------------------------------
    /// Gaming public functions
    /// -----------------------------------------------------------------------

    function combat(uint256 id) public payable returns(uint256 idGame){
        //usdc or ether  
        uint256 idGame;
        return(idGame);
    }

    function pointNFT()external{

    }

/// a cada 1 horas automate
    function powerNFT()external{
///vrf 
    }



    function bet(uint256 idGame, uint256 amount) public payable {
        //usdc or ether  
    }


    /// -----------------------------------------------------------------------
    /// returns functions
    /// -----------------------------------------------------------------------

    /**
     * @dev See {Metadata-name}.
     */
    function name() public view returns (string memory) {
        return s_name;
    }

    /**
     * @dev See {Metadata-symbol}.
     */
    function symbol() public view returns (string memory) {
        return s_symbol;
    }


    /**
     * @dev See {GetMaxSupply}.
     */
    function getMaxSupply(uint256[] calldata tokenIds) public view returns(uint256[] memory) {
         uint256[] memory maxSupplies = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
        maxSupplies[i] = s_maxSupplyForId[tokenIds[i]];
    }
    return maxSupplies;
    }
}