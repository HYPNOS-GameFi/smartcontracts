
/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

////import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*
 * @title OracleLib
 * @author Patrick Collins
 * @notice This library is used to check the Chainlink Oracle for stale data.
 * If a price is stale, functions will revert, and render the DSCEngine unusable - this is by design.
 * We want the DSCEngine to freeze if prices become stale.
 *
 * So if the Chainlink network explodes and you have a lot of money locked in the protocol... too bad.
 */
library OracleLib {
    error OracleLib__StalePrice();

    // @audit we know that this timeout is not acceptable for most chains
    uint256 private constant TIMEOUT = 3 hours;

    // @audit we are not checking any sequencers here
    // @audit we are also not checking for a min or max price
    function staleCheckLatestRoundData(AggregatorV3Interface chainlinkFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            chainlinkFeed.latestRoundData();

        if (updatedAt == 0 || answeredInRound < roundId) {
            revert OracleLib__StalePrice();
        }
        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert OracleLib__StalePrice();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    function getTimeout(AggregatorV3Interface /* chainlinkFeed */ ) public pure returns (uint256) {
        return TIMEOUT;
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

//  ██████╗ ███╗   ███╗███╗   ██╗███████╗███████╗
// ██╔═══██╗████╗ ████║████╗  ██║██╔════╝██╔════╝
// ██║   ██║██╔████╔██║██╔██╗ ██║█████╗  ███████╗
// ██║   ██║██║╚██╔╝██║██║╚██╗██║██╔══╝  ╚════██║
// ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║███████╗███████║
//  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝

/// -----------------------------------------------------------------------
/// ////Imports
/// -----------------------------------------------------------------------

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
////import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
////import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// -----------------------------------------------------------------------
/// Contract
/// -----------------------------------------------------------------------

/**
 * @title Main security features for an upgradeable smart contract.
 * @author Omnes Tech (Eduardo W. da Cunha - @EWCunha)
 * @notice This contract implements the main security features for an upgradeable smart contract.
 * It uses the upgradeable versions of OpenZeppelin's {ReentrancyGuard}, {Pausable}, and {Ownable} smart contracts.
 * @dev This contract implements a simple permission feature, using only a mapping from address to boolean that
 * specifies if a caller is allowed (true) to call a function or not (false). To implement a more specific/complex
 * permission system, please, create another smart contract and inherit this one.
 */
contract SecurityUpgradeable is ReentrancyGuardUpgradeable, PausableUpgradeable, OwnableUpgradeable {
    /// -----------------------------------------------------------------------
    /// Custom errors
    /// -----------------------------------------------------------------------

    /**
     * @dev Error when the caller is not allowed to call function.
     * @param addr: address from the caller.
     */
    error SecurityUpgradeable__NotAllowed(address addr);

    /**
     * @dev Error when the caller is not allowed to call function or is not the owner.
     * @param addr: address from the caller.
     */
    error SecurityUpgradeable__NotAllowedOrOwner(address addr);

    /// @dev Error when the given address is invalid for setting up owner.
    error SecurityUpgradeable__InvalidOwner();

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /* solhint-disable var-name-mixedcase */

    /// @dev Mapping from caller address to permission boolean.
    mapping(address caller => bool permission) internal s_permissions;

    uint256[50] private __gap;
    /* solhint-enable var-name-mixedcase */

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /**
     * @dev Event for when a permission is set for a given address.
     * @param caller: function caller address;
     * @param to: address to which the permission is set;
     * @param permission: boolean that specifices if address (to) is allowed (true) or not (false).
     */
    event PermissionSet(address indexed caller, address indexed to, bool permission);

    /// -----------------------------------------------------------------------
    /// Modifiers (or internal functions as modifiers)
    /// -----------------------------------------------------------------------

    /* solhint-disable no-empty-blocks */

    /**
     * @dev Function that uses onlyOwner modifier from OpenZeppelin's
     * {OwnableUpgradeable} smart contract. Done this way to reduce smart contract size.
     */
    function __onlyOwner() internal view virtual onlyOwner {}

    /**
     * @dev Function that uses whenNotPaused modifier from OpenZeppelin's
     * {PausableUpgradeable} smart contract. Done this way to reduce smart contract size.
     */
    function __whenNotPaused() internal view virtual whenNotPaused {}

    /* solhint-enable no-empty-blocks */

    /// -----------------------------------------------------------------------
    /// Initializer/constructor
    /// -----------------------------------------------------------------------

    /* solhint-disable func-name-mixedcase */
    /**
     * @dev Initializer function for this contract.
     * @dev Uses onlyInitializing modifier from OpenZeppelin's {Initializer} smart contract,
     * which is used in all upgradeable versions of ReentrancyGuard, Pausable, and Ownable
     * inherited by this contract.
     * @dev Reverts if given address is address(0).
     * @param owner_: smart contract owner address.
     */
    function __Security_init(address owner_) internal onlyInitializing {
        if (owner_ == address(0)) revert SecurityUpgradeable__InvalidOwner();

        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init(owner_);
    }

    /* solhint-enable func-name-mixedcase */

    /// -----------------------------------------------------------------------
    /// State-change public/external functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Sets permission for given address.
     * @dev Uses _setPermission internal function to set permission. Returns true if function call
     * was successful.
     * @param addr: address to set permission;
     * @param permission: boolean that indicates permission. True if allowed, false otherwise.
     */
    function setPermission(address addr, bool permission) external virtual nonReentrant {
        _checkPermissionOrOwner(msg.sender);
        _setPermission(addr, permission);

        emit PermissionSet(msg.sender, addr, permission);
    }

    /**
     * @notice Pauses this smart contract.
     * @dev This function will only be effective in functions that call __whenNotPaused internal function or
     * has whenNotPaused modifier.
     */
    function pause() external virtual nonReentrant {
        _checkPermissionOrOwner(msg.sender);

        _pause();
    }

    /**
     * @notice Unpauses this smart contract.
     * @dev This function will only be effective in functions that call __whenNotPaused internal function or
     * has whenNotPaused modifier.
     */
    function unpause() external virtual nonReentrant {
        _checkPermissionOrOwner(msg.sender);

        _unpause();
    }

    /// -----------------------------------------------------------------------
    /// State-change internal/private functions
    /// -----------------------------------------------------------------------

    /**
     * @dev Internal function that sets permission for given address.
     * @param addr: address to set permission;
     * @param permission: boolean that indicates permission. True if allowed, false otherwise.
     */
    function _setPermission(address addr, bool permission) internal {
        s_permissions[addr] = permission;
    }

    /// -----------------------------------------------------------------------
    /// View internal/private functions
    /// -----------------------------------------------------------------------

    /**
     * @dev Internal function to access permssion for a given address.
     * @param addr: address to check permission.
     * @return boolean that indicates permission. True if allowed, false otherwise.
     */
    function _getPermission(address addr) internal view returns (bool) {
        return s_permissions[addr];
    }

    /**
     * @dev Internal function that checks permissions for a given address. If address is not allowed, it reverts.
     * @param addr: address to check permission.
     */
    function _checkPermission(address addr) internal view {
        if (!_getPermission(addr)) revert SecurityUpgradeable__NotAllowed(addr);
    }

    /**
     * @dev Internal function that checks permissions for a given address. If address is not allowed, it reverts.
     * Unlike _checkPermission function, this function also checks if given address is the owner of the contract and
     * it also reverts if address is not owner.
     * @param addr: address to check permission.
     */
    function _checkPermissionOrOwner(address addr) internal view {
        if (!_getPermission(addr) && addr != owner()) revert SecurityUpgradeable__NotAllowedOrOwner(addr);
    }

    /// -----------------------------------------------------------------------
    /// View public/external functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Reads the permission value for given address.
     * @param addr: address to check permission.
     * @return boolean that indicates permission. True if allowed, false otherwise.
     */
    function getPermission(address addr) external view returns (bool) {
        return _getPermission(addr);
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT

// @dev This contract has been adapted to fit with dappTools
pragma solidity ^0.8.0;

////import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ERC677Receiver {
    function onTokenTransfer(address _sender, uint256 _value, bytes memory _data) external;
}

contract MockLinkToken is ERC20 {
    uint256 constant INITIAL_SUPPLY = 1_000_000_000_000_000_000_000_000;
    uint8 constant DECIMALS = 18;

    constructor() ERC20("LinkToken", "LINK") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);

    /**
     * @dev transfer token to a contract address with additional data if the recipient is a contact.
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     * @param _data The extra data to be passed to the receiving contract.
     */
    function transferAndCall(address _to, uint256 _value, bytes memory _data) public virtual returns (bool success) {
        super.transfer(_to, _value);
        // emit Transfer(msg.sender, _to, _value, _data);
        emit Transfer(msg.sender, _to, _value, _data);
        if (isContract(_to)) {
            contractFallback(_to, _value, _data);
        }
        return true;
    }

    // PRIVATE

    function contractFallback(address _to, uint256 _value, bytes memory _data) private {
        ERC677Receiver receiver = ERC677Receiver(_to);
        receiver.onTokenTransfer(msg.sender, _value, _data);
    }

    function isContract(address _addr) private view returns (bool hasCode) {
        uint256 length;
        assembly {
            length := extcodesize(_addr)
        }
        return length > 0;
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

////import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("MockUSDC", "MUSDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

////import {
    IFunctionsRouter,
    FunctionsResponse
} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/interfaces/IFunctionsRouter.sol";
////import {IFunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/interfaces/IFunctionsClient.sol";

contract MockFunctionsRouter is IFunctionsRouter {
    function handleOracleFulfillment(address who, bytes32 requestId, bytes memory response, bytes memory err)
        external
    {
        IFunctionsClient(who).handleOracleFulfillment(requestId, response, err);
    }

    /// @notice The identifier of the route to retrieve the address of the access control contract
    /// The access control contract controls which accounts can manage subscriptions
    /// @return id - bytes32 id that can be passed to the "getContractById" of the Router
    function getAllowListId() external pure returns (bytes32) {
        return bytes32(0);
    }

    /// @notice Set the identifier of the route to retrieve the address of the access control contract
    /// The access control contract controls which accounts can manage subscriptions
    function setAllowListId(bytes32 allowListId) external {}

    /// @notice Get the flat fee (in Juels of LINK) that will be paid to the Router owner for operation of the network
    /// @return adminFee
    function getAdminFee() external pure returns (uint72 adminFee) {
        return uint72(0);
    }

    /// @notice Sends a request using the provided subscriptionId
    /// @param subscriptionId - A unique subscription ID allocated by billing system,
    /// a client can make requests from different contracts referencing the same subscription
    /// @param data - CBOR encoded Chainlink Functions request data, use FunctionsClient API to encode a request
    /// @param dataVersion - Gas limit for the fulfillment callback
    /// @param callbackGasLimit - Gas limit for the fulfillment callback
    /// @param donId - An identifier used to determine which route to send the request along
    /// @return requestId - A unique request identifier
    function sendRequest(
        uint64 subscriptionId,
        bytes calldata data,
        uint16 dataVersion,
        uint32 callbackGasLimit,
        bytes32 donId
    ) external pure returns (bytes32) {
        return bytes32(keccak256(abi.encodePacked(subscriptionId, data, dataVersion, callbackGasLimit, donId)));
    }

    function sendRequestToProposed(
        uint64, /*subscriptionId*/
        bytes calldata, /*data*/
        uint16, /*dataVersion*/
        uint32, /*callbackGasLimit*/
        bytes32 /*donId*/
    ) external pure returns (bytes32) {
        return bytes32(0);
    }

    function fulfill(
        bytes memory, /*response*/
        bytes memory, /*err*/
        uint96, /*juelsPerGas*/
        uint96, /*costWithoutFulfillment*/
        address, /*transmitter*/
        FunctionsResponse.Commitment memory /*commitment*/
    ) external pure returns (FunctionsResponse.FulfillResult, uint96) {
        return (FunctionsResponse.FulfillResult.FULFILLED, uint96(0));
    }

    /// @notice Validate requested gas limit is below the subscription max.
    /// @param subscriptionId subscription ID
    /// @param callbackGasLimit desired callback gas limit
    function isValidCallbackGasLimit(uint64 subscriptionId, uint32 callbackGasLimit) external view {}

    /// @notice Get the current contract given an ID
    /// @return contract The current contract address
    function getContractById(bytes32 /*id*/ ) external pure returns (address) {
        return address(0);
    }

    /// @notice Get the proposed next contract given an ID
    /// @return contract The current or proposed contract address
    function getProposedContractById(bytes32 /*id*/ ) external pure returns (address) {
        return address(0);
    }

    /// @notice Return the latest proprosal set
    /// @return ids The identifiers of the contracts to update
    /// @return to The addresses of the contracts that will be updated to
    function getProposedContractSet() external pure returns (bytes32[] memory, address[] memory) {
        return (new bytes32[](0), new address[](0));
    }

    /// @notice Proposes one or more updates to the contract routes
    /// @dev Only callable by owner
    function proposeContractsUpdate(bytes32[] memory proposalSetIds, address[] memory proposalSetAddresses) external {}

    /// @notice Updates the current contract routes to the proposed contracts
    /// @dev Only callable by owner
    function updateContracts() external {}

    /// @dev Puts the system into an emergency stopped state.
    /// @dev Only callable by owner
    function pause() external {}

    /// @dev Takes the system out of an emergency stopped state.
    /// @dev Only callable by owner
    function unpause() external {}
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MockV3Aggregator
 * @notice Based on the FluxAggregator contract
 * @notice Use this contract when you need to test
 * other contract's ability to read data from an
 * aggregator contract, but how the aggregator got
 * its answer is ////important
 */
contract MockV3Aggregator {
    uint256 public constant version = 0;

    uint8 public decimals;
    int256 public latestAnswer;
    uint256 public latestTimestamp;
    uint256 public latestRound;

    mapping(uint256 => int256) public getAnswer;
    mapping(uint256 => uint256) public getTimestamp;
    mapping(uint256 => uint256) private getStartedAt;

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals = _decimals;
        updateAnswer(_initialAnswer);
    }

    function updateAnswer(int256 _answer) public {
        latestAnswer = _answer;
        latestTimestamp = block.timestamp;
        latestRound++;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = block.timestamp;
        getStartedAt[latestRound] = block.timestamp;
    }

    function updateRoundData(uint80 _roundId, int256 _answer, uint256 _timestamp, uint256 _startedAt) public {
        latestRound = _roundId;
        latestAnswer = _answer;
        latestTimestamp = _timestamp;
        getAnswer[latestRound] = _answer;
        getTimestamp[latestRound] = _timestamp;
        getStartedAt[latestRound] = _startedAt;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, getAnswer[_roundId], getStartedAt[_roundId], getTimestamp[_roundId], _roundId);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            uint80(latestRound),
            getAnswer[latestRound],
            getStartedAt[latestRound],
            getTimestamp[latestRound],
            uint80(latestRound)
        );
    }

    function description() external pure returns (string memory) {
        return "v0.6/tests/MockV3Aggregator.sol";
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
/*solhint-disable compiler-version */
pragma solidity ^0.8.20;

/// -----------------------------------------------------------------------
/// ////Imports
/// -----------------------------------------------------------------------

//  ==========  External imports  ==========

import {ERC20Upgradeable, IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
////import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

//  ==========  Internal ////imports  ==========

import {SecurityUpgradeable} from "./security/SecurityUpgradeable.sol";

/// -----------------------------------------------------------------------
/// Contract
/// -----------------------------------------------------------------------

contract betUSD is ERC20Upgradeable, SecurityUpgradeable, UUPSUpgradeable {
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

    /// @dev Error for when an invalid argument is given.
    error InvalidArgument();

    /// @dev Error for when given amount to withdraw is zero.
    error AmountIsZero();

    /**
     * @dev Error for when this contract does not have sufficient balance.
     * @param balance: current balance.
     */
    error InsuficientBalance(uint256 balance);

    /// -----------------------------------------------------------------------
    /// State variables
    /// -----------------------------------------------------------------------

    /* solhint-disable var-name-mixedcase */
    uint256 private s_maxSupply;
    mapping(address user => uint256 amount) private s_numberMinted;

    uint256[50] private __gap;
    /* solhint-enable var-name-mixedcase */

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /**
     * @dev Emitted when a new max amount per address is set.
     * @param caller: function caller address. Indexed.
     * @param newMaxPerAddress: uint256 value for new max amount per address.
     */
    event ChangedMaxAddress(address indexed caller, uint256 newMaxPerAddress);

    /**
     * @dev Emitted when a new max supply is set.
     * @param caller: function caller address. Indexed.
     * @param newMaxSupply: uint256 value for new max supply.
     */
    event ChangedMaxSupply(address indexed caller, uint256 newMaxSupply);

    /// -----------------------------------------------------------------------
    /// Modifiers (or internal functions as modifiers)
    /// -----------------------------------------------------------------------

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
     * @dev Uses `initializer` from OpenZeppelin's {OwnableUpgradeable}.
     * @param initialOwner: owner of this smart contract
     */
    function initialize(address initialOwner) external initializer {
        __ERC20_init("USDC", "USDC");
        __Security_init(initialOwner);
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
    function mint(uint256 amount) public virtual {
        mint(msg.sender, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
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
        __whenNotPaused();

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
        __onlyOwner();
        __whenNotPaused();

        _mint(to, amount);
    }

    /**
     * @notice Mints given amount of tokens to the given address
     * @dev Checks if caller is either contract owner or backend.
     * @dev Won't work if contract is paused.
     * @dev Added {nonReentrant} modifier from {ReentrancyGuardUpgradeable} smart contract.
     * @param tos: array of addresses to which tokens will be minted.
     * @param amounts: array of amounts of tokens to mint.
     */
    function superMintBatch(address[] calldata tos, uint256[] calldata amounts) external virtual nonReentrant {
        __onlyOwner();
        __whenNotPaused();
        if (tos.length != amounts.length) revert InvalidArgument();

        for (uint256 i = 0; i < tos.length;) {
            _mint(tos[i], amounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    //  ==========  Withdraw function  ==========

    /**
     * @notice Withdraws tokens that eventually were sent to this smart contract.
     * @notice The amount must be greater than zero and not greater than this contract balance.
     * @dev Only the contract owner or backend are allowed to withdraw.
     * @dev Won't work if contract is paused.
     * @dev Added {nonReentrant} modifier from {ReentrancyGuardUpgradeable} smart contract.
     * @param to: address to which the tokens will be transferred.
     * @param amount: amount of tokens to transfer.
     * @param tokenContract_: address of the ERC-20 token smart contract.
     */
    function withdrawTokens(address to, uint256 amount, address tokenContract_) external virtual nonReentrant {
        __onlyOwner();
        __whenNotPaused();

        IERC20 tokenContract = IERC20(tokenContract_);

        if (amount == 0) revert AmountIsZero();
        if (tokenContract.balanceOf(address(this)) < amount) {
            revert InsuficientBalance(tokenContract.balanceOf(address(this)));
        }

        tokenContract.transfer(to, amount);
    }

    //  ==========  Setter functions  ==========

    /// -----------------------------------------------------------------------
    /// State-change internal/private functions
    /// -----------------------------------------------------------------------

    /// @inheritdoc UUPSUpgradeable
    /// @dev Only contract owner or backend can call this function.
    /// @dev Won't work if contract is paused.
    function _authorizeUpgrade(address /*newImplementation*/ ) internal view virtual override(UUPSUpgradeable) {
        __onlyOwner();
        __whenNotPaused();
    }

    /// -----------------------------------------------------------------------
    /// View public/external functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Reads s_numberMinted storage mapping.
     * @param user: user address.
     * @return uint256 value for the amount of tokens minted by user address.
     */
    function getNumberMinted(address user) external view virtual returns (uint256) {
        return s_numberMinted[user];
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
/*solhint-disable compiler-version */
pragma solidity ^0.8.20;

/// -----------------------------------------------------------------------
/// ////Imports
/// -----------------------------------------------------------------------

//  ==========  External imports  ==========

import {ERC20Upgradeable, IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
////import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

//  ==========  Internal ////imports  ==========

import {SecurityUpgradeable} from "./security/SecurityUpgradeable.sol";

/// -----------------------------------------------------------------------
/// Contract
/// -----------------------------------------------------------------------

contract hypnosPoint is ERC20Upgradeable, SecurityUpgradeable, UUPSUpgradeable {
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

    /// @dev Error for when an invalid argument is given.
    error InvalidArgument();

    /// @dev Error for when given amount to withdraw is zero.
    error AmountIsZero();

    /**
     * @dev Error for when this contract does not have sufficient balance.
     * @param balance: current balance.
     */
    error InsuficientBalance(uint256 balance);

    /// -----------------------------------------------------------------------
    /// State variables
    /// -----------------------------------------------------------------------

    /* solhint-disable var-name-mixedcase */
    uint256 private s_maxSupply;
    mapping(address user => uint256 amount) private s_numberMinted;

    uint256[50] private __gap;
    /* solhint-enable var-name-mixedcase */

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /**
     * @dev Emitted when a new max amount per address is set.
     * @param caller: function caller address. Indexed.
     * @param newMaxPerAddress: uint256 value for new max amount per address.
     */
    event ChangedMaxAddress(address indexed caller, uint256 newMaxPerAddress);

    /**
     * @dev Emitted when a new max supply is set.
     * @param caller: function caller address. Indexed.
     * @param newMaxSupply: uint256 value for new max supply.
     */
    event ChangedMaxSupply(address indexed caller, uint256 newMaxSupply);

    /// -----------------------------------------------------------------------
    /// Modifiers (or internal functions as modifiers)
    /// -----------------------------------------------------------------------

    /**
     * @dev Checks if minting is possible with the given arguments.
     * @param to: address to which the token will be minted.
     * @param amount: amount of tokens to mint.
     */
    function _checkMint(address to, uint256 amount) internal virtual {
        uint256 supply = amount + totalSupply();
        if (supply > s_maxSupply) revert MaxSupplyReached(supply);
        unchecked {
            s_numberMinted[to] += amount;
        }
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
     * @dev Uses `initializer` from OpenZeppelin's {OwnableUpgradeable}.
     * @param initialOwner: owner of this smart contract.
     * @param maxSupply: maximum token supply.
     */
    function initialize(address initialOwner, uint256 maxSupply) external initializer {
        __ERC20_init("HypnosPoint", "HPpoint");
        __Security_init(initialOwner);

        s_maxSupply = maxSupply;
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
    function mint(uint256 amount) public virtual {
        mint(msg.sender, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 8;
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
        __whenNotPaused();
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
        __onlyOwner();
        __whenNotPaused();

        _mint(to, amount);
    }

    /**
     * @notice Mints given amount of tokens to the given address
     * @dev Checks if caller is either contract owner or backend.
     * @dev Won't work if contract is paused.
     * @dev Added {nonReentrant} modifier from {ReentrancyGuardUpgradeable} smart contract.
     * @param tos: array of addresses to which tokens will be minted.
     * @param amounts: array of amounts of tokens to mint.
     */
    function superMintBatch(address[] calldata tos, uint256[] calldata amounts) external virtual nonReentrant {
        __onlyOwner();
        __whenNotPaused();
        if (tos.length != amounts.length) revert InvalidArgument();

        for (uint256 i = 0; i < tos.length;) {
            _mint(tos[i], amounts[i]);

            unchecked {
                ++i;
            }
        }
    }

    //  ==========  Withdraw function  ==========

    /**
     * @notice Withdraws tokens that eventually were sent to this smart contract.
     * @notice The amount must be greater than zero and not greater than this contract balance.
     * @dev Only the contract owner or backend are allowed to withdraw.
     * @dev Won't work if contract is paused.
     * @dev Added {nonReentrant} modifier from {ReentrancyGuardUpgradeable} smart contract.
     * @param to: address to which the tokens will be transferred.
     * @param amount: amount of tokens to transfer.
     * @param tokenContract_: address of the ERC-20 token smart contract.
     */
    function withdrawTokens(address to, uint256 amount, address tokenContract_) external virtual nonReentrant {
        __onlyOwner();
        __whenNotPaused();

        IERC20 tokenContract = IERC20(tokenContract_);

        if (amount == 0) revert AmountIsZero();
        if (tokenContract.balanceOf(address(this)) < amount) {
            revert InsuficientBalance(tokenContract.balanceOf(address(this)));
        }

        tokenContract.transfer(to, amount);
    }

    //  ==========  Setter functions  ==========

    /**
     * @notice Sets new token max supply value.
     * @notice Reverts if given max supply value is greater than total supply (total amount of tokens minted).
     * @dev Only the contract owner or backend can call this function.
     * @dev Won't work if contract is paused.
     * @dev Added nonReentrant modifier from {ReentrancyGuardUpgradeable} smart contract.
     * @param maxSupply: new maximum token supply value.
     */
    function setMaxSupply(uint256 maxSupply) external virtual nonReentrant {
        __onlyOwner();
        __whenNotPaused();

        if (maxSupply < totalSupply()) revert InvalidArgument();

        s_maxSupply = maxSupply;

        emit ChangedMaxSupply(msg.sender, maxSupply);
    }

    /// -----------------------------------------------------------------------
    /// State-change internal/private functions
    /// -----------------------------------------------------------------------

    /// @inheritdoc UUPSUpgradeable
    /// @dev Only contract owner or backend can call this function.
    /// @dev Won't work if contract is paused.
    function _authorizeUpgrade(address /*newImplementation*/ ) internal view virtual override(UUPSUpgradeable) {
        __onlyOwner();
        __whenNotPaused();
    }

    /// -----------------------------------------------------------------------
    /// View public/external functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Reads s_maxSupply storage variable.
     * @return uint256 value for maximum supply.
     */
    function getMaxSupply() external view virtual returns (uint256) {
        return s_maxSupply;
    }

    /**
     * @notice Reads s_numberMinted storage mapping.
     * @param user: user address.
     * @return uint256 value for the amount of tokens minted by user address.
     */
    function getNumberMinted(address user) external view virtual returns (uint256) {
        return s_numberMinted[user];
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol

interface IPriceAgregadorV3 {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function updateAnswer(int256 _answer) external;
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

//  ==========  External ////imports  ==========
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
//////import { ConfirmedOwner } from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
////import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
////import {ERC20Upgradeable, IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
////import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
////import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

//  ==========  Internal ////imports  ==========

import {SecurityUpgradeable} from "../security/SecurityUpgradeable.sol";

////import {OracleLib, AggregatorV3Interface} from "./lib/OracleLib.sol";

/**
 * @title dIBTA ETF
 * @notice This is our contract to make requests to the Alpaca API to mint IBTA-backed dIBTA tokens
 * @dev This contract is meant to be for hackthon chainlink only
 */
contract dIBTAETF is FunctionsClient, ERC20Upgradeable, SecurityUpgradeable, UUPSUpgradeable {
    /// -----------------------------------------------------------------------
    /// Libraries
    /// -----------------------------------------------------------------------

    ///necessary for chainlink
    using FunctionsRequest for FunctionsRequest.Request;
    using OracleLib for AggregatorV3Interface;
    using Strings for uint256;

    error dIBTA__NotEnoughCollateral();
    error dIBTA__BelowMinimumRedemption();
    error dIBTA__RedemptionFailed();

    // Custom error type
    error UnexpectedRequestID(bytes32 requestId);

    enum MintOrRedeem {
        mint,
        redeem
    }

    struct dibtaRequest {
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
    string s_mintSource; //toda vez que chamar chainlink functions sera com esse parametro de API
    string s_redeemSource; // ou podemos usar este

    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 s_donID;
    uint256 s_portfolioBalance;
    uint64 s_secretVersion;
    uint8 s_secretSlot;

    //requestID tem q ser em bytes pq vamos armazenae na chamada das requests vinculado as informacoes da acao da Tesla Off-Chain atrelando de forma On-chain
    mapping(bytes32 requestId => dibtaRequest request) private s_requestIdToRequest;
    mapping(address user => uint256 amountAvailableForWithdrawal) private s_userToWithdrawalAmount;

    //// endereco do contrato da ibta/USD no data Feed
    address public i_ibtaUsdFeed;
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
        address ibtaPriceFeed,
        ///nao tem na rede da sepolia e usou o Link como simulacao.
        //porem, vamos usar o 0x5c13b249846540F81c093Bc342b5d963a7518145 que o ETF IBTA
        ///https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1&search=IBTA#sepolia-testnet
        address usdcPriceFeed,
        address redemptionCoin,
        uint64 secretVersion,
        uint8 secretSlot
    ) FunctionsClient(functionsRouter) {
        _disableInitializers();
        //API below
        s_mintSource = mintSource;
        s_redeemSource = redeemSource;
        //Chainlink Function below
        s_functionsRouter = functionsRouter;

        //Descentralized Oracle Network - cada rede tem a sua
        s_donID = donId;
        ///chainlink PriceFeed
        i_ibtaUsdFeed = ibtaPriceFeed;
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
    function initialize(address initialOwner, string memory name_, string memory symbol_) external initializer {
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
            revert dIBTA__NotEnoughCollateral();
        }
        //Assim ao tentar mandar uma requisicao de mint ele faz o request da API e verifica quanto de ibta ele tem na conta
        //fazendo essa
        FunctionsRequest.Request memory req;
        ///@dev se formos na library FunctionsRequest.sol conseguimos todos os parametros de request (struct) e linguagem disponivel
        req.initializeRequestForInlineJavaScript(s_mintSource); // Initialize the request with JS code
        ///Podemos usar keys secretas da API com o servico de criptografia seguro da Chainlink
        req.addDONHostedSecrets(s_secretSlot, s_secretVersion);
        //https://docs.chain.link/chainlink-functions/tutorials/api-use-secrets DOCUMENTACAO
        // Send the request and store the request ID
        /// CBOR e uma forma de de utilizar dados binarios em que e usado pela chainlink para entender a requisicao
        //Caso queira entender: https://cbor.io/
        //Assim ele armazena esse valor no contrato e podendo executar o _mintFulFillRequest inserindo o requestID retornado por essa funcao
        requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, s_donID);
        s_requestIdToRequest[requestId] = dibtaRequest(amountOfTokensToMint, msg.sender, MintOrRedeem.mint);
        return requestId; //nele tem todas as informacoes off-chain do valor da acao de ibta em USD
    }

    /*
     * @notice user sends a Chainlink Functions request to sell ibta for redemptionCoin
     * @notice this will put the redemptionCoin in a withdrawl queue that the user must call to redeem
     * 
     * @dev Burn dibta
     * @dev Sell ibta on brokerage
     * @dev Buy USDC on brokerage
     * @dev Send USDC to this contract for user to withdraw
     * 
     * @param amountdibta - the amount of dibta to redeem
     */
    function sendRedeemRequest(uint256 amountdibta) external whenNotPaused returns (bytes32 requestId) {
        // Should be able to just always redeem?
        // @audit potential exploit here, where if a user can redeem more than the collateral amount
        // Checks
        // Remember, this has 18 decimals
        uint256 amountibtaInUsdc = getUsdcValueOfUsd(getUsdValueOfibta(amountdibta));
        if (amountibtaInUsdc < MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT) {
            revert dIBTA__BelowMinimumRedemption();
        }

        // Internal Effects
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_redeemSource); // Initialize the request with JS code
        string[] memory args = new string[](2);
        args[0] = amountdibta.toString();
        // The transaction will fail if it's outside of 2% slippage
        // This could be a future improvement to make the slippage a parameter by someone
        args[1] = amountibtaInUsdc.toString();
        req.setArgs(args);

        // Send the request and store the request ID
        // We are assuming requestId is unique
        requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, s_donID);
        s_requestIdToRequest[requestId] = dibtaRequest(amountdibta, msg.sender, MintOrRedeem.redeem);

        // External Interactions
        _burn(msg.sender, amountdibta);
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     */
    // vai verificar pela Chainlink se temos LINK para ser executado essa funcao que nela tem o _mint e _redeem dos tokens
    ////@dev OBS. isso esta bem parecido com o Chainlink Automate.
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory /* err */ )
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
            revert dIBTA__RedemptionFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    function _mintFulFillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 amountOfTokensToMint = s_requestIdToRequest[requestId].amountOfToken;
        s_portfolioBalance = uint256(bytes32(response));
        ///@dev o response e referente a API e verificando se tem o saldo na plataforma referente as acoes q quer tokenizar

        if (_getCollateralRatioAdjustedTotalBalance(amountOfTokensToMint) > s_portfolioBalance) {
            revert dIBTA__NotEnoughCollateral();
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
            // revert dibta__RedemptionFailed();
            // Redemption failed, we need to give them a refund of dibta
            // This is a potential exploit, look at this line carefully!!
            uint256 amountOfdibtaBurned = s_requestIdToRequest[requestId].amountOfToken;
            _mint(s_requestIdToRequest[requestId].requester, amountOfdibtaBurned);
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
    function _authorizeUpgrade(address /*newImplementation*/ ) internal view virtual override(UUPSUpgradeable) {
        __onlyOwner();
        __whenNotPaused();
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getPortfolioBalance() public view returns (uint256) {
        return s_portfolioBalance;
    }

    // ibta USD has 8 decimal places, so we add an additional 10 decimal places
    function getibtaPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_ibtaUsdFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdcPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_usdcUsdFeed);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdValueOfibta(uint256 ibtaAmount) public view returns (uint256) {
        return (ibtaAmount * getibtaPrice()) / PRECISION;
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
        return (totalSupply() * getibtaPrice()) / PRECISION;
    }

    function getCalculatedNewTotalValue(uint256 addedNumberOfibta) public view returns (uint256) {
        // Calculate: 10 dibta tokens + 5 dibta tokens = 15 dibta tokens * ibta price(100) = 1500
        //precision is number of decimal token
        return ((totalSupply() + addedNumberOfibta) * getibtaPrice()) / PRECISION;
    }

    function getRequest(bytes32 requestId) public view returns (dibtaRequest memory) {
        return s_requestIdToRequest[requestId];
    }

    function getWithdrawalAmount(address user) public view returns (uint256) {
        return s_userToWithdrawalAmount[user];
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * ////IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.20;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {UpgradeableBeacon} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/ERC1967/ERC1967Utils.sol)

pragma solidity ^0.8.20;

////import {IBeacon} from "../beacon/IBeacon.sol";
////import {Address} from "../../utils/Address.sol";
////import {StorageSlot} from "../../utils/StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 */
library ERC1967Utils {
    // We re-declare ERC-1967 events here because they can't be used directly from IERC1967.
    // This will be fixed in Solidity 0.8.21. At that point we should remove these events.
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev The `implementation` of the proxy is invalid.
     */
    error ERC1967InvalidImplementation(address implementation);

    /**
     * @dev The `admin` of the proxy is invalid.
     */
    error ERC1967InvalidAdmin(address admin);

    /**
     * @dev The `beacon` of the proxy is invalid.
     */
    error ERC1967InvalidBeacon(address beacon);

    /**
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }

    /**
     * @dev Change the beacon and trigger a setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     *
     * CAUTION: Invoking this function has no effect on an instance of {BeaconProxy} since v5, since
     * it uses an immutable beacon without looking at the value of the ERC-1967 beacon slot for
     * efficiency.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.20;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * ////IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev This is a base storage for the  initialization function for upgradeable diamond facet contracts
 **/

library ERC721A__InitializableStorage {
    struct Layout {
        /*
         * Indicates that the contract has been initialized.
         */
        bool _initialized;
        /*
         * Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256('ERC721A.contracts.storage.initializable.facet');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev This is a base contract to aid in writing upgradeable diamond facet contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */

////import {ERC721A__InitializableStorage} from './ERC721A__InitializableStorage.sol';

abstract contract ERC721A__Initializable {
    using ERC721A__InitializableStorage for ERC721A__InitializableStorage.Layout;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializerERC721A() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(
            ERC721A__InitializableStorage.layout()._initializing
                ? _isConstructor()
                : !ERC721A__InitializableStorage.layout()._initialized,
            'ERC721A__Initializable: contract is already initialized'
        );

        bool isTopLevelCall = !ERC721A__InitializableStorage.layout()._initializing;
        if (isTopLevelCall) {
            ERC721A__InitializableStorage.layout()._initializing = true;
            ERC721A__InitializableStorage.layout()._initialized = true;
        }

        _;

        if (isTopLevelCall) {
            ERC721A__InitializableStorage.layout()._initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializingERC721A() {
        require(
            ERC721A__InitializableStorage.layout()._initializing,
            'ERC721A__Initializable: contract is not initializing'
        );
        _;
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        // extcodesize checks the size of the code stored in an address, and
        // address returns the current address. Since the code is still not
        // deployed when running a constructor, any checks on its code size will
        // yield zero, making it an effective way to detect if a contract is
        // under construction or not.
        address self = address(this);
        uint256 cs;
        assembly {
            cs := extcodesize(self)
        }
        return cs == 0;
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library ERC721AStorage {
    // Bypass for a `--via-ir` bug (https://github.com/chiru-labs/ERC721A/pull/364).
    struct TokenApprovalRef {
        address value;
    }

    struct Layout {
        // =============================================================
        //                            STORAGE
        // =============================================================

        // The next token ID to be minted.
        uint256 _currentIndex;
        // The number of tokens burned.
        uint256 _burnCounter;
        // Token name
        string _name;
        // Token symbol
        string _symbol;
        // Mapping from token ID to ownership details
        // An empty struct value does not necessarily mean the token is unowned.
        // See {_packedOwnershipOf} implementation for details.
        //
        // Bits Layout:
        // - [0..159]   `addr`
        // - [160..223] `startTimestamp`
        // - [224]      `burned`
        // - [225]      `nextInitialized`
        // - [232..255] `extraData`
        mapping(uint256 => uint256) _packedOwnerships;
        // Mapping owner address to address data.
        //
        // Bits Layout:
        // - [0..63]    `balance`
        // - [64..127]  `numberMinted`
        // - [128..191] `numberBurned`
        // - [192..255] `aux`
        mapping(address => uint256) _packedAddressData;
        // Mapping from token ID to approved address.
        mapping(uint256 => ERC721AStorage.TokenApprovalRef) _tokenApprovals;
        // Mapping from owner to operator approvals
        mapping(address => mapping(address => bool)) _operatorApprovals;
        // The amount of tokens minted above `_sequentialUpTo()`.
        // We call these spot mints (i.e. non-sequential mints).
        uint256 _spotMinted;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256('ERC721A.contracts.storage.ERC721A');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.3.0
// Creator: Chiru Labs

pragma solidity ^0.8.4;

/**
 * @dev Interface of ERC721A.
 */
interface IERC721AUpgradeable {
    /**
     * The caller must own the token or be an approved operator.
     */
    error ApprovalCallerNotOwnerNorApproved();

    /**
     * The token does not exist.
     */
    error ApprovalQueryForNonexistentToken();

    /**
     * Cannot query the balance for the zero address.
     */
    error BalanceQueryForZeroAddress();

    /**
     * Cannot mint to the zero address.
     */
    error MintToZeroAddress();

    /**
     * The quantity of tokens minted must be more than zero.
     */
    error MintZeroQuantity();

    /**
     * The token does not exist.
     */
    error OwnerQueryForNonexistentToken();

    /**
     * The caller must own the token or be an approved operator.
     */
    error TransferCallerNotOwnerNorApproved();

    /**
     * The token must be owned by `from`.
     */
    error TransferFromIncorrectOwner();

    /**
     * Cannot safely transfer to a contract that does not implement the
     * ERC721Receiver interface.
     */
    error TransferToNonERC721ReceiverImplementer();

    /**
     * Cannot transfer to the zero address.
     */
    error TransferToZeroAddress();

    /**
     * The token does not exist.
     */
    error URIQueryForNonexistentToken();

    /**
     * The `quantity` minted with ERC2309 exceeds the safety limit.
     */
    error MintERC2309QuantityExceedsLimit();

    /**
     * The `extraData` cannot be set on an unintialized ownership slot.
     */
    error OwnershipNotInitializedForExtraData();

    /**
     * `_sequentialUpTo()` must be greater than `_startTokenId()`.
     */
    error SequentialUpToTooSmall();

    /**
     * The `tokenId` of a sequential mint exceeds `_sequentialUpTo()`.
     */
    error SequentialMintExceedsLimit();

    /**
     * Spot minting requires a `tokenId` greater than `_sequentialUpTo()`.
     */
    error SpotMintTokenIdTooSmall();

    /**
     * Cannot mint over a token that already exists.
     */
    error TokenAlreadyExists();

    /**
     * The feature is not compatible with spot mints.
     */
    error NotCompatibleWithSpotMints();

    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct TokenOwnership {
        // The address of the owner.
        address addr;
        // Stores the start time of ownership with minimal overhead for tokenomics.
        uint64 startTimestamp;
        // Whether the token has been burned.
        bool burned;
        // Arbitrary data similar to `startTimestamp` that can be set via {_extraData}.
        uint24 extraData;
    }

    // =============================================================
    //                         TOKEN COUNTERS
    // =============================================================

    /**
     * @dev Returns the total number of tokens in existence.
     * Burned tokens will reduce the count.
     * To get the total number of tokens minted, please see {_totalMinted}.
     */
    function totalSupply() external view returns (uint256);

    // =============================================================
    //                            IERC165
    // =============================================================

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * [EIP section](https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified)
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    // =============================================================
    //                            IERC721
    // =============================================================

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables
     * (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in `owner`'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`,
     * checking first that contract recipients are aware of the ERC721 protocol
     * to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move
     * this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external payable;

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external payable;

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom}
     * whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external payable;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external payable;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    // =============================================================
    //                        IERC721Metadata
    // =============================================================

    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);

    // =============================================================
    //                           IERC2309
    // =============================================================

    /**
     * @dev Emitted when tokens in `fromTokenId` to `toTokenId`
     * (inclusive) is transferred from `from` to `to`, as defined in the
     * [ERC2309](https://eips.ethereum.org/EIPS/eip-2309) standard.
     *
     * See {_mintERC2309} for more details.
     */
    event ConsecutiveTransfer(uint256 indexed fromTokenId, uint256 toTokenId, address indexed from, address indexed to);
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface LinkTokenInterface {
    function allowance(address owner, address spender) external view returns (uint256 remaining);

    function approve(address spender, uint256 value) external returns (bool success);

    function balanceOf(address owner) external view returns (uint256 balance);

    function decimals() external view returns (uint8 decimalPlaces);

    function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

    function increaseApproval(address spender, uint256 subtractedValue) external;

    function name() external view returns (string memory tokenName);

    function symbol() external view returns (string memory tokenSymbol);

    function totalSupply() external view returns (uint256 totalTokensIssued);

    function transfer(address to, uint256 value) external returns (bool success);

    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);

    function transferFrom(address from, address to, uint256 value) external returns (bool success);
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * ////IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.20;

////import {IERC1822Proxiable} from "../../interfaces/draft-IERC1822.sol";
////import {ERC1967Utils} from "../ERC1967/ERC1967Utils.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 */
abstract contract UUPSUpgradeable is IERC1822Proxiable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable __self = address(this);

    /**
     * @dev The version of the upgrade interface of the contract. If this getter is missing, both `upgradeTo(address)`
     * and `upgradeToAndCall(address,bytes)` are present, and `upgradeTo` must be used if no function should be called,
     * while `upgradeToAndCall` will invoke the `receive` function if the second argument is the empty byte string.
     * If the getter returns `"5.0.0"`, only `upgradeToAndCall(address,bytes)` is present, and the second argument must
     * be the empty byte string if no function should be called, making it impossible to invoke the `receive` function
     * during an upgrade.
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * ////IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC1967-compliant implementation pointing to self.
     * See {_onlyProxy}.
     */
    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Performs an implementation upgrade with a security check for UUPS proxies, and additional setup call.
     *
     * As a security check, {proxiableUUID} is invoked in the new implementation, and the return value
     * is expected to be the implementation slot in ERC1967.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
        }
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.3.0
// Creator: Chiru Labs

pragma solidity ^0.8.4;

////import './IERC721AUpgradeable.sol';
////import {ERC721AStorage} from './ERC721AStorage.sol';
////import './ERC721A__Initializable.sol';

/**
 * @dev Interface of ERC721 token receiver.
 */
interface ERC721A__IERC721ReceiverUpgradeable {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/**
 * @title ERC721A
 *
 * @dev Implementation of the [ERC721](https://eips.ethereum.org/EIPS/eip-721)
 * Non-Fungible Token Standard, including the Metadata extension.
 * Optimized for lower gas during batch mints.
 *
 * Token IDs are minted in sequential order (e.g. 0, 1, 2, 3, ...)
 * starting from `_startTokenId()`.
 *
 * The `_sequentialUpTo()` function can be overriden to enable spot mints
 * (i.e. non-consecutive mints) for `tokenId`s greater than `_sequentialUpTo()`.
 *
 * Assumptions:
 *
 * - An owner cannot have more than 2**64 - 1 (max value of uint64) of supply.
 * - The maximum token ID cannot exceed 2**256 - 1 (max value of uint256).
 */
contract ERC721AUpgradeable is ERC721A__Initializable, IERC721AUpgradeable {
    using ERC721AStorage for ERC721AStorage.Layout;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    // Mask of an entry in packed address data.
    uint256 private constant _BITMASK_ADDRESS_DATA_ENTRY = (1 << 64) - 1;

    // The bit position of `numberMinted` in packed address data.
    uint256 private constant _BITPOS_NUMBER_MINTED = 64;

    // The bit position of `numberBurned` in packed address data.
    uint256 private constant _BITPOS_NUMBER_BURNED = 128;

    // The bit position of `aux` in packed address data.
    uint256 private constant _BITPOS_AUX = 192;

    // Mask of all 256 bits in packed address data except the 64 bits for `aux`.
    uint256 private constant _BITMASK_AUX_COMPLEMENT = (1 << 192) - 1;

    // The bit position of `startTimestamp` in packed ownership.
    uint256 private constant _BITPOS_START_TIMESTAMP = 160;

    // The bit mask of the `burned` bit in packed ownership.
    uint256 private constant _BITMASK_BURNED = 1 << 224;

    // The bit position of the `nextInitialized` bit in packed ownership.
    uint256 private constant _BITPOS_NEXT_INITIALIZED = 225;

    // The bit mask of the `nextInitialized` bit in packed ownership.
    uint256 private constant _BITMASK_NEXT_INITIALIZED = 1 << 225;

    // The bit position of `extraData` in packed ownership.
    uint256 private constant _BITPOS_EXTRA_DATA = 232;

    // Mask of all 256 bits in a packed ownership except the 24 bits for `extraData`.
    uint256 private constant _BITMASK_EXTRA_DATA_COMPLEMENT = (1 << 232) - 1;

    // The mask of the lower 160 bits for addresses.
    uint256 private constant _BITMASK_ADDRESS = (1 << 160) - 1;

    // The maximum `quantity` that can be minted with {_mintERC2309}.
    // This limit is to prevent overflows on the address data entries.
    // For a limit of 5000, a total of 3.689e15 calls to {_mintERC2309}
    // is required to cause an overflow, which is unrealistic.
    uint256 private constant _MAX_MINT_ERC2309_QUANTITY_LIMIT = 5000;

    // The `Transfer` event signature is given by:
    // `keccak256(bytes("Transfer(address,address,uint256)"))`.
    bytes32 private constant _TRANSFER_EVENT_SIGNATURE =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    function __ERC721A_init(string memory name_, string memory symbol_) internal onlyInitializingERC721A {
        __ERC721A_init_unchained(name_, symbol_);
    }

    function __ERC721A_init_unchained(string memory name_, string memory symbol_) internal onlyInitializingERC721A {
        ERC721AStorage.layout()._name = name_;
        ERC721AStorage.layout()._symbol = symbol_;
        ERC721AStorage.layout()._currentIndex = _startTokenId();

        if (_sequentialUpTo() < _startTokenId()) _revert(SequentialUpToTooSmall.selector);
    }

    // =============================================================
    //                   TOKEN COUNTING OPERATIONS
    // =============================================================

    /**
     * @dev Returns the starting token ID for sequential mints.
     *
     * Override this function to change the starting token ID for sequential mints.
     *
     * Note: The value returned must never change after any tokens have been minted.
     */
    function _startTokenId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Returns the maximum token ID (inclusive) for sequential mints.
     *
     * Override this function to return a value less than 2**256 - 1,
     * but greater than `_startTokenId()`, to enable spot (non-sequential) mints.
     *
     * Note: The value returned must never change after any tokens have been minted.
     */
    function _sequentialUpTo() internal view virtual returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @dev Returns the next token ID to be minted.
     */
    function _nextTokenId() internal view virtual returns (uint256) {
        return ERC721AStorage.layout()._currentIndex;
    }

    /**
     * @dev Returns the total number of tokens in existence.
     * Burned tokens will reduce the count.
     * To get the total number of tokens minted, please see {_totalMinted}.
     */
    function totalSupply() public view virtual override returns (uint256 result) {
        // Counter underflow is impossible as `_burnCounter` cannot be incremented
        // more than `_currentIndex + _spotMinted - _startTokenId()` times.
        unchecked {
            // With spot minting, the intermediate `result` can be temporarily negative,
            // and the computation must be unchecked.
            result = ERC721AStorage.layout()._currentIndex - ERC721AStorage.layout()._burnCounter - _startTokenId();
            if (_sequentialUpTo() != type(uint256).max) result += ERC721AStorage.layout()._spotMinted;
        }
    }

    /**
     * @dev Returns the total amount of tokens minted in the contract.
     */
    function _totalMinted() internal view virtual returns (uint256 result) {
        // Counter underflow is impossible as `_currentIndex` does not decrement,
        // and it is initialized to `_startTokenId()`.
        unchecked {
            result = ERC721AStorage.layout()._currentIndex - _startTokenId();
            if (_sequentialUpTo() != type(uint256).max) result += ERC721AStorage.layout()._spotMinted;
        }
    }

    /**
     * @dev Returns the total number of tokens burned.
     */
    function _totalBurned() internal view virtual returns (uint256) {
        return ERC721AStorage.layout()._burnCounter;
    }

    /**
     * @dev Returns the total number of tokens that are spot-minted.
     */
    function _totalSpotMinted() internal view virtual returns (uint256) {
        return ERC721AStorage.layout()._spotMinted;
    }

    // =============================================================
    //                    ADDRESS DATA OPERATIONS
    // =============================================================

    /**
     * @dev Returns the number of tokens in `owner`'s account.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        if (owner == address(0)) _revert(BalanceQueryForZeroAddress.selector);
        return ERC721AStorage.layout()._packedAddressData[owner] & _BITMASK_ADDRESS_DATA_ENTRY;
    }

    /**
     * Returns the number of tokens minted by `owner`.
     */
    function _numberMinted(address owner) internal view returns (uint256) {
        return
            (ERC721AStorage.layout()._packedAddressData[owner] >> _BITPOS_NUMBER_MINTED) & _BITMASK_ADDRESS_DATA_ENTRY;
    }

    /**
     * Returns the number of tokens burned by or on behalf of `owner`.
     */
    function _numberBurned(address owner) internal view returns (uint256) {
        return
            (ERC721AStorage.layout()._packedAddressData[owner] >> _BITPOS_NUMBER_BURNED) & _BITMASK_ADDRESS_DATA_ENTRY;
    }

    /**
     * Returns the auxiliary data for `owner`. (e.g. number of whitelist mint slots used).
     */
    function _getAux(address owner) internal view returns (uint64) {
        return uint64(ERC721AStorage.layout()._packedAddressData[owner] >> _BITPOS_AUX);
    }

    /**
     * Sets the auxiliary data for `owner`. (e.g. number of whitelist mint slots used).
     * If there are multiple variables, please pack them into a uint64.
     */
    function _setAux(address owner, uint64 aux) internal virtual {
        uint256 packed = ERC721AStorage.layout()._packedAddressData[owner];
        uint256 auxCasted;
        // Cast `aux` with assembly to avoid redundant masking.
        assembly {
            auxCasted := aux
        }
        packed = (packed & _BITMASK_AUX_COMPLEMENT) | (auxCasted << _BITPOS_AUX);
        ERC721AStorage.layout()._packedAddressData[owner] = packed;
    }

    // =============================================================
    //                            IERC165
    // =============================================================

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * [EIP section](https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified)
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        // The interface IDs are constants representing the first 4 bytes
        // of the XOR of all function selectors in the interface.
        // See: [ERC165](https://eips.ethereum.org/EIPS/eip-165)
        // (e.g. `bytes4(i.functionA.selector ^ i.functionB.selector ^ ...)`)
        return
            interfaceId == 0x01ffc9a7 || // ERC165 interface ID for ERC165.
            interfaceId == 0x80ac58cd || // ERC165 interface ID for ERC721.
            interfaceId == 0x5b5e139f; // ERC165 interface ID for ERC721Metadata.
    }

    // =============================================================
    //                        IERC721Metadata
    // =============================================================

    /**
     * @dev Returns the token collection name.
     */
    function name() public view virtual override returns (string memory) {
        return ERC721AStorage.layout()._name;
    }

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() public view virtual override returns (string memory) {
        return ERC721AStorage.layout()._symbol;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) _revert(URIQueryForNonexistentToken.selector);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, _toString(tokenId))) : '';
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, it can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return '';
    }

    // =============================================================
    //                     OWNERSHIPS OPERATIONS
    // =============================================================

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        return address(uint160(_packedOwnershipOf(tokenId)));
    }

    /**
     * @dev Gas spent here starts off proportional to the maximum mint batch size.
     * It gradually moves to O(1) as tokens get transferred around over time.
     */
    function _ownershipOf(uint256 tokenId) internal view virtual returns (TokenOwnership memory) {
        return _unpackedOwnership(_packedOwnershipOf(tokenId));
    }

    /**
     * @dev Returns the unpacked `TokenOwnership` struct at `index`.
     */
    function _ownershipAt(uint256 index) internal view virtual returns (TokenOwnership memory) {
        return _unpackedOwnership(ERC721AStorage.layout()._packedOwnerships[index]);
    }

    /**
     * @dev Returns whether the ownership slot at `index` is initialized.
     * An uninitialized slot does not necessarily mean that the slot has no owner.
     */
    function _ownershipIsInitialized(uint256 index) internal view virtual returns (bool) {
        return ERC721AStorage.layout()._packedOwnerships[index] != 0;
    }

    /**
     * @dev Initializes the ownership slot minted at `index` for efficiency purposes.
     */
    function _initializeOwnershipAt(uint256 index) internal virtual {
        if (ERC721AStorage.layout()._packedOwnerships[index] == 0) {
            ERC721AStorage.layout()._packedOwnerships[index] = _packedOwnershipOf(index);
        }
    }

    /**
     * @dev Returns the packed ownership data of `tokenId`.
     */
    function _packedOwnershipOf(uint256 tokenId) private view returns (uint256 packed) {
        if (_startTokenId() <= tokenId) {
            packed = ERC721AStorage.layout()._packedOwnerships[tokenId];

            if (tokenId > _sequentialUpTo()) {
                if (_packedOwnershipExists(packed)) return packed;
                _revert(OwnerQueryForNonexistentToken.selector);
            }

            // If the data at the starting slot does not exist, start the scan.
            if (packed == 0) {
                if (tokenId >= ERC721AStorage.layout()._currentIndex) _revert(OwnerQueryForNonexistentToken.selector);
                // Invariant:
                // There will always be an initialized ownership slot
                // (i.e. `ownership.addr != address(0) && ownership.burned == false`)
                // before an unintialized ownership slot
                // (i.e. `ownership.addr == address(0) && ownership.burned == false`)
                // Hence, `tokenId` will not underflow.
                //
                // We can directly compare the packed value.
                // If the address is zero, packed will be zero.
                for (;;) {
                    unchecked {
                        packed = ERC721AStorage.layout()._packedOwnerships[--tokenId];
                    }
                    if (packed == 0) continue;
                    if (packed & _BITMASK_BURNED == 0) return packed;
                    // Otherwise, the token is burned, and we must revert.
                    // This handles the case of batch burned tokens, where only the burned bit
                    // of the starting slot is set, and remaining slots are left uninitialized.
                    _revert(OwnerQueryForNonexistentToken.selector);
                }
            }
            // Otherwise, the data exists and we can skip the scan.
            // This is possible because we have already achieved the target condition.
            // This saves 2143 gas on transfers of initialized tokens.
            // If the token is not burned, return `packed`. Otherwise, revert.
            if (packed & _BITMASK_BURNED == 0) return packed;
        }
        _revert(OwnerQueryForNonexistentToken.selector);
    }

    /**
     * @dev Returns the unpacked `TokenOwnership` struct from `packed`.
     */
    function _unpackedOwnership(uint256 packed) private pure returns (TokenOwnership memory ownership) {
        ownership.addr = address(uint160(packed));
        ownership.startTimestamp = uint64(packed >> _BITPOS_START_TIMESTAMP);
        ownership.burned = packed & _BITMASK_BURNED != 0;
        ownership.extraData = uint24(packed >> _BITPOS_EXTRA_DATA);
    }

    /**
     * @dev Packs ownership data into a single uint256.
     */
    function _packOwnershipData(address owner, uint256 flags) private view returns (uint256 result) {
        assembly {
            // Mask `owner` to the lower 160 bits, in case the upper bits somehow aren't clean.
            owner := and(owner, _BITMASK_ADDRESS)
            // `owner | (block.timestamp << _BITPOS_START_TIMESTAMP) | flags`.
            result := or(owner, or(shl(_BITPOS_START_TIMESTAMP, timestamp()), flags))
        }
    }

    /**
     * @dev Returns the `nextInitialized` flag set if `quantity` equals 1.
     */
    function _nextInitializedFlag(uint256 quantity) private pure returns (uint256 result) {
        // For branchless setting of the `nextInitialized` flag.
        assembly {
            // `(quantity == 1) << _BITPOS_NEXT_INITIALIZED`.
            result := shl(_BITPOS_NEXT_INITIALIZED, eq(quantity, 1))
        }
    }

    // =============================================================
    //                      APPROVAL OPERATIONS
    // =============================================================

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account. See {ERC721A-_approve}.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     */
    function approve(address to, uint256 tokenId) public payable virtual override {
        _approve(to, tokenId, true);
    }

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) _revert(ApprovalQueryForNonexistentToken.selector);

        return ERC721AStorage.layout()._tokenApprovals[tokenId].value;
    }

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        ERC721AStorage.layout()._operatorApprovals[_msgSenderERC721A()][operator] = approved;
        emit ApprovalForAll(_msgSenderERC721A(), operator, approved);
    }

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return ERC721AStorage.layout()._operatorApprovals[owner][operator];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted. See {_mint}.
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool result) {
        if (_startTokenId() <= tokenId) {
            if (tokenId > _sequentialUpTo())
                return _packedOwnershipExists(ERC721AStorage.layout()._packedOwnerships[tokenId]);

            if (tokenId < ERC721AStorage.layout()._currentIndex) {
                uint256 packed;
                while ((packed = ERC721AStorage.layout()._packedOwnerships[tokenId]) == 0) --tokenId;
                result = packed & _BITMASK_BURNED == 0;
            }
        }
    }

    /**
     * @dev Returns whether `packed` represents a token that exists.
     */
    function _packedOwnershipExists(uint256 packed) private pure returns (bool result) {
        assembly {
            // The following is equivalent to `owner != address(0) && burned == false`.
            // Symbolically tested.
            result := gt(and(packed, _BITMASK_ADDRESS), and(packed, _BITMASK_BURNED))
        }
    }

    /**
     * @dev Returns whether `msgSender` is equal to `approvedAddress` or `owner`.
     */
    function _isSenderApprovedOrOwner(
        address approvedAddress,
        address owner,
        address msgSender
    ) private pure returns (bool result) {
        assembly {
            // Mask `owner` to the lower 160 bits, in case the upper bits somehow aren't clean.
            owner := and(owner, _BITMASK_ADDRESS)
            // Mask `msgSender` to the lower 160 bits, in case the upper bits somehow aren't clean.
            msgSender := and(msgSender, _BITMASK_ADDRESS)
            // `msgSender == owner || msgSender == approvedAddress`.
            result := or(eq(msgSender, owner), eq(msgSender, approvedAddress))
        }
    }

    /**
     * @dev Returns the storage slot and value for the approved address of `tokenId`.
     */
    function _getApprovedSlotAndAddress(uint256 tokenId)
        private
        view
        returns (uint256 approvedAddressSlot, address approvedAddress)
    {
        ERC721AStorage.TokenApprovalRef storage tokenApproval = ERC721AStorage.layout()._tokenApprovals[tokenId];
        // The following is equivalent to `approvedAddress = _tokenApprovals[tokenId].value`.
        assembly {
            approvedAddressSlot := tokenApproval.slot
            approvedAddress := sload(approvedAddressSlot)
        }
    }

    // =============================================================
    //                      TRANSFER OPERATIONS
    // =============================================================

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable virtual override {
        uint256 prevOwnershipPacked = _packedOwnershipOf(tokenId);

        // Mask `from` to the lower 160 bits, in case the upper bits somehow aren't clean.
        from = address(uint160(uint256(uint160(from)) & _BITMASK_ADDRESS));

        if (address(uint160(prevOwnershipPacked)) != from) _revert(TransferFromIncorrectOwner.selector);

        (uint256 approvedAddressSlot, address approvedAddress) = _getApprovedSlotAndAddress(tokenId);

        // The nested ifs save around 20+ gas over a compound boolean condition.
        if (!_isSenderApprovedOrOwner(approvedAddress, from, _msgSenderERC721A()))
            if (!isApprovedForAll(from, _msgSenderERC721A())) _revert(TransferCallerNotOwnerNorApproved.selector);

        _beforeTokenTransfers(from, to, tokenId, 1);

        // Clear approvals from the previous owner.
        assembly {
            if approvedAddress {
                // This is equivalent to `delete _tokenApprovals[tokenId]`.
                sstore(approvedAddressSlot, 0)
            }
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as `tokenId` would have to be 2**256.
        unchecked {
            // We can directly increment and decrement the balances.
            --ERC721AStorage.layout()._packedAddressData[from]; // Updates: `balance -= 1`.
            ++ERC721AStorage.layout()._packedAddressData[to]; // Updates: `balance += 1`.

            // Updates:
            // - `address` to the next owner.
            // - `startTimestamp` to the timestamp of transfering.
            // - `burned` to `false`.
            // - `nextInitialized` to `true`.
            ERC721AStorage.layout()._packedOwnerships[tokenId] = _packOwnershipData(
                to,
                _BITMASK_NEXT_INITIALIZED | _nextExtraData(from, to, prevOwnershipPacked)
            );

            // If the next slot may not have been initialized (i.e. `nextInitialized == false`) .
            if (prevOwnershipPacked & _BITMASK_NEXT_INITIALIZED == 0) {
                uint256 nextTokenId = tokenId + 1;
                // If the next slot's address is zero and not burned (i.e. packed value is zero).
                if (ERC721AStorage.layout()._packedOwnerships[nextTokenId] == 0) {
                    // If the next slot is within bounds.
                    if (nextTokenId != ERC721AStorage.layout()._currentIndex) {
                        // Initialize the next slot to maintain correctness for `ownerOf(tokenId + 1)`.
                        ERC721AStorage.layout()._packedOwnerships[nextTokenId] = prevOwnershipPacked;
                    }
                }
            }
        }

        // Mask `to` to the lower 160 bits, in case the upper bits somehow aren't clean.
        uint256 toMasked = uint256(uint160(to)) & _BITMASK_ADDRESS;
        assembly {
            // Emit the `Transfer` event.
            log4(
                0, // Start of data (0, since no data).
                0, // End of data (0, since no data).
                _TRANSFER_EVENT_SIGNATURE, // Signature.
                from, // `from`.
                toMasked, // `to`.
                tokenId // `tokenId`.
            )
        }
        if (toMasked == 0) _revert(TransferToZeroAddress.selector);

        _afterTokenTransfers(from, to, tokenId, 1);
    }

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable virtual override {
        safeTransferFrom(from, to, tokenId, '');
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public payable virtual override {
        transferFrom(from, to, tokenId);
        if (to.code.length != 0)
            if (!_checkContractOnERC721Received(from, to, tokenId, _data)) {
                _revert(TransferToNonERC721ReceiverImplementer.selector);
            }
    }

    /**
     * @dev Hook that is called before a set of serially-ordered token IDs
     * are about to be transferred. This includes minting.
     * And also called before burning one token.
     *
     * `startTokenId` - the first token ID to be transferred.
     * `quantity` - the amount to be transferred.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, `tokenId` will be burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}

    /**
     * @dev Hook that is called after a set of serially-ordered token IDs
     * have been transferred. This includes minting.
     * And also called after one token has been burned.
     *
     * `startTokenId` - the first token ID to be transferred.
     * `quantity` - the amount to be transferred.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` has been
     * transferred to `to`.
     * - When `from` is zero, `tokenId` has been minted for `to`.
     * - When `to` is zero, `tokenId` has been burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}

    /**
     * @dev Private function to invoke {IERC721Receiver-onERC721Received} on a target contract.
     *
     * `from` - Previous owner of the given token ID.
     * `to` - Target address that will receive the token.
     * `tokenId` - Token ID to be transferred.
     * `_data` - Optional data to send along with the call.
     *
     * Returns whether the call correctly returned the expected magic value.
     */
    function _checkContractOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        try
            ERC721A__IERC721ReceiverUpgradeable(to).onERC721Received(_msgSenderERC721A(), from, tokenId, _data)
        returns (bytes4 retval) {
            return retval == ERC721A__IERC721ReceiverUpgradeable(to).onERC721Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                _revert(TransferToNonERC721ReceiverImplementer.selector);
            }
            assembly {
                revert(add(32, reason), mload(reason))
            }
        }
    }

    // =============================================================
    //                        MINT OPERATIONS
    // =============================================================

    /**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event for each mint.
     */
    function _mint(address to, uint256 quantity) internal virtual {
        uint256 startTokenId = ERC721AStorage.layout()._currentIndex;
        if (quantity == 0) _revert(MintZeroQuantity.selector);

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        // Overflows are incredibly unrealistic.
        // `balance` and `numberMinted` have a maximum limit of 2**64.
        // `tokenId` has a maximum limit of 2**256.
        unchecked {
            // Updates:
            // - `address` to the owner.
            // - `startTimestamp` to the timestamp of minting.
            // - `burned` to `false`.
            // - `nextInitialized` to `quantity == 1`.
            ERC721AStorage.layout()._packedOwnerships[startTokenId] = _packOwnershipData(
                to,
                _nextInitializedFlag(quantity) | _nextExtraData(address(0), to, 0)
            );

            // Updates:
            // - `balance += quantity`.
            // - `numberMinted += quantity`.
            //
            // We can directly add to the `balance` and `numberMinted`.
            ERC721AStorage.layout()._packedAddressData[to] += quantity * ((1 << _BITPOS_NUMBER_MINTED) | 1);

            // Mask `to` to the lower 160 bits, in case the upper bits somehow aren't clean.
            uint256 toMasked = uint256(uint160(to)) & _BITMASK_ADDRESS;

            if (toMasked == 0) _revert(MintToZeroAddress.selector);

            uint256 end = startTokenId + quantity;
            uint256 tokenId = startTokenId;

            if (end - 1 > _sequentialUpTo()) _revert(SequentialMintExceedsLimit.selector);

            do {
                assembly {
                    // Emit the `Transfer` event.
                    log4(
                        0, // Start of data (0, since no data).
                        0, // End of data (0, since no data).
                        _TRANSFER_EVENT_SIGNATURE, // Signature.
                        0, // `address(0)`.
                        toMasked, // `to`.
                        tokenId // `tokenId`.
                    )
                }
                // The `!=` check ensures that large values of `quantity`
                // that overflows uint256 will make the loop run out of gas.
            } while (++tokenId != end);

            ERC721AStorage.layout()._currentIndex = end;
        }
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }

    /**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * This function is intended for efficient minting only during contract creation.
     *
     * It emits only one {ConsecutiveTransfer} as defined in
     * [ERC2309](https://eips.ethereum.org/EIPS/eip-2309),
     * instead of a sequence of {Transfer} event(s).
     *
     * Calling this function outside of contract creation WILL make your contract
     * non-compliant with the ERC721 standard.
     * For full ERC721 compliance, substituting ERC721 {Transfer} event(s) with the ERC2309
     * {ConsecutiveTransfer} event is only permissible during contract creation.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {ConsecutiveTransfer} event.
     */
    function _mintERC2309(address to, uint256 quantity) internal virtual {
        uint256 startTokenId = ERC721AStorage.layout()._currentIndex;
        if (to == address(0)) _revert(MintToZeroAddress.selector);
        if (quantity == 0) _revert(MintZeroQuantity.selector);
        if (quantity > _MAX_MINT_ERC2309_QUANTITY_LIMIT) _revert(MintERC2309QuantityExceedsLimit.selector);

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        // Overflows are unrealistic due to the above check for `quantity` to be below the limit.
        unchecked {
            // Updates:
            // - `balance += quantity`.
            // - `numberMinted += quantity`.
            //
            // We can directly add to the `balance` and `numberMinted`.
            ERC721AStorage.layout()._packedAddressData[to] += quantity * ((1 << _BITPOS_NUMBER_MINTED) | 1);

            // Updates:
            // - `address` to the owner.
            // - `startTimestamp` to the timestamp of minting.
            // - `burned` to `false`.
            // - `nextInitialized` to `quantity == 1`.
            ERC721AStorage.layout()._packedOwnerships[startTokenId] = _packOwnershipData(
                to,
                _nextInitializedFlag(quantity) | _nextExtraData(address(0), to, 0)
            );

            if (startTokenId + quantity - 1 > _sequentialUpTo()) _revert(SequentialMintExceedsLimit.selector);

            emit ConsecutiveTransfer(startTokenId, startTokenId + quantity - 1, address(0), to);

            ERC721AStorage.layout()._currentIndex = startTokenId + quantity;
        }
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }

    /**
     * @dev Safely mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called for each safe transfer.
     * - `quantity` must be greater than 0.
     *
     * See {_mint}.
     *
     * Emits a {Transfer} event for each mint.
     */
    function _safeMint(
        address to,
        uint256 quantity,
        bytes memory _data
    ) internal virtual {
        _mint(to, quantity);

        unchecked {
            if (to.code.length != 0) {
                uint256 end = ERC721AStorage.layout()._currentIndex;
                uint256 index = end - quantity;
                do {
                    if (!_checkContractOnERC721Received(address(0), to, index++, _data)) {
                        _revert(TransferToNonERC721ReceiverImplementer.selector);
                    }
                } while (index < end);
                // This prevents reentrancy to `_safeMint`.
                // It does not prevent reentrancy to `_safeMintSpot`.
                if (ERC721AStorage.layout()._currentIndex != end) revert();
            }
        }
    }

    /**
     * @dev Equivalent to `_safeMint(to, quantity, '')`.
     */
    function _safeMint(address to, uint256 quantity) internal virtual {
        _safeMint(to, quantity, '');
    }

    /**
     * @dev Mints a single token at `tokenId`.
     *
     * Note: A spot-minted `tokenId` that has been burned can be re-minted again.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` must be greater than `_sequentialUpTo()`.
     * - `tokenId` must not exist.
     *
     * Emits a {Transfer} event for each mint.
     */
    function _mintSpot(address to, uint256 tokenId) internal virtual {
        if (tokenId <= _sequentialUpTo()) _revert(SpotMintTokenIdTooSmall.selector);
        uint256 prevOwnershipPacked = ERC721AStorage.layout()._packedOwnerships[tokenId];
        if (_packedOwnershipExists(prevOwnershipPacked)) _revert(TokenAlreadyExists.selector);

        _beforeTokenTransfers(address(0), to, tokenId, 1);

        // Overflows are incredibly unrealistic.
        // The `numberMinted` for `to` is incremented by 1, and has a max limit of 2**64 - 1.
        // `_spotMinted` is incremented by 1, and has a max limit of 2**256 - 1.
        unchecked {
            // Updates:
            // - `address` to the owner.
            // - `startTimestamp` to the timestamp of minting.
            // - `burned` to `false`.
            // - `nextInitialized` to `true` (as `quantity == 1`).
            ERC721AStorage.layout()._packedOwnerships[tokenId] = _packOwnershipData(
                to,
                _nextInitializedFlag(1) | _nextExtraData(address(0), to, prevOwnershipPacked)
            );

            // Updates:
            // - `balance += 1`.
            // - `numberMinted += 1`.
            //
            // We can directly add to the `balance` and `numberMinted`.
            ERC721AStorage.layout()._packedAddressData[to] += (1 << _BITPOS_NUMBER_MINTED) | 1;

            // Mask `to` to the lower 160 bits, in case the upper bits somehow aren't clean.
            uint256 toMasked = uint256(uint160(to)) & _BITMASK_ADDRESS;

            if (toMasked == 0) _revert(MintToZeroAddress.selector);

            assembly {
                // Emit the `Transfer` event.
                log4(
                    0, // Start of data (0, since no data).
                    0, // End of data (0, since no data).
                    _TRANSFER_EVENT_SIGNATURE, // Signature.
                    0, // `address(0)`.
                    toMasked, // `to`.
                    tokenId // `tokenId`.
                )
            }

            ++ERC721AStorage.layout()._spotMinted;
        }

        _afterTokenTransfers(address(0), to, tokenId, 1);
    }

    /**
     * @dev Safely mints a single token at `tokenId`.
     *
     * Note: A spot-minted `tokenId` that has been burned can be re-minted again.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}.
     * - `tokenId` must be greater than `_sequentialUpTo()`.
     * - `tokenId` must not exist.
     *
     * See {_mintSpot}.
     *
     * Emits a {Transfer} event.
     */
    function _safeMintSpot(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mintSpot(to, tokenId);

        unchecked {
            if (to.code.length != 0) {
                uint256 currentSpotMinted = ERC721AStorage.layout()._spotMinted;
                if (!_checkContractOnERC721Received(address(0), to, tokenId, _data)) {
                    _revert(TransferToNonERC721ReceiverImplementer.selector);
                }
                // This prevents reentrancy to `_safeMintSpot`.
                // It does not prevent reentrancy to `_safeMint`.
                if (ERC721AStorage.layout()._spotMinted != currentSpotMinted) revert();
            }
        }
    }

    /**
     * @dev Equivalent to `_safeMintSpot(to, tokenId, '')`.
     */
    function _safeMintSpot(address to, uint256 tokenId) internal virtual {
        _safeMintSpot(to, tokenId, '');
    }

    // =============================================================
    //                       APPROVAL OPERATIONS
    // =============================================================

    /**
     * @dev Equivalent to `_approve(to, tokenId, false)`.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _approve(to, tokenId, false);
    }

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function _approve(
        address to,
        uint256 tokenId,
        bool approvalCheck
    ) internal virtual {
        address owner = ownerOf(tokenId);

        if (approvalCheck && _msgSenderERC721A() != owner)
            if (!isApprovedForAll(owner, _msgSenderERC721A())) {
                _revert(ApprovalCallerNotOwnerNorApproved.selector);
            }

        ERC721AStorage.layout()._tokenApprovals[tokenId].value = to;
        emit Approval(owner, to, tokenId);
    }

    // =============================================================
    //                        BURN OPERATIONS
    // =============================================================

    /**
     * @dev Equivalent to `_burn(tokenId, false)`.
     */
    function _burn(uint256 tokenId) internal virtual {
        _burn(tokenId, false);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId, bool approvalCheck) internal virtual {
        uint256 prevOwnershipPacked = _packedOwnershipOf(tokenId);

        address from = address(uint160(prevOwnershipPacked));

        (uint256 approvedAddressSlot, address approvedAddress) = _getApprovedSlotAndAddress(tokenId);

        if (approvalCheck) {
            // The nested ifs save around 20+ gas over a compound boolean condition.
            if (!_isSenderApprovedOrOwner(approvedAddress, from, _msgSenderERC721A()))
                if (!isApprovedForAll(from, _msgSenderERC721A())) _revert(TransferCallerNotOwnerNorApproved.selector);
        }

        _beforeTokenTransfers(from, address(0), tokenId, 1);

        // Clear approvals from the previous owner.
        assembly {
            if approvedAddress {
                // This is equivalent to `delete _tokenApprovals[tokenId]`.
                sstore(approvedAddressSlot, 0)
            }
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as `tokenId` would have to be 2**256.
        unchecked {
            // Updates:
            // - `balance -= 1`.
            // - `numberBurned += 1`.
            //
            // We can directly decrement the balance, and increment the number burned.
            // This is equivalent to `packed -= 1; packed += 1 << _BITPOS_NUMBER_BURNED;`.
            ERC721AStorage.layout()._packedAddressData[from] += (1 << _BITPOS_NUMBER_BURNED) - 1;

            // Updates:
            // - `address` to the last owner.
            // - `startTimestamp` to the timestamp of burning.
            // - `burned` to `true`.
            // - `nextInitialized` to `true`.
            ERC721AStorage.layout()._packedOwnerships[tokenId] = _packOwnershipData(
                from,
                (_BITMASK_BURNED | _BITMASK_NEXT_INITIALIZED) | _nextExtraData(from, address(0), prevOwnershipPacked)
            );

            // If the next slot may not have been initialized (i.e. `nextInitialized == false`) .
            if (prevOwnershipPacked & _BITMASK_NEXT_INITIALIZED == 0) {
                uint256 nextTokenId = tokenId + 1;
                // If the next slot's address is zero and not burned (i.e. packed value is zero).
                if (ERC721AStorage.layout()._packedOwnerships[nextTokenId] == 0) {
                    // If the next slot is within bounds.
                    if (nextTokenId != ERC721AStorage.layout()._currentIndex) {
                        // Initialize the next slot to maintain correctness for `ownerOf(tokenId + 1)`.
                        ERC721AStorage.layout()._packedOwnerships[nextTokenId] = prevOwnershipPacked;
                    }
                }
            }
        }

        emit Transfer(from, address(0), tokenId);
        _afterTokenTransfers(from, address(0), tokenId, 1);

        // Overflow not possible, as `_burnCounter` cannot be exceed `_currentIndex + _spotMinted` times.
        unchecked {
            ERC721AStorage.layout()._burnCounter++;
        }
    }

    // =============================================================
    //                     EXTRA DATA OPERATIONS
    // =============================================================

    /**
     * @dev Directly sets the extra data for the ownership data `index`.
     */
    function _setExtraDataAt(uint256 index, uint24 extraData) internal virtual {
        uint256 packed = ERC721AStorage.layout()._packedOwnerships[index];
        if (packed == 0) _revert(OwnershipNotInitializedForExtraData.selector);
        uint256 extraDataCasted;
        // Cast `extraData` with assembly to avoid redundant masking.
        assembly {
            extraDataCasted := extraData
        }
        packed = (packed & _BITMASK_EXTRA_DATA_COMPLEMENT) | (extraDataCasted << _BITPOS_EXTRA_DATA);
        ERC721AStorage.layout()._packedOwnerships[index] = packed;
    }

    /**
     * @dev Called during each token transfer to set the 24bit `extraData` field.
     * Intended to be overridden by the cosumer contract.
     *
     * `previousExtraData` - the value of `extraData` before transfer.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, `tokenId` will be burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _extraData(
        address from,
        address to,
        uint24 previousExtraData
    ) internal view virtual returns (uint24) {}

    /**
     * @dev Returns the next extra data for the packed ownership data.
     * The returned result is shifted into position.
     */
    function _nextExtraData(
        address from,
        address to,
        uint256 prevOwnershipPacked
    ) private view returns (uint256) {
        uint24 extraData = uint24(prevOwnershipPacked >> _BITPOS_EXTRA_DATA);
        return uint256(_extraData(from, to, extraData)) << _BITPOS_EXTRA_DATA;
    }

    // =============================================================
    //                       OTHER OPERATIONS
    // =============================================================

    /**
     * @dev Returns the message sender (defaults to `msg.sender`).
     *
     * If you are writing GSN compatible contracts, you need to override this function.
     */
    function _msgSenderERC721A() internal view virtual returns (address) {
        return msg.sender;
    }

    /**
     * @dev Converts a uint256 to its ASCII string decimal representation.
     */
    function _toString(uint256 value) internal pure virtual returns (string memory str) {
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits. Total: 5 * 0x20 = 0xa0.
            let m := add(mload(0x40), 0xa0)
            // Update the free memory pointer to allocate.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }

    /**
     * @dev For more efficient reverts.
     */
    function _revert(bytes4 errorSelector) internal pure {
        assembly {
            mstore(0x00, errorSelector)
            revert(0x00, 0x04)
        }
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIt
pragma solidity 0.8.23;

interface IGetTslaReturnTypes {
    struct GetTslaReturnType {
        uint64 subId;
        string mintSource;
        string redeemSource;
        address functionsRouter;
        bytes32 donId;
        address ibtaFeed;
        address usdcFeed;
        address redemptionCoin;
        uint64 secretVersion;
        uint8 secretSlot;
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

////import {MockV3Aggregator} from "../src/test/mocks/MockV3Aggregator.sol";
////import {MockFunctionsRouter} from "../src/test/mocks/MockFunctionsRouter.sol";
////import {MockUSDC} from "../src/test/mocks/MockUSDC.sol";
////import {MockCCIPRouter} from "@ccip/ccip/test/mocks/MockRouter.sol";
////import {MockLinkToken} from "../src/test/mocks/MockLinkToken.sol";

contract HelperFunction {
    NetworkConfig public activeNetworkConfig;

    mapping(uint256 chainId => uint64 ccipChainSelector) public chainIdToCCIPChainSelector;

    struct NetworkConfig {
        address ibtaPriceFeed;
        address usdcPriceFeed;
        address ethUsdPriceFeed;
        address functionsRouter;
        bytes32 donId;
        uint64 subId;
        address redemptionCoin;
        address linkToken;
        address ccipRouter;
        uint64 ccipChainSelector;
        uint64 secretVersion;
        uint8 secretSlot;
    }

    mapping(uint256 => NetworkConfig) public chainIdToNetworkConfig;

    // Mocks
    MockV3Aggregator public tslaFeedMock;
    MockV3Aggregator public ethUsdFeedMock;
    MockV3Aggregator public usdcFeedMock;
    MockUSDC public usdcMock;
    MockLinkToken public linkTokenMock;
    MockCCIPRouter public ccipRouterMock;

    MockFunctionsRouter public functionsRouterMock;

    // TSLA USD, ETH USD, and USDC USD both have 8 decimals
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_ANSWER = 2000e8;
    int256 public constant INITIAL_ANSWER_USD = 1e8;

    constructor() {
        chainIdToNetworkConfig[137] = getPolygonConfig();
        chainIdToNetworkConfig[80_001] = getMumbaiConfig();
        chainIdToNetworkConfig[11155111] = getSepoliaConfig();
        chainIdToNetworkConfig[31_337] = _setupAnvilConfig();
        activeNetworkConfig = chainIdToNetworkConfig[block.chainid];
    }

    function getPolygonConfig() internal pure returns (NetworkConfig memory config) {
        config = NetworkConfig({
            ibtaPriceFeed: 0x567E67f456c7453c583B6eFA6F18452cDee1F5a8,
            usdcPriceFeed: 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7,
            ethUsdPriceFeed: 0xF9680D99D6C9589e2a93a78A04A279e509205945,
            functionsRouter: 0xdc2AAF042Aeff2E68B3e8E33F19e4B9fA7C73F10,
            donId: 0x66756e2d706f6c79676f6e2d6d61696e6e65742d310000000000000000000000,
            subId: 0, // TODO
            // USDC on Polygon
            redemptionCoin: 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359,
            linkToken: 0xb0897686c545045aFc77CF20eC7A532E3120E0F1,
            ccipRouter: 0x849c5ED5a80F5B408Dd4969b78c2C8fdf0565Bfe,
            ccipChainSelector: 4_051_577_828_743_386_545,
            secretVersion: 0, // fill in!
            secretSlot: 0 // fill in!
        });
        // minimumRedemptionAmount: 30e6 // Please see your brokerage for min redemption amounts
        // https://alpaca.markets/support/crypto-wallet-faq
    }

    function getMumbaiConfig() internal pure returns (NetworkConfig memory config) {
        config = NetworkConfig({
            ibtaPriceFeed: 0x1C2252aeeD50e0c9B64bDfF2735Ee3C932F5C408, // this is LINK / USD but it'll work fine
            usdcPriceFeed: 0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0,
            ethUsdPriceFeed: 0x0715A7794a1dc8e42615F059dD6e406A6594651A,
            functionsRouter: 0x6E2dc0F9DB014aE19888F539E59285D2Ea04244C,
            donId: 0x66756e2d706f6c79676f6e2d6d756d6261692d31000000000000000000000000,
            subId: 1396,
            // USDC on Mumbai
            redemptionCoin: 0xe6b8a5CF854791412c1f6EFC7CAf629f5Df1c747,
            linkToken: 0x326C977E6efc84E512bB9C30f76E30c160eD06FB,
            ccipRouter: 0x1035CabC275068e0F4b745A29CEDf38E13aF41b1,
            ccipChainSelector: 12_532_609_583_862_916_517,
            secretVersion: 0, // fill in!
            secretSlot: 0 // fill in!
        });
        // minimumRedemptionAmount: 30e6 // Please see your brokerage for min redemption amounts
        // https://alpaca.markets/support/crypto-wallet-faq
    }

    ///@dev use Sepolia
    function getSepoliaConfig() internal pure returns (NetworkConfig memory config) {
        config = NetworkConfig({
            ibtaPriceFeed: 0x5c13b249846540F81c093Bc342b5d963a7518145, //IBTA / USD
            usdcPriceFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E,
            ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            functionsRouter: 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0,
            donId: 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000,
            subId: 2274,
            // USDC on Mumbai
            redemptionCoin: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            ccipRouter: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
            ccipChainSelector: 16_015_286_601_757_825_753,
            secretVersion: 0, // fill in!
            secretSlot: 0 // fill in!
        });
        // minimumRedemptionAmount: 30e6 // Please see your brokerage for min redemption amounts
        // https://alpaca.markets/support/crypto-wallet-faq
    }

    function getAnvilEthConfig() internal view returns (NetworkConfig memory anvilNetworkConfig) {
        anvilNetworkConfig = NetworkConfig({
            ibtaPriceFeed: address(tslaFeedMock),
            usdcPriceFeed: address(tslaFeedMock),
            ethUsdPriceFeed: address(ethUsdFeedMock),
            functionsRouter: address(functionsRouterMock),
            donId: 0x66756e2d706f6c79676f6e2d6d756d6261692d31000000000000000000000000, // Dummy
            subId: 1, // Dummy non-zero
            redemptionCoin: address(usdcMock),
            linkToken: address(linkTokenMock),
            ccipRouter: address(ccipRouterMock),
            ccipChainSelector: 1, // This is a dummy non-zero value
            secretVersion: 0,
            secretSlot: 0
        });
        // minimumRedemptionAmount: 30e6 // Please see your brokerage for min redemption amounts
        // https://alpaca.markets/support/crypto-wallet-faq
    }

    function _setupAnvilConfig() internal returns (NetworkConfig memory) {
        usdcMock = new MockUSDC();
        tslaFeedMock = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
        ethUsdFeedMock = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
        usdcFeedMock = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER_USD);
        functionsRouterMock = new MockFunctionsRouter();
        ccipRouterMock = new MockCCIPRouter();
        linkTokenMock = new MockLinkToken();
        return getAnvilEthConfig();
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

////import {CCIPReceiver} from "@ccip/ccip/applications/CCIPReceiver.sol";
////import {Client} from "@ccip/ccip/libraries/Client.sol";
////import {betUSD} from "../betUSD.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
///Deploy this contract in Amoy --
contract destinationBetUSD is CCIPReceiver {
    betUSD betusd;

    event MintCallSuccessfull();

    constructor(address router, address farmAddress) CCIPReceiver(router) {
        betusd = betUSD(farmAddress);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        (bool success,) = address(betusd).call(message.data);
        require(success);
        emit MintCallSuccessfull();
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

////import {CCIPReceiver} from "@ccip/ccip/applications/CCIPReceiver.sol";
////import {Client} from "@ccip/ccip/libraries/Client.sol";
////import {hypnosPoint} from "../hypnosPoint.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
///Deploy this contract in Amoy --
contract destinationHypnosPoint is CCIPReceiver {
    hypnosPoint hypnospoint;

    event MintCallSuccessfull();

    constructor(address router, address farmAddress) CCIPReceiver(router) {
        hypnospoint = hypnosPoint(farmAddress);
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        (bool success,) = address(hypnospoint).call(message.data);
        require(success);
        emit MintCallSuccessfull();
    }
}




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;


////import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
////import {IERC20} from "@ccip/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
////import {hypnosPoint} from "./hypnosPoint.sol";
////import {betUSD} from "./betUSD.sol";
////import {dIBTAETF} from "./chainlink/dIBTAETF.sol";

//  ==========  Chainlink ////imports  ==========

// This import includes functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
//import "@chainlink/contracts/src/v0.8/automation/KeeperCompatible.sol";
////import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

////import {IPriceAgregadorV3} from "./interfaces/IPriceAgregadorV3.sol";

//  ==========  Internal ////imports  ==========

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




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// -----------------------------------------------------------------------
///                                 ////Imports
/// -----------------------------------------------------------------------

import {ERC721AUpgradeable} from "lib/ERC721A-Upgradeable/contracts/ERC721AUpgradeable.sol";
////import {UUPSUpgradeable} from "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
////import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
////import {ERC20Upgradeable, IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
////import {SecurityUpgradeable} from "./security/SecurityUpgradeable.sol";
////import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
////import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
////import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
////import {LinkTokenInterface} from "./interfaces/LinkTokenInterface.sol";
////import {IRouterClient} from "@ccip/ccip/interfaces/IRouterClient.sol";
////import {Client} from "@ccip/ccip/libraries/Client.sol";
////import "@chainlink/contracts/src/v0.8/automation/KeeperCompatible.sol";

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




/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/
            
////// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

////import {Script} from "forge-std/Script.sol";
////import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Helper is Script {
    struct NewtorkConfig {
        address token;
        uint256 deployerKey;
    }

    NewtorkConfig public activeNetworkConfig;

    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111 || block.chainid == 80002) {
            //only sepolia and Amoy
            activeNetworkConfig = getTestnetConfig();
        } else if (block.chainid == 1 || block.chainid == 137) {
            activeNetworkConfig = getMainnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }

        networks[SupportedNetworks.ETHEREUM_SEPOLIA] = "Ethereum Sepolia";
        networks[SupportedNetworks.OPTIMISM_GOERLI] = "Optimism Goerli";
        networks[SupportedNetworks.AVALANCHE_FUJI] = "Avalanche Fuji";
        networks[SupportedNetworks.ARBITRUM_GOERLI] = "Arbitrum Goerli";
        networks[SupportedNetworks.POLYGON_AMOY] = "Polygon Amoy";
    }

    function getMainnetConfig() public view returns (NewtorkConfig memory) {
        return NewtorkConfig({token: address(0), deployerKey: vm.envUint("PRIVATE_KEY")});
    }

    function getTestnetConfig() public view returns (NewtorkConfig memory) {
        // vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        // ERC20Mock tokenMock = new ERC20Mock();
        // vm.stopBroadcast();

        return NewtorkConfig({
            token: address(0), //address(tokenMock),
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilConfig() public returns (NewtorkConfig memory) {
        vm.startBroadcast(vm.addr(DEFAULT_ANVIL_KEY));
        ERC20Mock tokenMock = new ERC20Mock();
        vm.stopBroadcast();

        return NewtorkConfig({token: address(tokenMock), deployerKey: DEFAULT_ANVIL_KEY});
    }

    // Supported Networks
    enum SupportedNetworks {
        ETHEREUM_SEPOLIA, //0
        OPTIMISM_GOERLI, //1
        AVALANCHE_FUJI, //2
        ARBITRUM_GOERLI, //3
        POLYGON_AMOY //4

    }

    mapping(SupportedNetworks enumValue => string humanReadableName) public networks;

    enum PayFeesIn {
        Native,
        LINK
    }

    // Chain IDs
    uint64 constant chainIdEthereumSepolia = 16015286601757825753;
    uint64 constant chainIdOptimismGoerli = 2664363617261496610;
    uint64 constant chainIdAvalancheFuji = 14767482510784806043;
    uint64 constant chainIdArbitrumTestnet = 6101244977088475029;
    uint64 constant chainIdPolygonAmoy = 12532609583862916517;

    // Router addresses
    address constant routerEthereumSepolia = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address constant routerOptimismGoerli = 0xEB52E9Ae4A9Fb37172978642d4C141ef53876f26;
    address constant routerAvalancheFuji = 0x554472a2720E5E7D5D3C817529aBA05EEd5F82D8;
    address constant routerArbitrumTestnet = 0x88E492127709447A5ABEFdaB8788a15B4567589E;
    address constant routerPolygonAmoy = 0x9C32fCB86BF0f4a1A8921a9Fe46de3198bb884B2;

    // Link addresses (can be used as fee)
    address constant linkEthereumSepolia = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant linkOptimismGoerli = 0xdc2CC710e42857672E7907CF474a69B63B93089f;
    address constant linkAvalancheFuji = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
    address constant linkArbitrumTestnet = 0xd14838A68E8AFBAdE5efb411d5871ea0011AFd28;
    address constant linkPolygonAmoy = 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904;

    // Wrapped native addresses
    address constant wethEthereumSepolia = 0x097D90c9d3E0B50Ca60e1ae45F6A81010f9FB534;
    address constant wethOptimismGoerli = 0x4200000000000000000000000000000000000006;
    address constant wavaxAvalancheFuji = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c;
    address constant wethArbitrumTestnet = 0x32d5D5978905d9c6c2D4C417F0E06Fe768a4FB5a;
    address constant wmaticPolygonAmoy = 0x360ad4f9a9A8EFe9A8DCB5f461c4Cc1047E1Dcf9;

    // CCIP-BnM addresses
    address constant ccipBnMEthereumSepolia = 0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05;
    address constant ccipBnMOptimismGoerli = 0xaBfE9D11A2f1D61990D1d253EC98B5Da00304F16;
    address constant ccipBnMArbitrumTestnet = 0x0579b4c1C8AcbfF13c6253f1B10d66896Bf399Ef;
    address constant ccipBnMAvalancheFuji = 0xD21341536c5cF5EB1bcb58f6723cE26e8D8E90e4;
    address constant ccipBnMPolygonMumbai = 0xf1E3A5842EeEF51F2967b3F05D45DD4f4205FF40;

    // CCIP-LnM addresses
    address constant ccipLnMEthereumSepolia = 0x466D489b6d36E7E3b824ef491C225F5830E81cC1;
    address constant clCcipLnMOptimismGoerli = 0x835833d556299CdEC623e7980e7369145b037591;
    address constant clCcipLnMArbitrumTestnet = 0x0E14dBe2c8e1121902208be173A3fb91Bb125CDB;
    address constant clCcipLnMAvalancheFuji = 0x70F5c5C40b873EA597776DA2C21929A8282A3b35;
    address constant clCcipLnMPolygonMumbai = 0xc1c76a8c5bFDE1Be034bbcD930c668726E7C1987;

    function getConfigFromNetwork(SupportedNetworks network)
        internal
        pure
        returns (address router, address linkToken, address wrappedNative, uint64 chainId)
    {
        if (network == SupportedNetworks.ETHEREUM_SEPOLIA) {
            return (routerEthereumSepolia, linkEthereumSepolia, wethEthereumSepolia, chainIdEthereumSepolia);
        } else if (network == SupportedNetworks.OPTIMISM_GOERLI) {
            return (routerOptimismGoerli, linkOptimismGoerli, wethOptimismGoerli, chainIdOptimismGoerli);
        } else if (network == SupportedNetworks.ARBITRUM_GOERLI) {
            return (routerArbitrumTestnet, linkArbitrumTestnet, wethArbitrumTestnet, chainIdArbitrumTestnet);
        } else if (network == SupportedNetworks.AVALANCHE_FUJI) {
            return (routerAvalancheFuji, linkAvalancheFuji, wavaxAvalancheFuji, chainIdAvalancheFuji);
        } else if (network == SupportedNetworks.POLYGON_AMOY) {
            return (routerPolygonAmoy, linkPolygonAmoy, wmaticPolygonAmoy, chainIdPolygonAmoy);
        }
    }
}


/** 
 *  SourceUnit: /home/afonsodalvi/HYPNOS/smartcontracts/script/DeployGame.s.sol
*/

////// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

////import {Script, console} from "forge-std/Script.sol";
////import {Helper} from "./Helpers.s.sol";
////import {HYPNOS_gameFi} from "../src/mainGame.sol";
////import {pool} from "../src/pool.sol";
////import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
////import {SubscriptionAPI} from "@chainlink/contracts/src/v0.8/vrf/dev/SubscriptionAPI.sol";

////import {hypnosPoint} from "../src/hypnosPoint.sol";
////import {betUSD} from "../src/betUSD.sol";
////import {destinationHypnosPoint} from "../src/chainlink/destinationHypnosPoint.sol";
////import {destinationBetUSD} from "../src/chainlink/destinationBetUSD.sol";

////import {HelperFunction} from "./HelperFunction.sol";
////import {dIBTAETF} from "../src/chainlink/dIBTAETF.sol";
////import {IGetTslaReturnTypes} from "../src/interfaces/IGetTslaReturnTypes.sol";

//tba ////import
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDestination is Script, Helper {
    Helper public config;
    hypnosPoint public hypnospoint;
    ERC1967Proxy public hypnospointProxy;
    betUSD public betusd;
    ERC1967Proxy public betUSDProxy;
    address public owner;

    bytes32 public salt = bytes32("HypnosAndBetUSD");
    //forge script ./script/DeployGame.s.sol:DeployDestination -vvv --broadcast --rpc-url amoy --sig "run(uint8)" -- 4 --verify -vvvv

    function run(SupportedNetworks destination) external {
        //destination 4 deve ser na polygon amoy
        config = new Helper();

        (, uint256 key) = config.activeNetworkConfig();
        owner = vm.addr(key);

        vm.startBroadcast(key);

        (address router,,,) = getConfigFromNetwork(destination);

        //HypnosPoint in AMOY for CCIP

        hypnosPoint hypnospointlementation = new hypnosPoint{salt: salt}();
        bytes memory init = abi.encodeWithSelector(hypnosPoint.initialize.selector, owner, 100e18);
        hypnospointProxy = new ERC1967Proxy{salt: salt}(address(hypnospointlementation), init);
        hypnospoint = hypnosPoint(payable(hypnospointProxy));

        console.log(
            "hypnosPoint deployed on ",
            networks[destination],
            "with address Proxy: ",
            address(hypnospoint) //
        );

        destinationHypnosPoint destinationMinter = new destinationHypnosPoint{salt: salt}(
            router, //pass 4
            address(hypnospoint)
        ); //esse vai ser o endereco que iremmos interagir para

        console.log(
            "destinationHypnosPoint deployed on ",
            networks[destination],
            "with address Proxy: ",
            address(destinationMinter)
        );

        hypnospoint.transferOwnership(address(destinationMinter));
        address minter = hypnospoint.owner();

        console.log("Minter role granted hypnosPoint to: ", minter);

        //BetUSD in AMOY for CCIP

        betUSD betUSDintlementation = new betUSD{salt: salt}();
        bytes memory initBUSD = abi.encodeWithSelector(betUSD.initialize.selector, owner);
        betUSDProxy = new ERC1967Proxy{salt: salt}(address(betUSDintlementation), initBUSD);
        betusd = betUSD(payable(betUSDProxy));

        console.log(
            "betUSDProxy deployed on ",
            networks[destination],
            "with address Proxy: ",
            address(betusd) //
        );

        destinationBetUSD destinationMinterUSD = new destinationBetUSD{salt: salt}(
            router, //pass 4
            address(betusd)
        ); //esse vai ser o endereco que iremmos interagir para

        console.log(
            "destinationbetusd deployed on ",
            networks[destination],
            "with address Proxy: ",
            address(destinationMinterUSD)
        );

        betusd.transferOwnership(address(destinationMinterUSD));
        address minterUSD = betusd.owner();

        console.log("Minter role BetUSD granted to: ", minterUSD);

        vm.stopBroadcast();
    }

    /*
    AMOY
    == Logs ==
    hypnosPoint deployed on  Polygon Amoy with address Proxy:  0xdF11fbE9C288EA58b4E2Fb6Da03f571710B48129
    destinationHypnosPoint deployed on  Polygon Amoy with address Proxy:  0xF90d22a0a22E85a349cbab43325267F360FE210E
    Minter role granted hypnosPoint to:  0xF90d22a0a22E85a349cbab43325267F360FE210E
    betUSDProxy deployed on  Polygon Amoy with address Proxy:  0x44bE502B660605aea4cC3837e315CDaE7c3A95eC
    destinationbetusd deployed on  Polygon Amoy with address Proxy:  0x6b022ACfAA62c3660B1eB163f557E93D8b246041
    Minter role BetUSD granted to:  0x6b022ACfAA62c3660B1eB163f557E93D8b246041
    */
}

contract DeployIBTAETF is Script {
    dIBTAETF public ibtaetf;
    string constant alpacaMintSource = "./functions/sources/alpacaBalance.js";
    string constant alpacaRedeemSource = "./functions/sources/alpacaBalance.js";

    function run() external {
        // Get params
        IGetTslaReturnTypes.GetTslaReturnType memory tslaReturnType = getdTslaRequirements();

        // Actually deploy
        vm.startBroadcast();
        deploydIBTAETF(
            tslaReturnType.subId,
            tslaReturnType.mintSource,
            tslaReturnType.redeemSource,
            tslaReturnType.functionsRouter,
            tslaReturnType.donId,
            tslaReturnType.ibtaFeed,
            tslaReturnType.usdcFeed,
            tslaReturnType.redemptionCoin,
            tslaReturnType.secretVersion,
            tslaReturnType.secretSlot
        );

        console.log("dIBTAETF", address(ibtaetf));
        vm.stopBroadcast();
    }

    function getdTslaRequirements() public returns (IGetTslaReturnTypes.GetTslaReturnType memory) {
        HelperFunction helperFunction = new HelperFunction();
        (
            address ibtaFeed,
            address usdcFeed, /*address ethFeed*/
            ,
            address functionsRouter,
            bytes32 donId,
            uint64 subId,
            address redemptionCoin,
            ,
            ,
            ,
            uint64 secretVersion,
            uint8 secretSlot
        ) = helperFunction.activeNetworkConfig();

        if (
            ibtaFeed == address(0) || usdcFeed == address(0) || functionsRouter == address(0) || donId == bytes32(0)
                || subId == 0
        ) {
            revert("something is wrong");
        }
        string memory mintSource = vm.readFile(alpacaMintSource);
        string memory redeemSource = vm.readFile(alpacaRedeemSource);
        return IGetTslaReturnTypes.GetTslaReturnType(
            subId,
            mintSource,
            redeemSource,
            functionsRouter,
            donId,
            ibtaFeed,
            usdcFeed,
            redemptionCoin,
            secretVersion,
            secretSlot
        );
    }

    function deploydIBTAETF(
        uint64 subId,
        string memory mintSource,
        string memory redeemSource,
        address functionsRouter,
        bytes32 donId,
        address ibtaFeed,
        address usdcFeed,
        address redemptionCoin,
        uint64 secretVersion,
        uint8 secretSlot
    ) public returns (dIBTAETF) {
        dIBTAETF dIbtaETF = new dIBTAETF(
            subId,
            mintSource,
            redeemSource,
            functionsRouter,
            donId,
            ibtaFeed,
            usdcFeed,
            redemptionCoin,
            secretVersion,
            secretSlot
        );
        return dIbtaETF;
    }
}

contract DeployGame is Script {
    Helper public config;
    ERC1967Proxy public poolProxy;
    HYPNOS_gameFi public game;

    pool public poolContract;
    ERC20Mock public mock;
    bool public deployMock = true;
    bool addComsumer = true;

    address public owner;
    string baseURI_ = "www.baseuri.com/";
    string name_ = "Hypnos Aircraft Game";
    string symbol_ = "HYPNOS";
    uint256 maxSupply_ = 1000000000;
    uint256 takerFee = 2000;
    uint256[4] priceClass = [0, 0, 0, 0];
    string[4] types = ["type1", "type2", "type3", "type4"];

    bytes32 public keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    address public vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    uint256 public subscriptionId = 86066367899265651094365220000614482092166546892613257493279963569089616398365;

    address _priceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306; //--ETH/US sepolia;
    uint256 updateInterval = 15; //15 seconds

    bytes32 public salt = bytes32("PoolGame10");

    function run() public {
        config = new Helper();

        (, uint256 key) = config.activeNetworkConfig();
        owner = vm.addr(key);

        vm.startBroadcast(key);
        pool poolContractImplementation = new pool{salt: salt}();
        bytes memory initPool = abi.encodeWithSelector(
            pool.initialize.selector,
            owner,
            updateInterval,
            address(0x6b022ACfAA62c3660B1eB163f557E93D8b246041), // BetUSD
            address(0xF90d22a0a22E85a349cbab43325267F360FE210E), // HypnosPoint
            owner, //address buyer ETHER
            owner //address buyer ETF Gov
        );
        poolProxy = new ERC1967Proxy{salt: salt}(address(poolContractImplementation), initPool);
        poolContract = pool(payable(poolProxy));

        // game = new HYPNOS_gameFi(vrfCoordinator, keyHash, subscriptionId);

        // bytes memory init = abi.encodeWithSelector(
        //     HYPNOS_gameFi.initialize.selector,
        //     owner,
        //     baseURI_,
        //     name_,
        //     symbol_,
        //     maxSupply_,
        //     address(0x6b022ACfAA62c3660B1eB163f557E93D8b246041), // BetUSD
        //     address(0xF90d22a0a22E85a349cbab43325267F360FE210E), // HypnosPoint
        //     updateInterval,
        //     address(poolContract),
        //     takerFee,
        //     priceClass,
        //     types
        // );

        //game = HYPNOS_gameFi(address(new ERC1967Proxy(address(game), init)));

        // if (addComsumer) {
        //     SubscriptionAPI(vrfCoordinator).addConsumer(
        //         subscriptionId,
        //         address(game)
        //     );
        // }

       // console.log("address:", address(game));
       console.log("PoolContract-Implemantation:", address(poolContract));
        console.log("PoolContract-Proxy:", address(poolContract));
        vm.stopBroadcast();
    }

    /*== Logs ==
        address: 0xFeB9A82dC19c4e7B025ea2d5A8eBA691E955B85f
        PoolContract-Proxy: 0xEA330f4C1FcDE1BbC4Cc13c18573307C4dCA3476*/
}

