// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "../../mToken.sol";

/**
 * @title pUSDC
 * @author TermMax Labs
 */
//solhint-disable contract-name-camelcase
contract pUSDC is mToken {
    /**
     * @notice actor that can mint pUSDC
     */
    bytes32 public constant P_USDC_MINT_OPERATOR_ROLE =
        keccak256("P_USDC_MINT_OPERATOR_ROLE");

    /**
     * @notice actor that can burn pUSDC
     */
    bytes32 public constant P_USDC_BURN_OPERATOR_ROLE =
        keccak256("P_USDC_BURN_OPERATOR_ROLE");

    /**
     * @notice actor that can pause pUSDC
     */
    bytes32 public constant P_USDC_PAUSE_OPERATOR_ROLE =
        keccak256("P_USDC_PAUSE_OPERATOR_ROLE");

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
        return ("Pharos USDC", "pUSDC");
    }

    /**
     * @dev AC role, owner of which can mint pUSDC token
     */
    function _minterRole() internal pure override returns (bytes32) {
        return P_USDC_MINT_OPERATOR_ROLE;
    }

    /**
     * @dev AC role, owner of which can burn pUSDC token
     */
    function _burnerRole() internal pure override returns (bytes32) {
        return P_USDC_BURN_OPERATOR_ROLE;
    }

    /**
     * @dev AC role, owner of which can pause pUSDC token
     */
    function _pauserRole() internal pure override returns (bytes32) {
        return P_USDC_PAUSE_OPERATOR_ROLE;
    }
}
