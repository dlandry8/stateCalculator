//=========================================================
// Project:       State Calculator
//                B EE 271 A
//                Lab 4
// Team members:  Nema Karimi and David Landry
//=========================================================

//=========================================================
// Module:        StateCalculatorLab4
// Description:   The main module of the verilog program.
// Calls:         scan, mapHex, setValue, SchmidtDB, 
//                   hexOutput
// Typical flow:  StateAddingMachine waits for a keypad (or
//                   on-board button) press. It determines
//                   the digit (or function) for the
//                   pressed object. (If it's a function,
//                   perform a function action.) If it's a
//                   digit, insert it into the
//                   currentNumber queue. (If the function
//                   press is add or subtract, perform the
//                   operation and display the accumulated
//                   sum.)
//                   (Items in parentheses have not yet
//                   been implemented).
// Note:           Thanks to Joe Decuir, whose sample code
//							provided some guidance. Thanks to
//							Miguel Huerta for some general advice.
//							Thanks to Youssef Beltagy for advice
//							on how to refactor the code to make it
//							easier to read & follow.
//=========================================================
module StateCalculatorLab4(

	//////////// CLOCK //////////
	input 		          		CLOCK2_50,
	input 		          		CLOCK3_50,
	input 		          		CLOCK4_50,
	input 		          		CLOCK_50,

	//////////// SEG7 //////////
	output		     [6:0]		HEX0,
	output		     [6:0]		HEX1,
	output		     [6:0]		HEX2,
	output		     [6:0]		HEX3,
	output		     [6:0]		HEX4,
	output		     [6:0]		HEX5,

	//////////// KEY //////////
	input 		     [3:0]		KEY,

	//////////// LED //////////
	output		     [9:0]		LEDR,

	//////////// SW //////////
	input 		     [9:0]		SW,

	//////////// GPIO_0, GPIO_0 connect to GPIO Default //////////
	inout 		    [35:0]		GPIO);

   // Here are some wire & reg declarations:
   wire rawValid;                // 1-bit flag stating
                                 //     whether a valid
                                 //     button is being 
                                 //     pressed.
   wire [3:0] hexDigit;          // The translated hex
                                 //     digit based on the
                                 //     coordinates from
                                 //     the keypad.
   wire delayedValid;            // Valid flag after going
                                 // through a debouncer
   wire [3:0] delayedButton;     // Valid flag after
                                 //    debouncer for 3 key
                                 //    buttons on FPGA.
   reg [1:0] display = 0;        // 0 for current, 1 for
                                 //    accumulator, 2 for
											//		remainder. 3 is
											//		invalid.
   wire [4:0] state;             // State
   reg [23:0] currentNumber = 0; // Current numeric entry.
   reg [23:0] accumulator = 0;   // Accumulated sum/diff.
	reg [47:0] product = 0;			// 48-bit product.
	reg [23:0] remainder = 0;		// Remainder
	reg [23:0] temp = 0;				// Temporary number.
   wire [23:0] displayNumber;    // Number to display
   reg pressFlag = 0;            // Detects if OP button
                                 //    is being pressed.
	reg [1:0] lastOperation;
	reg errorFlag = 0;				// Error Flag for division
											//		by 0.
   
   // LED test to verify which display and which state.
   assign LEDR[9] = ~display;		// Is current entry number
											//		being displayed?
   assign LEDR[8] = display;		//	Or is the accumulator
											//		being displayed?
	// LED 6 is on if accumulator equals 0.
	assign LEDR[6] = (accumulator == 0) ? 1 : 0;
	// LEDs 4-0 display the current state.
   assign LEDR[4:0] = state[4:0];
	// Display number can be the current number entry (0),
	//		the accumulator (1), the extended accumulator for
	//		multiplication (display = 2, lastOperation = 1),
	//		or the remainder for division (display = 2,
	//		lastOperation = 2).
   assign displayNumber = (display == 0) ? 
                          currentNumber : 
								  (display == 1) ?
								  accumulator : 
								  (lastOperation == 1) ?
								  product[47:24] :
								  remainder;
   // Assemble the state modes:
   assign state[4:0] = {delayedValid, delayedButton[3:0]};

	
   //======================================================
   // Begin main program flow here:
   //======================================================
	
   // Scan keypad entry:
   scan sc( 
      CLOCK_50,                               // Input
     {GPIO[25], GPIO[23], GPIO[21], GPIO[19], // Inouts
      GPIO[17], GPIO[15], GPIO[13], GPIO[11]},// Inouts
      hexDigit, rawValid                      // Outputs
      );
 
   // Delay to correctly set the hex digit & avoid
   //    debouncing for all key presses:
   debouncer keypadDelay(
      CLOCK_50, rawValid,                     // Inputs
      delayedValid                            // Output
      );
   debouncer resetButton(
      CLOCK_50, ~KEY[3],                      // Inputs
      delayedButton[3]                        // Output
      );
   debouncer clearButton(
      CLOCK_50, ~KEY[2],                      // Inputs
      delayedButton[2]                        // Output
      );
   debouncer entButton(
      CLOCK_50, ~KEY[1],                      // Inputs
      delayedButton[1]                        // Output
      );
   debouncer opButton(
      CLOCK_50, ~KEY[0],                      // Inputs
      delayedButton[0]                        // Output
      );
   
   // Concatenate the input digit to the right of the
   //    current number, left shifting the rest of the
   //    digits to the left one nyble.
	always@(posedge delayedValid)
   begin
      temp[23:0] = {currentNumber[19:0], hexDigit};
   end
   
   //======================================================
   // Begin determining which state we're in.
   //======================================================
   always @(posedge CLOCK_50)
   begin
      case (state)
         5'b10000:                     // Keypad
            begin
					errorFlag <= 0;
               currentNumber <= temp;
               display <= 0;
					lastOperation <= 0;
            end
         5'b01000:                     // Reset all
            begin
					errorFlag <= 0;
               currentNumber <= 0;
               accumulator <= 0;
               display <= 0;
					product <= 0;
					remainder <= 0;
					lastOperation <= 0;
            end
         5'b00100:                     // Clear entry
            begin
					errorFlag <= 0;
               currentNumber <= 0;
               display <= 0;
					lastOperation <= 0;
            end
         5'b00010:                     // Enter
            begin
					errorFlag <= 0;
					if (!pressFlag)
					begin
						pressFlag = 1;
						accumulator = currentNumber;
						display <= 1;
						lastOperation <= 0;
						currentNumber <= 0;
					end
            end
         5'b00001:                     //OPERATION
            begin
               // Flag makes sure only one press is being
					//		executed.
               if (!pressFlag)
               begin
						case (SW[9:8])
							2'b00:				// Add
							begin
								errorFlag <= 0;
								accumulator <= 
									accumulator + currentNumber;
								display <= 1;
								lastOperation <= 0;
							end
							2'b01:				// Subtract
							begin
								errorFlag <= 0;
								accumulator <=
									accumulator - currentNumber;
								display <= 1;
								lastOperation <= 0;
							end
							2'b10:				// Multiply
							begin
								errorFlag <= 0;
								product =
									accumulator * currentNumber;
								accumulator =
									product[23:0];
								display <= (SW[7]) ? 2 : 1;
								lastOperation <= 1;
							end	
							2'b11:				// Divide
							begin
								if (currentNumber == 0)
								//begin
									errorFlag <= 1;
								/*	
								end
								else
								begin
								*/
									errorFlag <= 0;
									accumulator <=
										accumulator / currentNumber;
									remainder <= 
									accumulator % currentNumber;
									display <= (SW[7]) ? 2 : 1;
									lastOperation <= 2;
								//end
							end
						endcase
                  display <= 1;
                  pressFlag = 1;
						currentNumber <= 0;
               end
            end
         5'b00000:                     // Default
            begin
               pressFlag = 0;
					if (lastOperation == 1 || lastOperation == 2)
						display <= (SW[7]) ? 2 : 1;
            end
      endcase
   end
   
   //======================================================
   // Display the result after key press.
   //======================================================
   hexOutput display0(
      1, // (always display 1st digit)        // Input
      displayNumber[3:0],
      HEX0                                    // Output
      );
   hexOutput display1(
     |displayNumber[23:4],
      displayNumber[7:4],
      HEX1                                    // Output
      );
   hexOutput display2(
     |displayNumber[23:8],
      displayNumber[11:8],
      HEX2                                    // Output
      );
   hexOutput display3(
     |displayNumber[23:12],
      displayNumber[15:12],
      HEX3                                    // Output
      );
   hexOutput display4(
     |displayNumber[23:16],
      displayNumber[19:16],
      HEX4                                    // Output
      );
   hexOutput display5(
     |displayNumber[23:20],
      displayNumber[23:20],
      HEX5                                    // Output
      );
endmodule

//=========================================================
// Module:           scan
// Description:      Automatic scan of the keyboard.
//                   Version 2
// Specifications:   5.3, 5.4
//=========================================================
module scan( 
       input clock,                // The on-board clock 
       inout [7:0] keypad,         // 4 rows and 4 columns
                                   //    of a 4x4 keypad.
       output [ 3:0 ] hexOutput,   // col, row coordinates
                                   //    of a pressed key.
       output reg rawValid         // Flag if a key is
                                   //    being pressed.
       );

   // Variable & wire declarations:
	reg [3:0] rawKey;
   reg [3:0] colDrive;        // This variable drives one
                              //    of the columns of the
                              //    keypad.
   wire [3:0] rowSense;       // This variable determines
                              //    which row is being
                              //    pressed in the keypad.
   reg [ 31:0 ] counter;      // Timing counter used to
                              //    simulate a clock of a
                              //    desired frequency.
   reg [ 1:0 ] columnNumber;  // This is the column number
                              //    currently being
                              //    energized.
   reg [ 1:0 ] rowNumber;     // This is the row number
                              //    currently being 
                              //    scanned.
   reg [3:0] hexDigit;        // The hex digit, assigned as a
                              //    variable type so that it can
                              //    be assigned at key change.
   
   // Constant parameter declarations:
   parameter
		clockFreq = 50_000_000,
      desiredFrequency = 50,  // Frequency, in Hz.
      divisor = clockFreq / desiredFrequency;
                              // Max value for the counter
                              //    used to simulate a
                              //    slower clock.

   // This always block ensures that the correct column is
   //    being energized. The column drive steps through
   //    the columns at the desired frequency. If the
   //    column has a row with a low, it sets rawValid to
   //    1. Otherwise, it keeps rawValid at 0 and continues
   //    cycling through columns.
   always @( posedge clock )
   begin
      if ( counter == 0 )
      begin
         counter <= divisor;
         if (keypad[7:4] == 4'b1111)
         begin
            rawValid <= 0;
            columnNumber <= columnNumber + 1;
         end
         else
            rawValid <= 1;
      end
      else
         counter <= counter - 1;
   end
   
   // This always blocks drives one of the columns based on
   //    what the current columnNumber is.
   always @(columnNumber)
   begin
      case (columnNumber)
         0: colDrive <= 4'bzzz0;
         1: colDrive <= 4'bzz0z;
         2: colDrive <= 4'bz0zz;
         3: colDrive <= 4'b0zzz;
      endcase
   end
   
   // Keypads 0-3 are the columns. Align colDrive with the
   //    columns of the keypad.
   assign keypad[3:0] = colDrive[3:0];
   
   // Scans which key row is being driven low. Assigns
   //    rowNumber to the low row (the rows are keypad
   //    4-7).
   always @*
   begin
      casex(keypad[7:4])
         'bxxx0:  rowNumber <= 0;
         'bxx0x:  rowNumber <= 1;
         'bx0xx:  rowNumber <= 2;
         'b0xxx:  rowNumber <= 3;
      endcase
      rawKey = {columnNumber, rowNumber};
   end
	
	// Map a rawKey coordinates to a hex digit:
	always @(rawKey)
   begin
      if (rawValid == 1)
      begin
         case(rawKey)
            // Row 0
            4'b0000: hexDigit <= 'hd;
            4'b0100: hexDigit <= 'he;
            4'b1000: hexDigit <= 'h0;
            4'b1100: hexDigit <= 'hf;
            
            // Row 1
            4'b0001: hexDigit <= 'hc;
            4'b0101: hexDigit <= 'h9;
            4'b1001: hexDigit <= 'h8;
            4'b1101: hexDigit <= 'h7;
            
            // Row 2
            4'b0010: hexDigit <= 'hb;
            4'b0110: hexDigit <= 'h6;
            4'b1010: hexDigit <= 'h5;
            4'b1110: hexDigit <= 'h4;
            
            // Row 3
            4'b0011: hexDigit <= 'ha;
            4'b0111: hexDigit <= 'h3;
            4'b1011: hexDigit <= 'h2;
            4'b1111: hexDigit <= 'h1;
         endcase
      end
   end
   
   // Continuously assign the hexDigit value to hexOutput.
   assign hexOutput = hexDigit;

endmodule


//=========================================================
// Module:        debouncer
// Description:   debounces key inputs. It basically delays
//                   the input and output until transients
//                   taper off, leaving with a solid logic
//                   1 or 0.
// Acknowledgement:
//                   Thanks to UMich for a working
//                   debouncer. Our debouncer module was
//                   adapted from the sample debouncer
//                   module found at:
//                      https://www.eecs.umich.edu/courses/
//                      eecs270/270lab/270_docs/
//                      debounce.html
//=========================================================
module debouncer(
    input clk,             //this is a 50MHz clock on FPGA
    input validIn,         //this is the input to be 
                           //debounced
     output reg validOut); //this is the debounced switch

   /*This module debounces the pushbutton PB (AKA valid).
   *It can be added to your project files and called as is:
   *DO NOT EDIT THIS MODULE
   *I EDITED THIS MODULE -DL
   * Original input name was PB. I changed it to validIn
   *     for clarity.
   * Original output name was PB_state. I changed it to
   *     validOut, also for clarity sake.
   * Reset was removed from original module.
   */
   
   reg PB_sync_0;
   reg PB_sync_1;
   reg [15:0] PB_cnt;
   
   // Synchronize the switch input to the clock
   always @(posedge clk) PB_sync_0 <= validIn;
   always @(posedge clk) PB_sync_1 <= PB_sync_0;

   // Debounce the switch
   always @(posedge clk)
   begin
      if(validOut == PB_sync_1)
         PB_cnt <= 0;
      else
      begin
         PB_cnt <= PB_cnt + 1'b1; 
         if(PB_cnt == 16'hffff) validOut <= ~validOut;
      end
   end
endmodule


//=========================================================
// Module:        hexOutput
// Description:   Sets up the seven-segment hex display.
// Inputs:        hexDigit:
//                   The 4 bits per each hex digit.
//                   (e.g. 1111 = F, 0100 = 4, 0001 = 1)
// Outputs:       segments:
//                   The 7 segments to a hex decimal:
//                            0
//                            -
//                         5 |_| 1
//                         4 |6| 2
//                            -
//                            3
//                   It's the inverse of the s array.
// Wires:         b0 - b3:
//                   The 4 hex digits, but in a shorter
//                   name.
//                s:
//                   The array of segment displays used
//                   in the equations.
// Note:          Imported from Lab 2.
//=========================================================
module hexOutput(
      input valid, 
      input [3:0] hexDigit,
      output reg  [6:0] segments);

   // Wire declarations:
   wire b0, b1, b2, b3;
   wire [6:0] s;
   
   // Each b is associated with one of the hex binary
   // digits.
   assign b0 = hexDigit[0];
   assign b1 = hexDigit[1];
   assign b2 = hexDigit[2];
   assign b3 = hexDigit[3];
   
   // s wire assignments based on the equations gathered
   // from the truth table & k-maps:
   assign s[0] =  b1 & b2 | 
                  ~b1 & ~b2 & b3 | 
                  ~b0 & b3 | 
                  ~b0 & ~b2 | 
                  b0 & b2 & ~b3 | 
                  b1 & ~b3;
   assign s[1] =  (~b0 | b1 | ~b2 | b3) & 
                  (b0 | ~b1 | ~b2) & 
                  (~b1 | ~b2 | ~b3) & 
                  (b0 | ~b2 | ~b3) & 
                  (~b3 | ~b1 | ~b0);
   assign s[2] =  (b0 | ~b1 | b2 | b3) & 
                  (~b1 | ~b2 | ~b3) & 
                  (b0 | ~b2 | ~b3);
   assign s[3] =  (~b0 | b1 | b2 | b3) & 
                  (b0 | b1 | ~b2 | b3) & 
                  (~b0 | ~b1 | ~b2) & 
                  (b0 | ~b1 | b2 | ~b3);
   assign s[4] =  (~b0 | b3) & 
                  (b1 | ~b2 | b3) & 
                  (~b0 | b1 | b2);
   assign s[5] =  (~b0 | b2 | b3) & 
                  (~b1 | b2 | b3) & 
                  (~b0 | ~b1 | b3) & 
                  (~b0 | b1 | ~b2 | ~b3);
   assign s[6] =  (b1 | b2 | b3) & 
                  (~b0 | ~b1 | ~b2 | b3) & 
                  (b0 | b1 | ~b2 | ~b3);
   
   // Invert the outputs for active low on the board.
   
   always @*
         segments = valid? ~s : ~0;
endmodule
