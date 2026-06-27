// ============================================================
// ob_processor.v — Top-Level Order Book Processor
// SITARAM BTCUSDT Order Book Processor
//
// Fixed for ModelSim 10.5b — no array ports
// Uses flattened bus: 200 prices packed into one wide bus
// bid_price_bus = {bid_price[199], ..., bid_price[0]}
// each price = 32 bits → total = 200*32 = 6400 bits
//
// Clock: 100 MHz (Kria KV260 PL)
// ============================================================
`include "ob_params.v"

module ob_processor (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     tick_valid,

    // Flattened bid bus: 200 x 32-bit prices & quantities
    input  wire [200*32-1:0]        bid_price_bus,
    input  wire [200*32-1:0]        bid_qty_bus,

    // Flattened ask bus: 200 x 32-bit prices & quantities
    input  wire [200*32-1:0]        ask_price_bus,
    input  wire [200*32-1:0]        ask_qty_bus,

    // Outputs
    output wire signed [31:0]       obi_out,
    output wire [`VOL_W-1:0]        vol_out,
    output wire [1:0]               regime_out,
    output wire                     obi_valid,
    output wire                     vol_valid
);

    // ── Extract top-5 bid quantities from flattened bus ───────────────────
    wire [`QTY_W-1:0] bid_qty_0 = bid_qty_bus[1*32-1 : 0*32];
    wire [`QTY_W-1:0] bid_qty_1 = bid_qty_bus[2*32-1 : 1*32];
    wire [`QTY_W-1:0] bid_qty_2 = bid_qty_bus[3*32-1 : 2*32];
    wire [`QTY_W-1:0] bid_qty_3 = bid_qty_bus[4*32-1 : 3*32];
    wire [`QTY_W-1:0] bid_qty_4 = bid_qty_bus[5*32-1 : 4*32];

    // ── Extract top-5 ask quantities from flattened bus ───────────────────
    wire [`QTY_W-1:0] ask_qty_0 = ask_qty_bus[1*32-1 : 0*32];
    wire [`QTY_W-1:0] ask_qty_1 = ask_qty_bus[2*32-1 : 1*32];
    wire [`QTY_W-1:0] ask_qty_2 = ask_qty_bus[3*32-1 : 2*32];
    wire [`QTY_W-1:0] ask_qty_3 = ask_qty_bus[4*32-1 : 3*32];
    wire [`QTY_W-1:0] ask_qty_4 = ask_qty_bus[5*32-1 : 4*32];

    // ── Extract best bid and ask prices (index 0) ─────────────────────────
    wire [`PRICE_W-1:0] best_bid = bid_price_bus[1*32-1 : 0*32];
    wire [`PRICE_W-1:0] best_ask = ask_price_bus[1*32-1 : 0*32];

    // ── OBI Calculator ────────────────────────────────────────────────────
    obi_calculator u_obi (
        .clk        (clk),
        .rst_n      (rst_n),
        .valid_in   (tick_valid),
        .bid_qty_0  (bid_qty_0),
        .bid_qty_1  (bid_qty_1),
        .bid_qty_2  (bid_qty_2),
        .bid_qty_3  (bid_qty_3),
        .bid_qty_4  (bid_qty_4),
        .ask_qty_0  (ask_qty_0),
        .ask_qty_1  (ask_qty_1),
        .ask_qty_2  (ask_qty_2),
        .ask_qty_3  (ask_qty_3),
        .ask_qty_4  (ask_qty_4),
        .obi_out    (obi_out),
        .valid_out  (obi_valid)
    );

    // ── Volatility Calculator ─────────────────────────────────────────────
    vol_calculator u_vol (
        .clk        (clk),
        .rst_n      (rst_n),
        .valid_in   (tick_valid),
        .best_bid   (best_bid),
        .best_ask   (best_ask),
        .vol_scaled (vol_out),
        .regime     (regime_out),
        .valid_out  (vol_valid)
    );

endmodule
