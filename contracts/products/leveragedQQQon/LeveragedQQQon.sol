// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "../../mToken.sol";

/**
 * @title LeveragedQQQon
 * @author TermMax Labs
 */
//solhint-disable contract-name-camelcase
contract LeveragedQQQon is mToken {
    /**
     * @notice actor that can mint leveragedQQQon
     */
    bytes32 public constant LEVERAGED_QQQON_MINT_OPERATOR_ROLE =
        keccak256("LEVERAGED_QQQON_MINT_OPERATOR_ROLE");

    /**
     * @notice actor that can burn leveragedQQQon
     */
    bytes32 public constant LEVERAGED_QQQON_BURN_OPERATOR_ROLE =
        keccak256("LEVERAGED_QQQON_BURN_OPERATOR_ROLE");

    /**
     * @notice actor that can pause leveragedQQQon
     */
    bytes32 public constant LEVERAGED_QQQON_PAUSE_OPERATOR_ROLE =
        keccak256("LEVERAGED_QQQON_PAUSE_OPERATOR_ROLE");

    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc mToken
     */
    function _getNameSymbol()
        internal
        pure
        override
        returns (string memory, string memory)
    {
        return ("2x Leveraged QQQon", "2xQQQon");
    }

    /**
     * @dev AC role, owner of which can mint leveragedQQQon token
     */
    function _minterRole() internal pure override returns (bytes32) {
        return LEVERAGED_QQQON_MINT_OPERATOR_ROLE;
    }

    /**
     * @dev AC role, owner of which can burn leveragedQQQon token
     */
    function _burnerRole() internal pure override returns (bytes32) {
        return LEVERAGED_QQQON_BURN_OPERATOR_ROLE;
    }

    /**
     * @dev AC role, owner of which can pause leveragedQQQon token
     */
    function _pauserRole() internal pure override returns (bytes32) {
        return LEVERAGED_QQQON_PAUSE_OPERATOR_ROLE;
    }
}
