// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;


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
   
    IPriceAgregadorV3 public s_priceFeedETH;
    uint256 public currentPriceETH;
    IPriceAgregadorV3 public s_priceFeedETF;
    uint256 public currentPriceETF;
    IPriceAgregadorV3 public s_priceFeedUSD;
    uint256 public currentPriceUSD; 

    
    //automate
    uint256 public /*immutable*/ interval;
    uint256 public lastTimeStamp;

    address public s_hypnosPoint;
    address public s_betUSD;

    address s_buyerEther;
    address s_buyerGov;

    struct infoForbuyerEther{
        uint256 price;
        uint256 time;
    }

    mapping(uint256 id => infoForbuyerEther) public manyTimesETHhasFallen;
    uint id;
    
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
     * @param updateInterval: Update Automate for execute buy ETH low 20%.
     */
    function initialize(
        address owner_,
        uint256 updateInterval, //15
        address betusd_,
        address hypnospoint_,
        address buyEther_,
        address buyGov_
    ) external initializer {
        __Security_init(owner_);

        s_hypnosPoint = hypnospoint_;
        s_betUSD = betusd_;
        s_buyerEther = buyEther_;
        s_buyerGov = buyGov_;
        ///@dev Chainlink information above
        //sets the keepers update interval
        interval = updateInterval;
        lastTimeStamp = block.timestamp;

        s_priceFeedETH = IPriceAgregadorV3(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        currentPriceETH = getLatestPriceETH();

        s_priceFeedETF = IPriceAgregadorV3(0xB677bfBc9B09a3469695f40477d05bc9BcB15F50);
        //iShares $ Treasury Bond 0-1yr UCITS ETF
        currentPriceETF = getLatestPriceETF();
        
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

            uint256 latestPriceETF = getLatestPriceETF();
            uint256 latestPriceETH = getLatestPriceETH();

            if (latestPriceETF == currentPriceETF) {
                 return;
            } if (latestPriceETF > currentPriceETF) {
                //ETF fallen
                hypnosPoint(s_hypnosPoint).mint(address(this), 1000e8);
            } else {
                betUSD(s_betUSD).transfer(s_buyerGov, 1000e6); 
                //transfer betUSD to dollarize and buy government assets
            }
            if (latestPriceETH == currentPriceETH) {
               return;
            } if (latestPriceETH < currentPriceETH) {
                //ether fallen
                betUSD(s_betUSD).transfer(s_buyerEther, 100e6);
                //transfer betUSD to dollarize and buy ETHER and other digital assets
                uint256 idplus = id++;
                manyTimesETHhasFallen[idplus] = infoForbuyerEther({
                    price: currentPriceETH,
                    time: block.timestamp
                });
            } 
            currentPriceETH = latestPriceETH;
            currentPriceETF = latestPriceETF;
        } else {
            // interval nor elapsed. intervalo não decorrido. No upkeep
        }
    }


    function getLatestPriceETH() public view returns (uint256) {
        (
            /*uint80 roundID*/
            ,
            int256 price,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = s_priceFeedETH.latestRoundData();
        return uint256(price); //decimals detail: https://docs.chain.link/docs/data-feeds/price-feeds/addresses/
    } // example price return 3034715771688

    function getLatestPriceETF() public view returns (uint256) {
        (
            /*uint80 roundID*/
            ,
            int256 price,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = s_priceFeedETF.latestRoundData();
        return uint256(price); //decimals detail: https://docs.chain.link/docs/data-feeds/price-feeds/addresses/
    } // example price return 3034715771688

    function getLatestPriceUSD() public view returns (uint256) {
        (
            /*uint80 roundID*/
            ,
            int256 price,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = s_priceFeedUSD.latestRoundData();
        return uint256(price); //decimals detail: https://docs.chain.link/docs/data-feeds/price-feeds/addresses/
    } // example price return 3034715771688


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

    function setNewbuyETH(address _buyeth)external onlyOwner{
        s_buyerEther = _buyeth;
    }

    function setNewbuyGov(address _buygov)external onlyOwner{
        s_buyerGov = _buygov;
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



}
