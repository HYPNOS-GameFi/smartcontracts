// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/*@TODO create a platform that takes all the user's investment data and returns investment 
information and integrates automation to make the investment automatically through 
DataFeed whenever the price of ethereum drops 20%, 
take your USDC balance and buy to make the pool locked for a period of 2 years.

Implement ERC6551 for create a tokenBOund NFT gaming for user, the benefit is in the future rewards and airdrops in plataform
*/

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@ccip/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {hypnosPoint} from "./hypnosPoint.sol";
import {betUSD} from "./betUSD.sol";
import {dIBTAETF} from "./chainlink/dIBTAETF.sol";

//  ==========  Chainlink imports  ==========

// This import includes functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
//import "@chainlink/contracts/src/v0.8/automation/KeeperCompatible.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

import {IPriceAgregadorV3} from "./interfaces/IPriceAgregadorV3.sol";

//  ==========  Internal imports  ==========

import {SecurityUpgradeable} from "./security/SecurityUpgradeable.sol";

contract pool is UUPSUpgradeable, SecurityUpgradeable, AutomationCompatibleInterface {
    error FailedToWithdrawEth(address owner, address target, uint256 value);

    //chainlink priceFeed
    IPriceAgregadorV3 public priceFeed; //price real time Safra token
    uint256 public currentPrice;

    address s_priceFeedETH = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    uint256 public currentPriceIBTAETF;

    //automate
    uint256 public /*immutable*/ interval;
    uint256 public lastTimeStamp;

    address public s_hypnosPoint;
    address public s_betUSD;
    address public s_ibtaetf;

    address s_buyerEther;

    mapping(uint256 index => uint256 quantity) public quantityETHByIndex;
    uint256[] amountRequest;
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
        address _priceFeed, //0x694AA1769357215DE4FAC081bf1f309aDC325306 --ETH/US sepolia
        uint256 updateInterval, //15
        address betusd_,
        address hypnospoint_,
        address dIBTAETF_, //price feed IBTAETF in here
        address buyEther_
    ) external initializer {
        __Security_init(owner_);

        s_hypnosPoint = hypnospoint_;
        s_betUSD = betusd_;
        s_ibtaetf = dIBTAETF_;
        s_buyerEther = buyEther_;
        ///@dev Chainlink information above
        //sets the keepers update interval
        interval = updateInterval;
        lastTimeStamp = block.timestamp;

        priceFeed = IPriceAgregadorV3(_priceFeed);
        currentPrice = getLatestPrice();
        //currentPriceIBTAETF = dIBTAETF(s_ibtaetf).getibtaPrice();
    }

    function updateCurrentPriceETF() external {
        currentPriceIBTAETF = dIBTAETF(s_ibtaetf).getibtaPrice();
    }
    /// -----------------------------------------------------------------------
    /// Chainlink functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Automate whith PriceFeed.
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

            uint256 latestPrice = dIBTAETF(s_ibtaetf).getibtaPrice();
            uint256 latestPriceETH = getLatestPrice();

            if (latestPrice == currentPriceIBTAETF) {
                return;
            } if (latestPrice > currentPriceIBTAETF) {
                //ETF caindo
                hypnosPoint(s_hypnosPoint).mint(address(this), 10e8);
            } else {
                betUSD(s_betUSD).mint(address(this), 10e6); //mint ETF whith Functions
            }
            if (latestPriceETH == currentPrice) {
                return;
            }
            if (latestPriceETH < currentPrice) {
                //ether caindo
                betUSD(s_betUSD).transferFrom(address(this), s_buyerEther, currentPrice);
                quantityETHByIndex[amountRequest.length - 1] = currentPrice;
            } else {
                quantityETHByIndex[amountRequest.length - 1] = 0;
            }
            currentPrice = latestPriceETH;
            currentPriceIBTAETF == latestPrice;
        } else {}
    }

    function getLatestPrice() public view returns (uint256) {
        (
            /*uint80 roundID*/
            ,
            int256 price,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return uint256(price); //decimals detail: https://docs.chain.link/docs/data-feeds/price-feeds/addresses/
    } // example price return 3034715771688

    ///@dev insert in here update the power of NFT
    function swap(address _usd, address _coin) internal {}

    function withdraw(address beneficiary) public onlyOwner {
        uint256 amount = address(this).balance;
        (bool sent,) = beneficiary.call{value: amount}("");
        if (!sent) revert FailedToWithdrawEth(msg.sender, beneficiary, amount);
    }

    function withdrawToken(address beneficiary, address token) public onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(beneficiary, amount);
    }

    /// -----------------------------------------------------------------------
    /// Helpers chainlink functions
    /// -----------------------------------------------------------------------

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
    }

    function setInterval(uint256 newInterval) public onlyOwner {
        interval = newInterval;
    }

    function setPriceFeed(address newFeed) public onlyOwner {
        priceFeed = IPriceAgregadorV3(newFeed);
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
    function _authorizeUpgrade(address /*newImplementation*/ ) internal view override(UUPSUpgradeable) {
        __onlyOwner();
        __whenNotPaused();
    }

    receive() external payable {}

    function getQuantityByIndex(uint256 index) public view returns (uint256) {
        require(index < amountRequest.length, "not Exist");
        return quantityETHByIndex[index];
    }

    // function getETHPrice() public view returns (uint256) {
    //     AggregatorV3Interface priceFeedETH = AggregatorV3Interface(s_priceFeedETH);
    //     (, int256 price,,,) = priceFeedETH.staleCheckLatestRoundData();
    //     return uint256(price) * ADDITIONAL_FEED_PRECISION;
    // }
}
