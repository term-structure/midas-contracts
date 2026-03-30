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
# Check additional required variables for mainnet deployments
if [[ $NETWORK == *"mainnet"* ]]; then
    IS_MAINNET=true
fi
# Check whether L2 network
if [[ $NETWORK == *"arb"* || $NETWORK == *"op"* ]]; then
    IS_L2=true
fi
# Check if --broadcast flag is present
for arg in "${ARGS[@]}"; do
    if [ "$arg" = "--broadcast" ]; then
        IS_BROADCAST=true
        break
    fi
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

echo "Mode: ${IS_BROADCAST:+Live Broadcast}${IS_BROADCAST:-Dry Run}"
echo "Verification: ${VERIFY:+Enabled}${VERIFY:-Disabled}"
echo "Tenderly Verification: ${TENDERLY:+Enabled}${TENDERLY:-Disabled}"
echo "Debug Mode: ${DEBUG:+Enabled}${DEBUG:-Disabled}"

echo "==============================="

VERIFY_PARAMS=()
# Load custom verifier settings if specified
if [[ " ${ARGS[*]} " == *" --customverify "* ]] && [[ " ${ARGS[*]} " == *" --verify "* ]]; then
    # remove --customverify from ARGS
    ARGS=("${ARGS[@]/--customverify}")
    VERIFIER_URL_VAR="${NETWORK_UPPER}_VERIFIER_URL"
    VERIFIER_API_KEY_VAR="${NETWORK_UPPER}_VERIFIER_API_KEY"
    if [[ -z "${!VERIFIER_URL_VAR}" ]]; then
        echo "Error: Custom verifier variables $VERIFIER_URL_VAR are not set"
        exit 1
    fi
    VERIFIER_URL="${!VERIFIER_URL_VAR}"
    # Add verifier URL and API key to arguments
    VERIFY_PARAMS+=("--verifier-url" "$VERIFIER_URL")
    echo "Using custom verifier URL: $VERIFIER_URL"
    VERIFIER_API_KEY="${!VERIFIER_API_KEY_VAR}"
    if [[ -n "$VERIFIER_API_KEY" ]]; then
        VERIFY_PARAMS+=("--etherscan-api-key" "\"$VERIFIER_API_KEY\"")
    fi
fi

# Export the network name for the Solidity script
export NETWORK=$NETWORK

# Run the script
echo "Starting script execution..."

# Build the forge command
# All scripts, including SubmitOracles and AcceptOracles, use the DEPLOYER_PRIVATE_KEY
FORGE_CMD="forge script $SCRIPT_PATH --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $RPC_URL"
FORGE_CMD="$FORGE_CMD ${ARGS[@]} ${VERIFY_PARAMS[@]}"

if [[ "$FORGE_CMD" == *"--debug"* ]]; then
    # Mask sensitive information in normal mode
    MASKED_CMD=$(echo "$FORGE_CMD" | sed -E 's/(--private-key )[^ ]*/\1[MASKED]/g' | sed -E 's/(--rpc-url )[^ ]*/\1[MASKED]/g' | sed -E 's/(--verifier-url )[^ ]*/\1[MASKED]/g' | sed -E 's/(--etherscan-api-key )[^ ]*/\1[MASKED]/g')
    echo "Executing: $MASKED_CMD"
fi

eval $FORGE_CMD