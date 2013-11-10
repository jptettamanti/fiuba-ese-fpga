library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


------------------------------------------------------------------------------------
-- Start of MULT 8x8 ENTITY
------------------------------------------------------------------------------------
entity mult_8x8 is
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
end mult_8x8;

------------------------------------------------------------------------------------
-- Start of MULT 8x8 ARCHITECTURE
------------------------------------------------------------------------------------
architecture rtl of mult_8x8 is

  -- Direcciones físicas de los registros de E/S
  constant REG_N1   : std_logic_vector(7 downto 0) := X"01";
  constant REG_N2   : std_logic_vector(7 downto 0) := X"02";
  constant REG_SIGN : std_logic_vector(7 downto 0) := X"03";

  constant REG_RH   : std_logic_vector(7 downto 0) := X"04";
  constant REG_RL   : std_logic_vector(7 downto 0) := X"05";

  -- Senales correspondientes a los registros de E/S
  signal n1    : unsigned(7 downto 0);	-- Multiplicando
  signal n2    : unsigned(7 downto 0);	-- Multiplicador
  signal sign  : unsigned(7 downto 0);	-- Multiplicacion SIN signo (==0). Multiplicacion CON signo (!=0)

  signal rh    : unsigned(7 downto 0);	-- Byte mas significativo del resultado
  signal rl    : unsigned(7 downto 0);	-- Byte menos significativo del resultado

  -- Senales intermedias del proceso de multiplicacion
  signal a, b : unsigned(7 downto 0);
  signal parcial0, parcial1, parcial2, parcial3, parcial4, parcial5, parcial6, parcial7 : unsigned(7 downto 0);
  signal sub1_0, sub1_1, sub1_2, sub1_3, sub2_0, sub2_1, sub3 : unsigned(15 downto 0);
  signal final : unsigned(15 downto 0);

  -- Estados internos del multiplicador
  type tipo_estado is (
    ESPERAR     ,
    ORDENAR     ,
    SUMA_PARCIAL,
    SUMA_FINAL  ,
    SEPARAR     ,
    FINALIZAR
  );

  -- Senales de la maquina de estados del multiplicador
  signal estado_actual, estado_siguiente: tipo_estado;

----------------------------------------------------------------------------------
-- Start of circuit description
----------------------------------------------------------------------------------	
begin
  -- Proceso de manejo de escrituras a los registros de entrada
  input_registers: process(clk)
  begin
    -- Si hay una solicitud de escritura
    if (clk'event and clk='1' and write_strobe='1') then
      case port_id is
      -- Escritura del registro "n1"
      when REG_N1 =>
        n1      <= unsigned(out_port);
      -- Escritura del registro "n2"
      when REG_N2 =>
        n2      <= unsigned(out_port);
      -- Escritura del registro "sign"
      when REG_SIGN =>
        sign    <= unsigned(out_port);
      when others =>
        null;
      end case;
	end if;
  end process input_registers;

  -- Proceso de manejo de lecturas desde los registros de salida
  output_registers: process(clk)
  begin
    -- Si hay una solicitud de lectura
    if (clk'event and clk='1' and read_strobe='1') then
      case port_id is
      -- Lectura del registro "rh"
      when REG_RH =>
        in_port <= std_logic_vector(rh);
      -- Lectura del registro "rl"
      when REG_RL =>
        in_port <= std_logic_vector(rl);
      when others =>
        null;
      end case;
    end if;
  end process output_registers;
	
  -- Proceso de sincronizacion del multiplicador
  process (clk, reset)
  begin
    -- Reset del multiplicador
    if (reset='1') then
      estado_actual <= ESPERAR;
    -- Avance del multiplicador
    elsif (clk'event and clk='1') then
      estado_actual <= estado_siguiente;
    end if;
  end process;

  -- Maquina de estados: logica de proximo estado
  process(estado_actual, write_strobe)
    variable res: std_logic;
  begin
    case estado_actual is

    -- Esperar a que se inicie una nueva multiplicacion
    when ESPERAR =>
      interrupt_event <= '0';

      -- Condicion de escritura del registro de signo
      if (port_id=REG_SIGN and write_strobe='1') then
        estado_siguiente <= ORDENAR;
      end if;

    -- Ordenar acorde al tipo de multiplicacion (CON/SIN signo)
    when ORDENAR =>
      -- Multiplicacion SIN signo,
      if (sign="00000000") then
        a <= n1;
        b <= n2;
        res := '0';					
 
      -- Multiplicacion CON signo
      else
        -- ( + * + = + )
        if (n1(7)='0' and n2(7)='0') then
          a <= n1;
          b <= n2;
          res := '0';
        -- ( + * - = - )
        elsif (n1(7)='0' and n2(7)='1') then
          a <= n1;
          b <= (not n2)+1;
          res := '1';
        -- ( - * + = - )
        elsif (n1(7)='1' and n2(7)='0') then
          a <= (not n1)+1;
          b <= n2;
          res := '1';
        -- ( - * - = + )
        else
          a <= (not n1)+1;
          b <= (not n2)+1;
          res := '0';
        end if;

      end if;

      estado_siguiente <= SUMA_PARCIAL;

    -- Calcular las sumas parciales
    when SUMA_PARCIAL =>
      parcial0 <= (others=>b(0)) and a;
      parcial1 <= (others=>b(1)) and a;
      parcial2 <= (others=>b(2)) and a;
      parcial3 <= (others=>b(3)) and a;
      parcial4 <= (others=>b(4)) and a;
      parcial5 <= (others=>b(5)) and a;
      parcial6 <= (others=>b(6)) and a;
      parcial7 <= (others=>b(7)) and a;

      estado_siguiente <= SUMA_FINAL;

    -- Sumar los resultados desplazados y agregar el signo
    when SUMA_FINAL =>
      sub1_0 <= ("00000000" & parcial0)      + ("0000000" & parcial1 & "0");
      sub1_1 <= ("000000" & parcial2 & "00") + ("00000" & parcial3 & "000");
      sub1_2 <= ("0000" & parcial4 & "0000") + ("000" & parcial5 & "00000");
      sub1_3 <= ("00" & parcial6 & "000000") + ("0" & parcial7 & "0000000");

      sub2_0 <= sub1_0 + sub1_1;
      sub2_1 <= sub1_2 + sub1_3;

      sub3 <= sub2_0 + sub2_1;

      if (res='1') then
        final <= ((not sub3)+1);
		else
		  final <= sub3;
		end if;

      estado_siguiente <= SEPARAR;

    -- Separar el resultado en registros de 8 bits
    when SEPARAR =>
      rh <= final(15 downto 8);
      rl <= final(7 downto 0);

      estado_siguiente <= FINALIZAR;

    -- Interrumpe al PicoBlaze indicando que esta listo el resultado
    when FINALIZAR =>
      interrupt_event  <= '1';

      estado_siguiente <= ESPERAR;				

    end case;
		
  end process;
	
end rtl;
