// ============================================================
// vol_calculator.v — Volatility Calculator Final Fix
// valid_out stays high once buffer is full
// ============================================================
`include "ob_params.v"

module vol_calculator (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 valid_in,
    input  wire [`PRICE_W-1:0] best_bid,
    input  wire [`PRICE_W-1:0] best_ask,
    output reg  [`VOL_W-1:0]   vol_scaled,
    output reg  [1:0]           regime,
    output reg                  valid_out
);

    wire [32:0] mid_price = ({1'b0,best_bid} + {1'b0,best_ask}) >> 1;

    reg signed [32:0] mid_buf    [0:49];
    reg signed [32:0] return_buf [0:49];
    reg [7:0]  tick_count;
    reg [5:0]  ptr;

    reg signed [`VOL_W-1:0] sum_sq;
    reg [`VOL_W-1:0] variance;
    reg [`VOL_W-1:0] vol_result;
    integer i;

    function [`VOL_W-1:0] isqrt;
        input [`VOL_W-1:0] n;
        reg [`VOL_W-1:0] x, x_next;
        integer j;
        begin
            if (n == 0) begin
                isqrt = 0;
            end else begin
                x = n >> 1;
                if (x == 0) x = 1;
                for (j = 0; j < 32; j = j + 1) begin
                    x_next = (x + n/x) >> 1;
                    if (x_next >= x) j = 32;
                    else x = x_next;
                end
                isqrt = x;
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_count <= 8'd0;
            ptr        <= 6'd0;
            vol_scaled <= 64'd0;
            regime     <= `REGIME_LOW;
            valid_out  <= 1'b0;
            for (i = 0; i < 50; i = i + 1) begin
                mid_buf[i]    <= 33'sd0;
                return_buf[i] <= 33'sd0;
            end
        end else if (valid_in) begin

            // Compute return vs previous mid
            if (tick_count > 8'd0) begin
                if (ptr == 6'd0)
                    return_buf[0] <= $signed({1'b0,mid_price})
                                   - mid_buf[49];
                else
                    return_buf[ptr] <= $signed({1'b0,mid_price})
                                     - mid_buf[ptr-1];
            end else begin
                return_buf[0] <= 33'sd0;
            end

            // Store current mid
            mid_buf[ptr] <= $signed({1'b0,mid_price});

            // Advance pointer
            if (ptr == 6'd49)
                ptr <= 6'd0;
            else
                ptr <= ptr + 6'd1;

            // Count ticks
            if (tick_count < 8'd255)
                tick_count <= tick_count + 8'd1;

            // Compute vol after 50 ticks
            if (tick_count >= 8'd50) begin
                sum_sq = 64'sd0;
                for (i = 0; i < 50; i = i + 1)
                    sum_sq = sum_sq + (return_buf[i] * return_buf[i]);

                if (sum_sq < 0)
                    variance = 64'd0;
                else
                    variance = sum_sq[63:0] / 64'd50;

                vol_result = isqrt(variance);
                vol_scaled <= vol_result;

                if (vol_result < 64'd20000000)
                    regime <= `REGIME_LOW;
                else if (vol_result < 64'd60000000)
                    regime <= `REGIME_MEDIUM;
                else
                    regime <= `REGIME_HIGH;

                // Stay valid once buffer is full
                valid_out <= 1'b1;
            end
            // Note: do NOT clear valid_out here when tick_count < 50
            // valid_out stays 0 until first time tick_count >= 50
        end
        // Note: do NOT clear valid_out on !valid_in
        // once valid, stays valid between ticks
    end

endmodule
