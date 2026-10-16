;==============================================================================
;  NetTest.asm  -  wrapper for the SymbOS Net Test program
;  Assemble this file in WinAPE 1.0.13 (no colon inside a comment).
;  Needs in the same folder - NetTest-head.asm, NetTest-code.asm and
;  Dmn-Network-libs.asm (the flattened libs from the ESP driver package).
;==============================================================================

org #1000

;--- output file, folder must exist
WRITE "\symnet\nettest.exe"
print "STEP 1 WRITE accepted"

READ "\symnet\SRC-Main\SymbOS-Constants.asm"
print "STEP 2 constants read"
READ "NetTest-head.asm"
print "STEP 3 head read"
READ "Dmn-Network-libs.asm"
print "STEP 4 libs read"
READ "NetTest-code.asm"
print "STEP 5 code read"

App_EndTrns

relocate_table
relocate_end
