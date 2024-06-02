// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@ccip/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {hypnosPoint} from "./hypnosPoint.sol";
//  ==========  Chainlink imports  ==========

//  ==========  Internal imports  ==========

import {SecurityUpgradeable} from "./security/SecurityUpgradeable.sol";

contract airdropFuji is UUPSUpgradeable, SecurityUpgradeable {
    error FailedToWithdrawEth(address owner, address target, uint256 value);

    address public s_hypnosPoint;

   
    mapping(address user => uint256 airdropsPoints) public quantityAirdrops;
    mapping(address user => bool claimAirdrop) allowAirdrop;
    mapping(uint id => address) addr;
    address[] public recipients;
  
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
     */
    function initialize(
        address owner_,
        address hypnospoint_//contract in
    ) external initializer {
        __Security_init(owner_);

        s_hypnosPoint = hypnospoint_;
    }

    function setAirdrop(address user, uint256 quantity)external{
        bool exists = false;
        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == user) {
                exists = true;
                break;
            }
        }
        quantityAirdrops[user] = quantity;
        allowAirdrop[user]=true;
    }

    function claimAirdrop(uint amount) public{
        if(allowAirdrop[msg.sender]=true){
            hypnosPoint(s_hypnosPoint).mint(msg.sender, amount);
        }
    }

    //Automate Airdrop
    function airdorp()public {
    for (uint256 i = 0; i < recipients.length; i++) {
    address recipient = recipients[i];
    hypnosPoint(s_hypnosPoint).mint(recipient, 10e8);
    }
    }

    /// -----------------------------------------------------------------------
    /// Chainlink functions
    /// -----------------------------------------------------------------------


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

}