// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OracleLib, AggregatorV3Interface} from "./lib/OracleLib.sol";

/*
 * @dev the codebase will mint sIBTAETF based on the collateral 
 * deposited into this contract. In our example, ETH is the
 * collateral that we will use to mint sIBTAETF.
 * 
 * This codebase is NOT COMPLETE
 * 
 * As far as the incentives to do this, people who want to 
 * short tesla and long eth would have the incentive to do this. 
 */
contract sIBTAETF is ERC20 {
    using OracleLib for AggregatorV3Interface;

    error sIBTAETF_feeds__InsufficientCollateral();

    // These both have 8 decimal places for Polygon
    // https://docs.chain.link/data-feeds/price-feeds/addresses?network=polygon
    address private i_ibtaetfFeed;
    address private i_ethUsdFeed;
    uint256 public constant DECIMALS = 8;
    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address user => uint256 ibtaetfMinted) public s_ibtaetfMintedPerUser;
    mapping(address user => uint256 ethCollateral) public s_ethCollateralPerUser;

    constructor(address ibtaetfFeed, address ethUsdFeed) ERC20("Synthetic Tesla (Feeds)", "sibtaetf") {
        i_ibtaetfFeed = ibtaetfFeed;
        i_ethUsdFeed = ethUsdFeed;
    }

    /* 
     * @dev User must deposit at least 200% of the value of the sibtaetf they want to mint
     */
    function depositAndmint(uint256 amountToMint) external payable {
        // Checks / Effects
        s_ethCollateralPerUser[msg.sender] += msg.value;
        s_ibtaetfMintedPerUser[msg.sender] += amountToMint;
        uint256 healthFactor = getHealthFactor(msg.sender);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert sIBTAETF_feeds__InsufficientCollateral();
        }
        _mint(msg.sender, amountToMint);
        // No external interactions
    }

    function redeemAndBurn(uint256 amountToRedeem) external {
        // Checks / Effects
        uint256 valueRedeemed = getUsdAmountFromsIBTAETF(amountToRedeem);
        uint256 ethToReturn = getEthAmountFromUsd(valueRedeemed);
        s_ibtaetfMintedPerUser[msg.sender] -= amountToRedeem;
        uint256 healthFactor = getHealthFactor(msg.sender);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert sIBTAETF_feeds__InsufficientCollateral();
        }
        _burn(msg.sender, amountToRedeem);
        // External
        (bool success,) = msg.sender.call{value: ethToReturn}("");
        if (!success) {
            revert("sIBTAETF_feeds: transfer failed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getHealthFactor(address user) public view returns (uint256) {
        (uint256 totalibtaetfMintedValueInUsd, uint256 totalCollateralEthValueInUsd) = getAccountInformationValue(user);
        return _calculateHealthFactor(totalibtaetfMintedValueInUsd, totalCollateralEthValueInUsd);
    }

    function getUsdAmountFromsIBTAETF(uint256 amountibtaetfInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_ibtaetfFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return (amountibtaetfInWei * (uint256(price) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }

    function getUsdAmountFromEth(uint256 ethAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_ethUsdFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return (ethAmountInWei * (uint256(price) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }

    function getEthAmountFromUsd(uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_ethUsdFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return (usdAmountInWei * PRECISION) / ((uint256(price) * ADDITIONAL_FEED_PRECISION) * PRECISION);
    }

    function getAccountInformationValue(address user)
        public
        view
        returns (uint256 totalibtaetfMintedValueUsd, uint256 totalCollateralValueUsd)
    {
        (uint256 totalibtaetfMinted, uint256 totalCollateralEth) = _getAccountInformation(user);
        totalibtaetfMintedValueUsd = getUsdAmountFromsIBTAETF(totalibtaetfMinted);
        totalCollateralValueUsd = getUsdAmountFromEth(totalCollateralEth);
    }

    function _calculateHealthFactor(uint256 ibtaetfMintedValueUsd, uint256 collateralValueUsd)
        internal
        pure
        returns (uint256)
    {
        if (ibtaetfMintedValueUsd == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / ibtaetfMintedValueUsd;
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalibtaetfMinted, uint256 totalCollateralEth)
    {
        totalibtaetfMinted = s_ibtaetfMintedPerUser[user];
        totalCollateralEth = s_ethCollateralPerUser[user];
    }
}
