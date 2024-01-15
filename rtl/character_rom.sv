/*
 * ROM with bitmap data for characters from the numbers 0 to 9
 * and also a smiley as number 10
 */
module character_rom (
    input  [3:0] number,
    input  [2:0] line,
    output [7:0] charline
);

    bit  [7:0] memout;
    wire [6:0] address = {number, line};

    // reverse order of bits to fit to screen coordinates
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : g_charlines
            assign charline[i] = memout[7-i];
        end
    endgenerate

    always_comb begin
        case (address)
            0: memout = 8'b01111110;
            1: memout = 8'b10000101;
            2: memout = 8'b10001001;
            3: memout = 8'b10010001;
            4: memout = 8'b10100001;
            5: memout = 8'b11000001;
            6: memout = 8'b01111110;
            7: memout = 0;

            8:  memout = 8'b00001000;
            9:  memout = 8'b00011000;
            10: memout = 8'b00101000;
            11: memout = 8'b00001000;
            12: memout = 8'b00001000;
            13: memout = 8'b00001000;
            14: memout = 8'b00111110;
            15: memout = 0;

            16: memout = 8'b01111110;
            17: memout = 8'b10000001;
            18: memout = 8'b00000001;
            19: memout = 8'b01111110;
            20: memout = 8'b10000000;
            21: memout = 8'b10000000;
            22: memout = 8'b11111111;
            23: memout = 0;

            24: memout = 8'b11111110;
            25: memout = 8'b00000001;
            26: memout = 8'b00000001;
            27: memout = 8'b01111111;
            28: memout = 8'b00000001;
            29: memout = 8'b00000001;
            30: memout = 8'b11111110;
            31: memout = 0;

            32: memout = 8'b10000001;
            33: memout = 8'b10000001;
            34: memout = 8'b10000001;
            35: memout = 8'b01111111;
            36: memout = 8'b00000001;
            37: memout = 8'b00000001;
            38: memout = 8'b00000001;
            39: memout = 0;

            40: memout = 8'b11111111;
            41: memout = 8'b10000000;
            42: memout = 8'b10000000;
            43: memout = 8'b11111110;
            44: memout = 8'b00000001;
            45: memout = 8'b00000001;
            46: memout = 8'b11111110;
            47: memout = 0;

            48: memout = 8'b01111110;
            49: memout = 8'b10000000;
            50: memout = 8'b10000000;
            51: memout = 8'b11111110;
            52: memout = 8'b10000001;
            53: memout = 8'b10000001;
            54: memout = 8'b01111110;
            55: memout = 0;

            56: memout = 8'b11111111;
            57: memout = 8'b00000010;
            58: memout = 8'b00000100;
            59: memout = 8'b00111110;
            60: memout = 8'b00010000;
            61: memout = 8'b00100000;
            62: memout = 8'b01000000;
            63: memout = 0;

            64: memout = 8'b01111110;
            65: memout = 8'b10000001;
            66: memout = 8'b10000001;
            67: memout = 8'b01111110;
            68: memout = 8'b10000001;
            69: memout = 8'b10000001;
            70: memout = 8'b01111110;
            71: memout = 0;

            72: memout = 8'b01111110;
            73: memout = 8'b10000001;
            74: memout = 8'b10000001;
            75: memout = 8'b01111111;
            76: memout = 8'b00000001;
            77: memout = 8'b00000001;
            78: memout = 8'b01111110;
            79: memout = 0;

            80: memout = 8'b01111110;
            81: memout = 8'b10000001;
            82: memout = 8'b10100101;
            83: memout = 8'b10000001;
            84: memout = 8'b10100101;
            85: memout = 8'b10011001;
            86: memout = 8'b10000001;
            87: memout = 8'b01111110;

            default: memout = 8'b11111111;
        endcase
    end

endmodule
