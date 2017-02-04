; KAVERNS OF KFEST 1.1
; by Kevin Savetz
; KansasFest 2016 hackfest winner
; ported to the Atari February 2017
; with massive help from Peter Dell
;
; An Apple // is Atari 800 without the best chips

; MADS compatible source code for use in WUDSN IDE
; Set "Preferences / General / Editors / Text Editors / Displayed Tab Width" to 8.
;
; @com.wudsn.ide.asm.hardware=ATARI8BIT

; OS zero page addresses
rtclok	= 18
attract	= 77

; OS page 2 and 3 addresses
vdslst	= $200	;DLI vector
vvblkd	= $224	;Deferred VBI vector
sdlstl	= $230	;Display list vector
stick	= 632
strig	= 644
chbase	= 756

; GTIA
colpf0	= $d016
colpf1	= $d017
colpf2	= $d018
colpf3	= $d019

; POKEY addresses
audf1	= $d200
audc1	= $d201
audf2	= $d202
audc2	= $d203
random	= $d20a
skctl	= $d20f

; ANTIC addresses
hscroll	= $d404
nmien   = $d40e

; OS addresses
xitvbv	= $e462

; User zero page addresses
ptr	= $80
px 	= $82
py	= $83
tmp	= $84
sound1	= $85
sound2	= $87

; User main memory addresses
code	  = $2000
chr 	  = $4000
sm	  = $4400
scroll_sm = $4800

newlinesc  equ sm+760 ;where to draw the new line of walls
statustext equ sm+800 ;where to print score level shields
statusline equ sm+840 ;where to print score on screen
msgline    equ sm+880 ;where to print message

	org scroll_sm

	.local scroll_text
	.byte "                        "
	.byte "KAVERNS OF KFEST BY KEVIN SAVETZ     ATARIPODCAST.COM"
	.endl
	.byte "                        "

	org chr+$200		;User defined characters

	.byte $00,$00,$00,$00,$00,$00,$00,$00 ;00 64
	.byte $55,$55,$55,$55,$55,$55,$55,$55 ;01 65
	.byte $aa,$aa,$aa,$aa,$aa,$aa,$aa,$aa ;10 66
	.byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff ;11 67
	.byte $00,$10,$10,$64,$74,$64,$10,$10 ;68 - prize
	.byte $00,$44,$44,$10,$10,$10,$10,$10 ;69 - player


	org code
	.proc main

	lda rtclok+2		;wait for the end of the current frame
wait	cmp rtclok+2
	beq wait

	mva #3 skctl		;reset POKEY
	mwa #dl sdlstl		;set DL vector and other vectors before the new frame starts
	mwa #dli vdslst		;set DLI vector
	mwa #vbi vvblkd		;set deferred VBI vector 
	mva #$c0 nmien		;enable VBI and DLI in ANTIC

	jmp restart_loop

;-----------------------------------------------------------------

	.local dl		;display list

	.byte $70		;8 blank lines
	.byte $56		;1 mode 6 line with horizontal soft scrolling
scroll_address
	.word scroll_sm
	.byte $44,a(sm)		;load memmory scan at sm with mode 2 (graphics 0)
:18	.byte $04		;18 mode 4 lines
	.byte $84		;1 mode 4 line with dli flag set, so next line triggers dli
	.byte $00
:3	.byte $02		;4 mode 2 lines
	.byte $41,a(dl)		;wait vertical blank, jump $70
	.endl

;-----------------------------------------------------------------

	.proc dli		;display list interrupt
	pha
	lda #$38
	sta $d40a
	sta colpf2		;score area bg color

	lda #0
	sta colpf1		;score area text color

	pla
	rti
	.end

;-----------------------------------------------------------------

	.proc vbi		;deferred vertical blank interrupt

	lda rtclok+2		;load frame counter
	eor #7
	and #7
	sta hscroll		;do fine scrolling
	cmp #7
	bne no_scroll
	inc dl.scroll_address	;do byte scrolling
	lda dl.scroll_address
	cmp #.len scroll_text	;end of scroll text?
	bcc no_scroll
	lda #<scroll_text	;wrap to start
	sta dl.scroll_address
no_scroll 

	lda sound1		;sound active?
	beq no_sound1		;no disable volume
	dec sound1		;decrement volume
	ora #%01100000		;add distortion
no_sound1
	sta audc1

	lda sound2
	beq no_sound2
	dec sound2
	ora #%11100000
no_sound2
	sta audc2

	lda #0
	sta attract 		;reset ATRACT mode

	jmp xitvbv

	.endp

;-----------------------------------------------------------------

hits	.byte 0 	;number of hits left
score	.word 0 	;score low byte and high byte
high	.word 0 	;high score low byte and high byte
level	.word 0 	;level low byte and high byte
speed	.byte 0 	;delay to slow down game
wallidx	.byte 0 	;wall color index
midwidth .byte 0	;width of the center play area
temp	.byte 0		;temp storage
htd_out	.byte 0,0,0	;hex to bcd output, 3 bytes
htd_in	.word 0		;hex to bcd inout, 2 hex bytes
lww 	.byte 0		;left wall width

;-----------------------------------------------------------------

	.proc clear_screen
	ldx #0
	lda #0
loop
	sta sm,x
	sta sm+$100,x
	sta sm+$200,x
	sta sm+$300,x
	inx
	bne loop
	rts

	.endp

;-----------------------------------------------------------------

;	Scroll the screen up, copying the 2nd line to the 1st line etc.
	.proc scroll_screen

	ldx #0
loop1	lda sm+40,x
	sta sm,x
	inx
	bne loop1

loop2	lda sm+40+$100,x
	sta sm+$100,x
	inx
	bne loop2

loop3	lda sm+40+$200,x
	sta sm+$200,x
	inx
	cpx #248			;last third is not copied completely
	bcc loop3
	rts
	.endp

;-----------------------------------------------------------------

	.proc copy_charset
	ldx #0
loop	lda $e000,x 
	sta chr,x
	lda $e100,x
	sta chr+$100,x
	lda $e300,x
	sta chr+$300,x
	inx
	bne loop
	
	lda #>chr
	sta chbase
	rts
	.endp

;-----------------------------------------------------------------

	.proc read_stick
	ldx stick	;use X as storage

	txa		;restore from X so we can use A for other things, too 
	and #4		;left?
	bne kbd1
	lda px		;don't move too far left
	beq kbd1
	dec px

kbd1	txa
	and #8 		;right?
	bne kbd2
	lda px
	cmp #39
	bcs kbd2 	;don't move too far right
	inc px

kbd2	txa
	and #2	 	;down?
	bne kbd3
	lda py
	cmp #34		 ;dont move down too low
	bcs kbd3
	inc py
	inc py

kbd3	txa
	and #1	 	;up?
	bne kbd4
	lda py 		;don't you get too high, baby
	cmp #04
	bcc kbd4
	dec py
	dec py
kbd4 			;in case I want to add more commands
	rts
	.endp

;-----------------------------------------------------------------

	.proc update_status
	
	cpw score high		;Check for new high score
	bcc no_new_high
	mwa score high
no_new_high
	
	lda score
	ldx score+1
	jsr hex_to_bcd
	ldx #1
	jsr print_bcd_number.with_6_digits

	lda level
	ldx level+1
	jsr hex_to_bcd
	ldx #11
	jsr print_bcd_number.with_6_digits

	lda hits
	ldx #0
	jsr hex_to_bcd
	ldx #24
	jsr print_bcd_number.with_2_digits

	lda high
	ldx high+1
	jsr hex_to_bcd
	ldx #33
	jsr print_bcd_number.with_6_digits
	rts

;-----------------------------------------------------------------

	.proc print_bcd_number		;IN: htd_out, <X>=x position, OUT: <X>=next x position
with_6_digits
	lda htd_out+2
	jsr print_two_digits
with_4_digits
	lda htd_out+1
	jsr print_two_digits
with_2_digits
	lda htd_out+0
	jsr print_two_digits
	rts
	.endp

	.proc print_two_digits		;IN: <A>=BCD number, <X>=x position, OUT: <X>=next x position
	pha
	lsr
	lsr
	lsr
	lsr
	clc
	adc #$10
	sta statusline,x
	inx
	pla
	and #$0f
	clc
	adc  #$10
	sta statusline,x
	inx
	rts
	.endp

;-----------------------------------------------------------------
;http://6502.org/source/integers/hex2dec.htm
	.proc hex_to_bcd	;IN: <A>=low byte, <X>=high byte
	sta htd_in	;store input parameters
	stx htd_in+1

	sed		;output gets added up in decimal.

	lda #0
	sta htd_out	;inititalize output as 0.
	sta htd_out+1	;(nmos 6502 will need lda#0, sta...)
	sta htd_out+2

	ldx #$2d	;2dh is 45 decimal, or 3x15 bits.
bcdloop asl htd_in	;(0 to 15 is 16 bit positions.)
	rol htd_in+1	;if the next highest bit was 0,
	bcc htd1	;then skip to the next bit after that.
	lda htd_out	;but if the bit was 1,
	clc		;get ready to
	adc table+2,x	;add the bit value in the table to eht
	sta htd_out	;output sum in decimal-- first low b,ety
	lda htd_out+1	;then middle byte,
	adc table+1,x
	sta htd_out+1
	lda htd_out+2	;then high byte,
	adc table,x	;storing each byte
	sta htd_out+2	;of the summed output in htd_out.

htd1	dex      	 ;by taking x in steps of 3, we don't have to
	dex      	 ;multiply by 3 to get the right bytes freht mo
	dex      	 ;table.
	bpl bcdloop

	cld
	rts

table	.he 00 00 01 00 00 02 00 00 04 00 00 08
	.he 00 00 16 00 00 32 00 00 64 00 01 28
	.he 00 02 56 00 05 12 00 10 24 00 20 48
	.he 00 40 96 00 81 92 01 63 84 03 27 68

	.endp
	
	.endp
;-----------------------------------------------------------------

	.proc restart_loop
;screen setup
	jsr clear_screen
	jsr copy_charset

	ldx #.len output1-1;print score depth shields high
txtout1	lda output1,x
	sta statustext,x
	dex
	bpl txtout1

	ldx #.len output2-1;print press tigger
txtout2	lda output2,x
	sta msgline+10,x
	dex
	bpl txtout2

	lda #10
	sta hits	;10 chances
	lda #0
	sta score
	sta score+1
	sta level
	sta level+1
	jsr update_status

waitkey lda strig 
	bne waitkey

	ldx #.len output3-1;print in game text
txtout3	lda output3,x
	sta msgline,x
	dex
	bpl txtout3

;setup values
	lda #20
	sta lww 	;width of the left wall
	lda #10
	sta midwidth	;size of space player lives in
	lda #23
	sta px 		;player x position
	lda #2
	sta py		;player y pos (line number * 2)

	lda #$80
	sta speed

	lda random
	and #$07
	sta wallidx

wallfuno
	lda random		;change wall colors
	cmp #04
	bcc wallfuno
	sta 709
wallfun2o
	lda random
	cmp #04
	bcc wallfun2o
	sta 710

	.proc game_loop

	jsr read_stick

	ldx py			;draw player
	lda lines,x		;get memory location of screen line
	sta ptr
	lda lines+1,x
	sta ptr+1
	ldy px			;draw the player on line + x pos.

	lda (ptr),y		;hit detection for new spot
	beq drawplayer2		;0 = black, so no hit

	cmp #$d0
	beq drawplayer2		;$d0=ship trail, so no hit

	 ;hit obstacle!

	cmp #68
	beq drawplayer1 ;hit a prize

	cmp #69
	beq drawplayer2 ;just touched self by going up, that's ok

;otherwise, hit a wall/brick

;buzz a buzz!
buzz	
	lda random
	cmp #100
	bcc buzz ;nah, too high
	sta audf1
	lda #15
	sta sound1
	
	ldy px ;prep  that for drawplayer1

	dec hits ;update hit counter
	lda hits
	bne drawplayer2

	jmp game_over
	
drawplayer1   ;touched a prize (#68) - beep a beep!
	LDA #100
	STA audf2
	LDA #15
	sta sound2

	;add 400 points
	adw score #400

drawplayer2   		;actually draw the player now
	lda #69 	;player character
	sta (ptr),y

	ldx speed	;slow down scrolling
	ldy #$ff
slow1 dey
	bne slow1
	dex
	bne slow1


	  ;prep to draw walls.
	  ;change width of left wall
	lda lww ;current width of left wall
	cmp #0 ;if far left, increase it
	bne n2
	inc lww
	jmp newline1
n2 cmp #34 ;if too far right, decrease it
	bne n3
	dec lww
	jmp newline1
n3
	lda random
	bmi n4 ;if 0, move right
	dec lww ;if 1, move left
	jmp newline1
n4 inc lww

newline1 ;lets draw the line now
	ldx #0
	lda #$ff
	clc
	sbc level
	sta temp
drawleftloop   ;draw the left wall
	lda random

	cmp temp
	bcc wallcol1

	ldy wallidx
	iny
	lda walls,y
	jmp wallcol2
wallcol1
	ldy wallidx
	lda walls,y
wallcol2
	sta newlinesc,x
	inx
	cpx lww
	bcc drawleftloop
	clc
	  ;prep to draw play space
	lda lww ;store the length of left
	adc midwidth ;wall plus play space
	cmp #40
	bcc less_than_40
	lda #39
less_than_40
	sta tmp

drawspaceloop
	lda random
	cmp #6 ;if it's <6, obstacle
	bcs dsl1
	cmp #3 ;if its <3,
	bcs obst2
	lda #195 ;block
	jmp dsl2
obst2
	lda #68 ;prize
	jmp dsl2
dsl1
	lda #$00 ;blank space
dsl2
	sta newlinesc,x
	inx
	cpx tmp
	bcc drawspaceloop

drawrightloop   ;fill rest of line with right wall
	;temp is stil #$ff-levellb from before
	lda random
	cmp temp
	bcc wallcol3

	ldy wallidx
	iny
	lda walls,y
	jmp wallcol4

wallcol3
	ldy wallidx
	lda walls,y
wallcol4
	cpx #40
	bcs skip_right
	sta newlinesc,x
	inx
	bne drawrightloop

skip_right


;--------------------------
	jsr scroll_screen

	;increase level number
	inw level		;increment word

	ldx py			;increase score, bonus for being lower down
incscore
	inw score		;increment word
	dex
	bne incscore

	lda level 		;harder level?
	bne cleanup
	lda speed
	cmp #1
	beq speed2 		;if nonzero, lets go faster
	sec
	sbc #$10
	bne speed1
	clc  			;if 0 set to 1
	adc #1
speed1
	sta speed

speed2
	lda midwidth
	cmp #4
	bcc wallfun 		;3 is the smallest width
	dec midwidth

wallfun				;change wall colors
	lda random
	cmp #04
	bcc wallfun
	sta 709
wallfun2
	lda random
	cmp #04
	bcc wallfun2
	sta 710

	ldy wallidx
	iny
	lda walls,y
	bne wallupd
	ldy #0

wallupd
	sty wallidx

cleanup
	jsr update_status
	jmp game_loop
	.endp

	.proc game_over		;oh noes! game over
	jsr update_status
	ldx #.len output4-1	;out of shields - game over
txtout2 lda output4,x
	sta msgline,x
	dex
	bpl txtout2
	
waitkey lda strig 
	bne waitkey

	jmp restart_loop
	.endp
	
	.endp

;----------------------

	.local lines	;start address of screen lines in words
:24	.word (sm+#*40)	;sm+0*40, sm+1*40, ...
	.endl

walls	.local
	.by 66 67 66 67 66 67 66 67 66 67 66 00
	.endl


output1	.local
	.byte " SCORE     DEPTH     SHIELDS     HIGH"
	.endl
output2	.local
	.byte "Press trigger to play"
	.endl
output3	.local
	.byte "          How deep can you go?          "
	.endl
output4	.local
	.byte " Out of shields - Press trigger to play "
	.endl


	.endp		;End of main

	run main
