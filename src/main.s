
.include "registers.inc"
.include "config.h"

.setcpu "65816"

.export ResetHandler
.export CopHandler
.export IrqHandler

.import InitGame
.import InitUi
.import PlayGame
.import __STACK_TOP

.code

; Sets Mode 0, OAM, load tiles
.proc ResetHandler
	SEI
	CLC
	XCE		; native mode

	REP	#$30
	SEP	#$20
.A8
.I16
	LDX	#__STACK_TOP
	TXS

	PHK
	PLB

	LDA	#0
	TCD

	JSR	InitGame
	JSR	InitUi

	JMP	PlayGame
.endproc


.proc CopHandler
	RTI
.endproc

.proc IrqHandler
	RTI
.endproc


.segment "COPYRIGHT"
		;1234567890123456789012345678901
	.byte	"Pong for The Super Nintendo    ", 10
	.byte	"(c) 2015, The Undisbeliever    ", 10
	.byte	"MIT Licensed                   ", 10
	.byte	"One Game Per Month Challange   ", 10

