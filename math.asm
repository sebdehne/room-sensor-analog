
#include "config.inc"

#define PRECISION 2             ; byte size for registers

M_STOR_STATUS macro WHERE
    movf    STATUS,w
    movwf   WHERE
    endm

M_RETR_STATUS macro WHERE
    movf    WHERE,w
    movwf   STATUS
    endm

    udata_shr
REG_X 				res PRECISION
REG_Y 				res PRECISION
REG_Z 				res PRECISION

	global	REG_X
	global	REG_Y
	global	REG_Z

    udata
REG_COUNTER			res 1
REG_STATUS			res 1
REG_T1				res 1
REG_T2				res 1
REG_ROT_COUNTER		res 1


	code

M_CLR                           ; clear a register
    movwf   FSR
    movlw   PRECISION
    movwf   REG_COUNTER
M_CLR_loop
    clrf    INDF
    incf    FSR,f
    decf    REG_COUNTER,f
    btfss   STATUS,Z
    goto    M_CLR_loop
    return

M_INC                           ; increment a register
    movwf   FSR
    movlw   PRECISION
    movwf   REG_COUNTER
M_INC_loop
    incf    INDF,f
    btfss   STATUS,Z
    return
    incf    FSR,f
    decf    REG_COUNTER,f
    btfss   STATUS,Z
    goto    M_INC_loop
    return


M_DEC                           ; decrement a register
    movwf   FSR
    movlw   PRECISION
    movwf   REG_COUNTER
M_DEC_loop
    decf    INDF,f
    movlw   0xFF
    subwf   INDF,w
    btfss   STATUS,Z
    return
    incf    FSR,f
    decf    REG_COUNTER,f
    btfss   STATUS,Z
    goto    M_DEC_loop
    return


M_ROL                           ; rotate a register to the left
    movwf   FSR
    M_STOR_STATUS REG_STATUS
    clrf    REG_COUNTER
M_ROL_loop
    M_RETR_STATUS REG_STATUS
    rlf     INDF,f
    M_STOR_STATUS REG_STATUS
    incf    FSR,f
    incf    REG_COUNTER,f
    movlw   PRECISION
    subwf   REG_COUNTER,w
    btfss   STATUS,Z
    goto    M_ROL_loop
    return


M_ROR                           ; rotates a register to the right
    movwf   FSR
    movlw   PRECISION-1
    addwf   FSR,f
    M_STOR_STATUS REG_STATUS
    clrf    REG_COUNTER
M_ROR_loop
    M_RETR_STATUS REG_STATUS
    rrf     INDF,f
    M_STOR_STATUS REG_STATUS
    decf    FSR,f
    incf    REG_COUNTER,f
    movlw   PRECISION
    subwf   REG_COUNTER,w
    btfss   STATUS,Z
    goto    M_ROR_loop
    return


M_CMP
	global	M_CMP               ; Z <=> X -> STATUS(C,Z)
                                ; STATUS,C set if Z => X;
                                ; STATUS,Z set if Z == X
    clrf    REG_COUNTER
M_CMP_loop
    movf    REG_COUNTER,w
    sublw   REG_Z+(PRECISION-1)
    movwf   FSR
    movf    INDF,w
    movwf   REG_T1
    movf    REG_COUNTER,w
    sublw   REG_X+(PRECISION-1)
    movwf   FSR
    movf    INDF,w
    subwf   REG_T1,f
    btfss   STATUS,Z
    return
    incf    REG_COUNTER,f
    movlw   PRECISION
    subwf   REG_COUNTER,w
    btfss   STATUS,Z
    goto    M_CMP_loop
    return


M_ADD                           ; Z + X -> Z
	global	M_ADD
    bcf     STATUS,C
    clrf    REG_STATUS
    clrf    REG_COUNTER
M_ADD_loop
    clrf    REG_T1
    btfsc   REG_STATUS,C
    incf    REG_T1,f
    clrf    REG_STATUS
    movlw   REG_X
    addwf   REG_COUNTER,w
    movwf   FSR
    movf    INDF,w
    addwf   REG_T1,f
    btfsc   STATUS,C
    bsf     REG_STATUS,C
    movlw   REG_Z
    addwf   REG_COUNTER,w
    movwf   FSR
    movf    INDF,w
    addwf   REG_T1,f
    btfsc   STATUS,C
    bsf     REG_STATUS,C
    movf    REG_T1,w
    movwf   INDF
    incf    REG_COUNTER,f
    movlw   PRECISION
    subwf   REG_COUNTER,w
    btfss   STATUS,Z
    goto    M_ADD_loop
    return


M_SUB                           ; Z - X -> Z
	global	M_SUB
    clrf    REG_COUNTER
    bsf     REG_STATUS,C
M_SUB_loop
    bsf     REG_T2,C
    movlw   REG_Z
    addwf   REG_COUNTER,w
    movwf   FSR
    movf    INDF,w
    movwf   REG_T1
    movlw   REG_X
    addwf   REG_COUNTER,w
    movwf   FSR
    movf    INDF,w
    subwf   REG_T1,f
    btfss   STATUS,C
    bcf     REG_T2,C
    btfsc   REG_STATUS,C
    goto    M_SUB_no_carry
    movlw   0x01
    subwf   REG_T1,f
    btfss   STATUS,C
    bcf     REG_T2,C
M_SUB_no_carry
    movlw   REG_Z
    addwf   REG_COUNTER,w
    movwf   FSR
    movf    REG_T1,w
    movwf   INDF
    bsf     REG_STATUS,C
    btfss   REG_T2,C
    bcf     REG_STATUS,C
    incf    REG_COUNTER,f
    movlw   PRECISION
    subwf   REG_COUNTER,w
    btfss   STATUS,Z
    goto    M_SUB_loop
    btfss   REG_STATUS,C
    bcf     STATUS,C
    return


M_MUL                           ; X * Y -> Z
	global	M_MUL

    movlw   REG_Z
    call    M_CLR
    movlw   PRECISION*8+1
    movwf   REG_ROT_COUNTER
M_MUL_loop
    decf    REG_ROT_COUNTER,f
    btfsc   STATUS,Z
    return
    btfsc   REG_Y,0
    call    M_ADD
    bcf     STATUS,C
    movlw   REG_Y
    call    M_ROR
    bcf     STATUS,C
    movlw   REG_X
    call    M_ROL
    goto    M_MUL_loop


M_DIV                           ; Z / X -> Y;  remainder -> Z
	global	M_DIV
	
    movlw   REG_Y
    call    M_CLR
    movlw   PRECISION*8
    movwf   REG_ROT_COUNTER
M_DIV_rot_loop
    btfsc   REG_X+(PRECISION-1),7
    goto    M_DIV_loop
    movlw   REG_X
    bcf     STATUS,C
    call    M_ROL
    decf    REG_ROT_COUNTER,f
    btfss   STATUS,Z
    goto    M_DIV_rot_loop
    bsf     STATUS,Z
    return
M_DIV_loop
    call    M_CMP
    M_STOR_STATUS REG_T2
    movlw   REG_Y
    call    M_ROL
    M_RETR_STATUS REG_T2
    btfsc   STATUS,C
    call    M_SUB
    bcf     STATUS,Z
    bcf     STATUS,C
    movlw   REG_X
    call    M_ROR
    incf    REG_ROT_COUNTER,f
    movlw   PRECISION*8+1
    subwf   REG_ROT_COUNTER,w
    btfss   STATUS,Z
    goto    M_DIV_loop
    return    

    END
    

