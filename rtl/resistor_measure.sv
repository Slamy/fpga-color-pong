/*
 * Sensing state machine to get a resistor value by measuring the time
 * it takes to charge a capacitor.
 * It is advised to have input hysteris enabled.
 */
module resistor_measure (
    input clk,
    input measure,  // Input state of the capacitor
    output bit drain_capacitance,  // Set to 1 if capacitor shall be discharged
    output bit [7:0] value,  // The measured sample
    output bit value_available  // Flag when new sample is available
);
    localparam int HighestBit = 15;

    bit [HighestBit:0] cnt = 0;
    bit [3:0] captured = 0;
    bit [7:0] sample = 0;

    bit measuring_q;
    wire measuring_d = !cnt[HighestBit];
    assign value_available = !measuring_q && measuring_d;

    always_ff @(posedge clk) begin

        // drain only half as long as measure cycle
        if (cnt[HighestBit] && cnt[HighestBit-1]) cnt <= 0;
        else cnt <= cnt + 1;

        measuring_q <= measuring_d;

        if (captured != 5 && measure && measuring_d && measuring_q) begin

            if (measure) begin
                captured <= captured + 1;
                value <= cnt[HighestBit-1:HighestBit-8];
            end else captured <= 0;

        end else if (!measuring_q && measuring_d) begin
            //$display("value %d %d", value, accumulator);
            captured <= 0;
            value <= 255;  // prepare default max value in case measure doesn't have a positive edge
        end

        drain_capacitance <= !measuring_d;
    end

endmodule
