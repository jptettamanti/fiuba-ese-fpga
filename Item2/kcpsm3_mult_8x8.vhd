library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


------------------------------------------------------------------------------------
-- Start of test ENTITY
------------------------------------------------------------------------------------
entity kcpsm3_mult_8x8 is
port(
  reset : in  std_logic;
  clk   : in  std_logic
);
end kcpsm3_mult_8x8;

------------------------------------------------------------------------------------
-- Start of test ACHITECTURE
------------------------------------------------------------------------------------
architecture behavioral of kcpsm3_mult_8x8 is

  ------------------------------------------------------------------------------------
  -- VHDL COMPONENT declaration of KCPSM3
  ------------------------------------------------------------------------------------
  component kcpsm3 
  port(
    reset           : in  std_logic                    ;
    clk             : in  std_logic                    ;
    address         : out std_logic_vector(9 downto 0) ;
    instruction     : in  std_logic_vector(17 downto 0);
    port_id         : out std_logic_vector(7 downto 0) ;
    write_strobe    : out std_logic                    ;
    out_port        : out std_logic_vector(7 downto 0) ;
    read_strobe     : out std_logic                    ;
    in_port         : in  std_logic_vector(7 downto 0) ;
    interrupt       : in  std_logic                    ;
    interrupt_ack   : out std_logic
  );
  end component;

  ------------------------------------------------------------------------------------
  -- VHDL COMPONENT declaration of program ROM
  ------------------------------------------------------------------------------------
  component prog_rom
  port(
    clk             : in  std_logic                    ;
    address         : in  std_logic_vector(9 downto 0) ;
    instruction     : out std_logic_vector(17 downto 0)
  );
  end component;

  ------------------------------------------------------------------------------------
  -- VHDL COMPONENT declaration of program MULT 8x8
  ------------------------------------------------------------------------------------
  component mult_8x8
  port(
    reset           : in  std_logic                   ;
    clk             : in  std_logic                   ;
    read_strobe     : in  std_logic                   ;
    write_strobe    : in  std_logic                   ;
    port_id         : in  std_logic_vector(7 downto 0);
    in_port         : out std_logic_vector(7 downto 0);					  
    out_port        : in  std_logic_vector(7 downto 0);
    interrupt_event : out std_logic
  );
  end component;

  ------------------------------------------------------------------------------------
  -- SIGNALS used to connect KCPSM3, program ROM and MULT 8x8
  ------------------------------------------------------------------------------------
  signal address          : std_logic_vector(9 downto 0);
  signal instruction      : std_logic_vector(17 downto 0);
  signal port_id          : std_logic_vector(7 downto 0);
  signal out_port         : std_logic_vector(7 downto 0);
  signal in_port          : std_logic_vector(7 downto 0);
  signal write_strobe     : std_logic;
  signal read_strobe      : std_logic;
  signal interrupt        : std_logic :='0';
  signal interrupt_ack    : std_logic;
  signal interrupt_event  : std_logic;

----------------------------------------------------------------------------------
-- Start of circuit description
----------------------------------------------------------------------------------
begin
  ----------------------------------------------------------------------------------
  -- VHDL component INSTANTIATION
  ----------------------------------------------------------------------------------

  -- kcpsm3 instance
  processor: kcpsm3
  port map(
    reset           => reset           ,
    clk             => clk             ,
    address         => address         ,
    instruction     => instruction     ,
    port_id         => port_id         ,
    write_strobe    => write_strobe    ,
    out_port        => out_port        ,
    read_strobe     => read_strobe     ,
    in_port         => in_port         ,
    interrupt       => interrupt       ,
    interrupt_ack   => interrupt_ack
  );
 
  -- program memory instance
  program: prog_rom 
  port map(
    clk             => clk             ,
    address         => address         ,
    instruction     => instruction
  );

  -- hardware multiplier instance
  multiplicador: mult_8x8
  port map(
    reset           => reset           ,
    clk             => clk             ,
    read_strobe     => read_strobe     ,
    write_strobe    => write_strobe    ,
    port_id         => port_id         ,
    in_port         => in_port         ,
    out_port        => out_port        ,
    interrupt_event => interrupt_event
  );

  ----------------------------------------------------------------------------------
  -- Adding the interrupt input
  ----------------------------------------------------------------------------------
  interrupt_control: process(Clk)
  begin
    if (Clk'event and Clk='1') then
      if (interrupt_ack='1') then
        interrupt <= '0';
      elsif (interrupt_event='1') then
        interrupt <= '1';
      else
        interrupt <= interrupt;
      end if;
    end if; 
  end process interrupt_control;

end behavioral;