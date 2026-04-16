// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "../../mToken.sol";

/**
 * @title mXAUT
 * @author TermMax Labs
 */
//solhint-disable contract-name-camelcase
contract mXAUT is mToken {
    /**
     * @notice actor that can mint mXAUT
     */
    bytes32 public constant M_XAUT_MINT_OPERATOR_ROLE =
        keccak256("M_XAUT_MINT_OPERATOR_ROLE");

    /**
     * @notice actor that can burn mXAUT
     */
    bytes32 public constant M_XAUT_BURN_OPERATOR_ROLE =
        keccak256("M_XAUT_BURN_OPERATOR_ROLE");

    /**
     * @notice actor that can pause mXAUT
     */
    bytes32 public constant M_XAUT_PAUSE_OPERATOR_ROLE =
        keccak256("M_XAUT_PAUSE_OPERATOR_ROLE");

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
        return ("Midas XAUT", "mXAUT");
    }

    /**
     * @dev AC role, owner of which can mint mXAUT token
     */
    function _minterRole() internal pure override returns (bytes32) {
        return M_XAUT_MINT_OPERATOR_ROLE;
    }

    /**
     * @dev AC role, owner of which can burn mXAUT token
     */
    function _burnerRole() internal pure override returns (bytes32) {
        return M_XAUT_BURN_OPERATOR_ROLE;
    }

    /**
     * @dev AC role, owner of which can pause mXAUT token
     */
    function _pauserRole() internal pure override returns (bytes32) {
        return M_XAUT_PAUSE_OPERATOR_ROLE;
    }
}
