#!/bin/bash

# Check if required arguments are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <network> <command> [options]"
    echo ""
    echo "Commands:"
    echo "  1. Script Commands:"
    echo "     - script:<script-name>   - Run a custom script"
    echo "                              (e.g., script:GrantRoles, script:SubmitOracles)"
    echo "                              (e.g., script:products/leveragedQQQon/DeployLeveragedQQQon)"
    echo ""
    echo "Options:"
    echo "  --broadcast     Broadcast transactions (default: dry run)"
    echo "  --verify        Enable contract verification"
    echo "  --debug         Show complete command with sensitive information (for debugging)"
    echo "  --customverify  Use custom verifier URL and API key from env vars CUSTOM_VERIFIER_URL and CUSTOM_VERIFIER_API_KEY"
    exit 1
fi

NETWORK=$1
COMMAND=$2
# get args from index 3
ARGS=("${@:3}")

# Parse the command to determine if it's a deployment or a script
if [[ "$COMMAND" == script:* ]]; then
    OPERATION="script"
    SCRIPT_NAME=${COMMAND#script:}
else
    echo "Error: Invalid command format. Must be either 'deploy:<type>' or 'script:<script-name>'"
    exit 1
fi

echo "Running on $NETWORK..."

# Convert network name to uppercase with underscores for env vars
NETWORK_UPPER=$(echo $NETWORK | tr '[:lower:]' '[:upper:]' | tr '-' '_')

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Get the RPC URL and other variables
RPC_URL_VAR="${NETWORK_UPPER}_RPC_URL"
DEPLOYER_PRIVATE_KEY_VAR="${NETWORK_UPPER}_DEPLOYER_PRIVATE_KEY"
ADMIN_ADDRESS_VAR="${NETWORK_UPPER}_ADMIN_ADDRESS"

RPC_URL="${!RPC_URL_VAR}"
DEPLOYER_PRIVATE_KEY="${!DEPLOYER_PRIVATE_KEY_VAR}"
ADMIN_ADDRESS="${!ADMIN_ADDRESS_VAR}"

# Check required environment variables
if [ -z "$RPC_URL" ]; then
    echo "Error: Required environment variable $RPC_URL_VAR is not set"
    exit 1
fi

if [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
    echo "Error: Required environment variable $DEPLOYER_PRIVATE_KEY_VAR is not set"
    exit 1
fi

if [ -z "$ADMIN_ADDRESS" ]; then
    echo "Error: Required environment variable $ADMIN_ADDRESS_VAR is not set"
    exit 1
fi


IS_L2=false
IS_MAINNET=false
IS_BROADCAST=false
VERIFY_REQUESTED=false
DEBUG=false
# Check additional required variables for mainnet deployments
if [[ $NETWORK == *"mainnet"* ]]; then
    IS_MAINNET=true
fi
# Check whether L2 network
if [[ $NETWORK == *"arb"* || $NETWORK == *"op"* ]]; then
    IS_L2=true
fi
# Check command flags
for arg in "${ARGS[@]}"; do
    case "$arg" in
        --broadcast)
            IS_BROADCAST=true
            ;;
        --verify)
            VERIFY_REQUESTED=true
            ;;
        --debug)
            DEBUG=true
            ;;
    esac
done
# set IS_L2 and IS_MAINNET to environment variables
export IS_L2
export IS_MAINNET
export IS_BROADCAST

# Ensure deployment output directory exists for script JSON artifacts
DEPLOYMENT_DIR="deployment/$NETWORK"
mkdir -p "$DEPLOYMENT_DIR"
export DEPLOYMENT_DIR

# Determine the script path and name
if [ "$OPERATION" = "script" ]; then
    # For custom scripts, try multiple locations
    SCRIPT_LOCATIONS=(
        "script/deploy/products/${SCRIPT_NAME}.s.sol"
        "script/deploy/${SCRIPT_NAME}.s.sol"
        "script/${SCRIPT_NAME}.s.sol"
        "script/utils/${SCRIPT_NAME}.s.sol"
    )

    SCRIPT_FOUND=false
    for POTENTIAL_SCRIPT_PATH in "${SCRIPT_LOCATIONS[@]}"; do
        if [ -f "$POTENTIAL_SCRIPT_PATH" ]; then
            SCRIPT_PATH=$POTENTIAL_SCRIPT_PATH
            SCRIPT_FOUND=true
            break
        fi
    done

    if [ "$SCRIPT_FOUND" = false ]; then
        echo "Error: Script file not found. Searched in:"
        for POTENTIAL_SCRIPT_PATH in "${SCRIPT_LOCATIONS[@]}"; do
            echo "  - $POTENTIAL_SCRIPT_PATH"
        done
        exit 1
    fi
fi

# Configuration summary
echo "=== Configuration ==="
echo "Operation: Script Execution"
echo "Network: $NETWORK"
echo "Script: $SCRIPT_NAME.s.sol"
echo "Path: $SCRIPT_PATH"

# Mask the RPC URL to avoid exposing API keys
RPC_MASKED=$(echo "$RPC_URL" | sed -E 's/([a-zA-Z0-9]{4})[a-zA-Z0-9]*/\1*****/g')
echo "RPC URL: $RPC_MASKED"
echo "Admin Address: $ADMIN_ADDRESS"

echo "Mode: $([[ "$IS_BROADCAST" == true ]] && echo "Live Broadcast" || echo "Dry Run")"
echo "Verification: $([[ "$VERIFY_REQUESTED" == true ]] && echo "Enabled" || echo "Disabled")"
echo "Tenderly Verification: ${TENDERLY:+Enabled}${TENDERLY:-Disabled}"
echo "Debug Mode: $([[ "$DEBUG" == true ]] && echo "Enabled" || echo "Disabled")"

echo "==============================="

VERIFY_PARAMS=()
# Load custom verifier settings if specified
if [[ " ${ARGS[*]} " == *" --customverify "* ]] && [[ " ${ARGS[*]} " == *" --verify "* ]]; then
    # Remove --customverify from the arguments passed to Forge.
    FILTERED_ARGS=()
    for arg in "${ARGS[@]}"; do
        if [[ "$arg" != "--customverify" ]]; then
            FILTERED_ARGS+=("$arg")
        fi
    done
    ARGS=("${FILTERED_ARGS[@]}")

    VERIFIER_URL_VAR="${NETWORK_UPPER}_VERIFIER_URL"
    VERIFIER_API_KEY_VAR="${NETWORK_UPPER}_VERIFIER_API_KEY"
    if [[ -z "${!VERIFIER_URL_VAR}" ]]; then
        echo "Error: Custom verifier variables $VERIFIER_URL_VAR are not set"
        exit 1
    fi
    VERIFIER_URL="${!VERIFIER_URL_VAR}"
    # Add verifier URL and API key to arguments
    VERIFY_PARAMS+=("--verifier" "custom" "--verifier-url" "$VERIFIER_URL")
    echo "Using custom verifier URL: $VERIFIER_URL"
    VERIFIER_API_KEY="${!VERIFIER_API_KEY_VAR}"
    if [[ -n "$VERIFIER_API_KEY" ]]; then
        VERIFY_PARAMS+=("--verifier-api-key" "$VERIFIER_API_KEY")
    fi
elif [[ " ${ARGS[*]} " == *" --verify "* ]]; then
    # Foundry defaults to Sourcify in recent versions. BscScan and Etherscan
    # use the Etherscan-compatible verifier.
    VERIFY_PARAMS+=("--verifier" "etherscan")
    if [[ -n "$ETHERSCAN_API_KEY" ]]; then
        VERIFY_PARAMS+=("--etherscan-api-key" "$ETHERSCAN_API_KEY")
    fi
fi

# This source is compiled into both 0.8.9 and newer compilation units, so
# Foundry creates a version-suffixed artifact and may submit that suffix as
# part of the contract name. Verify this deployment explicitly instead.
MANUAL_ACCESS_CONTROL_VERIFY=false
if [[ "$SCRIPT_NAME" == "DeployAccessController" ]] && [[ "$VERIFY_REQUESTED" == true ]]; then
    MANUAL_ACCESS_CONTROL_VERIFY=true
    FILTERED_ARGS=()
    for arg in "${ARGS[@]}"; do
        if [[ "$arg" != "--verify" ]]; then
            FILTERED_ARGS+=("$arg")
        fi
    done
    ARGS=("${FILTERED_ARGS[@]}")
fi

# Export the network name for the Solidity script
export NETWORK=$NETWORK

# Run the script
echo "Starting script execution..."

# Build the forge command
# All scripts, including SubmitOracles and AcceptOracles, use the DEPLOYER_PRIVATE_KEY
FORGE_CMD=(
    forge script "$SCRIPT_PATH"
    --private-key "$DEPLOYER_PRIVATE_KEY"
    --rpc-url "$RPC_URL"
    "${ARGS[@]}"
)
if [[ "$MANUAL_ACCESS_CONTROL_VERIFY" == false ]]; then
    FORGE_CMD+=("${VERIFY_PARAMS[@]}")
fi

if [[ " ${ARGS[*]} " == *" --debug "* ]]; then
    # Mask sensitive information in normal mode
    printf 'Executing:'
    skip_next=false
    for arg in "${FORGE_CMD[@]}"; do
        if $skip_next; then
            printf ' [MASKED]'
            skip_next=false
            continue
        fi
        case "$arg" in
            --private-key|--rpc-url|--verifier-url|--etherscan-api-key|--verifier-api-key)
                printf ' %s' "$arg"
                skip_next=true
                ;;
            *)
                printf ' %q' "$arg"
                ;;
        esac
    done
    printf '\n'
fi

if ! "${FORGE_CMD[@]}"; then
    exit 1
fi

if [[ "$MANUAL_ACCESS_CONTROL_VERIFY" == true ]]; then
    DEPLOYMENT_FILE="$DEPLOYMENT_DIR/midas-access-control.json"
    if [[ ! -f "$DEPLOYMENT_FILE" ]]; then
        echo "Error: Deployment artifact not found: $DEPLOYMENT_FILE"
        exit 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for explicit access control verification"
        exit 1
    fi

    ACCESS_CONTROL_IMPL=$(jq -er '.accessControlImpl' "$DEPLOYMENT_FILE") || exit 1
    ACCESS_CONTROL_PROXY=$(jq -er '.accessControlProxy' "$DEPLOYMENT_FILE") || exit 1
    CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL") || exit 1
    PROXY_CONSTRUCTOR_ARGS=$(
        cast abi-encode \
            "constructor(address,bytes)" \
            "$ACCESS_CONTROL_IMPL" \
            "0x8129fc1c"
    ) || exit 1

    VERIFY_COMMON=(
        --chain "$CHAIN_ID"
        --rpc-url "$RPC_URL"
        --compiler-version "0.8.9"
        --num-of-optimizations "200"
        --evm-version "london"
        --watch
        "${VERIFY_PARAMS[@]}"
    )

    echo "Verifying MidasAccessControl implementation: $ACCESS_CONTROL_IMPL"
    if ! forge verify-contract \
        "$ACCESS_CONTROL_IMPL" \
        "contracts/access/MidasAccessControl.sol:MidasAccessControl" \
        "${VERIFY_COMMON[@]}"; then
        exit 1
    fi

    echo "Verifying ERC1967Proxy: $ACCESS_CONTROL_PROXY"
    if ! forge verify-contract \
        "$ACCESS_CONTROL_PROXY" \
        "node_modules/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy" \
        --constructor-args "$PROXY_CONSTRUCTOR_ARGS" \
        "${VERIFY_COMMON[@]}"; then
        exit 1
    fi
fi
