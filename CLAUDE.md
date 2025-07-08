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

## Project Architecture

### Core Components
- **TimeWindowHook** (`src/TimeWindowHook.sol`): Main hook contract that restricts trading to specific time windows
- **Hook Permissions**: Only implements `beforeSwap` hook to check trading windows
- **Time Window Logic**: Uses immutable parameters for window start, duration, and interval

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

### Testing Hook Read Functions
Use these `cast` commands to test TimeWindowHook read functions:

```bash
# Set your hook address (replace with actual deployed address)
export HOOK_ADDRESS="0x..."

# Test immutable window parameters
cast call $HOOK_ADDRESS "windowStart()" --rpc-url http://localhost:8545
cast call $HOOK_ADDRESS "windowDuration()" --rpc-url http://localhost:8545  
cast call $HOOK_ADDRESS "windowInterval()" --rpc-url http://localhost:8545

# Test current window status
cast call $HOOK_ADDRESS "isWindowActive()" --rpc-url http://localhost:8545

# Test window timing functions
cast call $HOOK_ADDRESS "getNextWindowTime()" --rpc-url http://localhost:8545
cast call $HOOK_ADDRESS "getWindowEndTime()" --rpc-url http://localhost:8545

# Test hook permissions
cast call $HOOK_ADDRESS "getHookPermissions()" --rpc-url http://localhost:8545

# Convert to human readable formats
# Timestamps (Linux)
cast call $HOOK_ADDRESS "windowStart()" --rpc-url http://localhost:8545 | xargs printf "%d\n" | xargs -I {} date -d @{}
cast call $HOOK_ADDRESS "getNextWindowTime()" --rpc-url http://localhost:8545 | xargs printf "%d\n" | xargs -I {} date -d @{}
cast call $HOOK_ADDRESS "getWindowEndTime()" --rpc-url http://localhost:8545 | xargs printf "%d\n" | xargs -I {} date -d @{}

# Timestamps (macOS)
cast call $HOOK_ADDRESS "windowStart()" --rpc-url http://localhost:8545 | xargs printf "%d\n" | xargs -I {} date -r {}
cast call $HOOK_ADDRESS "getNextWindowTime()" --rpc-url http://localhost:8545 | xargs printf "%d\n" | xargs -I {} date -r {}
cast call $HOOK_ADDRESS "getWindowEndTime()" --rpc-url http://localhost:8545 | xargs printf "%d\n" | xargs -I {} date -r {}

# Duration in minutes
cast call $HOOK_ADDRESS "windowDuration()" --rpc-url http://localhost:8545 | xargs printf "%d\n" | xargs -I {} echo "$(({} / 60)) minutes"

# Interval in days
cast call $HOOK_ADDRESS "windowInterval()" --rpc-url http://localhost:8545 | xargs printf "%d\n" | xargs -I {} echo "$(({} / 86400)) days"

# Window status with color
cast call $HOOK_ADDRESS "isWindowActive()" --rpc-url http://localhost:8545 | grep -q "0x0000000000000000000000000000000000000000000000000000000000000001" && echo "✅ Window ACTIVE" || echo "❌ Window INACTIVE"
```

### Library Remappings
Located in `remappings.txt`:
- `v4-core/`: Uniswap v4 core contracts
- `v4-periphery/`: Uniswap v4 periphery contracts
- `forge-std/`: Foundry standard library
- `@openzeppelin/`: OpenZeppelin contracts