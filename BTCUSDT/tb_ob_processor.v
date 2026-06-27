// ============================================================
// tb_ob_processor.v — SITARAM OB Processor Testbench
// Debug version: displays every tick regardless of valid
// ============================================================
`include "ob_params.v"
`timescale 1ns/1ps

module tb_ob_processor;

    reg clk   = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;

    reg [200*32-1:0] bid_price_bus;
    reg [200*32-1:0] bid_qty_bus;
    reg [200*32-1:0] ask_price_bus;
    reg [200*32-1:0] ask_qty_bus;
    reg              tick_valid;

    reg [31:0] bid_price [0:199];
    reg [31:0] bid_qty   [0:199];
    reg [31:0] ask_price [0:199];
    reg [31:0] ask_qty   [0:199];

    wire signed [31:0]  obi_out;
    wire [`VOL_W-1:0]   vol_out;
    wire [1:0]          regime_out;
    wire                obi_valid;
    wire                vol_valid;

    ob_processor dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .tick_valid    (tick_valid),
        .bid_price_bus (bid_price_bus),
        .bid_qty_bus   (bid_qty_bus),
        .ask_price_bus (ask_price_bus),
        .ask_qty_bus   (ask_qty_bus),
        .obi_out       (obi_out),
        .vol_out       (vol_out),
        .regime_out    (regime_out),
        .obi_valid     (obi_valid),
        .vol_valid     (vol_valid)
    );

    integer k;
    task pack_buses;
        begin
            for (k = 0; k < 200; k = k + 1) begin
                bid_price_bus[k*32 +: 32] = bid_price[k];
                bid_qty_bus  [k*32 +: 32] = bid_qty[k];
                ask_price_bus[k*32 +: 32] = ask_price[k];
                ask_qty_bus  [k*32 +: 32] = ask_qty[k];
            end
        end
    endtask

    integer fd;
    integer tick_num, i, scan_ret;
    reg [31:0] tmp_price, tmp_qty;
    reg [8*4-1:0] token;
    reg done;
    integer obi_int, obi_frac;
    reg [47:0] regime_str;

    initial begin
        tick_valid    = 0;
        bid_price_bus = 0;
        bid_qty_bus   = 0;
        ask_price_bus = 0;
        ask_qty_bus   = 0;
        done          = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        $display("==============================================");
        $display("  SITARAM BTCUSDT OB PROCESSOR - LIVE FEED");
        $display("  Clock: 100MHz | OBI: Top-5 | Vol: 50 ticks");
        $display("==============================================");

        fd = $fopen("input_pipe.txt", "r");
        if (fd == 0) begin
            $display("ERROR: Cannot open input_pipe.txt");
            $finish;
        end

        $display("File opened OK");
        tick_num = 0;

        while (!$feof(fd) && !done) begin
            scan_ret = $fscanf(fd, "%s", token);
            if (scan_ret != 1) begin
                done = 1;
            end else if (token == "TICK") begin
                scan_ret = $fscanf(fd, "%d", tick_num);

                for (i = 0; i < 200; i = i + 1) begin
                    scan_ret = $fscanf(fd, "%s %d %d",
                                       token, tmp_price, tmp_qty);
                    bid_price[i] = tmp_price;
                    bid_qty[i]   = tmp_qty;
                end

                for (i = 0; i < 200; i = i + 1) begin
                    scan_ret = $fscanf(fd, "%s %d %d",
                                       token, tmp_price, tmp_qty);
                    ask_price[i] = tmp_price;
                    ask_qty[i]   = tmp_qty;
                end

                scan_ret = $fscanf(fd, "%s", token); // END
                pack_buses;

                // Apply tick
                @(posedge clk);
                tick_valid = 1;
                @(posedge clk);
                tick_valid = 0;
                @(posedge clk);
                @(posedge clk);
                #1;

                // Display every tick — no valid check
                case (regime_out)
                    2'b00: regime_str = "LOW   ";
                    2'b01: regime_str = "MEDIUM";
                    2'b10: regime_str = "HIGH  ";
                    default: regime_str = "???   ";
                endcase

                if ($signed(obi_out) < 0) begin
                    obi_int  = (-$signed(obi_out)) / 10000;
                    obi_frac = (-$signed(obi_out)) % 10000;
                end else begin
                    obi_int  = $signed(obi_out) / 10000;
                    obi_frac = $signed(obi_out) % 10000;
                end

                $display("==============================================");
                $display("  TICK #%0d  [obi_v=%b vol_v=%b]",
                          tick_num, obi_valid, vol_valid);
                $display("  Bid: $%0d.%0d  Ask: $%0d.%0d  Spread: $%0d.%0d",
                          bid_price[0]/`PRICE_SCALE,
                          bid_price[0]%`PRICE_SCALE,
                          ask_price[0]/`PRICE_SCALE,
                          ask_price[0]%`PRICE_SCALE,
                          (ask_price[0]-bid_price[0])/`PRICE_SCALE,
                          (ask_price[0]-bid_price[0])%`PRICE_SCALE);
                if ($signed(obi_out) < 0)
                    $display("  OBI: -%0d.%04d [SELL pressure]",
                              obi_int, obi_frac);
                else
                    $display("  OBI: +%0d.%04d [BUY  pressure]",
                              obi_int, obi_frac);
                if (vol_valid)
                    $display("  Vol: %0d  Regime: %s", vol_out, regime_str);
                else
                    $display("  Vol: warming up (%0d ticks collected, need 50)...", tick_num);
                $display("==============================================");
                $display("");

                repeat(2) @(posedge clk);
            end
        end

        $fclose(fd);
        $display("==============================================");
        $display("  Done - Total ticks: %0d", tick_num);
        $display("==============================================");
        $finish;
    end

    initial begin
        #500_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
