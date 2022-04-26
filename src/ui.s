
.include "registers.inc"
.include "config.h"

.setcpu "65816"

.export InitUi
.export VBlank

.import	p1ScoreBcd
.import p2ScoreBcd
.import ballXPos
.import ballYPos
.import p1PaddleYPos
.import p2PaddleYPos


.A8
.I16
.proc InitUi
	LDA	#INIDISP_FORCE
	STA	INIDISP

	STZ	NMITIMEN

	LDA	#(OBJ_TILES / OBSEL_BASE_WALIGN) | OBSEL_SIZE_8_16
	STA	OBSEL

	LDA	#0
	STA	BGMODE

	; Disabling interlacing
	STZ SETINI

	; Disable windows
	STZ WOBJSEL
	STZ WOBJLOG
	STZ CGWSEL
	STZ CGADSUB


	; Black BG
	STZ	CGADD
	STZ	CGDATA
	STZ	CGDATA


	LDA	#128
	STA	CGADD

	LDX	#0
PaletteLoop:
		LDA	Palette, X
		STA	CGDATA
		INX
		CPX	#32
		BCC	PaletteLoop


	LDA #VMAIN_INCREMENT_HIGH | VMAIN_INCREMENT_1
	STA VMAIN


	REP	#$30
.A16

	LDA	#OBJ_TILES
	STA	VMADD

	LDX	#0
TilesLoop:	
		LDA	Tiles, X
		STA	VMDATA
		INX
		INX
		CPX	#Tiles_End - Tiles
		BCC	TilesLoop

	SEP	#$20
.A8
	; Reset OAM
	STZ	OAMADDL
	STZ	OAMADDH

	LDA	#256 - 16
	LDX	#128
OamResetLoop:
		STA	OAMDATA
		STA	OAMDATA
		STZ	OAMDATA
		STZ	OAMDATA
		DEX
		BPL	OamResetLoop

	; High Table
	LDA	#128 / 4
OamResetHighLoop:
		STZ	OAMDATA
		DEC
		BPL	OamResetHighLoop


	LDA	#NMITIMEN_VBLANK_FLAG | NMITIMEN_AUTOJOY_FLAG
	STA	NMITIMEN

	LDA	#TM_OBJ
	STA	TM

	STZ TS
	STZ TMW
	STZ TSW


	LDA	#15
	STA	INIDISP

	RTS
.endproc

.macro DrawBcdNumber bcd, xPos, yPos
	LDA	#xPos
	STA	OAMDATA		; xpos

	LDA	#yPos
	STA	OAMDATA		; ypos

	LDA	bcd
	LSR
	LSR
	LSR
	LSR
	CLC
	ADC	#DIGIT_OFFSET
	STA	OAMDATA		; char
	STZ	OAMDATA		; attr


	LDA	#xPos + DIGIT_SPACING
	STA	OAMDATA		; xpos

	LDA	#yPos
	STA	OAMDATA		; ypos

	LDA	bcd
	AND	#$0F
	CLC
	ADC	#DIGIT_OFFSET
	STA	OAMDATA		; char
	STZ	OAMDATA		; attr
.endmacro

.macro DrawBall
	LDA	ballXPos + 1
	STA	OAMDATA		; xPos

	LDA	ballYPos + 1
	STA	OAMDATA		; yPos

	LDA	#BALL_SPRITE
	STA	OAMDATA		; char
	STZ	OAMDATA		; attr
.endmacro

.macro DrawPaddle xPos, yPos
	.assert PADDLE_HEIGHT = 24, error, "Bad Value"

	LDA	yPos
	TAY

	LDA	xPos
	STA	OAMDATA		; xPos
	TYA
	STA	OAMDATA		; yPos
	LDA	#PADDLE_SPRITE
	STA	OAMDATA		; char
	STZ	OAMDATA		; attr


	LDA	xPos
	STA	OAMDATA		; xPos
	TYA
	CLC
	ADC	#8
	TAY
	STA	OAMDATA		; yPos
	LDA	#PADDLE_SPRITE
	STA	OAMDATA		; char
	STZ	OAMDATA		; attr

	LDA	xPos
	STA	OAMDATA		; xPos
	TYA
	CLC
	ADC	#8
	TAY
	STA	OAMDATA		; yPos
	LDA	#PADDLE_SPRITE
	STA	OAMDATA		; char
	STZ	OAMDATA		; attr
.endmacro

.proc VBlank
	; Save state
	REP #$30
	PHA
	PHB
	PHD
	PHX
	PHY

	PHK
	PLB

	REP	#$30
	SEP	#$20
.A8
.I16
	; Reset NMI Flag.
	LDA	RDNMI

	LDY	#0
	STY	OAMADD

	DrawBcdNumber	p1ScoreBcd, SCORE_P1_XPOS, SCORE_YPOS
	DrawBcdNumber	p2ScoreBcd, SCORE_P2_XPOS, SCORE_YPOS
	DrawBall

	DrawPaddle	#PADDLE_P1_XPOS, p1PaddleYPos + 1
	DrawPaddle	#PADDLE_P2_XPOS, p2PaddleYPos + 1

	; Load State
	REP	#$30
	PLY
	PLX
	PLD
	PLB
	PLA

	RTI
.endproc

.rodata

Tiles:
	.incbin	"resources/tiles.4bpp"
Tiles_End:

Palette:
	.incbin "resources/tiles.clr", 0, 32

