# BTCUSDT Order Book Processor — Verilog RTL Pipeline (Kria KV260)

A synthesizable Verilog pipeline that computes order-book imbalance (OBI) and rolling volatility from live L2 BTCUSDT order-book data, entirely in hardware. Target: Xilinx Kria KV260 (Zynq UltraScale+), 100 MHz PL clock.

This module is the hardware half of a tick-to-trade system where the Python software baseline's compute-bound backtest cycle (60–75 minutes) was the direct specification for what needed to move into RTL.

## RTL architecture

```
                    ┌─────────────────────────────────────────┐
  bid_price_bus ───►│                                         │
  bid_qty_bus   ───►│                                         ├──► obi_out, obi_valid
  ask_price_bus ───►│           ob_processor (top)             │
  ask_qty_bus   ───►│                                         ├──► vol_out, regime_out, vol_valid
  tick_valid    ───►│                                         │
                    └───────────────┬─────────────┬───────────┘
                                     │             │
                          ┌──────────▼───┐   ┌─────▼─────────┐
                          │ obi_calculator│   │ vol_calculator │
                          └───────────────┘   └────────────────┘
```

| Module | Role | Latency |
|---|---|---|
| `ob_params.v` | Global `` `define `` parameters — fixed-point scaling, bus widths, regime thresholds | — |
| `obi_calculator.v` | Order-book imbalance from top-5 bid/ask quantities | 1 clock cycle |
| `vol_calculator.v` | 50-tick rolling return volatility + regime classification | Combinational after 50-tick warm-up |
| `ob_processor.v` | Top-level: unpacks flattened buses, instantiates and wires both calculators | — |

## Design decisions worth calling out

**Flattened bus interface, not array ports.** ModelSim 10.5b (the target simulator here) doesn't support unpacked array ports on module boundaries, so all 200 order-book levels are packed into single wide buses — `bid_price_bus` is `[200*32-1:0]`, sliced internally with `bus[k*32 +: 32]`. This is a real, tool-driven constraint rather than a stylistic choice, and it's the kind of interface pattern that carries over directly to any wide-bus, many-channel RTL design (packet processors, multi-lane SerDes front-ends, etc.).

**Fixed-point, not floating-point, throughout.** Prices are scaled ×10, quantities ×1,000,000, OBI output ×10,000 — chosen so all arithmetic stays in integer adders/multipliers/dividers rather than requiring floating-point IP. `ob_params.v` documents every scale factor and the reasoning (e.g., `$66970.6` → `669706`).

**OBI in a single clock cycle.** `obi_calculator.v` sums the top-5 bid and ask quantities combinationally, then registers a scaled signed division (`diff * 10000 / total`) on the clock edge. Accumulation uses a 64-bit (`` `ACC_W ``) intermediate to prevent overflow from summing five 32-bit quantities — a detail that matters once this scales past top-5 to deeper book levels.

**Volatility via an integer Newton-Raphson square root.** `vol_calculator.v` maintains a 50-entry circular buffer of mid-price returns, computes sum-of-squares variance every tick, then extracts a scaled standard deviation using a synthesizable `isqrt` function (fixed-iteration Newton-Raphson, no floating-point or `$sqrt`). Regime (`LOW`/`MEDIUM`/`HIGH`) is classified from the same scaled volatility against thresholds carried over from the Python engine (`REGIME_VOL_THRESHOLD = 6e-5`), so hardware and software regime definitions stay consistent.

**`valid_out` latches high once warmed up.** The volatility module intentionally does *not* clear `valid_out` once the 50-tick buffer fills, and does not clear it when `valid_in` drops — both are commented directly in the RTL as deliberate behavior, not oversights, since downstream consumers expect a stable regime/volatility reading between ticks rather than a pulsed one.

## Verification

- `tb_ob_processor.v` is a self-checking ModelSim testbench: it drives `clk`/`rst_n`, packs the flattened buses via a `pack_buses` task, and streams tick data from a text pipe file (`input_pipe.txt`) fed by the C++ order-book reconstructor below — so the RTL is verified against real exchange data, not synthetic vectors.
- `run_sim.do` compiles all four RTL files plus the testbench into a ModelSim `work` library and runs the simulation headless (`vsim -c ... -do "run -all; quit"`).
- A captured simulation `transcript` in this repo shows a real run against live data: **5,400+ ticks processed, 0 errors, 7 warnings**, with per-tick OBI, spread, volatility, and regime printed directly from the DUT's outputs (e.g. `OBI: -0.9794 [SELL pressure]`, `Regime: LOW`).

## Data path: from live exchange feed to RTL input

`ob_feeder_live.cpp` connects to a Bybit **demo** WebSocket endpoint, subscribes to the `orderbook.200` BTCUSDT stream, and converts incoming L2 snapshots/deltas into the pipe format the testbench consumes — so the same RTL can be exercised against either recorded `.data` files or a live feed, without changing the Verilog.

```bash
# Compile the live feeder
g++ -o ob_feeder_live ob_feeder_live.cpp \
    -I/root/websocketpp -I/root/json/include \
    -lssl -lcrypto -lboost_system -lpthread \
    -std=c++17 -O2

# Stream live data into the RTL simulation input
./ob_feeder_live > input_pipe.txt
```

## Running the simulation

```bash
cd BTCUSDT
vsim -c -do run_sim.do
```

Expected console output per tick:

```
==============================================
  TICK #5423  [obi_v=0 vol_v=1]
  Bid: $66889.4  Ask: $66889.5  Spread: $0.1
  OBI: -0.9794 [SELL pressure]
  Vol: 1  Regime: LOW
==============================================
```

## Fixed-point reference

| Value | Real | Scaled |
|---|---|---|
| Price | $66,970.6 | 669706 (×10) |
| Quantity | 0.055649 BTC | 55649 (×1,000,000) |
| OBI | +0.3245 | +3245 (×10,000) |

| OBI range | Interpretation |
|---|---|
| +0.8 to +1.0 | Strong buy pressure |
| +0.2 to +0.8 | Mild buy pressure |
| −0.2 to +0.2 | Balanced market |
| −0.8 to −0.2 | Mild sell pressure |
| −1.0 to −0.8 | Strong sell pressure |

| Regime | Volatility threshold |
|---|---|
| LOW | < 2×10⁻⁵ |
| MEDIUM | 2×10⁻⁵ to 6×10⁻⁵ |
| HIGH | > 6×10⁻⁵ |

## FPGA deployment target (Kria KV260)

- **Toolchain:** Vivado 2022.1 for synthesis and implementation
- **Clock:** 100 MHz, sourced from the PS via a Zynq UltraScale+ PL clocking block
- **Resource estimate:** ~10 DSP slices used of ~1,200 available; ~2 BRAMs used (50-entry mid-price and return circular buffers) of 144 available — well within headroom for adding deeper OBI levels or additional regime logic
- Clock-domain crossing between the tick-processing domain and any downstream strategy/execution domain is handled at the system level with an async FIFO (see the broader tick-to-trade pipeline this module feeds into)

## Repository structure

```
BTCUSDT/
├── ob_params.v              # Fixed-point scaling & global parameters
├── obi_calculator.v         # Order-book imbalance (1-cycle latency)
├── vol_calculator.v         # 50-tick rolling volatility + regime classifier
├── ob_processor.v           # Top-level module, flattened-bus unpacking
├── tb_ob_processor.v        # ModelSim self-checking testbench
├── run_sim.do               # ModelSim compile + run script
├── ob_feeder_live.cpp       # Live Bybit WebSocket → RTL pipe feeder
├── ob_feeder_old.cpp        # Earlier feeder version (recorded .data files)
├── transcript               # Captured real simulation run (5,400+ ticks, 0 errors)
├── vsim.wlf                 # ModelSim waveform database from the captured run
├── modelsim.ini             # ModelSim configuration
└── steps_to_run.txt         # Compile/run command reference
```

## Notes / next steps

- Current scope covers OBI and volatility computation only; the strategy-decision, risk-gate, and order-encoder stages of the full tick-to-trade pipeline live in the broader FPGA project this module feeds into.
- `ob_feeder_live.cpp` targets Bybit's **demo** WebSocket environment — swap the endpoint for production data only after separately validating rate limits and reconnect handling.
- The `isqrt` function's fixed 32-iteration Newton-Raphson bound is conservative for the input range in use; worth profiling actual convergence iterations if DSP/LUT budget becomes tight at deeper pipeline stages.
- No formal timing closure report (WNS/setup-hold) is included in this subfolder — see the top-level FPGA project for Vivado timing closure results and the 156.25 MHz → 100 MHz downclock rationale.
