# SITARAM BTCUSDT Order Book Processor
## Verilog + C++ Pipeline for Kria KV260 (100 MHz)

---

## Project Structure
```
btc_fpga/
├── rtl/
│   ├── ob_params.v          # Global parameters & scaling constants
│   ├── obi_calculator.v     # OBI from top-5 bid/ask levels
│   ├── vol_calculator.v     # 50-tick rolling volatility + regime
│   └── ob_processor.v       # Top-level module
├── tb/
│   └── tb_ob_processor.v    # ModelSim testbench (reads C++ pipe)
└── sim/
    ├── ob_feeder.cpp         # C++ data feeder (converts JSON → pipe)
    └── run_sim.do            # ModelSim compile + run script
```

---

## Fixed-Point Encoding
| Value       | Real          | Scaled          |
|-------------|---------------|-----------------|
| Price       | $66970.6      | 669706 (x10)    |
| Quantity    | 0.055649 BTC  | 55649 (x1M)     |
| OBI output  | +0.3245       | +3245 (x10000)  |

---

## Step 1: Compile C++ Feeder
```bash
cd btc_fpga/sim
g++ -o ob_feeder ob_feeder.cpp -std=c++17 -O2
```

---

## Step 2: Generate Input Pipe from .data file
```bash
# From your Bybit .data files (E:\Binance\March\All\...)
./ob_feeder /mnt/e/Binance/March/All/2026-03-01_BTCUSDT_ob200.data/2026-03-01_BTCUSDT_ob200.data > input_pipe.txt
```

You should see on stderr:
```
[Feeder] SNAPSHOT tick=1 bids=200 asks=200 best_bid=$66970.6 best_ask=$66970.7
[Feeder] DELTA tick=2 best_bid=$66970.6 best_ask=$66970.7 spread=$0.1
...
```

---

## Step 3: Copy input_pipe.txt to sim folder
```bash
# The testbench looks for input_pipe.txt in the current directory
cp input_pipe.txt btc_fpga/sim/
```

---

## Step 4: Run ModelSim Simulation
```bash
cd btc_fpga/sim
vsim -c -do run_sim.do
```

Or from Rocky Linux WSL2:
```bash
cd /root/btc_fpga/sim
/root/intelFPGA/18.1/modelsim_ase/bin/vsim -c -do run_sim.do
```

---

## Expected Output in ModelSim Console
```
================================================
  SITARAM BTCUSDT OB PROCESSOR — ModelSim Sim
  Clock: 100MHz | Fixed-point: 32-bit scaled
  OBI: Top-5 | Vol Window: 50 ticks
================================================

[TICK 1] Warming up... (1/50 ticks for vol)
[TICK 2] Warming up... (2/50 ticks for vol)
...
[TICK 50] Warming up... (50/50 ticks for vol)

╔══════════════════════════════════════════════╗
║     SITARAM OB PROCESSOR — TICK #51         ║
╠══════════════════════════════════════════════╣
║  Mid Price  : $66970.6                      ║
║  Best Bid   : $66970.6                      ║
║  Best Ask   : $66970.7                      ║
║  Spread     : $0.1                          ║
╠══════════════════════════════════════════════╣
║  OBI (top5) : +0.3245                       ║
║  Volatility : 42837 (scaled)                ║
║  Regime     : MEDIUM                        ║
╚══════════════════════════════════════════════╝
```

---

## OBI Interpretation
| OBI Value   | Meaning                          |
|-------------|----------------------------------|
| +0.8 to +1.0| Strong buy pressure              |
| +0.2 to +0.8| Mild buy pressure                |
| -0.2 to +0.2| Balanced market                  |
| -0.8 to -0.2| Mild sell pressure               |
| -1.0 to -0.8| Strong sell pressure             |

## Regime Flags
| Flag   | Vol Threshold | Meaning             |
|--------|---------------|---------------------|
| LOW    | < 2e-5        | Calm market         |
| MEDIUM | 2e-5 to 6e-5  | Normal volatility   |
| HIGH   | > 6e-5        | High volatility     |

---

## Notes for FPGA Deployment (Kria KV260)
- Use Vivado 2022.1 for synthesis
- Target clock: 100 MHz (from PS via ZYNQ block)
- DSP slices: ~10 used (1.2K available — plenty of headroom)
- BRAM: ~2 used for vol_window buffer (144 available)
