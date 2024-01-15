/*
 * Averaging window filter
 */
module window_avg (
    input clk,
    input [7:0] in,
    input in_latch,
    output bit [7:0] out
);
    bit [7:0] storage[32];

    bit [4:0] read_adr;
    bit [4:0] write_adr;

    bit [15:0] sum;

    always @(posedge clk) begin
        if (in_latch) begin
            storage[write_adr] <= in;
            write_adr <= write_adr + 1;
        end

        if (read_adr == 0) begin
            out <= 8'((sum + 16'(storage[read_adr])) >> 5);
            sum <= 0;
        end else begin
            sum <= sum + 16'(storage[read_adr]);
        end
        read_adr <= read_adr + 1;
    end
endmodule
