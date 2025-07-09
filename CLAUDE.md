# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Testing
```bash
# Build all contracts
forge build

# Run all tests
forge test

# Run tests with verbosity
forge test -v

# Run specific test file
forge test --match-path test/TimeWindowHook.t.sol

# Run tests with gas snapshots
forge test --gas-report

# Clean build artifacts
forge clean
```

### Deployment Commands

#### Local Anvil Network
```bash
# Deploy to local anvil network
anvil

# Deploy TimeWindowHook contract
forge script script/00_TimeWindowHook.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast

# Deploy everything at once (hook + pool + liquidity)
forge script script/TimeWindowAnvil.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast
```

#### Sepolia Testnet Deployment
```bash
# 1. Deploy TestToken (10B tokens)
forge script script/00a_DeployTestToken.s.sol \
    --rpc-url https://rpc.sepolia.org/ \
    --private-key [YOUR_SEPOLIA_PRIVATE_KEY] \
    --broadcast \
    --verify --etherscan-api-key [ETHERSCAN_API_KEY]

# 2. Deploy TimeWindowHook (set TEST_TOKEN_ADDRESS from step 1)
export TEST_TOKEN_ADDRESS=[ADDRESS_FROM_STEP_1]
forge script script/00_TimeWindowHook.s.sol \
    --rpc-url https://rpc.sepolia.org/ \
    --private-key [YOUR_SEPOLIA_PRIVATE_KEY] \
    --broadcast \
    --verify --etherscan-api-key [ETHERSCAN_API_KEY]

# 3. Create ETH/TEST pool (set TIME_WINDOW_HOOK_ADDRESS from step 2)
export TIME_WINDOW_HOOK_ADDRESS=[ADDRESS_FROM_STEP_2]
forge script script/01_CreateTimeWindowPool.s.sol \
    --rpc-url https://rpc.sepolia.org/ \
    --private-key [YOUR_SEPOLIA_PRIVATE_KEY] \
    --broadcast

# 4. Test swaps
forge script script/03_SwapTimeWindow.s.sol \
    --rpc-url https://rpc.sepolia.org/ \
    --private-key [YOUR_SEPOLIA_PRIVATE_KEY] \
    --broadcast \
    --block-timestamp [TIMESTAMP_IN_ACTIVE_WINDOW]
```

## Project Architecture

### Core Components
- **TimeWindowHook** (`src/TimeWindowHook.sol`): Main hook contract that restricts trading to specific time windows
- **TestToken** (`src/TestToken.sol`): ERC20 token with 10 billion total supply for testing
- **Hook Permissions**: Only implements `beforeSwap` hook to check trading windows
- **Time Window Logic**: Uses immutable parameters for window start, duration, and interval
- **Pool Configuration**: ETH/TEST pool with 1 ETH + 9.99 billion TEST liquidity (0.1001% reserved for funding)

### Key Dependencies
- **Uniswap v4 Core**: Pool management and hook infrastructure
- **Uniswap v4 Periphery**: Utility contracts including BaseHook and HookMiner
- **Forge Standard Library**: Testing utilities and scripting

### Contract Structure
The TimeWindowHook contract:
- Inherits from `BaseHook` (v4-periphery)
- Uses immutable state variables for window parameters
- Implements time-based trading restrictions using modulo arithmetic
- Provides view functions to check window status and timing

### Hook Deployment Process
1. Hook addresses must have specific flags encoded in the address
2. Uses `HookMiner.find()` to mine a salt that produces correct address flags
3. Deploys using CREATE2 with the mined salt
4. Requires the CREATE2 deployer at `0x4e59b44847b379578588920cA78FbF26c0B4956C`

### Testing Infrastructure
- Uses Foundry's test framework with `forge-std/Test.sol`
- Includes utilities for pool deployment and liquidity management
- Test fixtures in `test/utils/` provide common testing patterns
- Uses `vm.warp()` for time manipulation in tests

### Environment Variables
Scripts support customization via environment variables:
- `WINDOW_START`: Unix timestamp for first trading window
- `WINDOW_DURATION`: Duration in seconds (default: 1800 = 30 minutes)
- `WINDOW_INTERVAL`: Interval between windows (default: 604800 = 7 days)
- `TIME_WINDOW_HOOK_ADDRESS`: Address of deployed hook for subsequent scripts
- `TEST_TOKEN_ADDRESS`: Address of deployed TestToken contract

### Sepolia Testnet Setup
For Sepolia deployment you'll need:

1. **Sepolia ETH**: Get from faucets like:
   - Chainlink: https://faucets.chain.link/sepolia
   - Alchemy: https://www.alchemy.com/faucets/ethereum-sepolia
   - QuickNode: https://faucet.quicknode.com/ethereum/sepolia

2. **RPC Endpoints**: Use reliable endpoints:
   - Free: https://rpc.sepolia.org/
   - Free: https://ethereum-sepolia-rpc.publicnode.com/
   - Professional: Alchemy, Ankr, QuickNode

3. **Etherscan API Key**: For contract verification
   - Get from https://etherscan.io/apis

4. **Private Key**: Generate dedicated Sepolia key (never use mainnet keys)

### Testing Hook Read Functions
Use these `cast` commands to test TimeWindowHook read functions:

```bash
# Set your hook address and RPC URL
export HOOK_ADDRESS="0x..."
export RPC_URL="http://localhost:8545"  # For local anvil
# export RPC_URL="https://rpc.sepolia.org/"  # For Sepolia testnet

# Test immutable window parameters
cast call $HOOK_ADDRESS "windowStart()" --rpc-url $RPC_URL
cast call $HOOK_ADDRESS "windowDuration()" --rpc-url $RPC_URL  
cast call $HOOK_ADDRESS "windowInterval()" --rpc-url $RPC_URL

# Test current window status
cast call $HOOK_ADDRESS "isWindowActive()" --rpc-url $RPC_URL

# Test window timing functions
cast call $HOOK_ADDRESS "getNextWindowTime()" --rpc-url $RPC_URL
cast call $HOOK_ADDRESS "getWindowEndTime()" --rpc-url $RPC_URL

# Test hook permissions
cast call $HOOK_ADDRESS "getHookPermissions()" --rpc-url $RPC_URL

# Convert to human readable formats
# Timestamps (Linux)
cast call $HOOK_ADDRESS "windowStart()" --rpc-url $RPC_URL | xargs printf "%d\n" | xargs -I {} date -d @{}
cast call $HOOK_ADDRESS "getNextWindowTime()" --rpc-url $RPC_URL | xargs printf "%d\n" | xargs -I {} date -d @{}
cast call $HOOK_ADDRESS "getWindowEndTime()" --rpc-url $RPC_URL | xargs printf "%d\n" | xargs -I {} date -d @{}

# Timestamps (macOS)
cast call $HOOK_ADDRESS "windowStart()" --rpc-url $RPC_URL | xargs printf "%d\n" | xargs -I {} date -r {}
cast call $HOOK_ADDRESS "getNextWindowTime()" --rpc-url $RPC_URL | xargs printf "%d\n" | xargs -I {} date -r {}
cast call $HOOK_ADDRESS "getWindowEndTime()" --rpc-url $RPC_URL | xargs printf "%d\n" | xargs -I {} date -r {}

# Duration in minutes
cast call $HOOK_ADDRESS "windowDuration()" --rpc-url $RPC_URL | xargs printf "%d\n" | xargs -I {} echo "$(({} / 60)) minutes"

# Interval in days
cast call $HOOK_ADDRESS "windowInterval()" --rpc-url $RPC_URL | xargs printf "%d\n" | xargs -I {} echo "$(({} / 86400)) days"

# Window status with color
cast call $HOOK_ADDRESS "isWindowActive()" --rpc-url $RPC_URL | grep -q "0x0000000000000000000000000000000000000000000000000000000000000001" && echo "✅ Window ACTIVE" || echo "❌ Window INACTIVE"
```

### Library Remappings
Located in `remappings.txt`:
- `v4-core/`: Uniswap v4 core contracts
- `v4-periphery/`: Uniswap v4 periphery contracts
- `forge-std/`: Foundry standard library
- `@openzeppelin/`: OpenZeppelin contracts