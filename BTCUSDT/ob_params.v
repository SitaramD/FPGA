// ============================================================
// ob_params.v — Global Parameters
// SITARAM BTCUSDT Order Book Processor
// Target: Kria KV260 (100 MHz PL clock)
// Fixed-point: 32-bit [19:12] integer, [11:0] fraction (x10 scaled)
// Price example: $66970.6 → stored as 669706 (scaled x10)
// Qty example:   0.055649 → stored as 55649  (scaled x1000000)
// ============================================================

// Fixed-point scaling
`define PRICE_SCALE     10          // 1 decimal place → multiply by 10
`define QTY_SCALE       1000000     // 6 decimal places → multiply by 1000000

// Number of orderbook levels
`define OB_LEVELS       200         // Total bid/ask levels
`define OBI_LEVELS      5           // Top 5 for OBI calculation

// Volatility window
`define VOL_WINDOW      50          // 50-tick rolling window

// Regime thresholds (scaled for fixed-point)
// REGIME_VOL_THRESHOLD = 6e-5 in engine.py
// In our scaled arithmetic (x10^12): 6e-5 * 10^12 = 60,000,000
`define REGIME_LOW_THRESH    20000000   // < 2e-5  → LOW
`define REGIME_HIGH_THRESH   60000000   // > 6e-5  → HIGH
                                        // between → MEDIUM

// Regime flags
`define REGIME_LOW      2'b00
`define REGIME_MEDIUM   2'b01
`define REGIME_HIGH     2'b10

// Data widths
`define PRICE_W         32          // Price width in bits
`define QTY_W           32          // Quantity width in bits
`define ACC_W           64          // Accumulator width (prevent overflow)
`define VOL_W           64          // Volatility accumulator
