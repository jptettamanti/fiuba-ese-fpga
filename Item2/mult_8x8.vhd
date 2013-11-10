library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


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

architecture rtl of mult_8x8 is

  -- Direcciones físicas de los registros de E/S
  constant REG_N1   : std_logic_vector(7 downto 0) := X"01";
  constant REG_N2   : std_logic_vector(7 downto 0) := X"02";
  constant REG_SIGN : std_logic_vector(7 downto 0) := X"03";

  constant REG_RH   : std_logic_vector(7 downto 0) := X"04";
  constant REG_RL   : std_logic_vector(7 downto 0) := X"05";

  -- Señales correspondientes a los registros de E/S
  signal n1    : unsigned(7 downto 0);	-- Multiplicando
  signal n2    : unsigned(7 downto 0);	-- Multiplicador
  signal sign  : unsigned(7 downto 0);	-- Multiplicacion SIN signo (==0). Multiplicacion CON signo (!=0)

  signal rh    : unsigned(7 downto 0);	-- Byte mas significativo del resultado
  signal rl    : unsigned(7 downto 0);	-- Byte menos significativo del resultado

  -- Señales intermedias del proceso de multiplicacion
  signal a, b : unsigned(7 downto 0);
  signal b1_0, b1_1, b1_2, b1_3, b1_4, b1_5, b1_6, b1_7 : unsigned(7 downto 0);
  signal b2_0, b2_1, b2_2, b2_3, b2_4, b2_5, b2_6, b2_7 : unsigned(7 downto 0);
  signal p0, p1, p2, p3, p4, p5, p6, p7 : unsigned(15 downto 0);
  signal prod1, prod2 : unsigned(15 downto 0);

  -- Estados internos del multiplicador
  type tipo_estado is (
    ESPERAR     ,
    ORDENAR     ,
    EXTENDER    ,
    SUMA_PARCIAL,
    DESPLAZAR   ,
    SUMA_FINAL  ,
    SIGNO       ,
    SEPARAR     ,
    FINALIZAR
  );

  -- Señales de la maquina de estados del multiplicador
  signal estado_actual, estado_siguiente: tipo_estado;
	
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

      -- Condición de escritura del registro de signo
      if (port_id=REG_SIGN and write_strobe='1') then
        estado_siguiente <= ORDENAR;
      end if;

    -- Ordenar acorde al tipo de multiplicacion (CON/SIN signo)
    when ORDENAR =>
      -- Multiplicación SIN signo,
      if (sign="00000000") then
        a <= n1;
        b <= n2;
        res := '0';					
 
      -- Multiplicación CON signo
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

      estado_siguiente <= EXTENDER;

    -- Extender los bits del segundo operando
    when EXTENDER =>
      b1_0 <= (others=>b(0));
      b1_1 <= (others=>b(1));
      b1_2 <= (others=>b(2));
      b1_3 <= (others=>b(3));
      b1_4 <= (others=>b(4));
      b1_5 <= (others=>b(5));
      b1_6 <= (others=>b(6));
      b1_7 <= (others=>b(7));

      estado_siguiente <= SUMA_PARCIAL;

    -- Calcular las sumas parciales
    when SUMA_PARCIAL =>
      b2_0 <= b1_0 and a;
      b2_1 <= b1_1 and a;
      b2_2 <= b1_2 and a;
      b2_3 <= b1_3 and a;
      b2_4 <= b1_4 and a;
      b2_5 <= b1_5 and a;
      b2_6 <= b1_6 and a;
      b2_7 <= b1_7 and a;

      estado_siguiente <= DESPLAZAR;

    -- Desplazar las sumas parciales
    when DESPLAZAR =>
      p0 <= "00000000" & b2_0     ;
      p1 <= "0000000" & b2_1 & "0";
      p2 <= "000000" & b2_2 & "00";
      p3 <= "00000" & b2_3 & "000";
      p4 <= "0000" & b2_4 & "0000";
      p5 <= "000" & b2_5 & "00000";
      p6 <= "00" & b2_6 & "000000";
      p7 <= "0" & b2_7 & "0000000";

      estado_siguiente <= SUMA_FINAL;

    -- Sumar los resultados desplazados
    when SUMA_FINAL =>
      prod1 <= ((p0+p1)+(p2+p3))+((p4+p5)+(p6+p7));

      estado_siguiente <= SIGNO;

    -- Agregar el signo que corresponda
    when SIGNO =>
      if (res='1') then
        prod2 <= (not prod1)+1;
      else
        prod2 <= prod1;
      end if;

      estado_siguiente <= SEPARAR;

    -- Separar el resultado en registros de 8 bits
    when SEPARAR =>
      rh <= prod2(15 downto 8);
      rl <= prod2(7 downto 0);

      estado_siguiente <= FINALIZAR;

    -- Interrumpe al PicoBlaze indicando que esta listo el resultado
    when FINALIZAR =>
      interrupt_event  <= '1';

      estado_siguiente <= ESPERAR;				

    end case;
		
  end process;
	
end rtl;
