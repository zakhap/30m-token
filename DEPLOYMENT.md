# TimeWindowHook Deployment Guide

This guide covers deploying the TimeWindowHook system to Sepolia testnet.

## Prerequisites

### 1. Get Sepolia ETH
You'll need testnet ETH for deployment costs (~0.01 ETH total). Get from faucets:

- **Chainlink**: https://faucets.chain.link/sepolia (0.1 ETH/day)
- **Alchemy**: https://www.alchemy.com/faucets/ethereum-sepolia (0.5 ETH/day)
- **QuickNode**: https://faucet.quicknode.com/ethereum/sepolia (0.05 ETH/day, 2x with tweet)

⚠️ **Important**: Most faucets require 0.001-0.005 ETH mainnet balance to prevent spam.

### 2. Generate Sepolia Private Key
```bash
# Generate new private key (TESTNET ONLY!)
./scripts/generate_sepolia_key.sh

# Export the generated key
export SEPOLIA_PRIVATE_KEY="0x..."
```

### 3. Set Up Etherscan API Key (Optional)
For contract verification:
```bash
# Get from https://etherscan.io/apis
export ETHERSCAN_API_KEY="your_api_key_here"
```

### 4. Choose RPC Endpoint
```bash
# Free options
export RPC_URL="https://rpc.sepolia.org/"
# export RPC_URL="https://ethereum-sepolia-rpc.publicnode.com/"

# Professional options (better reliability)
# export RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY"
```

## Deployment Steps

### Step 1: Deploy TestToken
```bash
forge script script/00a_DeployTestToken.s.sol \
    --rpc-url $RPC_URL \
    --private-key $SEPOLIA_PRIVATE_KEY \
    --broadcast \
    --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

**Expected Output:**
```
TestToken deployed at: 0x...
Total supply: 10000000000000000000000000000 (10 billion tokens)
```

**Set Environment Variable:**
```bash
export TEST_TOKEN_ADDRESS="0x..."  # Use address from output
```

### Step 2: Deploy TimeWindowHook
```bash
forge script script/00_TimeWindowHook.s.sol \
    --rpc-url $RPC_URL \
    --private-key $SEPOLIA_PRIVATE_KEY \
    --broadcast \
    --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

**Expected Output:**
```
TimeWindowHook deployed at: 0x...
Window settings:
  Start: 1752081157
  Duration: 60 seconds
  Interval: 120 seconds
Next trading window starts at: 1752081277
```

**Set Environment Variable:**
```bash
export TIME_WINDOW_HOOK_ADDRESS="0x..."  # Use address from output
```

### Step 3: Create ETH/TEST Pool
```bash
forge script script/01_CreateTimeWindowPool.s.sol \
    --rpc-url $RPC_URL \
    --private-key $SEPOLIA_PRIVATE_KEY \
    --broadcast
```

**Expected Output:**
```
Creating ETH/TEST pool with TimeWindowHook at: 0x...
Pool configuration:
  currency0 (ETH): 0x0000000000000000000000000000000000000000
  currency1 (TEST): 0x...
  Initial liquidity: 1000000000000000000 ETH + 9989990000000000000000000000 TEST
```

### Step 4: Test Swap Functionality
```bash
# Test swap during active window
forge script script/03_SwapTimeWindow.s.sol \
    --rpc-url $RPC_URL \
    --private-key $SEPOLIA_PRIVATE_KEY \
    --broadcast \
    --block-timestamp $(date +%s)
```

**Expected Output (Success):**
```
Window active: YES
Swap successful!
Delta token0: -1033553649323884413
Delta token1: 1000000000000000000
```

**Expected Output (Failure):**
```
Window active: NO
WARNING: Trading window is not active. Swap will likely fail.
Swap failed with no reason
```

## Configuration Options

### Window Timing
Customize trading windows with environment variables:
```bash
# Set window to start now
export WINDOW_START=$(date +%s)

# 30 minutes active window
export WINDOW_DURATION=1800

# 1 week between windows  
export WINDOW_INTERVAL=604800
```

### Pool Configuration
Current settings in `script/01_CreateTimeWindowPool.s.sol`:
- **ETH Amount**: 1 ETH
- **TEST Amount**: 9.99 billion tokens (0.1001% reserved for funding)
- **Fee**: 0.30% (3000 basis points)
- **Tick Spacing**: 60

## Testing Hook Functions

Set up testing environment:
```bash
export HOOK_ADDRESS=$TIME_WINDOW_HOOK_ADDRESS
export RPC_URL="https://rpc.sepolia.org/"
```

### Basic Information
```bash
# Window parameters
cast call $HOOK_ADDRESS "windowStart()" --rpc-url $RPC_URL
cast call $HOOK_ADDRESS "windowDuration()" --rpc-url $RPC_URL  
cast call $HOOK_ADDRESS "windowInterval()" --rpc-url $RPC_URL

# Current status
cast call $HOOK_ADDRESS "isWindowActive()" --rpc-url $RPC_URL
cast call $HOOK_ADDRESS "getNextWindowTime()" --rpc-url $RPC_URL
cast call $HOOK_ADDRESS "getWindowEndTime()" --rpc-url $RPC_URL
```

### Human-Readable Timestamps
```bash
# macOS
cast call $HOOK_ADDRESS "windowStart()" --rpc-url $RPC_URL | xargs printf "%d\n" | xargs -I {} date -r {}
cast call $HOOK_ADDRESS "getNextWindowTime()" --rpc-url $RPC_URL | xargs printf "%d\n" | xargs -I {} date -r {}

# Linux
cast call $HOOK_ADDRESS "windowStart()" --rpc-url $RPC_URL | xargs printf "%d\n" | xargs -I {} date -d @{}
cast call $HOOK_ADDRESS "getNextWindowTime()" --rpc-url $RPC_URL | xargs printf "%d\n" | xargs -I {} date -d @{}
```

### Window Status Check
```bash
# Color-coded status
cast call $HOOK_ADDRESS "isWindowActive()" --rpc-url $RPC_URL | grep -q "0x0000000000000000000000000000000000000000000000000000000000000001" && echo "✅ Window ACTIVE" || echo "❌ Window INACTIVE"
```

## Expected Costs

| Operation | Estimated Gas | Cost (@20 gwei) |
|-----------|---------------|------------------|
| TestToken Deploy | ~100,000 | ~0.002 ETH |
| TimeWindowHook Deploy | ~1,500,000 | ~0.03 ETH |
| Pool Creation | ~500,000 | ~0.01 ETH |
| Swap Test | ~100,000 | ~0.002 ETH |
| **Total** | **~2,200,000** | **~0.044 ETH** |

## Troubleshooting

### Common Issues

**1. "insufficient funds for gas * price + value"**
- Solution: Get more Sepolia ETH from faucets
- Check balance: `cast balance $ADDRESS --rpc-url $RPC_URL`

**2. "TEST_TOKEN_ADDRESS environment variable not set"**
- Solution: Set the token address after TestToken deployment
- `export TEST_TOKEN_ADDRESS="0x..."`

**3. "TimeWindowHook: hook address mismatch"**
- Solution: This is rare but indicates salt mining failed
- Try rerunning the TimeWindowHook deployment

**4. "Swap failed with no reason"**
- Solution: Check if trading window is active
- Use `--block-timestamp` to set time within active window

### Gas Price Issues
If deployment fails due to gas:
```bash
# Check current gas price
cast gas-price --rpc-url $RPC_URL

# Add gas price override
forge script script/00a_DeployTestToken.s.sol \
    --rpc-url $RPC_URL \
    --private-key $SEPOLIA_PRIVATE_KEY \
    --broadcast \
    --gas-price 20000000000  # 20 gwei
```

## Contract Addresses

After deployment, record your addresses:

```bash
# Your deployed contracts
export TEST_TOKEN_ADDRESS="0x..."
export TIME_WINDOW_HOOK_ADDRESS="0x..."

# Sepolia v4 Infrastructure (pre-deployed)
export POOL_MANAGER="0xE03A1074c86CFeDd5C142C4F04F1a1536e203543"
export POSITION_MANAGER="0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4"
export PERMIT2="0x000000000022D473030F116dDEE9F6B43aC78BA3"
```

## Next Steps

1. **Share Contract Addresses**: Update any frontend or documentation with deployed addresses
2. **Test Different Scenarios**: Try swaps during active/inactive windows
3. **Monitor Pool**: Watch for trading activity and fee accumulation
4. **Scale Testing**: Consider deploying to other testnets or mainnet

## Support

- **Etherscan Sepolia**: https://sepolia.etherscan.io/
- **Uniswap v4 Docs**: https://docs.uniswap.org/contracts/v4/overview
- **Foundry Book**: https://book.getfoundry.sh/