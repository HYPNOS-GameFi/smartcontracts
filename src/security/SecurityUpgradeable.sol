// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

//  ██████╗ ███╗   ███╗███╗   ██╗███████╗███████╗
// ██╔═══██╗████╗ ████║████╗  ██║██╔════╝██╔════╝
// ██║   ██║██╔████╔██║██╔██╗ ██║█████╗  ███████╗
// ██║   ██║██║╚██╔╝██║██║╚██╗██║██╔══╝  ╚════██║
// ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║███████╗███████║
//  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝

/// -----------------------------------------------------------------------
/// Imports
/// -----------------------------------------------------------------------

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

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