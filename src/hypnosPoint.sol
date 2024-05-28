// SPDX-License-Identifier: MIT
/*solhint-disable compiler-version */
pragma solidity ^0.8.20;


/// -----------------------------------------------------------------------
/// Imports
/// -----------------------------------------------------------------------

//  ==========  External imports  ==========

import { ERC20Upgradeable, IERC20 } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

//  ==========  Internal imports  ==========

import { SecurityUpgradeable } from "./security/SecurityUpgradeable.sol";

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
    function initialize(
        address initialOwner,
        uint256 maxSupply
    ) external initializer {
        
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

    function decimals() public view override returns (uint8) {
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

        for (uint256 i = 0; i < tos.length; ) {
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
    function _authorizeUpgrade(address /*newImplementation*/) internal view virtual override(UUPSUpgradeable) {
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
