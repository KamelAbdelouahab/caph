-----------------------------------------------------------------------------------------
--                                                                                     --
--                This file is part of the CAPH Compiler distribution                  --
--                            http://caph.univ-bpclermont.fr                           --
--                                                                                     --
--                           Jocelyn SEROT, Francois BERRY                      --
--                   {Jocelyn.Serot,Francois.Berry}@univ-bpclermont.fr           --
--                                                                                     --
--         Copyright 2011-2018 Jocelyn SEROT.  All rights reserved.                    --
--  This file is distributed under the terms of the GNU Library General Public License --
--      with the special exception on linking described in file ../LICENSE.            --
--                                                                                     --
-----------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is
generic (
       depth     : integer  := 8;  -- FIFO depth (number of cells)
       width      : integer  := 8  -- FIFO width (size in bits of each cell)
   );
 port (
         full : out std_logic;
         datain : in std_logic_vector (width-1 downto 0);
         enw : in std_logic;
         empty : out std_logic;
         dataout : out std_logic_vector(width-1 downto 0);
         enr : in std_logic;
         clk : in std_logic;
         rst: in std_logic
         );
end fifo;


architecture arch of fifo is

 constant ad_Max : integer range 0 to depth-1:= depth-1;
 constant ad_Min : integer range 0 to depth-1:= 0;
 
 type mem_t is array ( 0 to depth-1) of std_logic_vector((width-1) downto 0);
 signal mem: mem_t ;

 signal address: integer range 0 to depth-1 := ad_Max;

 signal we_a,enr_c,enw_c:std_logic;
 signal readaddr : natural range 0 to depth-1;
 signal writeaddr : natural range 0 to depth-1;
 
 begin

 shift_reg: process (clk)             
     begin

       if (clk'event and clk='1' ) then
       
       -- read 
         if (enr='1' and enw='0') then    
           for i in 0 to ad_Max-1 loop
             mem(i+1) <= mem(i);
           end loop;
         end if;
         
       -- read & write 
         if (enw='1' and enr='1') then    
           if (address = ad_Max)  then   
             mem(address)<=datain;       
           else
             for i in 0 to ad_Max-1 loop
               mem(i+1) <= mem(i);
             end loop;
			 mem(address+1)<=datain;	 
           end if;
         end if;
         
       -- write
         if (enw='1' and enr='0') then    
           mem(address)<=datain;
         end if;

       end if;
     end process shift_reg;
     
     -----------------------------
     -- write address computation
     -----------------------------
     counter : process(clk, rst)          
     begin
       if ( rst='0' ) then  
         address <= ad_Max;
       elsif (clk='1' and clk'event) then

           if (enr = '1' and enw='0' and address < ad_Max) then -- read
             -- Read a new data in FIFO when is not empty 
             -- Read a new data in FIFO and Write simultaneously => No increment
             -- that's why wr='0'
               address <= address + 1;
           end if;

           if (enw = '1' and enr='0' and address > ad_Min) then -- write
             -- Write a new data in FIFO when is not full
             -- Read a new data in FIFO and Write simultaneously => No increment
             -- that's why rd='0'
               address <= address - 1;
           end if;
 
           if (enw = '1' and enr='1' and address= ad_Max) then  -- read & write
               address <= address;
           end if;

       end if;
     end process counter;

   -----------------------------
   -- empty/full flag generation
   -----------------------------
   flags : process(address,enw,enr)  
   begin
        if (  address > ad_Max-1 ) then
        -- if ( enr='1' and address > (ad_Max-2) ) then
           empty<= '1';
         else
           empty <='0';
         end if;

        if ( address < ad_Min+1 ) then
        -- if (enw = '1' and address < (ad_Min+2) ) then
           full<= '1';
         else
           full <='0';
         end if;
   end process flags;
   
   ----------------------------------------
   -- Last register provides the data out
   ----------------------------------------
   dataout <= mem(depth-1);

end architecture;
