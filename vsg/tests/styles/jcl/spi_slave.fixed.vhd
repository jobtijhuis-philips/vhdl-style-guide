----------------------------------------------------------------------------------
-- Author:          Jonny Doin, jdoin@opencores.org
--
-- Create Date:     15:36:20 05/15/2011
-- Module Name:     SPI_SLAVE - RTL
-- Project Name:    SPI INTERFACE
-- Target Devices:  Spartan-6
-- Tool versions:   ISE 13.1
-- Description:
--
--      This block is the SPI slave interface, implemented in one single entity.
--      All internal core operations are synchronous to the external SPI clock, and follows the general SPI de-facto standard.
--      The parallel read/write interface is synchronous to a supplied system master clock, 'clk_i'.
--      Synchronization for the parallel ports is provided by input data request and write enable lines, and output data valid line.
--      Fully pipelined cross-clock circuitry guarantees that no setup artifacts occur on the buffers that are accessed by the two
--      clock domains.
--
--      The block is very simple to use, and has parallel inputs and outputs that behave like a synchronous memory i/o.
--      It is parameterizable via generics for the data width ('N'), SPI mode (CPHA and CPOL), and lookahead prefetch
--      signaling ('PREFETCH').
--
--      PARALLEL WRITE INTERFACE
--      The parallel interface has a input port 'di_i' and an output port 'do_o'.
--      Parallel load is controlled using 3 signals: 'di_i', 'di_req_o' and 'wren_i'.
--      When the core needs input data, a look ahead data request strobe , 'di_req_o' is pulsed 'PREFETCH' 'spi_sck_i'
--      cycles in advance to synchronize a user pipelined memory or fifo to present the next input data at 'di_i'
--      in time to have continuous clock at the spi bus, to allow back-to-back continuous load.
--      The data request strobe on 'di_req_o' is 2 'clk_i' clock cycles long.
--      The write to 'di_i' must occur at most one 'spi_sck_i' cycle before actual load to the core shift register, to avoid
--      race conditions at the register transfer.
--      The user circuit places data at the 'di_i' port and strobes the 'wren_i' line for one rising edge of 'clk_i'.
--      For a pipelined sync RAM, a PREFETCH of 3 cycles allows an address generator to present the new adress to the RAM in one
--      cycle, and the RAM to respond in one more cycle, in time for 'di_i' to be latched by the interface one clock before transfer.
--      If the user sequencer needs a different value for PREFETCH, the generic can be altered at instantiation time.
--      The 'wren_i' write enable strobe must be valid at least one setup time before the rising edge of the last clock cycle,
--      if continuous transmission is intended.
--      When the interface is idle ('spi_ssel_i' is HIGH), the top bit of the latched 'di_i' port is presented at port 'spi_miso_o'.
--
--      PARALLEL WRITE PIPELINED SEQUENCE
--      =================================
--                     __    __    __    __    __    __    __
--      clk_i       __/  \__/  \__/  \__/  \__/  \__/  \__/  \...     -- parallel interface clock
--                           ___________
--      di_req_o    ________/           \_____________________...     -- 'di_req_o' asserted on rising edge of 'clk_i'
--                  ______________ ___________________________...
--      di_i        __old_data____X______new_data_____________...     -- user circuit loads data on 'di_i' at next 'clk_i' rising edge
--                                             ________
--      wren_i      __________________________/        \______...     -- 'wren_i' enables latch on rising edge of 'clk_i'
--
--
--      PARALLEL READ INTERFACE
--      An internal buffer is used to copy the internal shift register data to drive the 'do_o' port. When a complete
--      word is received, the core shift register is transferred to the buffer, at the rising edge of the spi clock, 'spi_sck_i'.
--      The signal 'do_valid_o' is strobed 3 'clk_i' clocks after, to directly drive a synchronous memory or fifo write enable.
--      'do_valid_o' is synchronous to the parallel interface clock, and changes only on rising edges of 'clk_i'.
--      When the interface is idle, data at the 'do_o' port holds the last word received.
--
--      PARALLEL READ PIPELINED SEQUENCE
--      ================================
--                      ______        ______        ______        ______
--      clk_spi_i   ___/ bit1 \______/ bitN \______/bitN-1\______/bitN-2\__...  -- spi base clock
--                     __    __    __    __    __    __    __    __    __
--      clk_i       __/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \_...  -- parallel interface clock
--                  _________________ _____________________________________...  -- 1) received data is transferred to 'do_buffer_reg'
--      do_o        __old_data_______X__________new_data___________________...  --    after last bit received, at next shift clock.
--                                                   ____________
--      do_valid_o  ________________________________/            \_________...  -- 2) 'do_valid_o' strobed for 2 'clk_i' cycles
--                                                                              --    on the 3rd 'clk_i' rising edge.
--
--
--      This design was originally targeted to a Spartan-6 platform, synthesized with XST and normal constraints.
--
------------------------------ COPYRIGHT NOTICE -----------------------------------------------------------------------
--
--      This file is part of the SPI MASTER/SLAVE INTERFACE project http://opencores.org/project,spi_master_slave
--
--      Author(s):      Jonny Doin, jdoin@opencores.org, jonnydoin@gmail.com
--
--      Copyright (C) 2011 Jonny Doin
--      -----------------------------
--
--      This source file may be used and distributed without restriction provided that this copyright statement is not
--      removed from the file and that any derivative work contains the original copyright notice and the associated
--      disclaimer.
--
--      This source file is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser
--      General Public License as published by the Free Software Foundation; either version 2.1 of the License, or
--      (at your option) any later version.
--
--      This source is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
--      warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
--      details.
--
--      You should have received a copy of the GNU Lesser General Public License along with this source; if not, download
--      it from http://www.gnu.org/licenses/lgpl.txt
--
------------------------------ REVISION HISTORY -----------------------------------------------------------------------
--
-- 2011/05/15   v0.10.0050  [JD]    created the slave logic, with 2 clock domains, from SPI_MASTER module.
-- 2011/05/15   v0.15.0055  [JD]    fixed logic for starting state when CPHA='1'.
-- 2011/05/17   v0.80.0049  [JD]    added explicit clock synchronization circuitry across clock boundaries.
-- 2011/05/18   v0.95.0050  [JD]    clock generation circuitry, with generators for all-rising-edge clock core.
-- 2011/06/05   v0.96.0053  [JD]    changed async clear to sync resets.
-- 2011/06/07   v0.97.0065  [JD]    added cross-clock buffers, fixed fsm async glitches.
-- 2011/06/09   v0.97.0068  [JD]    reduced control sets (resets, CE, presets) to the absolute minimum to operate, to reduce
--                                  synthesis LUT overhead in Spartan-6 architecture.
-- 2011/06/11   v0.97.0075  [JD]    redesigned all parallel data interfacing ports, and implemented cross-clock strobe logic.
-- 2011/06/12   v0.97.0079  [JD]    implemented wr_ack and di_req logic for state 0, and eliminated unnecessary registers reset.
-- 2011/06/17   v0.97.0079  [JD]    implemented wr_ack and di_req logic for state 0, and eliminated unnecessary registers reset.
-- 2011/07/16   v1.11.0080  [JD]    verified both spi_master and spi_slave in loopback at 50MHz SPI clock.
-- 2011/07/29   v2.00.0110  [JD]    FIX: CPHA bugs:
--                                      - redesigned core clocking to address all CPOL and CPHA configurations.
--                                      - added CHANGE_EDGE to the FSM register transfer logic, to have MISO change at opposite
--                                        clock phases from SHIFT_EDGE.
--                                  Removed global signal setting at the FSM, implementing exhaustive explicit signal attributions
--                                  for each state, to avoid reported inference problems in some synthesis engines.
--                                  Streamlined port names and indentation blocks.
-- 2011/08/01   v2.01.0115  [JD]    Adjusted 'do_valid_o' pulse width to be 2 'clk_i', as in the master core.
--                                  Simulated in iSim with the master core for continuous transmission mode.
-- 2011/08/02   v2.02.0120  [JD]    Added mux for MISO at reset state, to output di(N-1) at start. This fixed a bug in first bit.
--                                  The master and slave cores were verified in FPGA with continuous transmission, for all SPI modes.
-- 2011/08/04   v2.02.0121  [JD]    Changed minor comment bugs in the combinatorial fsm logic.
-- 2011/08/08   v2.02.0122  [JD]    FIX: continuous transfer mode bug. When wren_i is not strobed prior to state 1 (last bit), the
--                                  sequencer goes to state 0, and then to state 'N' again. This produces a wrong bit-shift for received
--                                  data. The fix consists in engaging continuous transfer regardless of the user strobing write enable, and
--                                  sequencing from state 1 to N as long as the master clock is present. If the user does not write new
--                                  data, the last data word is repeated.
-- 2011/08/08   v2.02.0123  [JD]    ISSUE: continuous transfer mode bug, for ignored 'di_req' cycles. Instead of repeating the last data word,
--                                  the slave will send (others => '0') instead.
-- 2011/08/28   v2.02.0126  [JD]    ISSUE: the miso_o MUX that preloads tx_bit when slave is desselected will glitch for CPHA='1'.
--                                  FIX: added a registered drive for the MUX select that will transfer the tx_reg only after the first tx_reg update.
--
-----------------------------------------------------------------------------------------------------------------------
--  TODO
--  ====
--
-----------------------------------------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.std_logic_unsigned.all;

entity SPI_SLAVE is
  generic (
    N        : positive  := 32;                                                 -- 32bit serial word length is default
    CPOL     : std_logic := '0';                                                -- SPI mode selection (mode 0 default)
    CPHA     : std_logic := '0';                                                -- CPOL = clock polarity, CPHA = clock phase.
    PREFETCH : positive  := 3                                                   -- prefetch lookahead cycles
  );
  port (
    CLK_I         : in    std_logic                        := 'X';                                    -- internal interface clock (clocks di/do registers)
    SPI_SSEL_I    : in    std_logic                        := 'X';                                    -- spi bus slave select line
    SPI_SCK_I     : in    std_logic                        := 'X';                                    -- spi bus sck clock (clocks the shift register core)
    SPI_MOSI_I    : in    std_logic                        := 'X';                                    -- spi bus mosi input
    SPI_MISO_O    : out   std_logic                        := 'X';                                    -- spi bus spi_miso_o output
    DI_REQ_O      : out   std_logic;                                                                  -- preload lookahead data request line
    DI_I          : in    std_logic_vector(N - 1 downto 0) := (others => 'X');                        -- parallel load data in (clocked in on rising edge of clk_i)
    WREN_I        : in    std_logic                        := 'X';                                    -- user data write enable
    WR_ACK_O      : out   std_logic;                                                                  -- write acknowledge
    DO_VALID_O    : out   std_logic;                                                                  -- do_o data valid strobe, valid during one clk_i rising edge.
    DO_O          : out   std_logic_vector(N - 1 downto 0);                                           -- parallel output (clocked out on falling clk_i)
    --- debug ports: can be removed for the application circuit ---
    DO_TRANSFER_O : out   std_logic;                                                                  -- debug: internal transfer driver
    WREN_O        : out   std_logic;                                                                  -- debug: internal state of the wren_i pulse stretcher
    RX_BIT_NEXT_O : out   std_logic;                                                                  -- debug: internal rx bit
    STATE_DBG_O   : out   std_logic_vector(3 downto 0);                                               -- debug: internal state register
    SH_REG_DBG_O  : out   std_logic_vector(N - 1 downto 0)                                            -- debug: internal shift register
  );
end entity SPI_SLAVE;

--================================================================================================================
-- SYNTHESIS CONSIDERATIONS
-- ========================
-- There are several output ports that are used to simulate and verify the core operation.
-- Do not map any signals to the unused ports, and the synthesis tool will remove the related interfacing
-- circuitry.
-- The same is valid for the transmit and receive ports. If the receive ports are not mapped, the
-- synthesis tool will remove the receive logic from the generated circuitry.
-- Alternatively, you can remove these ports and related circuitry once the core is verified and
-- integrated to your circuit.
--================================================================================================================

architecture RTL of SPI_SLAVE is

  -- constants to control FlipFlop synthesis
  constant shift_edge     : std_logic := (CPOL xnor CPHA);       -- MOSI data is captured and shifted at this SCK edge
  constant change_edge    : std_logic := (CPOL xor CPHA);        -- MISO data is updated at this SCK edge

  ------------------------------------------------------------------------------------------
  -- GLOBAL RESET:
  --      all signals are initialized to zero at GSR (global set/reset) by giving explicit
  --      initialization values at declaration. This is needed for all Xilinx FPGAs, and
  --      especially for the Spartan-6 and newer CLB architectures, where a local reset can
  --      reduce the usability of the slice registers, due to the need to share the control
  --      set (RESET/PRESET, CLOCK ENABLE and CLOCK) by all 8 registers in a slice.
  --      By using GSR for the initialization, and reducing RESET local init to the really
  --      essential, the model achieves better LUT/FF packing and CLB usability.
  ------------------------------------------------------------------------------------------
  -- internal state signals for register and combinatorial stages
  signal state_next       : natural range N downto 0 := 0;       -- state 0 is idle state
  signal state_reg        : natural range N downto 0 := 0;       -- state 0 is idle state
  -- shifter signals for register and combinatorial stages
  signal sh_next          : std_logic_vector(N - 1 downto 0);
  signal sh_reg           : std_logic_vector(N - 1 downto 0);
  -- mosi and miso connections
  signal rx_bit_next      : std_logic;                           -- sample of MOSI input
  signal tx_bit_next      : std_logic;
  signal tx_bit_reg       : std_logic;                           -- drives MISO during sequential logic
  signal preload_miso     : std_logic;                           -- controls the MISO MUX
  -- buffered di_i data signals for register and combinatorial stages
  signal di_reg           : std_logic_vector(N - 1 downto 0);
  -- internal wren_i stretcher for fsm combinatorial stage
  signal wren             : std_logic;
  signal wr_ack_next      : std_logic := '0';
  signal wr_ack_reg       : std_logic := '0';
  -- buffered do_o data signals for register and combinatorial stages
  signal do_buffer_next   : std_logic_vector(N - 1 downto 0);
  signal do_buffer_reg    : std_logic_vector(N - 1 downto 0);
  -- internal signal to flag transfer to do_buffer_reg
  signal do_transfer_next : std_logic := '0';
  signal do_transfer_reg  : std_logic := '0';
  -- internal input data request signal
  signal di_req_next      : std_logic := '0';
  signal di_req_reg       : std_logic := '0';
  -- cross-clock do_valid_o logic
  signal do_valid_next    : std_logic := '0';
  signal do_valid_a       : std_logic := '0';
  signal do_valid_b       : std_logic := '0';
  signal do_valid_c       : std_logic := '0';
  signal do_valid_d       : std_logic := '0';
  signal do_valid_o_reg   : std_logic := '0';
  -- cross-clock di_req_o logic
  signal di_req_o_next    : std_logic := '0';
  signal di_req_o_a       : std_logic := '0';
  signal di_req_o_b       : std_logic := '0';
  signal di_req_o_c       : std_logic := '0';
  signal di_req_o_d       : std_logic := '0';
  signal di_req_o_reg     : std_logic := '0';

begin

  --=============================================================================================
  --  GENERICS CONSTRAINTS CHECKING
  --=============================================================================================
  -- minimum word width is 8 bits
  assert N >= 8
    report "Generic parameter 'N' error: SPI shift register size needs to be 8 bits minimum"
    severity FAILURE;
  -- maximum prefetch lookahead check
  assert PREFETCH <= N - 5
    report "Generic parameter 'PREFETCH' error: lookahead count out of range, needs to be N-5 maximum"
    severity FAILURE;

  --=============================================================================================
  --  GENERATE BLOCKS
  --=============================================================================================

  --=============================================================================================
  --  DATA INPUTS
  --=============================================================================================
  -- connect rx bit input
  rx_bit_next <= SPI_MOSI_I;

  --=============================================================================================
  --  CROSS-CLOCK PIPELINE TRANSFER LOGIC
  --=============================================================================================
  -- do_valid_o and di_req_o strobe output logic
  -- this is a delayed pulse generator with a ripple-transfer FFD pipeline, that generates a
  -- fixed-length delayed pulse for the output flags, at the parallel clock domain
  OUT_TRANSFER_PROC : process (CLK_I, do_transfer_reg, di_req_reg,
                               do_valid_a, do_valid_b, do_valid_d,
                               di_req_o_a, di_req_o_b, di_req_o_d) is
  begin

    if (CLK_I'event and CLK_I = '1') then                     -- clock at parallel port clock
      -- do_transfer_reg -> do_valid_o_reg
      do_valid_a     <= do_transfer_reg;                      -- the input signal must be at least 2 clocks long
      do_valid_b     <= do_valid_a;                           -- feed it to a ripple chain of FFDs
      do_valid_c     <= do_valid_b;
      do_valid_d     <= do_valid_c;
      do_valid_o_reg <= do_valid_next;                        -- registered output pulse

      -- di_req_reg -> di_req_o_reg
      di_req_o_a   <= di_req_reg;                             -- the input signal must be at least 2 clocks long
      di_req_o_b   <= di_req_o_a;                             -- feed it to a ripple chain of FFDs
      di_req_o_c   <= di_req_o_b;
      di_req_o_d   <= di_req_o_c;
      di_req_o_reg <= di_req_o_next;                          -- registered output pulse
    end if;

    -- generate a 2-clocks pulse at the 3rd clock cycle
    do_valid_next <= do_valid_a and do_valid_b and not do_valid_d;
    di_req_o_next <= di_req_o_a and di_req_o_b and not di_req_o_d;

  end process OUT_TRANSFER_PROC;

  -- parallel load input registers: data register and write enable
  IN_TRANSFER_PROC : process (CLK_I, WREN_I, wr_ack_reg) is
  begin

    -- registered data input, input register with clock enable
    if (CLK_I'event and CLK_I = '1') then
      if (WREN_I = '1') then
        di_reg <= DI_I;                                     -- parallel data input buffer register
      end if;
    end if;

    -- stretch wren pulse to be detected by spi fsm (ffd with sync preset and sync reset)
    if (CLK_I'event and CLK_I = '1') then
      if (WREN_I = '1') then                                -- wren_i is the sync preset for wren
        wren <= '1';
      elsif (wr_ack_reg = '1') then                         -- wr_ack is the sync reset for wren
        wren <= '0';
      end if;
    end if;

  end process IN_TRANSFER_PROC;

  --=============================================================================================
  --  REGISTER TRANSFER PROCESSES
  --=============================================================================================
  -- fsm state and data registers change on spi SHIFT_EDGE
  CORE_REG_PROC : process (SPI_SCK_I, SPI_SSEL_I) is
  begin

    -- FFD registers clocked on SHIFT edge and cleared on idle (spi_ssel_i = 1)
    -- state fsm register (fdr)
    if (SPI_SSEL_I = '1') then                                     -- async clr
      state_reg <= 0;                                              -- state falls back to idle when slave not selected
    elsif (SPI_SCK_I'event and SPI_SCK_I = shift_edge) then        -- on SHIFT edge, update state register
      state_reg <= state_next;                                     -- core fsm changes state with spi SHIFT clock
    end if;

    -- FFD registers clocked on SHIFT edge
    -- rtl core registers (fd)
    if (SPI_SCK_I'event and SPI_SCK_I = shift_edge) then           -- on fsm state change, update all core registers
      sh_reg          <= sh_next;                                  -- core shift register
      do_buffer_reg   <= do_buffer_next;                           -- registered data output
      do_transfer_reg <= do_transfer_next;                         -- cross-clock transfer flag
      di_req_reg      <= di_req_next;                              -- input data request
      wr_ack_reg      <= wr_ack_next;                              -- wren ack for data load synchronization
    end if;

    -- FFD registers clocked on CHANGE edge and cleared on idle (spi_ssel_i = 1)
    -- miso MUX preload control register (fdp)
    if (SPI_SSEL_I = '1') then                                     -- async preset
      preload_miso <= '1';                                         -- miso MUX sees top bit of parallel input when slave not selected
    elsif (SPI_SCK_I'event and SPI_SCK_I = change_edge) then       -- on CHANGE edge, change to tx_reg output
      preload_miso <= SPI_SSEL_I;                                  -- miso MUX sees tx_bit_reg when it is driven by SCK
    end if;

    -- FFD registers clocked on CHANGE edge
    -- tx_bit register (fd)
    if (SPI_SCK_I'event and SPI_SCK_I = change_edge) then
      tx_bit_reg <= tx_bit_next;                                   -- update MISO driver from the MSb
    end if;

  end process CORE_REG_PROC;

  --=============================================================================================
  --  COMBINATORIAL LOGIC PROCESSES
  --=============================================================================================
  -- state and datapath combinatorial logic
  CORE_COMBI_PROC : process (sh_reg, sh_next, state_reg, tx_bit_reg, rx_bit_next, do_buffer_reg,
                             do_transfer_reg, di_reg, di_req_reg, wren, wr_ack_reg) is
  begin

    -- all output signals are assigned to (avoid latches)
    sh_next          <= sh_reg;                                               -- shift register
    tx_bit_next      <= tx_bit_reg;                                           -- MISO driver
    do_buffer_next   <= do_buffer_reg;                                        -- output data buffer
    do_transfer_next <= do_transfer_reg;                                      -- output data flag
    wr_ack_next      <= wr_ack_reg;                                           -- write enable acknowledge
    di_req_next      <= di_req_reg;                                           -- data input request
    state_next       <= state_reg;                                            -- fsm control state

    case state_reg is

      when (N) =>                                                             -- deassert 'di_rdy' and stretch do_valid
        wr_ack_next             <= '0';                                       -- acknowledge data in transfer
        di_req_next             <= '0';                                       -- prefetch data request: deassert when shifting data
        tx_bit_next             <= sh_reg(N - 1);                             -- output next MSbit
        sh_next(N - 1 downto 1) <= sh_reg(N - 2 downto 0);                    -- shift inner bits
        sh_next(0)              <= rx_bit_next;                               -- shift in rx bit into LSb
        state_next              <= state_reg - 1;                             -- update next state at each sck pulse

      when (N - 1) downto (PREFETCH + 3) =>                                   -- remove 'do_transfer' and shift bits
        do_transfer_next        <= '0';                                       -- reset 'do_valid' transfer signal
        di_req_next             <= '0';                                       -- prefetch data request: deassert when shifting data
        wr_ack_next             <= '0';                                       -- remove data load ack for all but the load stages
        tx_bit_next             <= sh_reg(N - 1);                             -- output next MSbit
        sh_next(N - 1 downto 1) <= sh_reg(N - 2 downto 0);                    -- shift inner bits
        sh_next(0)              <= rx_bit_next;                               -- shift in rx bit into LSb
        state_next              <= state_reg - 1;                             -- update next state at each sck pulse

      when (PREFETCH + 2) downto 3 =>                                         -- raise prefetch 'di_req_o' signal
        di_req_next             <= '1';                                       -- request data in advance to allow for pipeline delays
        wr_ack_next             <= '0';                                       -- remove data load ack for all but the load stages
        tx_bit_next             <= sh_reg(N - 1);                             -- output next MSbit
        sh_next(N - 1 downto 1) <= sh_reg(N - 2 downto 0);                    -- shift inner bits
        sh_next(0)              <= rx_bit_next;                               -- shift in rx bit into LSb
        state_next              <= state_reg - 1;                             -- update next state at each sck pulse

      when 2 =>                                                               -- transfer received data to do_buffer_reg on next cycle
        di_req_next             <= '1';                                       -- request data in advance to allow for pipeline delays
        wr_ack_next             <= '0';                                       -- remove data load ack for all but the load stages
        tx_bit_next             <= sh_reg(N - 1);                             -- output next MSbit
        sh_next(N - 1 downto 1) <= sh_reg(N - 2 downto 0);                    -- shift inner bits
        sh_next(0)              <= rx_bit_next;                               -- shift in rx bit into LSb
        do_transfer_next        <= '1';                                       -- signal transfer to do_buffer on next cycle
        do_buffer_next          <= sh_next;                                   -- get next data directly into rx buffer
        state_next              <= state_reg - 1;                             -- update next state at each sck pulse

      when 1 =>                                                               -- transfer rx data to do_buffer and restart if new data is written
        sh_next(0)  <= rx_bit_next;                                           -- shift in rx bit into LSb
        di_req_next <= '0';                                                   -- prefetch data request: deassert when shifting data
        state_next  <= N;                                                     -- next state is top bit of new data

        if (wren = '1') then                                                  -- load tx register if valid data present at di_reg
          wr_ack_next             <= '1';                                     -- acknowledge data in transfer
          sh_next(N - 1 downto 1) <= di_reg(N - 2 downto 0);                  -- shift inner bits
          tx_bit_next             <= di_reg(N - 1);                           -- first output bit comes from the MSb of parallel data
        else
          wr_ack_next             <= '0';                                     -- no data reload for continuous transfer mode
          sh_next(N - 1 downto 1) <= (others => '0');                         -- clear transmit shift register
          tx_bit_next             <= '0';                                     -- send ZERO
        end if;

      when 0 =>                                                               -- idle state: start and end of transmission
        sh_next(0)              <= rx_bit_next;                               -- shift in rx bit into LSb
        sh_next(N - 1 downto 1) <= di_reg(N - 2 downto 0);                    -- shift inner bits
        tx_bit_next             <= di_reg(N - 1);                             -- first output bit comes from the MSb of parallel data
        wr_ack_next             <= '1';                                       -- acknowledge data in transfer
        di_req_next             <= '0';                                       -- prefetch data request: deassert when shifting data
        do_transfer_next        <= '0';                                       -- clear signal transfer to do_buffer
        state_next              <= N;                                         -- next state is top bit of new data

      when others =>
        state_next <= 0;                                                      -- safe state

    end case;

  end process CORE_COMBI_PROC;

  --=============================================================================================
  --  OUTPUT LOGIC PROCESSES
  --=============================================================================================
  -- data output processes
  DO_O       <= do_buffer_reg;                          -- do_o always available
  DO_VALID_O <= do_valid_o_reg;                         -- copy registered do_valid_o to output
  DI_REQ_O   <= di_req_o_reg;                           -- copy registered di_req_o to output
  WR_ACK_O   <= wr_ack_reg;                             -- copy registered wr_ack_o to output

  -----------------------------------------------------------------------------------------------
  -- MISO driver process: preload top bit of parallel data to MOSI at reset
  -----------------------------------------------------------------------------------------------
  -- this is a MUX that selects the combinatorial next tx bit at reset, and the registered tx bit
  -- at sequential operation. The mux gives us a preload of the first bit, simplifying the shifter logic.
  SPI_MISO_O_PROC : process (preload_miso, tx_bit_reg, di_reg) is
  begin

    if (preload_miso = '1') then
      SPI_MISO_O <= di_reg(N - 1);                                  -- copy top bit of parallel data at reset
    else
      SPI_MISO_O <= tx_bit_reg;                                     -- copy top bit of shifter at sequential operation
    end if;

  end process SPI_MISO_O_PROC;

  --=============================================================================================
  --  DEBUG LOGIC PROCESSES
  --=============================================================================================
  -- these signals are useful for verification, and can be deleted after debug.
  DO_TRANSFER_O <= do_transfer_reg;
  STATE_DBG_O   <= std_logic_vector(to_unsigned(state_reg, 4)); -- export internal state to debug
  RX_BIT_NEXT_O <= rx_bit_next;
  WREN_O        <= wren;
  SH_REG_DBG_O  <= sh_reg;                                      -- export sh_reg to debug

end architecture RTL;

