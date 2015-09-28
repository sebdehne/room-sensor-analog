	errorlevel  -302


	#include "config.inc" 
	
	__CONFIG       _CP_OFF & _CPD_OFF & _WDT_OFF & _BOR_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT  & _MCLRE_OFF & _FCMEN_OFF & _IESO_OFF
	
	udata
Values			res	5 
DelayCounter1	res	1
DelayCounter2	res	1
DelayCounter3	res	1
Counter			res 1

	; imported from the rf_protocol_tx module
	extern	MsgAddr
	extern	MsgLen
	extern	RF_TX_Init
	extern	RF_TX_SendMsg
	; imported from the display module
	extern	Display_init
	extern	Display_clear
	extern	Display_set_pos_line1
	extern	Display_set_pos_line2
	extern	Display_digit_char
	extern	Display_write_char
	; imported from the math module
	extern	REG_X
	extern	REG_Y
	extern	REG_Z
	extern	M_DIV
	
	
	

Reset	CODE	0x0
	pagesel	_init
	goto	_init
	
	
	code
	
_init
	; set the requested clockspeed
	banksel	OSCCON
	if CLOCKSPEED == .8000000
		movlw	b'01110001'
	else
		if CLOCKSPEED == .4000000
			movlw	b'01100001'
		else
			error	"Unsupported clockspeed"
		endif
	endif
	movwf	OSCCON
	
	; setup option register
	banksel	OPTION_REG
	movlw	b'00000000'	
		;	  ||||||||---- PS0 - Timer 0: 
		;	  |||||||----- PS1
		;	  ||||||------ PS2
		;	  |||||------- PSA -  Assign prescaler to Timer0
		;	  ||||-------- TOSE - LtoH edge
		;	  |||--------- TOCS - Timer0 uses IntClk
		;	  ||---------- INTEDG - falling edge RB0
		;	  |----------- NOT_RABPU - pull-ups enabled
	movwf	OPTION_REG

	; osctune
	banksel	OSCTUNE
	movlw	OSCTUNE_VALUE
	movwf	OSCTUNE

	; all ports to digital, except for RA0, RA1 & RB5
	banksel	ANSEL
	clrf	ANSEL			; all digital
	clrf	ANSELH			; all digital
	BSF 	ANSEL,  0       ; Set AN0 to analog  (RA1)
	BSF 	ANSEL,  1       ; Set AN1 to analog  (RA0)
	;BSF	ANSELH, 2		; Set AN10 to analog (RB4)

	; Configure port A
	BANKSEL TRISA
	CLRF	TRISA			; output all
	BSF		TRISA, 0        ; input: AN0 / RA0
	BSF		TRISA, 1        ; input: AN1 / RA1

	; Configure port B
	BANKSEL	TRISB
	clrf	TRISB			; output all
	;BSF	TRISB, 4       	; input: AN10 / RB5 ; only on new boards
	
	; Set entire portC as output
	BANKSEL	TRISC
	clrf	TRISC			; output all	

	
	; Select the clock for our A/D conversations
	BANKSEL	ADCON1
	MOVLW 	B'01010000'	; ADC Fosc/16
	MOVWF 	ADCON1
	
	; set all output ports to 0
	banksel	PORTA
	clrf	PORTA
	clrf	PORTB
	clrf	PORTC
	
	; clear the msg buf
	banksel	Values
	clrf	Values		; temp-low
	clrf	Values+1	; temp-high
	clrf	Values+2	; humidity-low
	clrf	Values+3	; humidity-high
	clrf	Values+4	; counter
	banksel	Counter
	clrf	Counter

	
	; Configure the watch-dog timer, but disable it for now
	banksel	OPTION_REG
	movlw	b'00001111' ; 110 == 64 pre-scaler & WDT selected
	movwf	OPTION_REG
	banksel	WDTCON
	movlw	b'00010110' ; 1011 == max
	;            |||||
	;            ||||+--- disable watchdog timer SWDTEN
	;            |||+---- pre-scaler WDTPS0
	;            ||+----- pre-scaler WDTPS1
	;            |+------ pre-scaler WDTPS2
	;            +------- pre-scaler WDTPS3
	movwf	WDTCON
	banksel	PORTA
	
	; init the rf_protocol_tx.asm module
	call	RF_TX_Init
	
_main
	;enable watch-dog timer
	banksel	WDTCON
	bsf		WDTCON, SWDTEN
	SLEEP
	banksel	WDTCON
	bcf		WDTCON, SWDTEN
	banksel	PORTA
	
	; measure the temp now
	call	ReadTemperatureSensor

	; measure the humidity now
	call	ReadHumiditySensor

	; Counter
	banksel	Counter
	incf	Counter, F
	movfw	Counter
	banksel	Values
	movwf	Values+4

	; measure the ligh intensity now (only from rev 5)
	; call	ReadLightSensor

	; Load the value's location and send the msg
	movlw	HIGH	Values
	movwf	MsgAddr
	movlw	LOW		Values
	movwf	MsgAddr+1
	movlw	.5
	movwf	MsgLen
	; and transmit the data now
	call	RF_TX_SendMsg

	goto	_main

ReadLightSensor
	bsf		PORTB, 5; enable light sensor
	call	Delay_1ms
	; BEGIN A/D conversation
	BANKSEL ADCON0 ;
	MOVLW 	B'10101001' ;Right justify,
	MOVWF 	ADCON0 		; Vdd Vref, AN10, On
	call	Delay_1ms
	BSF 	ADCON0,GO ;Start conversion
	BTFSC 	ADCON0,GO ;Is conversion done?
	GOTO 	$-1       ;No, test again
	; END A/D conversation
	bcf		PORTB, 5  ; disable light sensor
	call	Delay_1ms
	BANKSEL ADRESH
	movfw	ADRESH
	BANKSEL Values
	movwf	Values+6
	BANKSEL ADRESL
	movfw	ADRESL
	BANKSEL Values
	movwf	Values+5
	return

ReadTemperatureSensor
	bsf		PORT_TEMP_ENABLE ; enable temp sensor
	call	Delay_1ms
	; BEGIN A/D conversation
	BANKSEL ADCON0 ;
	MOVLW 	B'10000101' ;Right justify,
	MOVWF 	ADCON0 		; Vdd Vref, AN1, On
	call	Delay_1ms
	BSF 	ADCON0,GO ;Start conversion
	BTFSC 	ADCON0,GO ;Is conversion done?
	GOTO 	$-1       ;No, test again
	; END A/D conversation
	bcf		PORT_TEMP_ENABLE  ; disable temp sensor
	call	Delay_1ms
	BANKSEL ADRESH
	movfw	ADRESH
	BANKSEL Values
	movwf	Values+1
	BANKSEL ADRESL
	movfw	ADRESL
	BANKSEL Values
	movwf	Values
	return

ReadHumiditySensor
	bsf		PORT_HUMIDITY_ENABLE ; enable temp sensor
	call	Delay_1ms
	; BEGIN A/D conversation
	BANKSEL ADCON0 ;
	MOVLW 	B'10000001' ;Right justify,
	MOVWF 	ADCON0 		; Vdd Vref, AN0, On
	call	Delay_1ms
	BSF 	ADCON0,GO ;Start conversion
	BTFSC 	ADCON0,GO ;Is conversion done?
	GOTO 	$-1       ;No, test again
	; END A/D conversation
	bcf		PORT_HUMIDITY_ENABLE  ; disable temp sensor
	call	Delay_1ms
	BANKSEL ADRESH
	movfw	ADRESH
	BANKSEL Values
	movwf	Values+3
	BANKSEL ADRESL
	movfw	ADRESL
	BANKSEL Values
	movwf	Values+2
	return
	
DisplayResult ; display the number in REG_Z
	
	; cal & show the first number
	movlw	HIGH	.1000
	movwf	REG_X+1
	movlw	LOW		.1000
	movwf	REG_X
	call	M_DIV
	movfw	REG_Y
	call	Display_digit_char

	; cal & show the second number
	movlw	HIGH	.100
	movwf	REG_X+1
	movlw	LOW		.100
	movwf	REG_X
	call	M_DIV
	movfw	REG_Y
	call	Display_digit_char

	; cal & show the third number
	movlw	HIGH	.10
	movwf	REG_X+1
	movlw	LOW		.10
	movwf	REG_X
	call	M_DIV
	movfw	REG_Y
	call	Display_digit_char

	; cal & show the last number
	movfw	REG_Z
	call	Display_digit_char
	
	; done
	return

Delay_1ms
	if CLOCKSPEED == .4000000
			;993 cycles
		movlw	0xC6
		movwf	DelayCounter1
		movlw	0x01
		movwf	DelayCounter2
	else
		if CLOCKSPEED == .8000000
					;1993 cycles
			movlw	0x8E
			movwf	DelayCounter1
			movlw	0x02
			movwf	DelayCounter2
		else
			error "Unsupported clockspeed
		endif
	endif
Delay_1ms_0
	decfsz	DelayCounter1, f
	goto	$+2
	decfsz	DelayCounter2, f
	goto	Delay_1ms_0

			;3 cycles
	goto	$+1
	nop
			;4 cycles (including call)
	return
	

	end