// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../mToken.sol";

/**
 * @title tmxOSV
 * @author TermMax Labs
 */
//solhint-disable contract-name-camelcase
contract tmxOSV is mToken {
    /**
     * @notice actor that can mint tmxOSV
     */
    bytes32 public constant TMX_OSV_MINT_OPERATOR_ROLE = keccak256("TMX_OSV_MINT_OPERATOR_ROLE");

    /**
     * @notice actor that can burn tmxOSV
     */
    bytes32 public constant TMX_OSV_BURN_OPERATOR_ROLE = keccak256("TMX_OSV_BURN_OPERATOR_ROLE");

    /**
     * @notice actor that can pause tmxOSV
     */
    bytes32 public constant TMX_OSV_PAUSE_OPERATOR_ROLE = keccak256("TMX_OSV_PAUSE_OPERATOR_ROLE");

    /**
     * @dev leaving a storage gap for future updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc mToken
     */
    function _getNameSymbol() internal pure override returns (string memory, string memory) {
        return ("TermMax Option Strategy Vault", "tmxOSV");
    }

    /**
     * @dev AC role whose owner can mint tmxOSV
     */
    function _minterRole() internal pure override returns (bytes32) {
        return TMX_OSV_MINT_OPERATOR_ROLE;
    }

    /**
     * @dev AC role whose owner can burn tmxOSV
     */
    function _burnerRole() internal pure override returns (bytes32) {
        return TMX_OSV_BURN_OPERATOR_ROLE;
    }

    /**
     * @dev AC role whose owner can pause tmxOSV
     */
    function _pauserRole() internal pure override returns (bytes32) {
        return TMX_OSV_PAUSE_OPERATOR_ROLE;
    }
}
