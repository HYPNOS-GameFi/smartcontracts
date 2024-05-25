
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

//  ==========  External imports  ==========
import { FunctionsClient } from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
//import { ConfirmedOwner } from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import { FunctionsRequest } from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import { ERC20Upgradeable, IERC20 } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

//  ==========  Internal imports  ==========

import { SecurityUpgradeable } from "../security/SecurityUpgradeable.sol";


import { OracleLib, AggregatorV3Interface } from "./lib/OracleLib.sol";


/*
In the future, we can use other APIs in the call, such as the telecom one, 
providing another layer of security in cases of theft and improper SIM access: https://opengateway.telefonica.com/pt/apis/sim-swap

But in this example below we will use the alpacas API to generate our real-world stock derivative
link: https://docs.alpaca.markets/reference/stockauctions-1
*/

/**
 * @title dTSLA
 * @notice This is our contract to make requests to the Alpaca API to mint TSLA-backed dTSLA tokens
 * @dev This contract is meant to be for educational purposes only
 */

 contract dTSLAOracleLumx is FunctionsClient, ERC20Upgradeable, SecurityUpgradeable, UUPSUpgradeable{
    /// -----------------------------------------------------------------------
    /// Libraries
    /// -----------------------------------------------------------------------


    ///necessary for chainlink
    using FunctionsRequest for FunctionsRequest.Request;
    using OracleLib for AggregatorV3Interface; ///@dev: modificar no futuro as regras envolvendo o Aggregator na sua propria Lib
    using Strings for uint256;

    error dTSLA__NotEnoughCollateral();
    error dTSLA__BelowMinimumRedemption();
    error dTSLA__RedemptionFailed();

    // Custom error type
    error UnexpectedRequestID(bytes32 requestId);

    enum MintOrRedeem {
        mint,
        redeem
    }

    struct dTslaRequest {
        uint256 amountOfToken;
        address requester;
        MintOrRedeem mintOrRedeem;
    }

    uint32 private constant GAS_LIMIT = 300_000;
    uint64 immutable i_subId;

    // Check to get the router address for your supported network
    // https://docs.chain.link/chainlink-functions/supported-networks
    address s_functionsRouter;

    ///@dev as definicoes abaixo sao da regra da API e caso usemos outra devemos rescrever conforme as regras
    string s_mintSource;//toda vez que chamar chainlink functions sera com esse parametro de API 
    string s_redeemSource;// ou podemos usar este

    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 s_donID;
    uint256 s_portfolioBalance;
    uint64 s_secretVersion;
    uint8 s_secretSlot;

    //requestID tem q ser em bytes pq vamos armazenae na chamada das requests vinculado as informacoes da acao da Tesla Off-Chain atrelando de forma On-chain
    mapping(bytes32 requestId => dTslaRequest request) private s_requestIdToRequest;
    mapping(address user => uint256 amountAvailableForWithdrawal) private s_userToWithdrawalAmount;

    //// endereco do contrato da TSLA/USD no data Feed
    address public i_tslaUsdFeed;
    address public i_usdcUsdFeed;
    address public i_redemptionCoin;

    // This hard-coded value isn't great engineering. Please check with your brokerage
    // and update accordingly
    // For example, for Alpaca: https://alpaca.markets/support/crypto-wallet-faq
    uint256 public constant MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT = 100e18;

    uint256 public constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 public constant PORTFOLIO_PRECISION = 1e18;
    uint256 public constant COLLATERAL_RATIO = 200; // 200% collateral ratio
    uint256 public constant COLLATERAL_PRECISION = 100;

    uint256 private constant TARGET_DECIMALS = 18;
    uint256 private constant PRECISION = 1e18;
    uint256 private immutable i_redemptionCoinDecimals;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Response(bytes32 indexed requestId, uint256 character, bytes response, bytes err);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor(
        uint64 subId,
        string memory mintSource,
        string memory redeemSource,
        address functionsRouter,
        bytes32 donId,
        address tslaPriceFeed,///nao tem na rede da sepolia e usou o Link como simulacao.
        //porem, vamos usar o 0x5c13b249846540F81c093Bc342b5d963a7518145 que o ETF IBTA
        ///https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1&search=IBTA#sepolia-testnet
        address usdcPriceFeed,
        address redemptionCoin,
        uint64 secretVersion,
        uint8 secretSlot
    )
        FunctionsClient(functionsRouter)
    {
        _disableInitializers();
        //API below
        s_mintSource = mintSource;
        s_redeemSource = redeemSource;
        //Chainlink Function below
        s_functionsRouter = functionsRouter;

        //Descentralized Oracle Network - cada rede tem a sua
        s_donID = donId;
        ///chainlink PriceFeed
        i_tslaUsdFeed = tslaPriceFeed;
        i_usdcUsdFeed = usdcPriceFeed;
        ///o subId e a subscricao da chainlink feita no site deles q precisa ser abastecida com tokens LINK
        i_subId = subId;
        ///
        i_redemptionCoin = redemptionCoin;
        i_redemptionCoinDecimals = ERC20Upgradeable(redemptionCoin).decimals();

        s_secretVersion = secretVersion;
        s_secretSlot = secretSlot;
    }

    /**
     * @notice Initializes this smart contract.
     * @dev This function is required so that the upgradeable proxy is functional.
     * @dev Callable only once.
     * @dev Uses `initializer` from OpenZeppelin's {OwnableUpgradeable}.
     * @param initialOwner: owner of this smart contract.
     * @param name_: ERC-20 token name.
     * @param symbol_: ERC-20 token symbol.
     */
    function initialize(
        address initialOwner,
        string memory name_,
        string memory symbol_
    ) external initializer {
        
        __ERC20_init(name_, symbol_);
        __Security_init(initialOwner);
    }


    function setSecretVersion(uint64 secretVersion) external onlyOwner {
        s_secretVersion = secretVersion;
    }

    function setSecretSlot(uint8 secretSlot) external onlyOwner {
        s_secretSlot = secretSlot;
    }

    /**
     * @notice Sends an HTTP request for character information
     * @dev If you pass 0, that will act just as a way to get an updated portfolio balance
     * @return requestId The ID of the request
     */
    function sendMintRequest(uint256 amountOfTokensToMint)
        external
        onlyOwner
        whenNotPaused
        returns (bytes32 requestId)
    {
        // they want to mint $100 and the portfolio has $200 - then that's cool
        //nessa parte usamos o DataFeed para pegar os valores em dollar
        if (_getCollateralRatioAdjustedTotalBalance(amountOfTokensToMint) > s_portfolioBalance) {
            revert dTSLA__NotEnoughCollateral();
        }
         //Assim ao tentar mandar uma requisicao de mint ele faz o request da API e verifica quanto de TSLA ele tem na conta
         //fazendo essa 
        FunctionsRequest.Request memory req; ///@dev se formos na library FunctionsRequest.sol conseguimos todos os parametros de request (struct) e linguagem disponivel  
        req.initializeRequestForInlineJavaScript(s_mintSource); // Initialize the request with JS code
        ///Podemos usar keys secretas da API com o servico de criptografia seguro da Chainlink
        req.addDONHostedSecrets(s_secretSlot, s_secretVersion);

        // Send the request and store the request ID
        /// CBOR e uma forma de de utilizar dados binarios em que e usado pela chainlink para entender a requisicao
        //Caso queira entender: https://cbor.io/
        //Assim ele armazena esse valor no contrato e podendo executar o _mintFulFillRequest inserindo o requestID retornado por essa funcao
        requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, s_donID);
        s_requestIdToRequest[requestId] = dTslaRequest(amountOfTokensToMint, msg.sender, MintOrRedeem.mint);
        return requestId; //nele tem todas as informacoes off-chain do valor da acao de TSLA em USD
    }

    /*
     * @notice user sends a Chainlink Functions request to sell TSLA for redemptionCoin
     * @notice this will put the redemptionCoin in a withdrawl queue that the user must call to redeem
     * 
     * @dev Burn dTSLA
     * @dev Sell TSLA on brokerage
     * @dev Buy USDC on brokerage
     * @dev Send USDC to this contract for user to withdraw
     * 
     * @param amountdTsla - the amount of dTSLA to redeem
     */
    function sendRedeemRequest(uint256 amountdTsla) external whenNotPaused returns (bytes32 requestId) {
        // Should be able to just always redeem?
        // @audit potential exploit here, where if a user can redeem more than the collateral amount
        // Checks
        // Remember, this has 18 decimals
        uint256 amountTslaInUsdc = getUsdcValueOfUsd(getUsdValueOfTsla(amountdTsla));
        if (amountTslaInUsdc < MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT) {
            revert dTSLA__BelowMinimumRedemption();
        }

        // Internal Effects
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_redeemSource); // Initialize the request with JS code
        string[] memory args = new string[](2);
        args[0] = amountdTsla.toString();
        // The transaction will fail if it's outside of 2% slippage
        // This could be a future improvement to make the slippage a parameter by someone
        args[1] = amountTslaInUsdc.toString();
        req.setArgs(args);

        // Send the request and store the request ID
        // We are assuming requestId is unique
        requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, s_donID);
        s_requestIdToRequest[requestId] = dTslaRequest(amountdTsla, msg.sender, MintOrRedeem.redeem);

        // External Interactions
        _burn(msg.sender, amountdTsla);
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     */ // vai verificar pela Chainlink se temos LINK para ser executado essa funcao que nela tem o _mint e _redeem dos tokens
     ////@dev OBS. isso esta bem parecido com o Chainlink Automate.
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory /* err */
    )
        internal
        override
        whenNotPaused
    {
        if (s_requestIdToRequest[requestId].mintOrRedeem == MintOrRedeem.mint) {
            _mintFulFillRequest(requestId, response);
        } else {
            _redeemFulFillRequest(requestId, response);
        }
    }

    function withdraw() external whenNotPaused {
        uint256 amountToWithdraw = s_userToWithdrawalAmount[msg.sender];
        s_userToWithdrawalAmount[msg.sender] = 0;
        // Send the user their USDC
        bool succ = ERC20Upgradeable(i_redemptionCoin).transfer(msg.sender, amountToWithdraw);
        if (!succ) {
            revert dTSLA__RedemptionFailed();
        }
    }


    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    function _mintFulFillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 amountOfTokensToMint = s_requestIdToRequest[requestId].amountOfToken;
        s_portfolioBalance = uint256(bytes32(response)); ///@dev o response e referente a API e verificando se tem o saldo na plataforma referente as acoes q quer tokenizar

        if (_getCollateralRatioAdjustedTotalBalance(amountOfTokensToMint) > s_portfolioBalance) {
            revert dTSLA__NotEnoughCollateral();
        }

        if (amountOfTokensToMint != 0) {
            _mint(s_requestIdToRequest[requestId].requester, amountOfTokensToMint);
        }
        // Do we need to return anything?
    }

    /*
     * @notice the callback for the redeem request
     * At this point, USDC should be in this contract, and we need to update the user
     * That they can now withdraw their USDC
     * 
     * @param requestId - the requestId that was fulfilled
     * @param response - the response from the request, it'll be the amount of USDC that was sent
     */
    function _redeemFulFillRequest(bytes32 requestId, bytes memory response) internal {
        // This is going to have redemptioncoindecimals decimals
        uint256 usdcAmount = uint256(bytes32(response));
        uint256 usdcAmountWad;
        if (i_redemptionCoinDecimals < 18) {
            usdcAmountWad = usdcAmount * (10 ** (18 - i_redemptionCoinDecimals));
        }
        if (usdcAmount == 0) {
            // revert dTSLA__RedemptionFailed();
            // Redemption failed, we need to give them a refund of dTSLA
            // This is a potential exploit, look at this line carefully!!
            uint256 amountOfdTSLABurned = s_requestIdToRequest[requestId].amountOfToken;
            _mint(s_requestIdToRequest[requestId].requester, amountOfdTSLABurned);
            return;
        }

        s_userToWithdrawalAmount[s_requestIdToRequest[requestId].requester] += usdcAmount;
    }

    function _getCollateralRatioAdjustedTotalBalance(uint256 amountOfTokensToMint) internal view returns (uint256) {
        uint256 calculatedNewTotalValue = getCalculatedNewTotalValue(amountOfTokensToMint);
        return (calculatedNewTotalValue * COLLATERAL_RATIO) / COLLATERAL_PRECISION;
    }

    /// -----------------------------------------------------------------------
    /// State-change internal/private functions
    /// -----------------------------------------------------------------------

    /// @inheritdoc UUPSUpgradeable
    /// @dev Only contract owner or backend can call this function.
    /// @dev Won't work if contract is paused.
    function _authorizeUpgrade(address /*newImplementation*/) internal view virtual override(UUPSUpgradeable) {
        __onlyOwner();
        __whenNotPaused();
    }


    /*//////////////////////////////////////////////////////////////
                             VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getPortfolioBalance() public view returns (uint256) {
        return s_portfolioBalance;
    }

    // TSLA USD has 8 decimal places, so we add an additional 10 decimal places
    function getTslaPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_tslaUsdFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdcPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_usdcUsdFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdValueOfTsla(uint256 tslaAmount) public view returns (uint256) {
        return (tslaAmount * getTslaPrice()) / PRECISION;
    }

    /* 
     * Pass the USD amount with 18 decimals (WAD)
     * Return the redemptionCoin amount with 18 decimals (WAD)
     * 
     * @param usdAmount - the amount of USD to convert to USDC in WAD
     * @return the amount of redemptionCoin with 18 decimals (WAD)
     */
    function getUsdcValueOfUsd(uint256 usdAmount) public view returns (uint256) {
        return (usdAmount * getUsdcPrice()) / PRECISION;
    }

    function getTotalUsdValue() public view returns (uint256) {
        return (totalSupply() * getTslaPrice()) / PRECISION;
    }

    function getCalculatedNewTotalValue(uint256 addedNumberOfTsla) public view returns (uint256) {
        // Calculate: 10 dtsla tokens + 5 dtsla tokens = 15 dtsla tokens * tsla price(100) = 1500
        //precision is number of decimal token
        return ((totalSupply() + addedNumberOfTsla) * getTslaPrice()) / PRECISION;
    }

    function getRequest(bytes32 requestId) public view returns (dTslaRequest memory) {
        return s_requestIdToRequest[requestId];
    }

    function getWithdrawalAmount(address user) public view returns (uint256) {
        return s_userToWithdrawalAmount[user];
    }
}



