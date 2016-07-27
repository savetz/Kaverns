;KAVERNS OF KFEST 1.1
;by Kevin Savetz
;KansasFest 2016
;hackfest
;An Apple // is Atari 800
;without the best chips

 ORG $8000
HOME EQU $FC58
RANDOM EQU $EFAE
PX EQU $1D
PY EQU $1E
HITS EQU $300 ;number of hits left
SCORELB EQU $301 ;score low byte
SCOREHB EQU $302 ;score high byte
LEVELLB EQU $303 ;level low byte
LEVELHB EQU $304 ;level high byte
SEED EQU $305 ;random number seed
SPEED EQU $306 ;delay to slow down game
WALLIDX EQU $307 ;wall color index
MIDWIDTH EQU $308 ;width of the center play area
TEMP EQU $309 ;temp storage
HTD_OUT EQU $310 ;hex to BCD output, 3 bytes
HTD_IN EQU $313 ;hex to BCD inout, 2 hex bytes
LWW EQU $315 ;left wall width
SCORESC EQU $6D1 ;where to print score on screen

RESTART
;Screen setup
 JSR HOME
 JSR  $F836  ;clear lo-res screen (mixed mode)
 LDA  $C050 ;lo-res mode
 LDA  $C053  ;text window

;print SCORE DEPTH SHIELDS
 LDX #27
TXTOUT LDA OUTPUT,X
; CLC
 ;ADC #$40
 STA $650,X
 DEX
 TXA
 BNE TXTOUT

;setup values
 LDA #20
 STA LWW ;width of the left wall
 LDA #10
 STA MIDWIDTH ;size of space player lives in
 LDA #23
 STA PX ;player x position
 LDA #2
 STA PY ;player y pos (line number * 2)
 LDA #10
 STA HITS ;10 chances
 LDA #0
 STA SCORELB
 STA SCOREHB
 STA LEVELLB
 STA LEVELHB
; STA WALLIDX
 LDA #$80
 STA SPEED

PICKWALL JSR RANDOM ;RANDOM
 AND #$07
 STA WALLIDX


GAMELOOP
;--------------------------------
;check keyboard
 LDA $C000
 CMP #$80
 BCC DRAWPLAYER ;no key pressed, nothing to see here
 CMP #$88 ;leftarrow?
 BNE KBD1
 DEC PX
 LDA PX
 BNE DRAWPLAYER
 INC PX
 JMP DRAWPLAYER
KBD1
 CMP #$95 ;rightarrow?
 BNE KBD2
 INC PX
 LDA PX
 CMP #40
 BCC DRAWPLAYER ;if less than 39, go on
 DEC PX ;otherwise don't go right
 JMP DRAWPLAYER
KBD2
 CMP #$8A ;down?
 BNE KBD3
 INC PY
 INC PY
 LDA PY
 CMP #38 ;dont move down too low
 BCC DRAWPLAYER
 DEC PY
 DEC PY
 JMP DRAWPLAYER
KBD3 CMP #$8B ;up?
 BNE KBD4
 DEC PY
 DEC PY
 LDA PY ;don't move up too high
 CMP #02
 BCS DRAWPLAYER
 INC PY
 INC PY
 JMP DRAWPLAYER

KBD4   ;in case I want to add more kbd commands

DRAWPLAYER
 LDA $C010 ;clear keyboard strobe
;draw player
 LDX PY
 LDA DATA,X ;get memory location of screen line
 STA $07 ;that player is on. PY must always
 INX  ;be even (or 0). Store at $06-07.
 LDA DATA,X
 STA $06
 LDY PX ;draw the player on line + X pos.

 LDA ($06),Y ;hit detection for new spot
 BEQ DRAWPLAYER2 ;0 = black, so no hit

 CMP #$D0
 BEQ DRAWPLAYER2 ; $D0=ship trail, so no hit

  ;hit obstacle!

 CMP #$CC
 BEQ DRAWPLAYER1 ;hit a prize

;otherwise, hit a wall/brick

 LDX #20  ;Beep a beep - DURATION
CLICK1
 LDA $C030 ;click
 LDY #230
CLICK2
 DEY
 BNE CLICK2
 DEX
 BNE CLICK1
 LDY PX ;prep  that for drawplayer1

 DEC HITS ;update hit counter
 LDA HITS
 BNE DRAWPLAYER2

   ;oh noes! game over
 JSR UPDATESCORE
 LDX #26 ;out of shields - game over
TXTOUT2 LDA OUTPUT2,X
 STA $750,X
 DEX
 TXA
 BNE TXTOUT2

;DELAY
 LDY #$FF
 LDX #$FF
 LDA #$10
 STA TEMP
ENDLOOP DEX
 BNE ENDLOOP
 DEY
 BNE ENDLOOP
 DEC TEMP
 LDA TEMP
 BNE ENDLOOP

 LDX #25 ;press a key to play again
TXTOUT3 LDA OUTPUT3,X
 STA $7D0,X
 DEX
 TXA
 BNE TXTOUT3

 STA $C010 ;CLEAR KEYBOARD STROBE
WAITKEY LDA $C000
 CMP #$80
 BCC WAITKEY

 JMP RESTART


DRAWPLAYER1   ;touched a prize (#$CC)
 LDY #40 ;DURATION
CLICK3
 LDX #40 ;PITCH
 LDA $C030
CLICK4
 DEX
 BNE CLICK4
 DEY
 BNE CLICK3
 LDY PX

 ;add 400 points
 LDA SCORELB
 CLC
 ADC #$90
 STA SCORELB
 LDA SCOREHB
 ADC #$01
 STA SCOREHB



DRAWPLAYER2   ;actually draw the player now
 LDA #$D0 ;player color
 STA ($06),Y

;Slow down scrolling
 LDX SPEED
 LDY #$FF
SLOW1 DEY
 BNE SLOW1
 DEX
 BNE SLOW1


   ;prep to draw walls.
   ;change width of left wall
 LDA LWW ;current width of left wall
 CMP #0 ;if far left, increase it
 BNE N2
 INC LWW
 JMP NEWLINE1
N2 CMP #34 ;if too far right, decrease it
 BNE N3
 DEC LWW
 JMP NEWLINE1
N3
 JSR RANDOM
 BMI N4 ;if 0, move right
 DEC LWW ;if 1, move left
;**improve by trending in a direction
 JMP NEWLINE1
N4 INC LWW

NEWLINE1 ;lets draw the line now
 LDX #0
 LDA #$FF
 CLC
 SBC LEVELLB
 STA TEMP
DRAWLEFTLOOP   ;draw the left wall
 JSR HAPPYRAND

 CMP TEMP
 BCC WALLCOL1

 LDY WALLIDX
 INY
 LDA WALLS,Y
 JMP WALLCOL2
WALLCOL1
 LDY WALLIDX
 LDA WALLS,Y
WALLCOL2
 STA $5D0,X
 INX
 CPX LWW
 BCC DRAWLEFTLOOP
 CLC
   ;prep to draw play space
 LDA LWW ;store the length of left
 ADC MIDWIDTH ;wall plus play space
 STA $1A ;in $1a because Quinn said so
DRAWSPACELOOP
  JSR HAPPYRAND ;get a random number
 CMP #6 ;if it's <6, obstacle
 BCS DSL1
 CMP #3 ;if its <3,
 BCS OBST2
 LDA #$AA ;block
 JMP DSL2
OBST2
 LDA #$CC ;prize
 JMP DSL2
DSL1
 LDA #$00 ;blank space
DSL2
 STA $5D0,X
 INX
 CPX $1A
 BCC DRAWSPACELOOP

DRAWRIGHTLOOP   ;fill rest of line with right wall
 ;temp is stil #$FF-LEVELLB from before
 JSR HAPPYRAND
 CMP TEMP
 BCC WALLCOL3

 LDY WALLIDX
 INY
 LDA WALLS,Y
 JMP WALLCOL4

WALLCOL3
 LDY WALLIDX
 LDA WALLS,Y
WALLCOL4
 STA $5D0,X
 INX
 CPX #40
 BCC DRAWRIGHTLOOP

;--------------------------
;scroll the screen up
;starting by coping the 2nd
;line to the 1st line
 LDX #0
COPYLOOPOUTER
;$04-05 screen line to copy from LBHB
;$06-07 line to copy to LBHB
 INX
 INX
 LDA DATA,X
 STA $05
 INX
 LDA DATA,X
 STA $04
 DEX
 DEX
 LDA DATA,X
 STA $06
 DEX
 LDA DATA,X
 STA $07
 INX
 INX
 LDY #0
COPYLOOPINNER
 LDA ($04),Y
 STA ($06),Y
 INY
 CPY #40
 BCC COPYLOOPINNER
 TXA
 CMP #38 ;dont copy past the bottom line
;otherwise, next line
 BCC COPYLOOPOUTER

 ;INCREASE LEVEL NUMBER
 CLC
 LDA LEVELLB
 ADC #1 ;+1
 STA LEVELLB

 LDA LEVELHB ;CHECK FOR ROLLOVER INTO HIGH BYTE
 ADC #0
 STA LEVELHB

 LDX PY
INCSCORE CLC ;INCREASE SCORE, BONUS FOR BEING LOWER DOWN
 LDA SCORELB
 ADC #1
 STA SCORELB
 LDA SCOREHB
 ADC #0
 STA SCOREHB
 DEX
 BNE INCSCORE

 LDA LEVELLB ;HARDER LEVEL?
 BNE CLEANUP
 LDA SPEED
 CMP #1
 BEQ SPEED2 ;IF NONZERO, LETS GO FASTER
 SEC
 SBC #$10
 BNE SPEED1
 CLC  ;IF 0 SET TO 1
 ADC #1
SPEED1
 STA SPEED

SPEED2
 LDA MIDWIDTH
 CMP #4
 BCC WALLFUN ;3 IS THE SMALLEST WIDTH
 DEC MIDWIDTH

WALLFUN
 ;CHANGE WALL COLOR
 LDY WALLIDX
 INY
 LDA WALLS,Y
 BNE WALLUPD
 LDY #0

WALLUPD
 STY WALLIDX

CLEANUP
 JSR UPDATESCORE
 JMP GAMELOOP

;----------------------

DATA HEX 04000480050005800600068007000780042804A8
 HEX 052805A8062806A8072807A8045004D0055005D0065006D0075007D0
 HEX FFFF
WALLS HEX 66112233448899AABB77EE00


UPDATESCORE
 LDA SCORELB
 STA HTD_IN
 LDA SCOREHB
 STA HTD_IN+1
 JSR TOBCD
 LDX #0
 JSR  SCORE

 LDA LEVELLB
 STA HTD_IN
 LDA LEVELHB
 STA HTD_IN+1
 JSR TOBCD
 LDX #10
 JSR SCORE

 LDA HITS
 STA HTD_IN
 LDA #0
 STA HTD_IN+1
 JSR TOBCD
 LDX #18
 JSR SCORE2DIG

 RTS

HAPPYRAND
;http://codebase64.org/doku.php?
;id=base:small_fast_8-bit_prng
 LDA SEED
 BEQ DOEOR
 ASL
 BEQ NOEOR
 BCC NOEOR
DOEOR EOR #$1D
NOEOR STA SEED
 RTS

SCORE
 LDA HTD_OUT+2
 AND #$F0
 LSR
 LSR
 LSR
 LSR
 CLC
 ADC #$B0
 STA SCORESC,X

  LDA  HTD_OUT+2
 AND  #$0F
 CLC
 ADC  #$B0
 STA SCORESC+1,X

 LDA HTD_OUT+1
 AND #$F0
 LSR
 LSR
 LSR
 LSR
 CLC
 ADC #$B0
 STA SCORESC+2,X

  LDA  HTD_OUT+1
 AND  #$0F
 CLC
 ADC  #$B0
 STA SCORESC+3,X

SCORE2DIG
 LDA HTD_OUT
 AND #$F0
 LSR
 LSR
 LSR
 LSR
 CLC
 ADC #$B0
 STA SCORESC+4,X

 LDA  HTD_OUT
 AND #$0F
 CLC
 ADC  #$B0
 STA SCORESC+5,X

 RTS



TOBCD ;HEX TO BCD
;http://6502.org/source/integers/hex2dec.htm
HTD SED       ; Output gets added up in decimal.

 LDA #0
 STA HTD_OUT   ; Inititalize output as 0.
 STA HTD_OUT+1  ; (NMOS 6502 will need LDA#0, STA...)
 STA HTD_OUT+2

 LDX #$2D    ; 2DH is 45 decimal, or 3x15 bits.
LOOP ASL HTD_IN   ; (0 to 15 is 16 bit positions.)
 ROL HTD_IN+1  ; If the next highest bit was 0,
 BCC HTD1    ; then skip to the next bit after that.
 LDA HTD_OUT   ; But if the bit was 1,
 CLC       ; get ready to
 ADC TABLE+2,X  ; add the bit value in the table to eht
 STA HTD_OUT   ; output sum in decimal-- first low b,ety
 LDA HTD_OUT+1  ; then middle byte,
 ADC TABLE+1,X
 STA HTD_OUT+1
 LDA HTD_OUT+2  ; then high byte,
 ADC TABLE,X   ; storing each byte
 STA HTD_OUT+2  ; of the summed output in HTD_OUT.

HTD1 DEX       ; By taking X in steps of 3, we don't have to
 DEX       ; multiply by 3 to get the right bytes freht mo
 DEX       ; table.
 BPL LOOP

 CLD
 RTS

TABLE
 HEX 000001000002000004000008
 HEX 000016000032000064000128
 HEX 000256000512001024002048
 HEX 004096008192016384032768

OUTPUT ASC " SCORE     DEPTH     SHIELDS"
OUTPUT2 ASC " Out of shields - game over"
OUTPUT3 ASC " Press a key to play again"
