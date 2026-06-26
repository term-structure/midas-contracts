// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "../../mToken.sol";

/**
 * @title TermPrime
 * @author TermMax Labs
 */
contract TermPrime is mToken {
    /**
     * @notice actor that can mint termPrime
     */
    bytes32 public constant TERM_PRIME_MINT_OPERATOR_ROLE =
        keccak256("TERM_PRIME_MINT_OPERATOR_ROLE");

    /**
     * @notice actor that can burn termPrime
     */
    bytes32 public constant TERM_PRIME_BURN_OPERATOR_ROLE =
        keccak256("TERM_PRIME_BURN_OPERATOR_ROLE");

    /**
     * @notice actor that can pause termPrime
     */
    bytes32 public constant TERM_PRIME_PAUSE_OPERATOR_ROLE =
        keccak256("TERM_PRIME_PAUSE_OPERATOR_ROLE");

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
        return ("TermMax Prime Strategy USDC Vault", "primeUSDC");
    }

    /**
     * @dev AC role, owner of which can mint termPrime token
     */
    function _minterRole() internal pure override returns (bytes32) {
        return TERM_PRIME_MINT_OPERATOR_ROLE;
    }

    /**
     * @dev AC role, owner of which can burn termPrime token
     */
    function _burnerRole() internal pure override returns (bytes32) {
        return TERM_PRIME_BURN_OPERATOR_ROLE;
    }

    /**
     * @dev AC role, owner of which can pause termPrime token
     */
    function _pauserRole() internal pure override returns (bytes32) {
        return TERM_PRIME_PAUSE_OPERATOR_ROLE;
    }
}
