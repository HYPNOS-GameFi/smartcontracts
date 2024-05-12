// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// __/\\\_____________________________________________________________
//  _\/\\\_____________________________________________________________
//   _\/\\\_____________________________________________________________
//    _\/\\\______________/\\\____/\\\____/\\\\\__/\\\\\____/\\\____/\\\_
//     _\/\\\_____________\/\\\___\/\\\__/\\\///\\\\\///\\\_\///\\\/\\\/__
//      _\/\\\_____________\/\\\___\/\\\_\/\\\_\//\\\__\/\\\___\///\\\/____
//       _\/\\\_____________\/\\\___\/\\\_\/\\\__\/\\\__\/\\\____/\\\/\\\___
//        _\/\\\\\\\\\\\\\\\_\//\\\\\\\\\__\/\\\__\/\\\__\/\\\__/\\\/\///\\\_
//         _\///////////////___\/////////___\///___\///___\///__\///____\///_

/// -----------------------------------------------------------------------
/// Imports
/// -----------------------------------------------------------------------

//  ==========  External imports  ==========

import { ERC721AUpgradeable } from "@ERC721A-Upgradeable/contracts/ERC721AUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

//  ==========  Chainlink imports  ==========

// This import includes functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/automation/KeeperCompatible.sol";

import {IPriceSafraAgregadorV3} from "./interfaces/IPriceSafraAgregadorV3.sol";


//  ==========  Internal imports  ==========

import { SecurityUpgradeable } from "./security/SecurityUpgradeable.sol";


/// -----------------------------------------------------------------------
/// Contract
/// -----------------------------------------------------------------------

/**
 * @title Lumx ERC-721 non-fungible smart contract.
 * @author Lumx by Bruno Leao.
 * @dev Uses {ERC721AUpgradeable} smart contract from @chiru-labs.
 * @dev Mints tokens in sequence, that is, it is not possible to define
 * the token ID to mint.
 * @custom:revisors Eduardo W. da Cunha (@EWCunha) and Afonso Dalvi (@Afonsodalvi).
 * @custom:revision-id 1
 */
contract gameNFT_VRF_Automate is ERC721AUpgradeable, UUPSUpgradeable, SecurityUpgradeable, KeeperCompatibleInterface{
   

    /// -----------------------------------------------------------------------
    /// Custom errors
    /// -----------------------------------------------------------------------

    /**
     * @dev Error for when the max supply amount is reached.
     * @param supply: uint256 value for resultant supply.
     */
    error MaxSupplyReached(uint256 supply);


    /**
     * @dev Error for when trasfering token to this contract is attempted.
     */
    error TransferNotAllowed();

    /// -----------------------------------------------------------------------
    /// State variables
    /// -----------------------------------------------------------------------

    /* solhint-disable var-name-mixedcase */
    uint256 private s_maxPerAddress;
    string private s_baseURI;
    uint256 private s_maxSupply;

    uint256[50] private __gap;
    /* solhint-enable var-name-mixedcase */

    //chainlink
    IPriceSafraAgregadorV3 public priceFeed; //price real time Safra token
    int256 public currentPrice;


     // IPFS URIs for the dynamic nft https://nft.storage/
    // NOTE: IPFs valuation Safra
    string constant public SafraHype = "https://ipfs.io/ipfs/QmTXGUE8ciatzL1epqZTQRDDpzCXQSksQndQnaATfT9ATN";
    string constant public SafraMedium = "https://ipfs.io/ipfs/QmWYLkVwHR29GzYXQzZfAnvjNFQtWs2QGJSxEHspgr71YL";

    uint public /*immutable*/ interval;
    uint public lastTimeStamp;
    event TokenUpdated(string SafraURI);

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /**
     * @dev Emitted when a new backend address is set.
     * @param caller: function _from address. Indexed.
     * @param baseURI_: string value for new URI.
     */
    event ChangedBaseUri(address indexed caller, string baseURI_);

    /**
     * @dev Emitted when a new backend address is set.
     * @param caller: function from address. Indexed.
     * @param withdrawAddress: address value for new withdraw address.
     */
    event ChangedWithdrawAddress(address indexed caller, address withdrawAddress);

    /// -----------------------------------------------------------------------
    /// Modifiers (or internal functions as modifiers)
    /// -----------------------------------------------------------------------

    /**
     * @dev Performs required checks before minting NFTs.
     * @param to: address to which tokens will be minted.
     * @param amount: amount of tokens to mint.
     */
    function _checkMint(address to, uint256 amount) internal view virtual {
       
        uint256 supply = totalSupply() + amount;
        if (supply > s_maxSupply) revert MaxSupplyReached(supply);
    }

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
     * @dev Uses two initializer: `initializerERC721A` from {ERC721AUpgradeable} and
     * `initializer` from OpenZeppelin's {Initializer}.
     * @param owner_: owner of this smart contract.
     * @param baseURI_: base URI for the collection.
     * @param name_: ERC-721A token name.
     * @param symbol_: ERC-721A token symbol.
     * @param maxSupply_: max supply of tokens.
     */
    function initialize(
        address owner_,
        string memory baseURI_,
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        address _priceFeed,
        uint256 updateInterval
    ) external initializerERC721A initializer {
        __ERC721A_init(name_, symbol_);
        __Security_init(owner_);

        s_baseURI = baseURI_;
        s_maxSupply = maxSupply_;

         ///@dev Chainlink information above
        //sets the keepers update interval
        interval = updateInterval;
        lastTimeStamp = block.timestamp;

        // the value of the Safra is updated from the interface contract, 
        //which is updated in real time with the values of the tokenized Safra
       priceFeed = IPriceSafraAgregadorV3(_priceFeed);
        currentPrice = getLatestPrice();
    }

    /// -----------------------------------------------------------------------
    /// State-change public/external functions
    /// -----------------------------------------------------------------------

    //  ==========  Mint functions  ==========

    /**
     * @notice Mints given amount of tokens.
     * @dev Calls {mint(address,uint256)} public function.
     * @param amount: amount of tokens to mint.
     */
    function mint(uint256 amount) external virtual {
        mint(msg.sender, amount);
    }

    /**
     * @notice Mints given amount of tokens to the given address
     * @dev Checks if caller has permission to mint.
     * @dev Checks if it is possible to mint given amount to the given address.
     * @dev Won't work if contract is paused.
     * @dev Added {nonReentrant} modifier from {ReentrancyGuardUpgradeable} smart contract.
     * @param to: address to which tokens will be minted.
     * @param amount: amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public virtual nonReentrant {
        _checkMint(to, amount);

        _mint(to, amount);
    }

    /**
     * @notice Mints given amount of tokens to the given address
     * @dev Checks if caller is either contract owner or backend.
     * @dev Won't work if contract is paused.
     * @dev Added {nonReentrant} modifier from {ReentrancyGuardUpgradeable} smart contract.
     * @param to: address to which tokens will be minted.
     * @param amount: amount of tokens to mint.
     */
    function superMint(address to, uint256 amount) external virtual nonReentrant {
        _checkMint(to, amount);
        __whenNotPaused();

        _mint(to, amount);
    }

    //  ==========  Setter functions  ==========

    

    /**
     * @notice Sets new base URI for the collection.
     * @dev Checks if caller is either contract owner or backend.
     * @dev Won't work if contract is paused.
     * @dev Added {nonReentrant} modifier from {ReentrancyGuardUpgradeable} smart contract.
     * @param baseURI_: new base URI for this collection.
     */
    function setBaseURI(string memory baseURI_) external virtual nonReentrant {
        __onlyOwner();
        __whenNotPaused();

        s_baseURI = baseURI_;

        emit ChangedBaseUri(msg.sender, baseURI_);
    }

    /// -----------------------------------------------------------------------
    /// View internal/private functions
    /// -----------------------------------------------------------------------

    /**
     * @dev Authorizes smart contract upgrade (required by {UUPSUpgradeable}).
     * @dev Only contract owner or backend can call this function.
     * @dev Won't work if contract is paused.
     * @inheritdoc UUPSUpgradeable
     */
    function _authorizeUpgrade(address /*newImplementation*/) internal view override(UUPSUpgradeable) {
       __onlyOwner();
        __whenNotPaused();
    }

    /**
     * @dev Reads the s_baseURI storage variable.
     * @dev Overriden from {ERC721AUpgradeable}.
     * @return string value for the base URI of this collection.
     * @inheritdoc ERC721AUpgradeable
     */
    function _baseURI() internal view virtual override(ERC721AUpgradeable) returns (string memory) {
        return s_baseURI;
    }

    /**
     *
     * @notice Overrides {ERC721AUpgradeable-_beforeTokenTransfers} function to prevent transfering to this contract.
     * @dev Added {__whenNotPaused} function to prevent transfering when the contract is paused.
     * @param to: address to which token is transferred.
     * @inheritdoc ERC721AUpgradeable
     */
    function _beforeTokenTransfers(
        address,
        address to,
        uint256,
        uint256
    ) internal view virtual override(ERC721AUpgradeable) {
        __whenNotPaused();
        if (to == address(this)) revert TransferNotAllowed();
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
        priceFeed = IPriceSafraAgregadorV3(newFeed);
    }


    /// -----------------------------------------------------------------------
    /// Gaming public functions
    /// -----------------------------------------------------------------------

    function combat(uint256 id, uint256 amount) public payable returns(uint256 idGame){
        //usdc or ether  
        uint256 idGame;
        return(idGame);
    }


    function bet(uint256 idGame, uint256 amount) public payable {
        //usdc or ether  
    }

    /// -----------------------------------------------------------------------
    /// View public/external functions
    /// -----------------------------------------------------------------------


    /**
     * @notice Reads the s_baseURI storage variable.
     * @return string for the base URI of the collection.
     */
    function getBaseURI() external view returns (string memory) {
        return s_baseURI;
    }

    /**
     * @notice Reads the s_maxSupply storage variable.
     * @return uint256 value maximum token supply.
     */
    function getMaxSupply() external view returns (uint256) {
        return s_maxSupply;
    }
}