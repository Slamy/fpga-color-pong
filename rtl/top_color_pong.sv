import common::*;

module top_color_pong (
    input clk27,
    input switch1,
    input switch2,
    output bit [7:0] video,
    output bit [7:6] video_extra,
    input uart_rx,
    output uart_tx,
    output bit [5:0] led,
    inout paddle0_measure_and_drain,
    inout paddle1_measure_and_drain,
    output debug
)  /* synthesis syn_netlist_hierarchy=0 */;

    wire clk  /*verilator public_flat_rw*/;
    wire video_overflow;

    assign video_extra[7:6] = video[7:6];
    assign led[0] = !video_overflow;

`ifndef VERILATOR
    Gowin_rPLL pll (
        .clkout(clk),  //output clkout
        .lock(lock_o),  //output lock
        .clkin(clk27)  //input clkin
    );
`endif

    debug_bus_if dbus (clk);

    // We are always ready to answer. Must be here to avoid removal of TX UART
    assign dbus.slave.ready = 1;

    uart_busmaster uart_db (
        .clk,
        .uart_rx,
        .uart_tx,
        .dbus(dbus.master)
    );


    localparam bit [8:0] NumberOfLines_50HZ = 312;
    localparam bit [8:0] NumberOfLines_60HZ = 262;
    localparam bit [8:0] NumberOfVisibleLines_50HZ = 256;
    localparam bit [8:0] NumberOfVisibleLines_60HZ = 200;

    bit sync;
    bit newline;
    bit newframe;
    bit newpixel;
    bit qam_startburst;
    bit [8:0] video_y;
    bit [12:0] video_x;
    bit visible_line;
    bit visible_window;
    bit [8:0] v_total = NumberOfLines_50HZ;
    bit [8:0] v_active = NumberOfVisibleLines_50HZ;
    bit even_field;
    bit interlacing_enable = 0;

    video_timing video_timing0 (
        .clk(clk),
        .v_total(v_total),
        .v_active(v_active),
        .interlacing_enable,
        .sync(sync),
        .newline(newline),
        .newframe(newframe),
        .newpixel(newpixel),
        .startburst(qam_startburst),
        .video_x(video_x),
        .video_y(video_y),

        .visible_line  (visible_line),
        .visible_window(visible_window),
        .even_field
    );

    video_standard_e video_standard = PAL;
    bit switch1_q = 0;
    bit switch1_q2 = 0;
    bit switch2_q = 0;
    bit switch2_q2 = 0;
    always_ff @(posedge clk) begin
        switch1_q  <= switch1;
        switch1_q2 <= switch1_q;
        switch2_q  <= switch2;
        switch2_q2 <= switch2_q;
        // We are not allowed to work with the external signal directly
        // because of metastability!
        if (!switch1_q && switch1_q2) begin
            case (video_standard)
                PAL: begin
                    video_standard <= NTSC;
                    v_total <= NumberOfLines_60HZ;
                    v_active <= NumberOfVisibleLines_60HZ;
                end
                NTSC: begin
                    video_standard <= SECAM;
                    v_total <= NumberOfLines_50HZ;
                    v_active <= NumberOfVisibleLines_50HZ;
                end
                SECAM:   video_standard <= PAL;
                default: video_standard <= PAL;
            endcase
        end
    end

    assign led[5] = !(video_standard == PAL);
    assign led[4] = !(video_standard == NTSC);
    assign led[3] = !(video_standard == SECAM);

    ycbcr_t cvbs_in;

    composite_video_encoder cvbs (
        .clk,
        .sync(sync),
        .newframe,
        .newline,
        .secam_enabled(video_y > 7),
        .qam_startburst,
        .video_standard,
        .in(cvbs_in),
        .video,
        .video_overflow,
        .dbus
    );

    wire paddle0_drain_capacitance;
    wire paddle0_measure;
    bit [7:0] paddle0_temp_val;
    bit [7:0] paddle0_filtered_val;
    wire paddle0_value_available;

    wire paddle1_drain_capacitance;
    wire paddle1_measure;
    bit [7:0] paddle1_temp_val;
    bit [7:0] paddle1_filtered_val;
    wire paddle1_value_available;


`ifndef VERILATOR
    /*
     * This is ugly but I don't know how to do this otherwise.
     * With Xilinx ISE I can implement tristate IO using RTL,
     * but with GOWIN EDA this is not possible as it seems and I have to
     * instantiate an IOBUF here.
     *
     * If paddle*_drain_capacitance is set, the pad must be dragged to ground.
     * If not, we would like to measure the pin and deliver that state
     * to the sensing circuit.
     */

    IOBUF paddle0io (
        .O  (paddle0_measure),
        .IO (paddle0_measure_and_drain),
        .I  (0),
        .OEN(!paddle0_drain_capacitance)
    );

    IOBUF paddle1io (
        .O  (paddle1_measure),
        .IO (paddle1_measure_and_drain),
        .I  (0),
        .OEN(!paddle1_drain_capacitance)
    );
`endif

    resistor_measure paddle0 (
        .clk,
        .measure(paddle0_measure),
        .drain_capacitance(paddle0_drain_capacitance),
        .value(paddle0_temp_val),
        .value_available(paddle0_value_available)
    );

    resistor_measure paddle1 (
        .clk,
        .measure(paddle1_measure),
        .drain_capacitance(paddle1_drain_capacitance),
        .value(paddle1_temp_val),
        .value_available(paddle1_value_available)
    );

    window_avg paddle0_filt (
        .clk,
        .in(paddle0_temp_val),
        .in_latch(paddle0_value_available),
        .out(paddle0_filtered_val)
    );

    window_avg paddle1_filt (
        .clk,
        .in(paddle1_temp_val),
        .in_latch(paddle1_value_available),
        .out(paddle1_filtered_val)
    );

    // The game itself
    pong_game game (
        .clk,
        .reset(!switch2_q2),
        .video_y,
        .video_x,
        .v_active(v_active),
        .newline,
        .newframe,
        .newpixel,
        .visible_window,
        .paddle0(paddle0_filtered_val),
        .paddle1(paddle1_filtered_val),
        .paddle0_button(0),
        .paddle1_button(0),
        .ycbcr_out(cvbs_in)
    );

endmodule
