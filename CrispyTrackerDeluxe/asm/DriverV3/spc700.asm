namespace SPC
Test =      $F0
Control =   $F1
RegADDR =   $F2
RegData =   $F3
APU0 =      $F4
APU1 =      $F5
APU2 =      $F6
APU3 =      $F7
Unused1 =   $F8
Unused2 =   $F9
Timer1 =    $FA
Timer2 =    $FB
Timer3 =    $FC
Count1 =    $FD
Count2 =    $FE
Count3 =    $FF

macro spc_write(reg, val)
    mov SPC_RegADDR, #<reg>
    mov SPC_RegData, #<val>
endmacro
namespace off