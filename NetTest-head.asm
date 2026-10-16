relocate_start

App_BegCode

;### APPLICATION HEADER #######################################################

;header structure
;prgdatcod       equ 0           ;Length of the code area (OS will place this area everywhere)
;prgdatdat       equ 2           ;Length of the data area (screen manager data; OS will place this area inside a 16k block of one 64K bank)
;prgdattra       equ 4           ;Length of the transfer area (stack, message buffer, desktop manager data; placed between #c000 and #ffff of a 64K bank)
;prgdatorg       equ 6           ;Original origin of the assembler code
;prgdatrel       equ 8           ;Number of entries in the relocator table
;prgdatstk       equ 10          ;Length of the stack in bytes
prgdati16       equ 12          ;Fileoffset of the included 16 colour icon
prgdatflg       equ 14          ;Flags (+1=16colour icon included)
prgdatnam       equ 15          ;Application name. The end of the string must be filled with 0.
;prgdatidn       equ 48          ;"SymExe10" SymbOS executable file identification
prgdatcex       equ 56          ;additional memory for code area (will be reserved directly behind the loaded code area)
prgdatdex       equ 58          ;additional memory for data area (see above)
prgdattex       equ 60          ;additional memory for transfer area (see above)
;prgdatres       equ 62          ;*reserved* (26 bytes)
;prgdatver       equ 88          ;required OS version (3.0)
;prgdatism       equ 90          ;Application icon (small version), 8x8 pixel, SymbOS graphic format
;prgdatibg       equ 109         ;Application icon (big version), 24x24 pixel, SymbOS graphic format
;prgdatlen       equ 256         ;length of header

;prgpstdat       equ 6           ;start address of the data area
;prgpsttra       equ 8           ;start address of the transfer area
;prgpstspz       equ 10          ;additional sub process or timer IDs (4*1)
;prgpstbnk       equ 14          ;64K ram bank (1-15), where the application is located
;prgpstmem       equ 48          ;additional memory areas; 8 memory areas can be registered here, each entry consists of 5 bytes
                                ;00  1B  Ram bank number (1-8; if 0, the entry will be ignored)
                                ;01  1W  Address
                                ;03  1W  Length
prgpstnum       equ 88          ;Application ID
;prgpstprz       equ 89          ;Main process ID

            dw App_BegData-App_BegCode  ;length of code area
            dw App_BegTrns-App_BegData  ;length of data area
            dw App_EndTrns-App_BegTrns  ;length of transfer area
prgdatadr   dw #1000                ;original origin                    POST address data area
prgtrnadr   dw relocate_count       ;number of relocator table entries  POST address transfer area
prgprztab   dw prgstk-App_BegTrns   ;stack length                       POST table processes
            dw 0                    ;*reserved*
App_BnkNum  db 0                    ;*reserved*                         POST bank number
            db "Net Test":ds 16:db 0  ;name
            db 1                    ;flags (+1=16c icon)
            dw App_BegData-App_BegCode  ;16 colour icon offset
            ds 5                    ;*reserved*
prgmemtab   db "SymExe10"           ;SymbOS-EXE-identifier              POST table reserved memory areas
            dw 0                    ;additional code memory
            dw 0                    ;additional data memory
            dw 0                    ;additional transfer memory
            ds 26                   ;*reserved*
            db 0,2                  ;required OS version (3.0) ##!!##
prgicnsml   db 2,8,8
            db #f0,#0f,#f6,#0f,#f0,#5d,#4f,#af,#5f,#2f,#ab,#f0,#0f,#f6,#0f,#f0
prgicnbig   db 6,24,24
            db #3f,#ff,#ff,#ef,#0f,#0f,#4f,#0f,#0f,#3a,#7f,#ed,#88,#00,#00,#76,#ce,#7d,#9a,#f0,#f0,#7e,#46,#6c,#9a,#ff,#ee,#7e,#c6,#7c,#9a,#ff,#ee,#7e,#78,#e1,#9a,#ff,#ee,#7e,#1f,#43,#9a,#ff,#ff,#ff,#ff,#ef
            db #9a,#00,#47,#0f,#0f,#3a,#8b,#0f,#88,#00,#00,#76,#ff,#ff,#9a,#f0,#f0,#7e,#f0,#f0,#9a,#ff,#ee,#7e,#88,#00,#9a,#ff,#ee,#7e,#8b,#3c,#9a,#ff,#ee,#7e,#8a,#0f,#9a,#ff,#ee,#7e,#ff,#ff,#9a,#00,#00,#7e
            db #f0,#f0,#8b,#0f,#0f,#7e,#1f,#43,#ff,#ff,#ff,#fd,#7f,#ed,#f0,#f0,#f0,#f2,#ce,#7d,#88,#00,#00,#76,#46,#6c,#8b,#1e,#f0,#7e,#c6,#7c,#8a,#0f,#4f,#7e,#78,#e1,#ff,#ff,#ff,#ed,#0f,#0f,#f0,#f0,#f0,#c3
