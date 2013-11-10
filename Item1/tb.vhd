-- Test Bench
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

entity testbench is
end testbench;

architecture behavior of testbench is

  -- Design to be tested
  component kcpsm3_mult_8x8
  port(
    reset : in std_logic;
    clk   : in std_logic
  );
  end component;

  -- signals to connect kcpsm3_mult_8x8
  constant PERIOD     : time := 20ns;

  signal reset        : std_logic;
  signal clk          : std_logic := '0';

begin
  -- Define the unit under test
  uut: kcpsm3_mult_8x8
  port map(
    reset => reset,
    clk   => clk
  );
				
  -- Test Bench begins

  -- Unused inputs on processor
  reset <= '0';
		
  -- Nominal 50MHz clock which also defines number of cycles in simulation 
  clk_gen: process
  begin
    clk <= '0';
    wait for PERIOD/2;
    clk <= '1';
    wait for PERIOD/2;
  end process;
	 
end;
