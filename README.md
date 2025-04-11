# TimeWindowHook - Uniswap v4 30-Minute Trading Window

A Uniswap v4 hook that restricts trading to a 30-minute window each week. This hook demonstrates how to implement time-based restrictions for Uniswap v4 pools.

## Features

- Restricts trading to a 30-minute window each week
- Immutable window parameters set at deployment time
- Simple and gas-efficient implementation using modulo arithmetic
- Helpful error messages when users attempt to trade outside the window
- View functions to check when the next trading window will open

## Hook Implementation

The TimeWindowHook uses the `beforeSwap` hook to check if the current timestamp falls within an allowed trading window. If not, it reverts the transaction with a clear error message providing information about when the next window will open.

Key functions:
- `isWindowActive()`: Checks if trading is currently allowed
- `getNextWindowTime()`: Calculates when the next trading window will open
- `getWindowEndTime()`: Calculates when the current/next window will close

## How to Use

### Setup

*requires [foundry](https://book.getfoundry.sh)*

```bash
forge install
forge test
```

### Local Testing

```bash
# start anvil, a local EVM chain
anvil

# Deploy everything in one go (hook, pool, and test swaps)
forge script script/TimeWindowAnvil.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast
```

### Step by Step Deployment

```bash
# 1. Deploy the hook
forge script script/00_TimeWindowHook.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast

# 2. Create a pool with the hook (set TIME_WINDOW_HOOK_ADDRESS to the deployed hook address)
forge script script/01_CreateTimeWindowPool.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast \
    --env TIME_WINDOW_HOOK_ADDRESS=0x...

# 3. Try swapping in the pool
forge script script/03_SwapTimeWindow.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast \
    --env TIME_WINDOW_HOOK_ADDRESS=0x...
```

## Customizing Window Parameters

You can customize the window parameters by setting environment variables:

```bash
# Set custom window parameters
WINDOW_START=1718380800 # Unix timestamp for when the first window starts
WINDOW_DURATION=1800    # Duration in seconds (30 minutes)
WINDOW_INTERVAL=604800  # Interval in seconds (7 days)

forge script script/00_TimeWindowHook.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast \
    --env WINDOW_START=$WINDOW_START \
    --env WINDOW_DURATION=$WINDOW_DURATION \
    --env WINDOW_INTERVAL=$WINDOW_INTERVAL
```

## Testing in Different Time Windows

To test trading during or outside the window, you can set the block timestamp:

```bash
# Test with a specific timestamp to simulate being in an active window
forge script script/03_SwapTimeWindow.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast \
    --env TIME_WINDOW_HOOK_ADDRESS=0x... \
    --block-timestamp 1718381100  # A timestamp during an active window
```

---

<details>
<summary><h2>Troubleshooting</h2></summary>

### *Permission Denied*

When installing dependencies with `forge install`, Github may throw a `Permission Denied` error

Typically caused by missing Github SSH keys, and can be resolved by following the steps [here](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh) 

Or [adding the keys to your ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent), if you have already uploaded SSH keys

### Hook deployment failures

Hook deployment failures are caused by incorrect flags or incorrect salt mining

1. Verify the flags are in agreement:
    * `getHookCalls()` returns the correct flags
    * `flags` provided to `HookMiner.find(...)`
2. Verify salt mining is correct:
    * In **forge test**: the *deployer* for: `new Hook{salt: salt}(...)` and `HookMiner.find(deployer, ...)` are the same. This will be `address(this)`. If using `vm.prank`, the deployer will be the pranking address
    * In **forge script**: the deployer must be the CREATE2 Proxy: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
        * If anvil does not have the CREATE2 deployer, your foundry may be out of date. You can update it with `foundryup`

</details>

---

## Additional Resources

[Uniswap v4 docs](https://docs.uniswap.org/contracts/v4/overview)

[v4-periphery](https://github.com/uniswap/v4-periphery) contains advanced hook implementations that serve as a great reference

[v4-core](https://github.com/uniswap/v4-core)

[v4-by-example](https://v4-by-example.org)
