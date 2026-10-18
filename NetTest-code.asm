;==============================================================================
;  NetTest-code.asm  -  small network test program for SymbOS
;  World clock (SNTP over UDP), weather (HTTP over TCP) and sun times (HTTP).
;  Talks to the Network Daemon through the SyNet functions.
;  Comment rule for WinAPE 1.0.13 - never put a colon inside a comment.
;==============================================================================

LINES       equ 9           ;number of result lines
LINEW       equ 36          ;bytes per result line, keep at 36
NCITY       equ 16
CT_NAME     equ 0
CT_URL      equ 16
CT_TZ       equ 32
CT_LAT      equ 56
CT_LNG      equ 64
CT_OFF      equ 72
CT_RULE     equ 73
CT_LEN      equ 74
RXMAX       equ 1800
NTTMO       equ 2500

;==============================================================================
;### MAIN PROCESS #############################################################
;==============================================================================

prgprz  ld a,(App_BnkNum)
        ld de,ntwindat
        call SyDesktop_WINOPN
        jp c,ntend
        ld (ntwinid),a
        call ntclr
        call SyNet_NETINI
        jr c,prgprz1
        ld hl,nttxtrdy
        jr prgprz2
prgprz1 ld hl,nttxtnod
prgprz2 call ntmsg
prgprz3 rst #30
        ld a,(App_PrcID)
        db #dd:ld l,a
        db #dd:ld h,-1
        ld iy,App_MsgBuf
        rst #08
        db #dd:dec l
        jr nz,prgprz3
        ld a,(App_MsgBuf+0)
        cp MSR_DSK_WCLICK
        jr nz,prgprz3
        ld a,(App_MsgBuf+2)
        cp DSK_ACT_CLOSE
        jp z,ntend
        cp DSK_ACT_CONTENT
        jr nz,prgprz3
        ld hl,(App_MsgBuf+8)
        ld a,h
        or l
        jr z,prgprz3
        jp (hl)

ntend   ld hl,(App_BegCode+prgpstnum)
        call SySystem_PRGEND
ntend0  rst #30
        jr ntend0

;### NTFAIL -> show message in HL and go back to the main loop
ntfail  call ntmsg
        jp prgprz3

;==============================================================================
;### RESULT LINE HELPERS ######################################################
;==============================================================================

;### NTCLR -> empties all result lines
ntclr   ld hl,ntlines
        ld de,ntlines+1
        ld bc,LINES*LINEW-1
        ld (hl),0
        ldir
        ret

;### NTMSG -> clears the lines, puts the text HL into line 0 and redraws
ntmsg   push hl
        call ntclr
        xor a
        call ntlbeg
        pop hl
        call ntpstr
        jp ntredraw

;### NTREDRAW -> redraws the window content
ntredraw ld a,(ntwinid)
        ld e,255
        jp SyDesktop_WINDIN

;### NTLBEG -> starts writing into line A
ntlbeg  push hl
        push de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld de,ntlines
        add hl,de
        ld (ntpp),hl
        ld (hl),0
        ld a,LINEW-1
        ld (ntpcnt),a
        pop de
        pop hl
        ret

;### NTPCH -> appends character A to the current line
ntpch   push hl
        push af
        ld a,(ntpcnt)
        or a
        jr z,ntpch1
        dec a
        ld (ntpcnt),a
        ld hl,(ntpp)
        pop af
        ld (hl),a
        inc hl
        ld (hl),0
        ld (ntpp),hl
        pop hl
        ret
ntpch1  pop af
        pop hl
        ret

;### NTPSTR -> appends the 0-terminated string HL
ntpstr  ld a,(hl)
        or a
        ret z
        inc hl
        call ntpch
        jr ntpstr

;### NTP3 -> appends 3 characters from HL
ntp3    ld b,3
ntp31   ld a,(hl)
        inc hl
        call ntpch
        djnz ntp31
        ret

;### NTPD2 -> appends A (0-99) as two digits
ntpd2   ld b,"0"
ntpd21  cp 10
        jr c,ntpd22
        sub 10
        inc b
        jr ntpd21
ntpd22  push af
        ld a,b
        call ntpch
        pop af
        add a,"0"
        jp ntpch

;### NTPDEC -> appends A (0-255) as a decimal number without leading zeros
ntpdec  ld c,0
        ld b,100
        call ntpdc1
        ld b,10
        call ntpdc1
        add a,"0"
        jp ntpch
ntpdc1  ld d,"0"
ntpdc2  cp b
        jr c,ntpdc3
        sub b
        inc d
        jr ntpdc2
ntpdc3  ld e,a
        ld a,d
        cp "0"
        jr nz,ntpdc4
        ld a,c
        or a
        jr z,ntpdc5
        ld a,"0"
        jr ntpdc6
ntpdc4  ld c,1
ntpdc6  call ntpch
ntpdc5  ld a,e
        ret

;### NTPPORT -> appends the port, with TLS when the HTTPS box is ticked
ntpport ld hl,nttxtp80
        ld a,(ntchk)
        or a
        jr z,ntppo1
        ld hl,nttxtp443
ntppo1  jp ntpstr

;### NTPADTO -> pads the current line with spaces up to column A
ntpadto ld b,a
ntpad1  ld a,LINEW-1
        ld hl,ntpcnt
        sub (hl)
        cp b
        ret nc
        ld a," "
        call ntpch
        jr ntpad1

;### NTPDAY -> appends the 3 letter day name of A (0=sunday)
ntpday  ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,ntdayn
        add hl,de
        jp ntp3

;### NTPMON -> appends the 3 letter month name of A (1-12)
ntpmon  dec a
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,de
        ld de,ntmonn
        add hl,de
        jp ntp3

;### NTPLEFT -> appends the text HL to the lines starting at line A, wraps at the line end
ntpleft ld (ntwl),a
        call ntlbeg
ntpl1   ld a,(hl)
        or a
        ret z
        inc hl
        cp 32
        jr nc,ntpl2
        ld a," "
ntpl2   cp 127
        jr nc,ntpl1
        push hl
        call ntpch
        ld a,(ntpcnt)
        or a
        jr nz,ntpl3
        ld a,(ntwl)
        inc a
        ld (ntwl),a
        cp LINES-1
        jr nc,ntpl4
        call ntlbeg
ntpl3   pop hl
        jr ntpl1
ntpl4   pop hl
        ret

;### NTSTATLINE -> writes the first line of the reply (the HTTP status) into line A
ntstatline call ntlbeg
        ld hl,rxbuf
ntstl1  ld a,(hl)
        cp 32
        ret c
        inc hl
        call ntpch
        jr ntstl1

;==============================================================================
;### BUTTON HANDLERS ##########################################################
;==============================================================================

;### BTCLK -> world clock through SNTP over UDP
btclk   ld hl,nttxtwrk
        call ntmsg
        ld hl,ntsntph
        call ntdns
        jr nc,btclk1
        ld hl,nttxtedns
        jp ntfail
btclk1  ld hl,#ffff             ;the daemon picks a free local port
        ld a,(App_BnkNum)
        ld e,a
        xor a
        call SyNet_UDPOPN
        jr nc,btclk2
        ld hl,nttxtesck
        jp ntfail
btclk2  ld (nthnd),a
        ld b,3
btclk3  push bc
        ld a,b
        cp 2
        ld hl,ntipg
        jr z,btclk3a
        cp 1
        ld hl,ntipc
        jr nz,btclk3b
btclk3a ld de,ntip
        ld bc,4
        ldir
btclk3b call ntsntq
        pop bc
        jr nc,btclk4
        djnz btclk3
        ld a,(nthnd)
        call SyNet_UDPCLO
        ld hl,nttxtetmo
        call ntdbgmsg
        jp ntfail
btclk4  ld a,b
        ld (ntsrv),a            ;3 = pool.ntp.org, 2 = Google, 1 = Cloudflare
        ld a,(nthnd)
        call SyNet_UDPCLO
        ;--- transmit timestamp, big endian at offset 40, to little endian
        ld a,(ntpkt+40)
        ld (ntsec+3),a
        ld a,(ntpkt+41)
        ld (ntsec+2),a
        ld a,(ntpkt+42)
        ld (ntsec+1),a
        ld a,(ntpkt+43)
        ld (ntsec+0),a
        ld hl,ntsec
        ld de,nt1970
        call nt32sub
        ld hl,ntsec
        ld de,ntutc
        ld bc,4
        ldir
        call ntclr
        ;--- line 0 = the selected city
        call ntgetsel
        ld (ntcsel),a
        ld b,a
        xor a
        ld (ntlnum),a
        ld a,b
        call ntcline
        ;--- line 1 = UTC with seconds
        ld hl,ntutc
        ld de,ntsec
        ld bc,4
        ldir
        call ntdate
        ld a,1
        call ntlbeg
        ld hl,nttxtutc
        call ntpstr
        ld a,15
        call ntpadto
        call ntpdt
        ld a,(ntsc)
        push af
        ld a,":"
        call ntpch
        pop af
        call ntpd2
        ;--- explanation and what was sent to whom
        ld a,3
        ld hl,nttxtstar
        call ntpleft
        ld a,5
        ld hl,nttxtsent
        call ntpleft
        ld a,6
        call ntlbeg
        ld hl,nttxtto
        call ntpstr
        ld a,(ntsrv)
        ld hl,ntsntph
        cp 3
        jr z,btclk8
        ld hl,nttxtgoo
        cp 2
        jr z,btclk8
        ld hl,nttxtclf
btclk8  call ntpstr
        ld a,7
        call ntlbeg
        ld hl,nttxtip
        call ntpstr
        ld hl,ntip
        ld b,4
btclk9  ld a,(hl)
        inc hl
        push hl
        push bc
        call ntpdec
        pop bc
        pop hl
        ld a,b
        cp 1
        jr z,btclk10
        ld a,"."
        call ntpch
btclk10 djnz btclk9
        ld a,8
        call ntlbeg
        ld hl,nttxtstr
        call ntpstr
        ld a,(ntpkt+1)
        call ntpd2
        ;--- put the date of the city into the date fields
        call ntfilldate
        call ntredraw
        jp prgprz3

;### NTPDT -> appends day name, day, month name and hh mm of the converted date
ntpdt   ld a,(ntdow)
        call ntpday
        ld a," "
        call ntpch
        ld a,(ntdy)
        call ntpd2
        ld a," "
        call ntpch
        ld a,(ntmo)
        call ntpmon
        ld a," "
        call ntpch
        ld a,(nthr)
        call ntpd2
        ld a,":"
        call ntpch
        ld a,(ntmi)
        jp ntpd2

;### NTCLINE -> city A, written into line (ntlnum)
ntcline ld (ntcidx),a
        call ntgetc
        ld (ntcrec),hl
        ld de,CT_OFF
        add hl,de
        ld a,(hl)
        ld (ntoff15),a
        inc hl
        ld a,(hl)
        ld (ntrule),a
        ld hl,ntutc
        ld de,ntsec
        ld bc,4
        ldir
        call ntoffadd
        call ntdate
        call ntdst
        or a
        ld (ntdstf),a
        jr z,ntcln1
        ld hl,ntsec
        ld de,nt3600
        call nt32add
        call ntdate
ntcln1  ld a,(ntlnum)
        or a
        call z,ntsvdt
        ld a,(ntlnum)
        call ntlbeg
        ld hl,(ntcrec)
        call ntpstr
        ld a,15
        call ntpadto
        call ntpdt
        ld a,(ntdstf)
        or a
        ret z
        ld a,"*"
        jp ntpch

;### NTSVDT -> remember the date of the first line
ntsvdt  ld hl,(ntyr)
        ld (ntdsy),hl
        ld a,(ntmo)
        ld (ntdsm),a
        ld a,(ntdy)
        ld (ntdsd),a
        ret

;### NTFILLDATE -> writes the saved date into the three date input fields
ntfilldate
        ld hl,ntbufy
        ld (ntqp),hl
        ld hl,(ntdsy)
        call ntq4
        ld hl,ntbufm
        ld (ntqp),hl
        ld a,(ntdsm)
        call ntq2
        ld hl,ntbufd
        ld (ntqp),hl
        ld a,(ntdsd)
        call ntq2
        ld ix,ntcyr
        ld a,4
        call ntsetlen
        ld ix,ntcmo
        ld a,2
        call ntsetlen
        ld ix,ntcdy
        ld a,2
        jp ntsetlen
ntsetlen ld (ix+4),a
        ld (ix+8),a
        xor a
        ld (ix+2),a
        ld (ix+6),a
        ret

;### NTSNTQ -> sends one SNTP request and waits for the answer, CF=1 means no answer
ntsntq  ld b,3                  ;resend the request up to three times per server
ntsntw  push bc
        call ntsnt1
        pop bc
        ret nc
        djnz ntsntw
        scf
        ret

ntsnt1  ld hl,ntpkt
        ld de,ntpkt+1
        ld bc,63
        ld (hl),0
        ldir
        ld a,#1b
        ld (ntpkt),a
        ld a,(nthnd)
        ld hl,ntpkt
        ld bc,48
        ld ix,(ntip)
        ld iy,(ntip+2)
        ld de,123
        call SyNet_UDPSND
        jr nc,ntsq0
        ld (ntdbgv),a
        ld a,"D"
        ld (ntdbgc),a
        scf
        ret
ntsq0   ld hl,150
        ld (ntcnt),hl
ntsq1   ld a,(nthnd)
        call SyNet_UDPSTA
        jr c,ntsqx
        ld a,l
        ld (ntdbgv),a
        ld a,"U"
        ld (ntdbgc),a
        bit 7,l
        jr nz,ntsq2
        rst #30
        ld hl,(ntcnt)
        dec hl
        ld (ntcnt),hl
        ld a,h
        or l
        jr nz,ntsq1
ntsqe   scf
        ret
ntsqx   ld (ntdbgv),a
        ld a,"E"
        ld (ntdbgc),a
        scf
        ret
ntsq2   ld a,(nthnd)
        ld hl,ntpkt
        call SyNet_UDPRCV
        ret c
        ld a,(ntpkt)
        ld (ntdbgv),a
        ld a,"M"
        ld (ntdbgc),a
        ld a,(ntpkt)
        and 7
        cp 4
        jr nz,ntsqe
        ld a,(ntpkt+1)
        ld (ntdbgv),a
        ld a,"Z"
        ld (ntdbgc),a
        or a
        jr z,ntsqe
        or a
        ret

;### BTWEA -> short weather text from wttr.in
btwea   ld hl,nttxtwrk
        call ntmsg
        call ntgetsel
        ld hl,ntreq
        ld (ntqp),hl
        ld (hl),0
        ld hl,nttxtwget
        call ntqs
        ld hl,(ntcrec)
        ld de,CT_URL
        add hl,de
        call ntqs
        ld hl,nttxtwfmt
        call ntqs
        ld hl,ntwttrh
        call ntqtail
        ld hl,ntwttrh
        call nthttp
        jp c,ntfail
        call ntbody
        call ntclr
        xor a
        call ntlbeg
        ld hl,nttxtwtr
        call ntpstr
        ld hl,(ntcrec)
        call ntpstr
        ld hl,(ntbdy)
        ld a,1
        call ntpleft
        ld a,7
        call ntlbeg
        ld hl,nttxtswe
        call ntpstr
        call ntpport
        ld a,LINES-1
        call ntstatline
        call ntredraw
        jp prgprz3

;### BTSUN -> sunrise and sunset from api.sunrise-sunset.org
btsun   ld hl,nttxtwrk
        call ntmsg
        call ntgetsel
        ;--- read the date fields
        ld hl,ntbufy
        call ntnum
        jp c,ntebd
        ld (ntyv),de
        ld (ntyc),a
        ld hl,ntbufm
        call ntnum
        jp c,ntebd
        ld (ntmv),de
        ld (ntmc),a
        ld hl,ntbufd
        call ntnum
        jp c,ntebd
        ld (ntdv),de
        ld (ntdc),a
        ld hl,ntdatestr
        ld (ntqp),hl
        ld a,(ntyc)
        ld hl,ntmc
        or (hl)
        ld hl,ntdc
        or (hl)
        jr nz,btsun1
        ld hl,nttxttoday
        call ntqs
        jr btsun3
btsun1  ld a,(ntyc)
        cp 4
        jp nz,ntebd
        ld hl,(ntyv)
        ld de,1900
        or a
        sbc hl,de
        jp c,ntebd
        ld hl,(ntyv)
        ld de,2100
        or a
        sbc hl,de
        jp nc,ntebd
        ld hl,(ntmv)
        ld b,1
        ld c,12
        call ntinrng
        jp c,ntebd
        ld hl,(ntdv)
        ld b,1
        ld c,31
        call ntinrng
        jp c,ntebd
        ld hl,(ntyv)
        call ntq4
        ld a,"-"
        call ntqc
        ld a,(ntmv)
        call ntq2
        ld a,"-"
        call ntqc
        ld a,(ntdv)
        call ntq2
        ;--- build the request
btsun3  ld hl,ntreq
        ld (ntqp),hl
        ld (hl),0
        ld hl,nttxtsget
        call ntqs
        ld hl,(ntcrec)
        ld de,CT_LAT
        add hl,de
        call ntqs
        ld hl,nttxtlng
        call ntqs
        ld hl,(ntcrec)
        ld de,CT_LNG
        add hl,de
        call ntqs
        ld hl,nttxtdat
        call ntqs
        ld hl,ntdatestr
        call ntqs
        ld hl,nttxtfmt
        call ntqs
        ld hl,(ntcrec)
        ld de,CT_TZ
        add hl,de
        call ntqs
        ld hl,ntsunhost
        call ntqtail
        ld hl,ntsunhost
        call nthttp
        jp c,ntfail
        ;--- check the status field
        ld hl,rxbuf
        ld de,nttxtsok
        call ntstrstr
        jr nc,btsun4
        call ntclr
        ld a,1
        call ntstatline
        xor a
        call ntlbeg
        ld hl,nttxteres
        call ntpstr
        call ntredraw
        jp prgprz3
btsun4  call ntclr
        xor a
        call ntlbeg
        ld hl,nttxtstit
        call ntpstr
        ld hl,(ntcrec)
        call ntpstr
        ld a,1
        call ntlbeg
        ld hl,nttxtdate
        call ntpstr
        ld hl,ntdatestr
        call ntpstr
        ;--- sunrise
        ld a,2
        ld (ntlnum),a
        ld hl,nttxtlrs
        ld de,nttxtkrs
        call ntsunline
        ld (ntmin1),de
        ;--- solar noon
        ld a,3
        ld (ntlnum),a
        ld hl,nttxtlno
        ld de,nttxtkno
        call ntsunline
        ;--- sunset
        ld a,4
        ld (ntlnum),a
        ld hl,nttxtlss
        ld de,nttxtkss
        call ntsunline
        ld (ntmin2),de
        ;--- day length
        ld a,5
        call ntlbeg
        ld hl,nttxtlln
        call ntpstr
        ld a,12
        call ntpadto
        ld hl,(ntmin1)
        ld de,(ntmin2)
        ex de,hl
        or a
        sbc hl,de
        jr nc,btsun5
        ld de,1440
        add hl,de
btsun5  ld de,60
        ld b,0
btsun6  or a
        sbc hl,de
        jr c,btsun7
        inc b
        jr btsun6
btsun7  add hl,de
        push hl
        ld a,b
        call ntpd2
        ld a,":"
        call ntpch
        pop hl
        ld a,l
        call ntpd2
        ld a,6
        call ntlbeg
        ld hl,nttxtloc
        call ntpstr
        ld a,7
        call ntlbeg
        ld hl,nttxtssu
        call ntpstr
        call ntpport
        ld a,LINES-1
        call ntstatline
        call ntredraw
        jp prgprz3

;### NTEBD -> date error
ntebd   ld hl,nttxtebd
        jp ntfail

;### NTSUNLINE -> HL=label, DE=json key. Writes label and the time into line (ntlnum)
;### Output DE=minutes of the day of the found time, 0 if not found
ntsunline
        push de
        push hl
        ld a,(ntlnum)
        call ntlbeg
        pop hl
        call ntpstr
        ld a,12
        call ntpadto
        pop de
        ld hl,rxbuf
        call ntstrstr
        jr c,ntsul9
ntsul1  ld a,(hl)
        or a
        jr z,ntsul9
        inc hl
        cp "T"
        jr nz,ntsul1
        ;--- hl points at the hours
        push hl
        ld b,5
ntsul2  ld a,(hl)
        inc hl
        call ntpch
        djnz ntsul2
        pop hl
        call ntdig2
        ld c,a
        inc hl
        call ntdig2
        ld e,a
        ld d,0
        ld b,c
        ld hl,0
        ld a,b
        or a
        jr z,ntsul4
        ld c,60
ntsul3  push de
        ld e,c
        ld d,0
        add hl,de
        pop de
        djnz ntsul3
ntsul4  add hl,de
        ex de,hl
        ret
ntsul9  ld hl,nttxtnone
        call ntpstr
        ld de,0
        ret

;### NTDIG2 -> reads two digits at HL, returns the value in A, HL advanced by 2
ntdig2  ld a,(hl)
        inc hl
        sub "0"
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,a
        ld b,a
        ld a,(hl)
        inc hl
        sub "0"
        add a,b
        ret

;### NTINRNG -> HL must be in B to C, CF=1 if not
ntinrng ld a,h
        or a
        jr nz,ntirx
        ld a,l
        cp b
        jr c,ntirx
        ld a,c
        cp l
        ret nc
ntirx   scf
        ret

;### NTNUM -> reads the decimal digits at HL, DE=value, A=number of digits, CF=1 if not a number
ntnum   ld de,0
        ld b,0
ntnm1   ld a,(hl)
        or a
        jr z,ntnm9
        sub "0"
        cp 10
        jr nc,ntnmx
        inc hl
        inc b
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        jr ntnm1
ntnm9   ld a,b
        or a
        ret
ntnmx   scf
        ret

;==============================================================================
;### HTTP #####################################################################
;==============================================================================

;### NTHTTP -> HL=host name, sends the request in ntreq, answer goes to rxbuf
;### Output CF=0 ok, CF=1 error and HL=error text
nthttp  push hl                 ;host name
        ld hl,80                ;plain HTTP, or HTTPS when the box is ticked
        ld a,(ntchk)
        or a
        jr z,nthttp0
        ld hl,443               ;the daemon makes port 443 a TLS connection
nthttp0 ld (nthport),hl
        pop hl
        call ntdns
        jp c,nthe1
        ld ix,(ntip)
        ld iy,(ntip+2)
        ld de,(nthport)
        ld hl,-1
        xor a
        call SyNet_TCPOPN
        jp c,nthe2
        ld (nthnd),a
        ld hl,NTTMO
        ld (ntcnt),hl
nthw1   ld a,(nthnd)
        call SyNet_TCPSTA
        jp c,nthw9
        ld a,l
        and 127
        cp 2
        jr z,nthsnd
        cp 3
        jp nc,nthw8
        rst #30
        ld hl,(ntcnt)
        dec hl
        ld (ntcnt),hl
        ld a,h
        or l
        jr nz,nthw1
        jp nthe4
nthsnd  ld hl,ntreq
        call ntstrlen
        ld (ntsl),bc
        ld hl,ntreq
        ld (ntsp),hl
        ld a,30
        ld (ntretry),a
nthsl   ld a,(App_BnkNum)
        ld e,a
        ld hl,(ntsp)
        ld bc,(ntsl)
        ld a,(nthnd)
        call SyNet_TCPSND
        jp c,nths9
        ld a,h
        or l
        jr z,nthrcv
        ld (ntsl),hl
        ld hl,(ntsp)
        add hl,bc
        ld (ntsp),hl
        rst #30
        ld hl,ntretry
        dec (hl)
        jr nz,nthsl
        jp nthe4
nthrcv  ld hl,rxbuf
        ld (ntrp),hl
        ld hl,0
        ld (ntrxl),hl
        ld hl,NTTMO
        ld (ntcnt),hl
nthr1   ld a,(nthnd)
        call SyNet_TCPSTA
        jp c,nthdone
        bit 7,l
        jr nz,nthdat
        ld a,l
        cp 3
        jp nc,nthdone
        rst #30
        ld hl,(ntcnt)
        dec hl
        ld (ntcnt),hl
        ld a,h
        or l
        jr nz,nthr1
        jp nthdone
nthdat  ld hl,RXMAX
        ld de,(ntrxl)
        or a
        sbc hl,de
        ld a,h
        or l
        jp z,nthdone
        push hl
        or a
        sbc hl,bc
        pop hl
        jr nc,nthd2
        ld b,h
        ld c,l
nthd2   ld a,(App_BnkNum)
        ld e,a
        ld hl,(ntrp)
        ld a,(nthnd)
        call SyNet_TCPRCV
        jp c,nthdone
        ld hl,(ntrp)
        add hl,bc
        ld (ntrp),hl
        ld hl,(ntrxl)
        add hl,bc
        ld (ntrxl),hl
        ld hl,NTTMO
        ld (ntcnt),hl
        jp nthr1
nthdone ld hl,(ntrp)
        ld (hl),0
        ld a,(nthnd)
        call SyNet_TCPDIS
        ld hl,(ntrxl)
        ld a,h
        or l
        jr z,nthe5
        or a
        ret
nthe1   ld hl,nttxtedns
        scf
        ret
nthe2   ld hl,nttxtesck
        scf
        ret
nthw9   ld c,a
        ld b,"A"
        jr nthe3x
nthw8   ld c,l
        ld b,"B"
        jr nthe3x
nths9   ld c,a
        ld b,"C"
nthe3x  ld a,b
        ld (ntdbgc),a
        ld a,c
        ld (ntdbgv),a
nthe3   ld a,(nthnd)
        call SyNet_TCPDIS
        ld hl,nttxtecon
        call ntdbgmsg
        scf
        ret
nthe4   ld a,(nthnd)
        call SyNet_TCPDIS
nthe5   ld hl,nttxtetmo
        scf
        ret

;### NTDBGMSG -> HL=text, returns HL=text followed by the debug letter and value in hex
ntdbgmsg push hl
        ld hl,ntdbgbuf
        ld (ntqp),hl
        pop hl
        call ntqs
        ld a," "
        call ntqc
        ld a,(ntdbgc)
        call ntqc
        ld a,(ntdbgv)
        call ntqhex
        ld hl,ntdbgbuf
        ret
ntqhex  push af
        rrca
        rrca
        rrca
        rrca
        call ntqhx1
        pop af
ntqhx1  and 15
        add a,"0"
        cp "9"+1
        jr c,ntqhx2
        add a,7
ntqhx2  jp ntqc

;### NTDNS -> HL=host name, resolves it into ntip. CF=1 on error
ntdns   call SyNet_DNSRSV
        ret c
        ld (ntip),ix
        ld (ntip+2),iy
        ret

;### NTSTRLEN -> HL=string, BC=length
ntstrlen ld bc,0
ntstln1 ld a,(hl)
        or a
        ret z
        inc hl
        inc bc
        jr ntstln1

;### NTSTRSTR -> searches the string DE in the string HL. CF=0 found and HL=position
ntstrstr ld a,(hl)
        or a
        jr z,ntsts9
        push hl
        push de
ntsts2  ld a,(de)
        or a
        jr z,ntsts5
        cp (hl)
        jr nz,ntsts4
        inc hl
        inc de
        jr ntsts2
ntsts4  pop de
        pop hl
        inc hl
        jr ntstrstr
ntsts5  pop de
        pop hl
        or a
        ret
ntsts9  scf
        ret

;### NTBODY -> (ntbdy)=start of the reply body
ntbody  ld hl,rxbuf
        ld de,nttxtcrlf2
        call ntstrstr
        jr c,ntbd1
        inc hl
        inc hl
        inc hl
        inc hl
        jr ntbd2
ntbd1   ld hl,rxbuf
ntbd2   push hl
        ld hl,rxbuf
        ld de,nttxtchunk
        call ntstrstr
        pop de
        jr c,ntbd5
        or a
        sbc hl,de
        jr nc,ntbd5
ntbd3   ld a,(de)
        or a
        jr z,ntbd5
        inc de
        cp 10
        jr nz,ntbd3
ntbd5   ld (ntbdy),de
        ret

;### request builder, appends at (ntqp)
ntqs    ld de,(ntqp)
ntqs1   ld a,(hl)
        or a
        jr z,ntqs2
        ld (de),a
        inc hl
        inc de
        jr ntqs1
ntqs2   ld (de),a
        ld (ntqp),de
        ret
ntqc    ld hl,(ntqp)
        ld (hl),a
        inc hl
        ld (hl),0
        ld (ntqp),hl
        ret
ntq2    ld b,"0"
ntq21   cp 10
        jr c,ntq22
        sub 10
        inc b
        jr ntq21
ntq22   push af
        ld a,b
        call ntqc
        pop af
        add a,"0"
        jp ntqc
ntq4    ld de,100
        ld c,0
ntq41   or a
        sbc hl,de
        jr c,ntq42
        inc c
        jr ntq41
ntq42   add hl,de
        ld a,c
        push hl
        call ntq2
        pop hl
        ld a,l
        jp ntq2
ntqtail push hl
        ld hl,nttxttl1
        call ntqs
        pop hl
        call ntqs
        ld hl,nttxttl2
        jp ntqs

;==============================================================================
;### CITY TABLE ACCESS ########################################################
;==============================================================================

;### NTGETSEL -> reads the dropdown, A=index, (ntcrec)=city record
ntgetsel ld a,(ntcctl+12)
        cp NCITY
        jr c,ntgs1
        xor a
ntgs1   ld (ntsel),a
        call ntgetc
        ld (ntcrec),hl
        ld a,(ntsel)
        ret

;### NTGETC -> A=index, HL=city record
ntgetc  ld e,a
        ld d,0
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        push hl
        add hl,hl
        add hl,hl
        add hl,hl
        pop bc
        add hl,bc
        add hl,de
        add hl,hl
        ld bc,ntcities
        add hl,bc
        ret

;==============================================================================
;### 32 BIT AND CALENDAR ROUTINES #############################################
;==============================================================================

;### NT32ADD -> (HL) = (HL) + (DE), 4 bytes
nt32add or a
        ld b,4
nt32a1  ld a,(de)
        adc a,(hl)
        ld (hl),a
        inc hl
        inc de
        djnz nt32a1
        ret

;### NT32SUB -> (HL) = (HL) - (DE), 4 bytes, CF=1 if it went below zero
nt32sub or a
        ld b,4
nt32s1  ld a,(de)
        ld c,a
        ld a,(hl)
        sbc a,c
        ld (hl),a
        inc hl
        inc de
        djnz nt32s1
        ret

;### NT32DIV -> d32n = d32n / d32d, d32r = remainder
nt32div xor a
        ld (d32r+0),a
        ld (d32r+1),a
        ld (d32r+2),a
        ld (d32r+3),a
        ld a,32
        ld (d32cnt),a
nt32d1  ld hl,d32n
        sla (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        ld hl,d32r
        rl (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        ld hl,d32r
        ld de,d32d
        call nt32sub
        jr nc,nt32d2
        ld hl,d32r
        ld de,d32d
        call nt32add
        jr nt32d3
nt32d2  ld hl,d32n
        inc (hl)
nt32d3  ld hl,d32cnt
        dec (hl)
        jr nz,nt32d1
        ret

ntd86k  ld hl,nt86400
        jr ntdset
ntd60   ld hl,nt60
ntdset  ld de,d32d
        ld bc,4
        ldir
        jp nt32div

;### NTMOD7 -> HL mod 7 in A, destroys HL and DE
ntmod7  ld de,7168
        call ntmod71
        ld de,896
        call ntmod71
        ld de,112
        call ntmod71
        ld de,7
        call ntmod71
        ld a,l
        ret
ntmod71 or a
        sbc hl,de
        jr nc,ntmod71
        add hl,de
        ret

;### NTOFFADD -> ntsec = ntsec + offset in quarter hours times 900
ntoffadd ld a,(ntoff15)
        or a
        ret z
        bit 7,a
        jr nz,ntofn
        ld b,a
ntofp1  push bc
        ld hl,ntsec
        ld de,nt900
        call nt32add
        pop bc
        djnz ntofp1
        ret
ntofn   neg
        ld b,a
ntofn1  push bc
        ld hl,ntsec
        ld de,nt900
        call nt32sub
        pop bc
        djnz ntofn1
        ret

;### NTYLEN -> BC=year, DE=days of the year
ntylen  ld de,365
        ld a,c
        and 3
        ret nz
        inc de
        ret

;### NTMLEN -> B=month, A=days of the month in year (ntyr). Keeps all other registers
ntmlen  push hl
        push de
        ld d,0
        ld e,b
        ld hl,ntmtab-1
        add hl,de
        ld e,(hl)
        ld a,b
        cp 2
        jr nz,ntmln
        ld a,(ntyr)
        and 3
        jr nz,ntmln
        inc e
ntmln   ld a,e
        pop de
        pop hl
        ret

;### NTDATE -> converts the unix time in ntsec into
;### ntyr, ntmo, ntdy, nthr, ntmi, ntsc, ntdow, ntybase
ntdate  ld hl,ntsec
        ld de,d32n
        ld bc,4
        ldir
        call ntd86k
        ld hl,(d32n)
        ld (ntdays),hl
        ld de,4
        add hl,de
        call ntmod7
        ld (ntdow),a
        ld hl,d32r
        ld de,d32n
        ld bc,4
        ldir
        call ntd60
        ld a,(d32r)
        ld (ntsc),a
        call ntd60
        ld a,(d32r)
        ld (ntmi),a
        ld a,(d32n)
        ld (nthr),a
        ld hl,(ntdays)
        ld bc,1970
ntdt1   call ntylen
        or a
        sbc hl,de
        jr c,ntdt2
        inc bc
        jr ntdt1
ntdt2   add hl,de
        ld (ntyr),bc
        ld (ntdoy),hl
        ex de,hl
        ld hl,(ntdays)
        or a
        sbc hl,de
        ld (ntybase),hl
        ld hl,(ntdoy)
        ld b,1
ntdt3   call ntmlen
        ld e,a
        ld d,0
        or a
        sbc hl,de
        jr c,ntdt4
        inc b
        jr ntdt3
ntdt4   add hl,de
        ld a,l
        inc a
        ld (ntdy),a
        ld a,b
        ld (ntmo),a
        ret

;### NTSUN -> C=month, D=which (1=first, 2=second, 0=last), A=day of that sunday in ntyr
ntsun   push de
        ld hl,(ntybase)
        ld b,1
ntsn1   ld a,b
        cp c
        jr z,ntsn2
        call ntmlen
        ld e,a
        ld d,0
        add hl,de
        inc b
        jr ntsn1
ntsn2   ld de,4
        add hl,de
        call ntmod7
        or a
        jr z,ntsn3
        ld e,a
        ld a,8
        sub e
        jr ntsn4
ntsn3   ld a,1
ntsn4   pop de
        ld e,a
        ld a,d
        or a
        jr z,ntsnl
        cp 1
        jr z,ntsnr
        ld a,e
        add a,7
        ret
ntsnr   ld a,e
        ret
ntsnl   ld b,c
        call ntmlen
        ld d,a
ntsnl1  ld a,e
        add a,7
        cp d
        jr z,ntsnl2
        jr nc,ntsnl3
ntsnl2  ld e,a
        jr ntsnl1
ntsnl3  ld a,e
        ret

;### NTKEY -> C=month, A=day, B=hour, HL=((month*32+day)*24+hour)
ntkey   ld h,0
        ld l,c
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld e,a
        ld d,0
        add hl,de
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld e,b
        ld d,0
        add hl,de
        ret

;### NTDST -> A=1 if summer time is active at the standard time in ntmo ntdy nthr
ntdst   ld a,(ntrule)
        or a
        ret z
        dec a
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        ld de,ntrules
        add hl,de
        push hl
        pop ix
        xor a
        bit 1,(ix+6)
        jr z,ntds1
        ld a,(ntoff15)
        sra a
        sra a
ntds1   ld (ntdsta),a
        ;--- start of summer time
        ld c,(ix+0)
        ld d,(ix+1)
        call ntsun
        ld e,a
        ld a,(ntdsta)
        add a,(ix+2)
        ld b,a
        ld a,e
        ld c,(ix+0)
        call ntkey
        ld (ntksta),hl
        ;--- end of summer time
        ld c,(ix+3)
        ld d,(ix+4)
        call ntsun
        ld e,a
        ld a,(ntdsta)
        add a,(ix+5)
        ld b,a
        ld a,e
        ld c,(ix+3)
        call ntkey
        ld (ntkend),hl
        ;--- now
        ld a,(nthr)
        ld b,a
        ld a,(ntmo)
        ld c,a
        ld a,(ntdy)
        call ntkey
        ld (ntkcur),hl
        ld hl,(ntkcur)
        ld de,(ntksta)
        or a
        sbc hl,de
        ld c,0
        jr c,ntds2
        inc c
ntds2   ld hl,(ntkcur)
        ld de,(ntkend)
        or a
        sbc hl,de
        ld b,0
        jr nc,ntds3
        inc b
ntds3   bit 0,(ix+6)
        jr nz,ntds4
        ld a,b
        and c
        ret
ntds4   ld a,b
        or c
        ret

;==============================================================================
;### NETWORK DAEMON CLIENT FUNCTIONS ##########################################
;==============================================================================

SyNet_PrcID db 0

SyNet_NETINI
        ld e,0
        ld hl,snwdmnt
        ld a,(App_BnkNum)
        call SySystem_PRGSRV
        or a
        scf
        ret nz
        ld a,h
        ld (SyNet_PrcID),a
        or a
        ret
snwdmnt db "Network Daem"

SyNet_TCPOPN
        call snwmsgi_afbcdehlixiy
        db FNC_NET_TCPOPN
        jp snwmsgo_afhl
SyNet_TCPSTA
        call snwmsgi_af
        db FNC_NET_TCPSTA
        jp snwmsgo_afbcdehlixiy
SyNet_TCPRCV
        call snwmsgi_afbcdehl
        db FNC_NET_TCPRCV
        jp snwmsgo_afbchl
SyNet_TCPSND
        call snwmsgi_afbcdehl
        db FNC_NET_TCPSND
        jp snwmsgo_afbchl
SyNet_TCPDIS
        call snwmsgi_af
        db FNC_NET_TCPDIS
        jp snwmsgo_afhl
SyNet_UDPOPN
        call snwmsgi_afdehl
        db FNC_NET_UDPOPN
        jp snwmsgo_afhl
SyNet_UDPCLO
        call snwmsgi_af
        db FNC_NET_UDPCLO
        jp snwmsgo_afhl
SyNet_UDPSTA
        call snwmsgi_af
        db FNC_NET_UDPSTA
        jp snwmsgo_afbcdehlixiy
SyNet_UDPRCV
        call snwmsgi_afhl
        db FNC_NET_UDPRCV
        jp snwmsgo_afhl
SyNet_UDPSND
        call snwmsgi_afbcdehlixiy
        db FNC_NET_UDPSND
        jp snwmsgo_afhl
SyNet_DNSRSV
        ld de,(App_BnkNum)
        call snwmsgi_afdehl
        db FNC_NET_DNSRSV
        jp snwmsgo_afbcdehlixiy

snwmsgi_afbcdehlixiy
        ld (App_MsgBuf+10),ix
        ld (App_MsgBuf+12),iy
snwmsgi_afbcdehl
        ld (App_MsgBuf+04),bc
snwmsgi_afdehl
        ld (App_MsgBuf+06),de
snwmsgi_afhl
        ld (App_MsgBuf+08),hl
snwmsgi_af
        push af
        pop hl
        ld (App_MsgBuf+02),hl
        pop hl
        ld a,(hl)
        inc hl
        push hl
        ld (App_MsgBuf+0),a
        ld (snwmsg2+1),a
        ld iy,App_MsgBuf
        ld a,(App_PrcID)
        db #dd:ld l,a
        ld a,(SyNet_PrcID)
        db #dd:ld h,a
        ld (snwmsg1+2),ix
        rst #10
snwmsg1 ld ix,0
        rst #08
        db #dd:dec l
        jr nz,snwmsg1
        ld a,(App_MsgBuf)
        sub 128
snwmsg2 cp 0
        ret z
        ld a,(App_PrcID)
        db #dd:ld h,a
        ld a,(SyNet_PrcID)
        db #dd:ld l,a
        rst #10
        rst #30
        jr snwmsg1
snwmsgo_afbcdehlixiy
        ld ix,(App_MsgBuf+10)
        ld iy,(App_MsgBuf+12)
        ld de,(App_MsgBuf+06)
snwmsgo_afbchl
        ld bc,(App_MsgBuf+04)
snwmsgo_afhl
        ld hl,(App_MsgBuf+02)
        push hl
        pop af
        ld hl,(App_MsgBuf+08)
        ret

;==============================================================================
;### DATA AREA ################################################################
;==============================================================================

App_BegData

prgicn16c   db 12,24,24:dw $+7:dw $+4,12*24:db 5
db #66,#55,#55,#55,#55,#55,#55,#56,#66,#66,#66,#66,#65,#dd,#dd,#dd,#dd,#dd,#d8,#51,#63,#33,#33,#16,#58,#88,#88,#88,#88,#88,#85,#51,#33,#d8,#d3,#13,#58,#d1,#11,#11,#11,#11,#d5,#51,#83,#d8,#d3,#18
db #58,#d1,#44,#44,#44,#48,#d5,#51,#13,#d8,#d3,#11,#58,#d1,#44,#44,#44,#48,#d5,#51,#61,#11,#11,#16,#58,#d1,#44,#44,#44,#48,#d5,#51,#66,#63,#81,#66,#58,#d1,#44,#44,#44,#55,#55,#55,#55,#55,#55,#56
db #58,#d1,#88,#88,#85,#dd,#dd,#dd,#dd,#dd,#d8,#51,#58,#dd,#dd,#dd,#58,#88,#88,#88,#88,#88,#85,#51,#55,#55,#55,#55,#58,#d1,#11,#11,#11,#11,#d5,#51,#11,#11,#11,#11,#58,#d1,#44,#44,#44,#48,#d5,#51
db #58,#88,#88,#88,#58,#d1,#44,#44,#44,#48,#d5,#51,#58,#dd,#dd,#11,#58,#d1,#44,#44,#44,#48,#d5,#51,#58,#da,#dd,#dd,#58,#d1,#44,#44,#44,#48,#d5,#51,#55,#55,#55,#55,#58,#d1,#88,#88,#88,#88,#d5,#51
db #11,#11,#11,#11,#58,#dd,#dd,#dd,#dd,#dd,#d5,#51,#66,#63,#81,#66,#55,#55,#55,#55,#55,#55,#55,#15,#63,#33,#33,#16,#11,#11,#11,#11,#11,#11,#11,#51,#33,#d8,#d3,#15,#58,#88,#88,#88,#88,#88,#85,#51
db #83,#d8,#d3,#18,#58,#dd,#dd,#d1,#11,#11,#d5,#51,#13,#d8,#d3,#11,#58,#da,#dd,#dd,#d5,#dd,#d5,#51,#61,#11,#11,#16,#55,#55,#55,#55,#55,#55,#55,#16,#66,#66,#66,#66,#11,#11,#11,#11,#11,#11,#11,#66

;### variables
ntwinid     db 0
ntsel       db 0
ntcsel      db 0
ntcidx      db 0
ntlnum      db 0
ntwl        db 0
ntpp        dw 0
ntpcnt      db 0
ntqp        dw 0
ntcrec      dw 0
ntip        ds 4
nthnd       db 0
ntchk       db 0            ;state of the HTTPS check box
nthport     dw 80
ntsrv       db 0
ntcnt       dw 0
ntsl        dw 0
ntsp        dw 0
ntretry     db 0
ntrp        dw 0
ntrxl       dw 0
ntbdy       dw 0
ntoff15     db 0
ntrule      db 0
ntdstf      db 0
ntdsta      db 0
ntksta      dw 0
ntkend      dw 0
ntkcur      dw 0
ntsec       ds 4
ntutc       ds 4
ntdays      dw 0
ntdoy       dw 0
ntybase     dw 0
ntyr        dw 0
ntmo        db 0
ntdy        db 0
nthr        db 0
ntmi        db 0
ntsc        db 0
ntdow       db 0
ntdsy       dw 0
ntdsm       db 0
ntdsd       db 0
ntyv        dw 0
ntmv        dw 0
ntdv        dw 0
ntyc        db 0
ntmc        db 0
ntdc        db 0
ntmin1      dw 0
ntmin2      dw 0
d32n        ds 4
d32d        ds 4
d32r        ds 4
d32cnt      db 0

;### constants
nt86400     db #80,#51,#01,#00
nt60        db 60,0,0,0
nt3600      db #10,#0e,0,0
nt900       db #84,#03,0,0
nt1970      db #80,#7e,#aa,#83
ntmtab      db 31,28,31,30,31,30,31,31,30,31,30,31
ntdayn      db "SunMonTueWedThuFriSat"
ntmonn      db "JanFebMarAprMayJunJulAugSepOctNovDec"
;### summer time rules - start month, which sunday, hour, end month, which sunday, hour, flags
;### flags - bit 0 southern hemisphere, bit 1 hour is UTC
ntrules     db 3,0,1, 10,0,1, 2        ;1 europe
            db 3,2,2, 11,1,1, 0        ;2 usa
            db 10,1,2, 4,1,2, 1        ;3 australia
            db 9,0,2, 4,1,2, 1         ;4 new zealand

;### texts
nttxttit    db "Net Test",0
nttxtcity   db "City",0
nttxtdt     db "Date",0
nttxthint   db "YYYY MM DD, or empty",0
nttxtfra    db "Result",0
nttxthttps  db "HTTPS",0
nttxtbck    db "World clock",0
nttxtbwe    db "Weather",0
nttxtbsn    db "Sun times",0
nttxtrdy    db "Pick a city and a button",0
nttxtnod    db "Network daemon is not running",0
nttxtwrk    db "Working...",0
nttxtedns   db "DNS lookup failed",0
nttxtesck   db "Cannot open connection",0
nttxtecon   db "Connection error",0
nttxtetmo   db "No answer (timeout)",0
nttxtebd    db "Please enter a valid date",0
nttxteres   db "Unexpected answer",0
nttxtutc    db "UTC (SNTP)",0
nttxtstar   db "* = daylight saving time is active",0
nttxtsent   db "Sent: SNTP request, UDP port 123",0
nttxtto     db "To:   ",0
nttxtip     db "IP:   ",0
nttxtstr    db "Reply: stratum ",0
nttxtgoo    db "time.google.com",0
nttxtclf    db "time.cloudflare.com",0
nttxtswe    db "GET wttr.in",0
nttxtssu    db "GET api.sunrise-sunset.org",0
nttxtp80    db ":80",0
nttxtp443   db ":443 TLS",0
nttxtwtr    db "Weather now - ",0
nttxtstit   db "Sun times - ",0
nttxtdate   db "Date ",0
nttxttoday  db "today",0
nttxtlrs    db "Sunrise",0
nttxtlno    db "Solar noon",0
nttxtlss    db "Sunset",0
nttxtlln    db "Day length",0
nttxtloc    db "All times are local to the city",0
nttxtnone   db "n/a",0
nttxtkrs    db 34,"sunrise",34,":",34,0
nttxtkno    db 34,"solar_noon",34,":",34,0
nttxtkss    db 34,"sunset",34,":",34,0
nttxtsok    db 34,"status",34,":",34,"OK",34,0
nttxtcrlf2  db 13,10,13,10,0
nttxtchunk  db "hunked",0
ntsntph     db "pool.ntp.org",0
ntipg       db 216,239,35,0
ntipc       db 162,159,200,1
ntwttrh     db "wttr.in",0
ntsunhost   db "api.sunrise-sunset.org",0
nttxtwget   db "GET /",0
nttxtwfmt   db "?format=%25C+%25t+%25w+%25h&m",0
nttxtsget   db "GET /json?lat=",0
nttxtlng    db "&lng=",0
nttxtdat    db "&date=",0
nttxtfmt    db "&formatted=0&tzid=",0
nttxttl1    db " HTTP/1.0",13,10,"Host: ",0
nttxttl2    db 13,10,"User-Agent: curl/8.0",13,10,"Accept: */*",13,10,"Connection: close",13,10,13,10,0

;### city table - name 16, weather name 16, time zone 24, lat 8, lng 8, offset in quarter hours, rule
ntcities
        db "Amsterdam",0:ds 6
        db "Amsterdam",0:ds 6
        db "Europe/Amsterdam",0:ds 7
        db "52.37",0:ds 2
        db "4.90",0:ds 3
        db 4,1
        db "London",0:ds 9
        db "London",0:ds 9
        db "Europe/London",0:ds 10
        db "51.51",0:ds 2
        db "-0.13",0:ds 2
        db 0,1
        db "New York",0:ds 7
        db "New+York",0:ds 7
        db "America/New_York",0:ds 7
        db "40.71",0:ds 2
        db "-74.01",0:ds 1
        db 236,2
        db "Los Angeles",0:ds 4
        db "Los+Angeles",0:ds 4
        db "America/Los_Angeles",0:ds 4
        db "34.05",0:ds 2
        db "-118.24",0
        db 224,2
        db "Mexico City",0:ds 4
        db "Mexico+City",0:ds 4
        db "America/Mexico_City",0:ds 4
        db "19.43",0:ds 2
        db "-99.13",0:ds 1
        db 232,0
        db "Sao Paulo",0:ds 6
        db "Sao+Paulo",0:ds 6
        db "America/Sao_Paulo",0:ds 6
        db "-23.55",0:ds 1
        db "-46.63",0:ds 1
        db 244,0
        db "Johannesburg",0:ds 3
        db "Johannesburg",0:ds 3
        db "Africa/Johannesburg",0:ds 4
        db "-26.20",0:ds 1
        db "28.05",0:ds 2
        db 8,0
        db "Moscow",0:ds 9
        db "Moscow",0:ds 9
        db "Europe/Moscow",0:ds 10
        db "55.76",0:ds 2
        db "37.62",0:ds 2
        db 12,0
        db "Dubai",0:ds 10
        db "Dubai",0:ds 10
        db "Asia/Dubai",0:ds 13
        db "25.20",0:ds 2
        db "55.27",0:ds 2
        db 16,0
        db "Mumbai",0:ds 9
        db "Mumbai",0:ds 9
        db "Asia/Kolkata",0:ds 11
        db "19.08",0:ds 2
        db "72.88",0:ds 2
        db 22,0
        db "Bangkok",0:ds 8
        db "Bangkok",0:ds 8
        db "Asia/Bangkok",0:ds 11
        db "13.76",0:ds 2
        db "100.50",0:ds 1
        db 28,0
        db "Beijing",0:ds 8
        db "Beijing",0:ds 8
        db "Asia/Shanghai",0:ds 10
        db "39.90",0:ds 2
        db "116.41",0:ds 1
        db 32,0
        db "Tokyo",0:ds 10
        db "Tokyo",0:ds 10
        db "Asia/Tokyo",0:ds 13
        db "35.68",0:ds 2
        db "139.69",0:ds 1
        db 36,0
        db "Sydney",0:ds 9
        db "Sydney",0:ds 9
        db "Australia/Sydney",0:ds 7
        db "-33.87",0:ds 1
        db "151.21",0:ds 1
        db 40,3
        db "Auckland",0:ds 7
        db "Auckland",0:ds 7
        db "Pacific/Auckland",0:ds 7
        db "-36.85",0:ds 1
        db "174.76",0:ds 1
        db 48,4
        db "Honolulu",0:ds 7
        db "Honolulu",0:ds 7
        db "Pacific/Honolulu",0:ds 7
        db "21.31",0:ds 2
        db "-157.86",0
        db 216,0

;### date input buffers
ntbufy       ds 6
ntbufm       ds 4
ntbufd      ds 4

;### result lines
ntlines
        ds LINES*LINEW

ntdatestr   ds 16
ntdbgc      db 0
ntdbgv      db 0
ntdbgbuf    ds 44
ntpkt       ds 64
ntreq       ds 400
rxbuf       ds RXMAX+2

;==============================================================================
;### TRANSFER AREA ############################################################
;==============================================================================

App_BegTrns
        ds 128
prgstk  ds 6*2
        dw prgprz
App_PrcID db 0
App_MsgBuf ds 14

;### window
ntwindat    dw #1501,0,40,16,200,150,0,0,200,150,200,150,200,150,prgicnsml,nttxttit,0,0
ntwindat0   dw ntwingrp,0,0:ds 136+14
ntwingrp    db 13+LINES,0:dw ntwindata,0,0,4*256+3,0,0,2

ntwindata
; onclick         type   property   xpos   ypos   xlen   ylen
dw      0,  255*256+ 0,         2,     0,     0, 10000, 10000, 0    ;background
dw      0,  255*256+ 1, ntctxc,       4,     6,    24,     8, 0    ;text city
dw      0,  255*256+42, ntcctl,      30,     4,   100,    10, 0    ;city dropdown
dw      0,  255*256+17, ntcchk,     140,     5,    54,     8, 0    ;check box https
dw  btclk,  255*256+16, nttxtbck,     4,    20,    62,    12, 0    ;button clock
dw  btwea,  255*256+16, nttxtbwe,    70,    20,    58,    12, 0    ;button weather
dw  btsun,  255*256+16, nttxtbsn,   132,    20,    62,    12, 0    ;button sun
dw      0,  255*256+ 1, ntctxd,       4,    38,    24,     8, 0    ;text date
dw      0,  255*256+32, ntcyr,       30,    36,    28,    12, 0    ;input year
dw      0,  255*256+32, ntcmo,       62,    36,    18,    12, 0    ;input month
dw      0,  255*256+32, ntcdy,       84,    36,    18,    12, 0    ;input day
dw      0,  255*256+ 1, ntctxh,     108,    38,    88,     8, 0    ;text hint
dw      0,  255*256+ 3, ntcfra,       0,    52,   200,    96, 0    ;frame
dw      0,  255*256+ 1, ntlin0,       6,   62,   188,     8, 0
dw      0,  255*256+ 1, ntlin1,       6,   71,   188,     8, 0
dw      0,  255*256+ 1, ntlin2,       6,   80,   188,     8, 0
dw      0,  255*256+ 1, ntlin3,       6,   89,   188,     8, 0
dw      0,  255*256+ 1, ntlin4,       6,   98,   188,     8, 0
dw      0,  255*256+ 1, ntlin5,       6,  107,   188,     8, 0
dw      0,  255*256+ 1, ntlin6,       6,  116,   188,     8, 0
dw      0,  255*256+ 1, ntlin7,       6,  125,   188,     8, 0
dw      0,  255*256+ 1, ntlin8,       6,  134,   188,     8, 0

;### control data
ntctxc      dw nttxtcity,2+4
ntctxd      dw nttxtdt,2+4
ntctxh      dw nttxthint,2+4
ntcfra      dw nttxtfra,2+4
ntcchk      dw ntchk,nttxthttps,256*0+2+4
ntcyr       dw ntbufy,0,0,0,0,4:db 0
ntcmo       dw ntbufm,0,0,0,0,2:db 0
ntcdy       dw ntbufd,0,0,0,0,2:db 0
ntcctl      dw NCITY,0,ntcitylist,0,1,ntcityrow,0,1
ntcityrow   dw 0,100,0,0
ntcitylist
        dw 0,ntcities+0
        dw 1,ntcities+74
        dw 2,ntcities+148
        dw 3,ntcities+222
        dw 4,ntcities+296
        dw 5,ntcities+370
        dw 6,ntcities+444
        dw 7,ntcities+518
        dw 8,ntcities+592
        dw 9,ntcities+666
        dw 10,ntcities+740
        dw 11,ntcities+814
        dw 12,ntcities+888
        dw 13,ntcities+962
        dw 14,ntcities+1036
        dw 15,ntcities+1110
ntlin0      dw ntlines+0,2+4
ntlin1      dw ntlines+36,2+4
ntlin2      dw ntlines+72,2+4
ntlin3      dw ntlines+108,2+4
ntlin4      dw ntlines+144,2+4
ntlin5      dw ntlines+180,2+4
ntlin6      dw ntlines+216,2+4
ntlin7      dw ntlines+252,2+4
ntlin8      dw ntlines+288,2+4
