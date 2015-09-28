;--------------------------
; config.inc
;--------------------------

	list	p=16f690
#include    <p16f690.inc>


;#define CLOCKSPEED      .20000000	; 20 MHz Osc
;#define CLOCKSPEED      .8000000	; 8 MHz Osc
#define CLOCKSPEED       .4000000	; 4 MHz Osc

#define	OSCTUNE_VALUE	.0


;**********************************************
; old vs new boards
;            
; - RF_TX_PORT is B4 on old boards and B6 on new ones
; - ensure initial port setup is adjusted because B4 is used to read light on new boards  
; - messageLeng is used two places. should be 5 on old boards and 7 on new boards
; - on old boards, just comment out the light sensor read
;
;**********************************************

;**********************************************
; Port config:
; * RA0/AN0 : In  - humidity voltage (ADC)
; * RA1/AN1 : In  - termistor voltage (ADC)
; * PA2     : Out - enable temperature sensor
; * PA3     : Out - enable humidity sensor
;
; * RB4     : Out - RF transmitter 
;
;**********************************************
#define		PORT_HUMIDITY_VOLTAGE	PORTA, 0
#define		PORT_TEMP_VOLTAGE		PORTA, 1
#define		PORT_TEMP_ENABLE		PORTA, 2
#define		PORT_HUMIDITY_ENABLE	PORTA, 4
;***************************************
; Values required by rf_protocol.asm
;***************************************
#define	RF_TX_PORT		PORTB, 4 ; 4 on old boards, 6 on new boards
#define	RF_DST_ADDR		.1		; receiver has id 1
#define	RF_SRC_ADDR		.8		; local addr



;***************************************
; Values required by display.asm
;***************************************
#define DISPLAY_PORT	PORTC
#define DISPLAY_PORT_RS	PORTB, 6
#define DISPLAY_PORT_E	PORTB, 7


