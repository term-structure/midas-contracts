// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../mToken.sol";

/**
 * @title XAUEUSDT
 * @author TermMax Labs
 */
//solhint-disable contract-name-camelcase
contract XAUEUSDT is mToken {
    /**
     * @notice actor that can mint XAUEUSDT
     */
    bytes32 public constant XAUE_USDT_MINT_OPERATOR_ROLE = keccak256("XAUE_USDT_MINT_OPERATOR_ROLE");

    /**
     * @notice actor that can burn XAUEUSDT
     */
    bytes32 public constant XAUE_USDT_BURN_OPERATOR_ROLE = keccak256("XAUE_USDT_BURN_OPERATOR_ROLE");

    /**
     * @notice actor that can pause XAUEUSDT
     */
    bytes32 public constant XAUE_USDT_PAUSE_OPERATOR_ROLE = keccak256("XAUE_USDT_PAUSE_OPERATOR_ROLE");

    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc mToken
     */
    function _getNameSymbol() internal pure override returns (string memory, string memory) {
        return ("Lending USDT against XAUE", "XAUE-USDT");
    }

    /**
     * @dev AC role, owner of which can mint XAUEUSDT token
     */
    function _minterRole() internal pure override returns (bytes32) {
        return XAUE_USDT_MINT_OPERATOR_ROLE;
    }

    /**
     * @dev AC role, owner of which can burn XAUEUSDT token
     */
    function _burnerRole() internal pure override returns (bytes32) {
        return XAUE_USDT_BURN_OPERATOR_ROLE;
    }

    /**
     * @dev AC role, owner of which can pause XAUEUSDT token
     */
    function _pauserRole() internal pure override returns (bytes32) {
        return XAUE_USDT_PAUSE_OPERATOR_ROLE;
    }
}
