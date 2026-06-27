// ============================================================
// obi_calculator.v — Order Book Imbalance Calculator
// SITARAM BTCUSDT Order Book Processor
//
// Formula:
//   OBI = (sum_bid_qty[0:4] - sum_ask_qty[0:4]) /
//         (sum_bid_qty[0:4] + sum_ask_qty[0:4])
//
// Result: signed 32-bit fixed-point, range [-1.0, +1.0]
//         scaled as integer * 10000 (4 decimal places)
//         e.g. OBI=+0.3245 → obi_out = +3245
//
// Computed in 1 clock cycle (combinational adders + divider reg)
// Clock: 100 MHz (Kria KV260 PL)
// ============================================================
`include "ob_params.v"

module obi_calculator (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 valid_in,       // pulse: new tick arrived

    // Top 5 bid quantities (scaled x1000000)
    input  wire [`QTY_W-1:0]   bid_qty_0,
    input  wire [`QTY_W-1:0]   bid_qty_1,
    input  wire [`QTY_W-1:0]   bid_qty_2,
    input  wire [`QTY_W-1:0]   bid_qty_3,
    input  wire [`QTY_W-1:0]   bid_qty_4,

    // Top 5 ask quantities (scaled x1000000)
    input  wire [`QTY_W-1:0]   ask_qty_0,
    input  wire [`QTY_W-1:0]   ask_qty_1,
    input  wire [`QTY_W-1:0]   ask_qty_2,
    input  wire [`QTY_W-1:0]   ask_qty_3,
    input  wire [`QTY_W-1:0]   ask_qty_4,

    output reg  signed [31:0]  obi_out,        // OBI x10000, signed
    output reg                  valid_out       // result valid flag
);

    // ── Combinational sum of top-5 bids and asks ──────────────────────────
    wire [`ACC_W-1:0] sum_bid = bid_qty_0 + bid_qty_1 + bid_qty_2
                              + bid_qty_3 + bid_qty_4;

    wire [`ACC_W-1:0] sum_ask = ask_qty_0 + ask_qty_1 + ask_qty_2
                              + ask_qty_3 + ask_qty_4;

    wire [`ACC_W-1:0] total   = sum_bid + sum_ask;
    wire [`ACC_W-1:0] diff    = sum_bid - sum_ask;  // can be negative

    // ── Register result on clock edge ────────────────────────────────────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            obi_out   <= 32'sd0;
            valid_out <= 1'b0;
        end else if (valid_in) begin
            if (total == 0) begin
                obi_out   <= 32'sd0;
            end else begin
                // OBI = diff/total scaled to x10000
                // Use 64-bit to prevent overflow: diff*10000 / total
                obi_out   <= $signed(($signed({{32{diff[`ACC_W-1]}}, diff}) * 64'sd10000)
                             / $signed({32'b0, total}));
            end
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
