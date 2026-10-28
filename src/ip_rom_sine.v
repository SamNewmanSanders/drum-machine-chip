// Sine lookup tables (ROMs) at three resolutions, all centred on 128 and swinging 1 to 255.
//   ip_rom_sine64 - 64 samples, addr = phase[15:10]  (used by the kick)
//   ip_rom_sine32 - 32 samples, addr = phase[15:11]  (used by the snare)
//   ip_rom_sine16 - 16 samples, addr = phase[15:12]  (available; no voice uses it yet)
`default_nettype none

// -----------------------------------------------------------------------------
// 64-entry sine ROM
// -----------------------------------------------------------------------------
module ip_rom_sine64 (
    input  wire [5:0] addr,
    output reg  [7:0] data
);
    always @(*) begin
        case (addr)
            6'd0:  data = 8'd128;
            6'd1:  data = 8'd140;
            6'd2:  data = 8'd153;
            6'd3:  data = 8'd165;
            6'd4:  data = 8'd177;
            6'd5:  data = 8'd188;
            6'd6:  data = 8'd199;
            6'd7:  data = 8'd209;
            6'd8:  data = 8'd218;
            6'd9:  data = 8'd226;
            6'd10: data = 8'd234;
            6'd11: data = 8'd240;
            6'd12: data = 8'd245;
            6'd13: data = 8'd250;
            6'd14: data = 8'd253;
            6'd15: data = 8'd254;
            6'd16: data = 8'd255;
            6'd17: data = 8'd254;
            6'd18: data = 8'd253;
            6'd19: data = 8'd250;
            6'd20: data = 8'd245;
            6'd21: data = 8'd240;
            6'd22: data = 8'd234;
            6'd23: data = 8'd226;
            6'd24: data = 8'd218;
            6'd25: data = 8'd209;
            6'd26: data = 8'd199;
            6'd27: data = 8'd188;
            6'd28: data = 8'd177;
            6'd29: data = 8'd165;
            6'd30: data = 8'd153;
            6'd31: data = 8'd140;
            6'd32: data = 8'd128;
            6'd33: data = 8'd116;
            6'd34: data = 8'd103;
            6'd35: data = 8'd91;
            6'd36: data = 8'd79;
            6'd37: data = 8'd68;
            6'd38: data = 8'd57;
            6'd39: data = 8'd47;
            6'd40: data = 8'd38;
            6'd41: data = 8'd30;
            6'd42: data = 8'd22;
            6'd43: data = 8'd16;
            6'd44: data = 8'd11;
            6'd45: data = 8'd6;
            6'd46: data = 8'd3;
            6'd47: data = 8'd2;
            6'd48: data = 8'd1;
            6'd49: data = 8'd2;
            6'd50: data = 8'd3;
            6'd51: data = 8'd6;
            6'd52: data = 8'd11;
            6'd53: data = 8'd16;
            6'd54: data = 8'd22;
            6'd55: data = 8'd30;
            6'd56: data = 8'd38;
            6'd57: data = 8'd47;
            6'd58: data = 8'd57;
            6'd59: data = 8'd68;
            6'd60: data = 8'd79;
            6'd61: data = 8'd91;
            6'd62: data = 8'd103;
            6'd63: data = 8'd116;
            default: data = 8'd128;
        endcase
    end
endmodule

// -----------------------------------------------------------------------------
// 32-entry sine ROM (every 2nd sample of the 64-entry table)
// -----------------------------------------------------------------------------
module ip_rom_sine32 (
    input  wire [4:0] addr,
    output reg  [7:0] data
);
    always @(*) begin
        case (addr)
            5'd0:  data = 8'd128;
            5'd1:  data = 8'd153;
            5'd2:  data = 8'd177;
            5'd3:  data = 8'd199;
            5'd4:  data = 8'd218;
            5'd5:  data = 8'd234;
            5'd6:  data = 8'd245;
            5'd7:  data = 8'd253;
            5'd8:  data = 8'd255;
            5'd9:  data = 8'd253;
            5'd10: data = 8'd245;
            5'd11: data = 8'd234;
            5'd12: data = 8'd218;
            5'd13: data = 8'd199;
            5'd14: data = 8'd177;
            5'd15: data = 8'd153;
            5'd16: data = 8'd128;
            5'd17: data = 8'd103;
            5'd18: data = 8'd79;
            5'd19: data = 8'd57;
            5'd20: data = 8'd38;
            5'd21: data = 8'd22;
            5'd22: data = 8'd11;
            5'd23: data = 8'd3;
            5'd24: data = 8'd1;
            5'd25: data = 8'd3;
            5'd26: data = 8'd11;
            5'd27: data = 8'd22;
            5'd28: data = 8'd38;
            5'd29: data = 8'd57;
            5'd30: data = 8'd79;
            5'd31: data = 8'd103;
            default: data = 8'd128;
        endcase
    end
endmodule

// -----------------------------------------------------------------------------
// 16-entry sine ROM (every 4th sample of the 64-entry table).
// -----------------------------------------------------------------------------
module ip_rom_sine16 (
    input  wire [3:0] addr,
    output reg  [7:0] data
);
    always @(*) begin
        case (addr)
            4'd0:  data = 8'd128;
            4'd1:  data = 8'd177;
            4'd2:  data = 8'd218;
            4'd3:  data = 8'd245;
            4'd4:  data = 8'd255;
            4'd5:  data = 8'd245;
            4'd6:  data = 8'd218;
            4'd7:  data = 8'd177;
            4'd8:  data = 8'd128;
            4'd9:  data = 8'd79;
            4'd10: data = 8'd38;
            4'd11: data = 8'd11;
            4'd12: data = 8'd1;
            4'd13: data = 8'd11;
            4'd14: data = 8'd38;
            4'd15: data = 8'd79;
            default: data = 8'd128;
        endcase
    end
endmodule


`default_nettype wire
