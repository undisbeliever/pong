
.include "registers.inc"
.include "config.h"

.setcpu "65816"

.export InitGame
.export PlayGame
.export p1ScoreBcd
.export p2ScoreBcd
.export ballXPos
.export ballYPos

.struct Paddle
	xPos	.word
	yPos	.word
	yVecl	.word	; 1:8:8 fixed point integer
.endstruct

.export p1PaddleYPos = p1Paddle + Paddle::yPos
.export p2PaddleYPos = p2Paddle + Paddle::yPos


.segment "SHADOW"
	p1ScoreBcd:		.res 1
	p2ScoreBcd:		.res 1
	ballXPos:		.res 2	; 0:8:8 fixed point integer
	ballYPos:		.res 2	; 0:8:8 fixed point integer

	ballXVecl:		.res 2	; 1:8:8 fixed point integer
	ballYVecl:		.res 2	; 1:8:8 fixed point integer

	startingDirection:	.res 0	; p1 on zero

	p1Paddle:		.tag Paddle
	p2Paddle:		.tag Paddle
.code

.A8
.I16
.proc InitGame
	STZ	p1ScoreBcd
	STZ	p2ScoreBcd

	STZ	startingDirection

	LDY	#(SCREEN_TOP + (SCREEN_BOTTOM - PADDLE_HEIGHT) / 2) << 8
	STY	p1Paddle + Paddle::yPos
	STY	p2Paddle + Paddle::yPos

	LDX	#PADDLE_P1_XPOS << 8
	STX	p1Paddle + Paddle::xPos

	LDX	#PADDLE_P2_XPOS << 8
	STX	p2Paddle + Paddle::xPos

	LDX	#0
	STX	p1Paddle + Paddle::yVecl
	STX	p2Paddle + Paddle::yVecl

	.assert * = ResetBall, error, "Bad Flow"
.endproc


.A8
.I16
.proc ResetBall
	REP	#$30
	SEP	#$20
.A8
.I16

	LDY	#((SCREEN_WIDTH - BALL_WIDTH) / 2) << 8
	STY	ballXPos

	LDY	#(SCREEN_TOP + (SCREEN_BOTTOM - BALL_HEIGHT) / 2) << 8
	STY	ballYPos

	LDA	startingDirection
	BEQ	Player1Start
Player2Start:
		STZ	startingDirection
		LDX	#START_BALL_XVECL
		BRA	EndPlayerCheck
Player1Start:
		INC
		STA	startingDirection
		LDX	#.loword(-START_BALL_XVECL)
EndPlayerCheck:

	STX	ballXVecl

	LDY	#START_BALL_YVECL
	STY	ballYVecl

	RTS
.endproc


.proc PlayGame
	WAI

	SEP	#$20
.A8
	; Wait until autojoy is completed
	JoypadNotReady:
		LDA HVJOY
		AND #HVJOY_AUTOJOY
		BNE JoypadNotReady

	REP	#$30
.A16
.I16
	JSR	ProcessFrame
	BRA	PlayGame
.endproc


.A16
.I16
.proc ProcessFrame

	; Test if in score area
	LDA	ballXVecl
	BPL	BallTowardsP2
		; ball moving towards p1, underflow check
		; A = ballXVecl
		CLC
		ADC	ballXPos
		STA	ballXPos

		BCS	ProcessYPos

			; xPos underflowed, failed to hit ball
			LDX	#p2ScoreBcd
			JSR	IncreaseScore
			BRA	ResetBall
BallTowardsP2:

		; ball moving towards p2, overflowflow check
		; A = ballXVecl
		CLC
		ADC	ballXPos
		STA	ballXPos

		BCC	ProcessYPos

			; xPos overflowed, failed to hit ball
			LDX	#p1ScoreBcd
			JSR	IncreaseScore
			BRA	ResetBall

ProcessYPos:

	LDA	ballYVecl
	BPL	BallTowardsBottom
		; ball moving towards top, underflow check
		; A = ballYVecl
		CLC
		ADC	ballYPos
		STA	ballYPos

		CMP	#SCREEN_TOP << 8
		BCS	ProcessPaddles

			; yPos hit celing
			LDA	#SCREEN_TOP << 8
			STA	ballYPos

			LDA	ballYVecl
			EOR	#$FFFF
			INC
			STA	ballYVecl

		BRA	ProcessPaddles

BallTowardsBottom:
		; ball moving towards bottom, normal check
		; A = ballYVecl
		CLC
		ADC	ballYPos
		STA	ballYPos

		CMP	#(SCREEN_BOTTOM - BALL_HEIGHT) << 8
		BCC	ProcessPaddles

			; yPos hit bottom
			LDA	#(SCREEN_BOTTOM - BALL_HEIGHT) << 8
			STA	ballYPos

			LDA	ballYVecl
			EOR	#$FFFF
			INC
			STA	ballYVecl
ProcessPaddles:

	LDX	#p1Paddle
	LDY	#JOY1
	JSR	ProcessPaddle

	LDX	#p2Paddle
	LDY	#JOY2
	JSR	ProcessPaddle

	RTS
.endproc


; IN: X - Paddle ptr
; IN: Y - joypad ptr
.A16
.I16
.proc	ProcessPaddle
	LDA	0, Y
	AND	#JOY_UP | JOY_DOWN
	BEQ	NothingPressed

	CMP	#JOY_UP | JOY_DOWN
	BEQ	NothingPressed		; cancel each other out

	AND	#JOY_UP
	BEQ	DownPressed
UpPressed:
		LDA	a:Paddle::yVecl, X
		SEC
		SBC	#PADDLE_ACCEL
		CMP	#.loword(-PADDLE_MAX_VECL)
		BPL	SkipUpLimit

		LDA	#.loword(-PADDLE_MAX_VECL)
SkipUpLimit:
		STA	a:Paddle::yVecl, X

		BRA	EndJoypad


DownPressed:
		LDA	a:Paddle::yVecl, X
		CLC
		ADC	#PADDLE_ACCEL
		CMP	#PADDLE_MAX_VECL
		BMI	SkipDownLimit

		LDA	#PADDLE_MAX_VECL
SkipDownLimit:
		STA	a:Paddle::yVecl, X

		BRA	EndJoypad

NothingPressed:
	; Friction

	LDA	a:Paddle::yVecl, X
	BMI	FrictionMinus
FrictionPlus:
		CMP	#PADDLE_FRICTION
		BCC	FrictionZero

			SEC
			SBC	#PADDLE_FRICTION
			STA	a:Paddle::yVecl, X

		BRA	EndJoypad

FrictionMinus:
		CMP	#.loword(-PADDLE_FRICTION)
		BPL	FrictionZero

			CLC
			ADC	#PADDLE_FRICTION
			STA	a:Paddle::yVecl, X

		BRA	EndJoypad
FrictionZero:
	STZ	a:Paddle::yVecl, X

EndJoypad:


	LDA	a:Paddle::yVecl, X
	BPL	MoveDown
		; paddle moving towards top, underflow check
		; A = ballYVecl
		CLC
		ADC	a:Paddle::yPos, X
		STA	a:Paddle::yPos, X

		CMP	#SCREEN_TOP << 8
		BCS	CheckBall

			LDA	#SCREEN_TOP << 8
			STA	a:Paddle::yPos, X
			STZ	a:Paddle::yVecl, X

		BRA	CheckBall

MoveDown:
		; ball moving towards bottom, normal check
		; A = ballYVecl
		CLC
		ADC	a:Paddle::yPos, X
		STA	a:Paddle::yPos, X

		CMP	#(SCREEN_BOTTOM - PADDLE_HEIGHT) << 8
		BCC	CheckBall

			; yPos hit bottom
			LDA	#(SCREEN_BOTTOM - PADDLE_HEIGHT) << 8
			STA	a:Paddle::yPos, X
			STZ	a:Paddle::yVecl, X

CheckBall:
	; Had to look this one up sadly
	;
	; 	if ballXPos < paddle->xPos
	;		if ballXPos + ball_width < paddle->xPos
	;			goto NoCollision
	; 	else
	;		if ballXPos - paddle_width >= paddle->xPos
	;			goto NoCollision

	LDA	ballXPos
	CMP	a:Paddle::xPos, X
	BCS	BallXGE
		; C clear
		ADC	#BALL_WIDTH << 8
		CMP	a:Paddle::xPos, X
		BCC	NoCollision
		BRA	TestBallYPos

BallXGE:
		; C set
		SBC	#PADDLE_WIDTH << 8
		SEC
		SBC	a:Paddle::xPos, X
		BCS	NoCollision

TestBallYPos:

	LDA	ballYPos
	CMP	a:Paddle::yPos, X
	BCS	BallYGE
		; C clear
		ADC	#BALL_HEIGHT << 8
		CMP	a:Paddle::yPos, X
		BCC	NoCollision
		BRA	Collision

BallYGE:
		; C set
		SBC	#PADDLE_HEIGHT << 8
		SEC
		SBC	a:Paddle::yPos, X

		.scope
			; Signed branch ge

			; BUGFIX: Required because `ballYPos - paddle_height` could be < 0

			BVS	Invert
			BMI	Collision
			BPL	NoCollision
Invert:
			BMI	NoCollision
		.endscope

Collision:
	; negate X vecl
	LDA	ballXVecl
	EOR	#$FFFF
	INC
	STA	ballXVecl

	; Move ball to outside the paddle
	; Prevent ball moving backwards
	CPX	#p2Paddle
	BEQ	SetBallXPosP2
		LDA	#(PADDLE_P1_XPOS + PADDLE_WIDTH) << 8
		STA	ballXPos
		BRA	EndSetBallXPos
SetBallXPosP2:
		LDA	#(PADDLE_P2_XPOS - BALL_WIDTH + 1) << 8
		STA	ballXPos
EndSetBallXPos:

	; Add 1/8 the paddles yVecl to the ball
	; Decrease paddles yVecl by half

	LDA	a:Paddle::yVecl, X
	; ASR
	CMP	#$8000
	ROR
	STA	a:Paddle::yVecl, X

	; ASR
	CMP	#$8000
	ROR

	; ASR
	CMP	#$8000
	ROR

	CLC
	ADC	ballYVecl
	STA	ballYVecl

NoCollision:

	RTS
.endproc



; IN: X - location of score variable
.proc	IncreaseScore
	PHP
	SEP	#$28
.A8
	LDA	0, X
	CLC
	ADC	#$01
	STA	0, X

	CMP	#$99
	BNE	Skip
		BRA	*	; Loop forever if someone score 99
Skip:

	PLP
	RTS
.endproc
