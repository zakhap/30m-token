#!/bin/bash

# Generate a new private key for Sepolia testnet
# NEVER use this for mainnet or real funds!

echo "Generating new Sepolia testnet private key..."
echo "WARNING: This is for TESTNET ONLY. Never use for mainnet!"
echo ""

# Generate new private key using cast
PRIVATE_KEY=$(cast wallet new | grep "Private key:" | cut -d' ' -f3)
ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)

echo "Private Key: $PRIVATE_KEY"
echo "Address: $ADDRESS"
echo ""
echo "Export this private key for use:"
echo "export SEPOLIA_PRIVATE_KEY=$PRIVATE_KEY"
echo ""
echo "Get Sepolia ETH from faucets:"
echo "1. Chainlink: https://faucets.chain.link/sepolia"
echo "2. Alchemy: https://www.alchemy.com/faucets/ethereum-sepolia"
echo "3. QuickNode: https://faucet.quicknode.com/ethereum/sepolia"
echo ""
echo "Check balance with:"
echo "cast balance $ADDRESS --rpc-url https://rpc.sepolia.org/"