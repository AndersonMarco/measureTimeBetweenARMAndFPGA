// (C) 2001-2016 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.



// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// $Id: //acds/rel/16.1/ip/merlin/altera_merlin_router/altera_merlin_router.sv.terp#1 $
// $Revision: #1 $
// $Date: 2016/08/07 $
// $Author: swbranch $

// -------------------------------------------------------
// Merlin Router
//
// Asserts the appropriate one-hot encoded channel based on 
// either (a) the address or (b) the dest id. The DECODER_TYPE
// parameter controls this behaviour. 0 means address decoder,
// 1 means dest id decoder.
//
// In the case of (a), it also sets the destination id.
// -------------------------------------------------------

`timescale 1 ns / 1 ns

module soc_system_mm_interconnect_0_router_default_decode
  #(
     parameter DEFAULT_CHANNEL = 0,
               DEFAULT_WR_CHANNEL = -1,
               DEFAULT_RD_CHANNEL = -1,
               DEFAULT_DESTID = 15 
   )
  (output [95 - 91 : 0] default_destination_id,
   output [32-1 : 0] default_wr_channel,
   output [32-1 : 0] default_rd_channel,
   output [32-1 : 0] default_src_channel
  );

  assign default_destination_id = 
    DEFAULT_DESTID[95 - 91 : 0];

  generate
    if (DEFAULT_CHANNEL == -1) begin : no_default_channel_assignment
      assign default_src_channel = '0;
    end
    else begin : default_channel_assignment
      assign default_src_channel = 32'b1 << DEFAULT_CHANNEL;
    end
  endgenerate

  generate
    if (DEFAULT_RD_CHANNEL == -1) begin : no_default_rw_channel_assignment
      assign default_wr_channel = '0;
      assign default_rd_channel = '0;
    end
    else begin : default_rw_channel_assignment
      assign default_wr_channel = 32'b1 << DEFAULT_WR_CHANNEL;
      assign default_rd_channel = 32'b1 << DEFAULT_RD_CHANNEL;
    end
  endgenerate

endmodule


module soc_system_mm_interconnect_0_router
(
    // -------------------
    // Clock & Reset
    // -------------------
    input clk,
    input reset,

    // -------------------
    // Command Sink (Input)
    // -------------------
    input                       sink_valid,
    input  [120-1 : 0]    sink_data,
    input                       sink_startofpacket,
    input                       sink_endofpacket,
    output                      sink_ready,

    // -------------------
    // Command Source (Output)
    // -------------------
    output                          src_valid,
    output reg [120-1    : 0] src_data,
    output reg [32-1 : 0] src_channel,
    output                          src_startofpacket,
    output                          src_endofpacket,
    input                           src_ready
);

    // -------------------------------------------------------
    // Local parameters and variables
    // -------------------------------------------------------
    localparam PKT_ADDR_H = 56;
    localparam PKT_ADDR_L = 36;
    localparam PKT_DEST_ID_H = 95;
    localparam PKT_DEST_ID_L = 91;
    localparam PKT_PROTECTION_H = 110;
    localparam PKT_PROTECTION_L = 108;
    localparam ST_DATA_W = 120;
    localparam ST_CHANNEL_W = 32;
    localparam DECODER_TYPE = 0;

    localparam PKT_TRANS_WRITE = 59;
    localparam PKT_TRANS_READ  = 60;

    localparam PKT_ADDR_W = PKT_ADDR_H-PKT_ADDR_L + 1;
    localparam PKT_DEST_ID_W = PKT_DEST_ID_H-PKT_DEST_ID_L + 1;



    // -------------------------------------------------------
    // Figure out the number of bits to mask off for each slave span
    // during address decoding
    // -------------------------------------------------------
    localparam PAD0 = log2ceil(64'h10080 - 64'h10070); 
    localparam PAD1 = log2ceil(64'h10090 - 64'h10080); 
    localparam PAD2 = log2ceil(64'h100a0 - 64'h10090); 
    localparam PAD3 = log2ceil(64'h100b0 - 64'h100a0); 
    localparam PAD4 = log2ceil(64'h100c0 - 64'h100b0); 
    localparam PAD5 = log2ceil(64'h100d0 - 64'h100c0); 
    localparam PAD6 = log2ceil(64'h100e0 - 64'h100d0); 
    localparam PAD7 = log2ceil(64'h100f0 - 64'h100e0); 
    localparam PAD8 = log2ceil(64'h10100 - 64'h100f0); 
    localparam PAD9 = log2ceil(64'h10110 - 64'h10100); 
    localparam PAD10 = log2ceil(64'h10120 - 64'h10110); 
    localparam PAD11 = log2ceil(64'h10130 - 64'h10120); 
    localparam PAD12 = log2ceil(64'h10140 - 64'h10130); 
    localparam PAD13 = log2ceil(64'h10150 - 64'h10140); 
    localparam PAD14 = log2ceil(64'h10160 - 64'h10150); 
    localparam PAD15 = log2ceil(64'h10170 - 64'h10160); 
    localparam PAD16 = log2ceil(64'h10180 - 64'h10170); 
    localparam PAD17 = log2ceil(64'h10190 - 64'h10180); 
    localparam PAD18 = log2ceil(64'h101a0 - 64'h10190); 
    localparam PAD19 = log2ceil(64'h101b0 - 64'h101a0); 
    localparam PAD20 = log2ceil(64'h101c0 - 64'h101b0); 
    localparam PAD21 = log2ceil(64'h101d0 - 64'h101c0); 
    localparam PAD22 = log2ceil(64'h101e0 - 64'h101d0); 
    localparam PAD23 = log2ceil(64'h101f0 - 64'h101e0); 
    localparam PAD24 = log2ceil(64'h10200 - 64'h101f0); 
    localparam PAD25 = log2ceil(64'h10210 - 64'h10200); 
    localparam PAD26 = log2ceil(64'h10220 - 64'h10210); 
    localparam PAD27 = log2ceil(64'h10230 - 64'h10220); 
    localparam PAD28 = log2ceil(64'h10240 - 64'h10230); 
    localparam PAD29 = log2ceil(64'h10250 - 64'h10240); 
    localparam PAD30 = log2ceil(64'h10260 - 64'h10250); 
    localparam PAD31 = log2ceil(64'h10270 - 64'h10260); 
    // -------------------------------------------------------
    // Work out which address bits are significant based on the
    // address range of the slaves. If the required width is too
    // large or too small, we use the address field width instead.
    // -------------------------------------------------------
    localparam ADDR_RANGE = 64'h10270;
    localparam RANGE_ADDR_WIDTH = log2ceil(ADDR_RANGE);
    localparam OPTIMIZED_ADDR_H = (RANGE_ADDR_WIDTH > PKT_ADDR_W) ||
                                  (RANGE_ADDR_WIDTH == 0) ?
                                        PKT_ADDR_H :
                                        PKT_ADDR_L + RANGE_ADDR_WIDTH - 1;

    localparam RG = RANGE_ADDR_WIDTH-1;
    localparam REAL_ADDRESS_RANGE = OPTIMIZED_ADDR_H - PKT_ADDR_L;

      reg [PKT_ADDR_W-1 : 0] address;
      always @* begin
        address = {PKT_ADDR_W{1'b0}};
        address [REAL_ADDRESS_RANGE:0] = sink_data[OPTIMIZED_ADDR_H : PKT_ADDR_L];
      end   

    // -------------------------------------------------------
    // Pass almost everything through, untouched
    // -------------------------------------------------------
    assign sink_ready        = src_ready;
    assign src_valid         = sink_valid;
    assign src_startofpacket = sink_startofpacket;
    assign src_endofpacket   = sink_endofpacket;
    wire [PKT_DEST_ID_W-1:0] default_destid;
    wire [32-1 : 0] default_src_channel;




    // -------------------------------------------------------
    // Write and read transaction signals
    // -------------------------------------------------------
    wire read_transaction;
    assign read_transaction  = sink_data[PKT_TRANS_READ];


    soc_system_mm_interconnect_0_router_default_decode the_default_decode(
      .default_destination_id (default_destid),
      .default_wr_channel   (),
      .default_rd_channel   (),
      .default_src_channel  (default_src_channel)
    );

    always @* begin
        src_data    = sink_data;
        src_channel = default_src_channel;
        src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = default_destid;

        // --------------------------------------------------
        // Address Decoder
        // Sets the channel and destination ID based on the address
        // --------------------------------------------------

    // ( 0x10070 .. 0x10080 )
    if ( {address[RG:PAD0],{PAD0{1'b0}}} == 17'h10070  && read_transaction  ) begin
            src_channel = 32'b00000000000000000000000000000001;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 15;
    end

    // ( 0x10080 .. 0x10090 )
    if ( {address[RG:PAD1],{PAD1{1'b0}}} == 17'h10080  && read_transaction  ) begin
            src_channel = 32'b00000000000000000000000000000010;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 7;
    end

    // ( 0x10090 .. 0x100a0 )
    if ( {address[RG:PAD2],{PAD2{1'b0}}} == 17'h10090  && read_transaction  ) begin
            src_channel = 32'b00000000000000000000000000000100;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 8;
    end

    // ( 0x100a0 .. 0x100b0 )
    if ( {address[RG:PAD3],{PAD3{1'b0}}} == 17'h100a0  && read_transaction  ) begin
            src_channel = 32'b00000000000000000000000000001000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 9;
    end

    // ( 0x100b0 .. 0x100c0 )
    if ( {address[RG:PAD4],{PAD4{1'b0}}} == 17'h100b0  && read_transaction  ) begin
            src_channel = 32'b00000000000000000000000000010000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 10;
    end

    // ( 0x100c0 .. 0x100d0 )
    if ( {address[RG:PAD5],{PAD5{1'b0}}} == 17'h100c0  && read_transaction  ) begin
            src_channel = 32'b00000000000000000000000000100000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 11;
    end

    // ( 0x100d0 .. 0x100e0 )
    if ( {address[RG:PAD6],{PAD6{1'b0}}} == 17'h100d0  && read_transaction  ) begin
            src_channel = 32'b00000000000000000000000001000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 12;
    end

    // ( 0x100e0 .. 0x100f0 )
    if ( {address[RG:PAD7],{PAD7{1'b0}}} == 17'h100e0  && read_transaction  ) begin
            src_channel = 32'b00000000000000000000000010000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 13;
    end

    // ( 0x100f0 .. 0x10100 )
    if ( {address[RG:PAD8],{PAD8{1'b0}}} == 17'h100f0  && read_transaction  ) begin
            src_channel = 32'b00000000000000000000000100000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 14;
    end

    // ( 0x10100 .. 0x10110 )
    if ( {address[RG:PAD9],{PAD9{1'b0}}} == 17'h10100  && read_transaction  ) begin
            src_channel = 32'b00000000000000000000001000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 0;
    end

    // ( 0x10110 .. 0x10120 )
    if ( {address[RG:PAD10],{PAD10{1'b0}}} == 17'h10110  && read_transaction  ) begin
            src_channel = 32'b00000000000000000000010000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 1;
    end

    // ( 0x10120 .. 0x10130 )
    if ( {address[RG:PAD11],{PAD11{1'b0}}} == 17'h10120  && read_transaction  ) begin
            src_channel = 32'b00000000000000000000100000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 2;
    end

    // ( 0x10130 .. 0x10140 )
    if ( {address[RG:PAD12],{PAD12{1'b0}}} == 17'h10130  && read_transaction  ) begin
            src_channel = 32'b00000000000000000001000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 3;
    end

    // ( 0x10140 .. 0x10150 )
    if ( {address[RG:PAD13],{PAD13{1'b0}}} == 17'h10140  && read_transaction  ) begin
            src_channel = 32'b00000000000000000010000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 4;
    end

    // ( 0x10150 .. 0x10160 )
    if ( {address[RG:PAD14],{PAD14{1'b0}}} == 17'h10150  && read_transaction  ) begin
            src_channel = 32'b00000000000000000100000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 5;
    end

    // ( 0x10160 .. 0x10170 )
    if ( {address[RG:PAD15],{PAD15{1'b0}}} == 17'h10160  && read_transaction  ) begin
            src_channel = 32'b00000000000000001000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 6;
    end

    // ( 0x10170 .. 0x10180 )
    if ( {address[RG:PAD16],{PAD16{1'b0}}} == 17'h10170   ) begin
            src_channel = 32'b00000000000000010000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 31;
    end

    // ( 0x10180 .. 0x10190 )
    if ( {address[RG:PAD17],{PAD17{1'b0}}} == 17'h10180   ) begin
            src_channel = 32'b00000000000000100000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 23;
    end

    // ( 0x10190 .. 0x101a0 )
    if ( {address[RG:PAD18],{PAD18{1'b0}}} == 17'h10190   ) begin
            src_channel = 32'b00000000000001000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 24;
    end

    // ( 0x101a0 .. 0x101b0 )
    if ( {address[RG:PAD19],{PAD19{1'b0}}} == 17'h101a0   ) begin
            src_channel = 32'b00000000000010000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 25;
    end

    // ( 0x101b0 .. 0x101c0 )
    if ( {address[RG:PAD20],{PAD20{1'b0}}} == 17'h101b0   ) begin
            src_channel = 32'b00000000000100000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 26;
    end

    // ( 0x101c0 .. 0x101d0 )
    if ( {address[RG:PAD21],{PAD21{1'b0}}} == 17'h101c0   ) begin
            src_channel = 32'b00000000001000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 27;
    end

    // ( 0x101d0 .. 0x101e0 )
    if ( {address[RG:PAD22],{PAD22{1'b0}}} == 17'h101d0   ) begin
            src_channel = 32'b00000000010000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 28;
    end

    // ( 0x101e0 .. 0x101f0 )
    if ( {address[RG:PAD23],{PAD23{1'b0}}} == 17'h101e0   ) begin
            src_channel = 32'b00000000100000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 29;
    end

    // ( 0x101f0 .. 0x10200 )
    if ( {address[RG:PAD24],{PAD24{1'b0}}} == 17'h101f0   ) begin
            src_channel = 32'b10000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 30;
    end

    // ( 0x10200 .. 0x10210 )
    if ( {address[RG:PAD25],{PAD25{1'b0}}} == 17'h10200   ) begin
            src_channel = 32'b00000001000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 16;
    end

    // ( 0x10210 .. 0x10220 )
    if ( {address[RG:PAD26],{PAD26{1'b0}}} == 17'h10210   ) begin
            src_channel = 32'b00000010000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 17;
    end

    // ( 0x10220 .. 0x10230 )
    if ( {address[RG:PAD27],{PAD27{1'b0}}} == 17'h10220   ) begin
            src_channel = 32'b00000100000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 18;
    end

    // ( 0x10230 .. 0x10240 )
    if ( {address[RG:PAD28],{PAD28{1'b0}}} == 17'h10230   ) begin
            src_channel = 32'b00001000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 19;
    end

    // ( 0x10240 .. 0x10250 )
    if ( {address[RG:PAD29],{PAD29{1'b0}}} == 17'h10240   ) begin
            src_channel = 32'b00010000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 20;
    end

    // ( 0x10250 .. 0x10260 )
    if ( {address[RG:PAD30],{PAD30{1'b0}}} == 17'h10250   ) begin
            src_channel = 32'b00100000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 21;
    end

    // ( 0x10260 .. 0x10270 )
    if ( {address[RG:PAD31],{PAD31{1'b0}}} == 17'h10260   ) begin
            src_channel = 32'b01000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 22;
    end

end


    // --------------------------------------------------
    // Ceil(log2()) function
    // --------------------------------------------------
    function integer log2ceil;
        input reg[65:0] val;
        reg [65:0] i;

        begin
            i = 1;
            log2ceil = 0;

            while (i < val) begin
                log2ceil = log2ceil + 1;
                i = i << 1;
            end
        end
    endfunction

endmodule


