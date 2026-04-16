// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "../../mToken.sol";

/**
 * @title auUSD
 * @author TermMax Labs
 */
//solhint-disable contract-name-camelcase
contract auUSD is mToken {
    /**
     * @notice actor that can mint auUSD
     */
    bytes32 public constant AU_USD_MINT_OPERATOR_ROLE =
        keccak256("AU_USD_MINT_OPERATOR_ROLE");

    /**
     * @notice actor that can burn auUSD
     */
    bytes32 public constant AU_USD_BURN_OPERATOR_ROLE =
        keccak256("AU_USD_BURN_OPERATOR_ROLE");

    /**
     * @notice actor that can pause auUSD
     */
    bytes32 public constant AU_USD_PAUSE_OPERATOR_ROLE =
        keccak256("AU_USD_PAUSE_OPERATOR_ROLE");

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
        return ("Midas auUSD", "auUSD");
    }

    /**
     * @dev AC role, owner of which can mint auUSD token
     */
    function _minterRole() internal pure override returns (bytes32) {
        return AU_USD_MINT_OPERATOR_ROLE;
    }

    /**
     * @dev AC role, owner of which can burn auUSD token
     */
    function _burnerRole() internal pure override returns (bytes32) {
        return AU_USD_BURN_OPERATOR_ROLE;
    }

    /**
     * @dev AC role, owner of which can pause auUSD token
     */
    function _pauserRole() internal pure override returns (bytes32) {
        return AU_USD_PAUSE_OPERATOR_ROLE;
    }
}
