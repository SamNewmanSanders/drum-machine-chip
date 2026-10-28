// PWM: a free running 8 bit counter, and an output that is high while the counter is below duty.
`default_nettype none

module ip_pwm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] duty,
    output wire       out
);
    reg [7:0] counter;

    assign out = counter < duty;

    always @(posedge clk) begin
        if (!rst_n) counter <= 8'd0;
        else        counter <= counter + 8'd1;
    end
endmodule
