;KAVERNS OF KFEST
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

 JSR HOME
 JSR $F832 ;clear lo-res screen
 LDA $C050

;setup values
 LDA #20
 STA $08 ;$08 is width of the left wall
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
 STA WALLIDX
 LDA #$80
 STA SPEED

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
 CMP #39
 BCC DRAWPLAYER ;if less than 38, go on
 DEC PX ;otherwise don't go right
 JMP DRAWPLAYER
KBD2
 CMP #$8A ;down?
 BNE KBD3
 INC PY
 INC PY
 LDA PY
 CMP #30 ;dont move down too low
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
 LDA $C051 ;back to text mode
 JSR HOME
   ;**print final stats
 RTS

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
 LDA $08 ;current width of left wall
 CMP #0 ;if far left, increase it
 BNE N2
 INC $08
 JMP NEWLINE1
N2 CMP #34 ;if too far right, decrease it
 BNE N3
 DEC $08
 JMP NEWLINE1
N3
 JSR RANDOM
 BMI N4 ;if 0, move right
 DEC $08 ;if 1, move left
;**improve by trending in a direction
 JMP NEWLINE1
N4 INC $08

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
 CPX $08
 BCC DRAWLEFTLOOP
 CLC
   ;prep to draw play space
 LDA $08 ;store the length of left
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
 INC LEVELLB ;+1

 LDA LEVELHB ;CHECK FOR ROLLOVER INTO HIGH BYTE
 ADC #0
 STA LEVELHB

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
 JMP GAMELOOP


;----------------------

DATA HEX 04000480050005800600068007000780042804A8
 HEX 052805A8062806A8072807A8045004D0055005D0065006D0075007D0
 HEX FFFF
WALLS HEX 66112233448899AABB77EE00


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
