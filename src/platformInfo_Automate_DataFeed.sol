// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;


/*@TODO create a platform that takes all the user's investment data and returns investment 
information and integrates automation to make the investment automatically through 
DataFeed whenever the price of ethereum drops 20%, 
take your USDC balance and buy to make the pool locked for a period of 2 years.

Implement ERC6551 for create a tokenBOund NFT gaming for user, the benefit is in the future rewards and airdrops in plataform
*/

import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

//  ==========  Chainlink imports  ==========

// This import includes functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/automation/KeeperCompatible.sol";

import {IPriceSafraAgregadorV3} from "./interfaces/IPriceSafraAgregadorV3.sol";

//  ==========  Internal imports  ==========

import { SecurityUpgradeable } from "./security/SecurityUpgradeable.sol";



contract platformInfo_Automate_DataFeed is  UUPSUpgradeable, SecurityUpgradeable, KeeperCompatibleInterface{


//chainlink priceFeed
IPriceSafraAgregadorV3 public priceFeed; //price real time Safra token
int256 public currentPrice;

//automate
uint public /*immutable*/ interval;
uint public lastTimeStamp;


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
     * @param _priceFeed: priceFeed ETH/USDC.
     * @param updateInterval: Update Automate for execute buy ETH low 20%.
     */
    function initialize(
        address owner_,
        address _priceFeed,
        uint256 updateInterval
    ) external initializer {
        __Security_init(owner_);

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
               ///@TODO buyOrSell("basic"); set buy or sell ETH/USDT
            } else {
                ///bull
                ///@TODO buyOrSell("luxo"); set buy or sell ETH/USDT
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
     function buyOrSell(string memory trend) internal{
        // if(compareStrings("basic", trend)){
        //        // _setBaseURI(SafraMedium);
        // }else {
        //       //  _setBaseURI(SafraHype);
        // }

        // emit TokenUpdated(trend);
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

}