.org 0
rjmp main
.org 0X1A
rjmp TIMER1_COMPA_ISR

.org 0x40
main:
	call LCD_Init
	call TIMER1_COMPA_ISR_init
MAIN_LOOP:
	RJMP main_LOOP

/*
********************************************
*        Ch??ng trình ng?t Timer1          *
********************************************
*/
TIMER1_COMPA_ISR_init:
	ldi r16, (1 << WGM12)            ; CTC mode (WGM12 = 1)
	sts TCCR1B, r16

	ldi r16, (1 << CS12) | (1 << CS10) ; Prescaler = 1024
	ori r16, (1 << WGM12)
	sts TCCR1B, r16

	ldi r16, (1 << OCIE1A)           ; Enable interrupt compare match A
	sts TIMSK1, r16

	ldi r16, high(15624)
	sts OCR1AH, r16
	ldi r16, low(15624)
	sts OCR1AL, r16


	sei ; Cho phép ng?t toàn c?c
ret

TIMER1_COMPA_ISR:
	call read_DHT22

	push r16
	push r17
	push r18

	ldi r16, 0x01
    call LCD_Send_Command
    ldi r16, 0x80
    call LCD_Send_Command
	
	call DISPLAY_Temperature
	call DISPLAY_Relative_Humidity

	pop r18
	pop r17
	pop r16
	reti

/*
********************************************
*        Hàm nh?n tín hi?u t? DTH22         *
********************************************
*/

read_DHT22:
;??c giá tr? thu ???c t? DHT22
;d? li?u nhi?t ?? g?m 2 byte; byte cao l?u ? R1; byte th?p l?u ? R2
;d? li?u ?? ?m g?m 2 byte; byte cao l?u ? R3; byte th?p l?u ? R4
	SBI DDRD,0
	cbi PORTd,0
	call delay_10ms
	call delay_10ms
	CBI DDRD,0
	call PD0_wait0
	call PD0_wait1

	rcall read_next_8bit
	mov r3, r18
	rcall read_next_8bit
	mov r4, r18
	rcall read_next_8bit
	bst r18,7
	mov r1, R18
	rcall read_next_8bit
	mov r2, r18
	rcall read_next_8bit
	mov r5, r18

	LDI R18,0x7F
	AND R1,R18

;x? lý d? li?u nhi?t ??
;ph?n nguyên l?u ? R1, ph?n th?p phân  1 s? l? l?u ? R2
	MOV AH,R1
	MOV AL,R2
	LDI BL,10
	LDI BH,0
	call DIV1616
	mov R1,ANSL
	mov R2,REML

;x? lý d? li?u ?? ?m, làm tròn
;Làm tròn ??n ph?n nguyên và l?u ? R3
	MOV AH,R3
	MOV AL,R4
	LDI BL,10 
	LDI BH,0

	call DIV1616
	mov R3,ANSL
	mov R4,REML

  ;làm tròn
    mov R16,r4
    cpi r16,5
    brsh RH_plus_1
	    ret
	RH_plus_1:
		inc R3
ret
read_next_8bit:
LDI R17,8
read_next_bit:  
	call PD0_wait0
	call PD0_wait1
	call delay_40us
	IN r16,PIND
	ANDI r16,0X01 ; l?y bit pd0
	LSL r18
	or r18,r16
	DEC R17
	BrNE read_next_bit
ret
PD0_wait0:
	SBIC PinD,0
	rjmp PD0_wait0
ret

PD0_wait1:
	SBIS PinD,0
	rjmp PD0_wait1
ret

/*
********************************************
*Hàm chuy?n s? nh? phân  thành BCD qua r16 *
********************************************
*/
BIN8_BCD:
push r15
push r17
		LDI R17, 10; s? chia
		CLR R15 ;R15=th??ng s?
	GT_DV: 
		SUB R16,R17 ;tr? s? b? chi cho s? chia
		BRCS LT_DV ;C=1 không chia ???c
		INC R15 ;t?ng th??ng s? thêm 1
		RJMP GT_DV ;th?c hi?n ti?p
	LT_DV: 
		ADD R16,R17 ;l?y l?i d? s?
		SWAP R15
		OR R16,R15
pop r17
pop r15
RET

/*
********************************************
*     Hàm hi?n th? nhi?t ??/ ?? ?m         *
********************************************
*/
Temperature: .db "T: ",0
DISPLAY_Temperature:
   
	ldi r16, 0
    ldi r17, 1
    call LCD_Move_Cursor
    ; Dòng 1: "T: [DISPLAY_Temperature]°C"
    ldi ZH, high(Temperature)
    ldi ZL, low(Temperature)
    call LCD_Send_String

	;Xu?t d?u
	BRTC  T_n
	ldi R16,'-'
	call LCD_Send_Data
T_n:
	;xu?t ph?n nguyên 
	mov r16,r1
	call BIN8_BCD     
    call LCD_display_BCD

	ldi R16,'.'
	call LCD_Send_Data
	; xu?t ph?n th?p phân 
    mov  R16,r2
	ldi R17,48
	add	 R16,R17
	call LCD_Send_Data

	;xu?t ký hi?u 
    ldi r16, 223; 
    call LCD_Send_Data
	ldi r16, 'C'; 
    call LCD_Send_Data
    ret

Relative_Humidity: .db "RH: ",0,0
DISPLAY_Relative_Humidity:
    

	ldi r16, 1
    ldi r17, 1
    call LCD_Move_Cursor
    ; Dòng 1: "RH: [Relative_Humidity]%"
    ldi ZH, high(Relative_Humidity)
    ldi ZL, low(Relative_Humidity)
    call LCD_Send_String
	
    mov r16,r3
	CPI r16,100
	BrSH RH_100

	call BIN8_BCD
    call LCD_display_BCD
	ldi r16, '%'; 
    call LCD_Send_Data
    ret

Relative_Humidity_100: .db "100%",0,0
	RH_100:
	ldi ZH, high(Relative_Humidity_100)
    ldi ZL, low(Relative_Humidity_100)
    call LCD_Send_String
	ret

/*
********************************************
*            Các hàm LCD                   *
********************************************
*/
.equ LCDPORT = PORTA
.equ LCDPORTDIR = DDRA
.equ LCDPORTPIN = PINA
.equ LCD_RS = PINA0
.equ LCD_RW = PINA1
.equ LCD_EN = PINA2
.equ LCD_D7 = PINA7
.equ LCD_D6 = PINA6
.equ LCD_D5 = PINA5
.equ LCD_D4 = PINA4

LCD_Init:
    ldi r16, 0b11110111
    out LCDPORTDIR, r16
    call DELAY_10MS
    call DELAY_10MS
    ldi r16, 0x02
    call LCD_Send_Command
    ldi r16, 0x28
    call LCD_Send_Command
    ldi r16, 0x0E
    call LCD_Send_Command
    ldi r16, 0x01
    call LCD_Send_Command
    ldi r16, 0x80
    call LCD_Send_Command
    ret

LCD_display_BCD:
	push r17
	mov r17,r16 ;

    swap r16
    andi r16, 0x0F        ; L?y hàng ch?c
    subi r16, -48        ; Chuy?n thành ASCII
    call LCD_Send_Data

	mov r16,r17
    andi r16, 0x0F        ; L?y hàng ??n v?
    subi r16, -48        ; Chuy?n thành ASCII
    call LCD_Send_Data
	pop r17
    ret

LCD_Move_Cursor:
    cpi r16, 0
    brne LCD_Move_Cursor_Second
    andi r17, 0x0F
    ori r17, 0x80
    mov r16, r17
    call LCD_Send_Command
    ret
LCD_Move_Cursor_Second:
    cpi r16, 1
    brne LCD_Move_Cursor_Exit
    andi r17, 0x0F
    ori r17, 0xC0
    mov r16, r17
    call LCD_Send_Command
LCD_Move_Cursor_Exit:
    ret

LCD_Send_String:; in ch? t? ??a ch? trong ZH ZL
    push ZH
    push ZL
    push R16
    lsl ZL
    rol ZH
LCD_Send_String_01:
    lpm R16, Z+
    cpi R16, 0
    breq LCD_Send_String_02
    call LCD_Send_Data
    rjmp LCD_Send_String_01
LCD_Send_String_02:
    pop R16
    pop ZL
    pop ZH
    ret

LCD_Send_Command:; g?i l?nh
    push r17
    call LCD_wait_busy
    mov r17, r16
    andi r17, 0xF0
    out LCDPORT, r17
    nop
    nop
    sbi LCDPORT, LCD_EN
    nop
    nop
    cbi LCDPORT, LCD_EN
    call delay_40us
    swap r16
    andi r16, 0xF0
    out LCDPORT, r16
    sbi LCDPORT, LCD_EN
    nop
    nop
    cbi LCDPORT, LCD_EN
    call delay_40us
    pop r17
    ret

LCD_Send_Data: ;in ra d? li?u trong R16
    push r17
    call LCD_wait_busy
    mov r17, r16
    andi r17, 0xF0
    ori r17, 0x01
    out LCDPORT, r17
    nop
    sbi LCDPORT, LCD_EN
    nop
    cbi LCDPORT, LCD_EN
    call delay_40us
    swap r16
    andi r16, 0xF0
    ori r16, 0x01
    out LCDPORT, r16
    nop
    sbi LCDPORT, LCD_EN
    nop
    cbi LCDPORT, LCD_EN
    call delay_40us
    pop r17
    ret

LCD_wait_busy:
    push r16
    ldi r16, 0b00000111
    out LCDPORTDIR, r16
    ldi r16, 0b11110010
    out LCDPORT, r16
    nop
LCD_wait_busy_loop:
    sbi LCDPORT, LCD_EN
    nop
    nop
    in r16, LCDPORTPIN
    cbi LCDPORT, LCD_EN
    nop
    sbi LCDPORT, LCD_EN
    nop
    nop
    cbi LCDPORT, LCD_EN
    nop
    andi r16, 0x80
    cpi r16, 0x80
    breq LCD_wait_busy_loop
    ldi r16, 0b11110111
    out LCDPORTDIR, r16
    ldi r16, 0b00000000
    out LCDPORT, r16
    pop r16
    ret

/*
********************************************
*            Hàm delay                     *
********************************************
*/
delay_40us:
	push r16
	LDI r16,80
	LP_40us:
		NOP
	DEC R16
	BRNE LP_40us
	pop r16
	ret


delay_10ms:
	push r16
	LDI r16,250
	LP_10ms:
		call delay_40us
	DEC R16
	BRNE LP_10ms
	pop r16
	ret

/*
********************************************
*         Hàm chia 16bit cho 16 bit        *
********************************************
*/
.DEF ANSL = R6 ;To hold low-byte of answer
.DEF ANSH = R7 ;To hold high-byte of answer
.DEF REML = R8 ;To hold low-byte of remainder
.DEF REMH = R9 ;To hold high-byte of remainder
.DEF AL = R16;To hold low-byte of dividend
.DEF AH = R17 ;To hold high-byte of dividend
.DEF BL = R18 ;To hold low-byte of divisor
.DEF BH = R19 ;To hold high-byte of divisor
.DEF C = R20 ;Bit Counter

DIV1616:
    MOVW ANSH:ANSL, AH:AL   ; Copy dividend into answer (quotient)
    CLR   REML              ; Clear remainder
    CLR   REMH
    LDI   C, 17             ; Load bit counter (16 + 1)

DIV1616_LOOP:
    ROL   ANSL              ; Shift quotient left (bring in carry)
    ROL   ANSH
    DEC   C
    BREQ  DIV1616_DONE      ; If all bits shifted, we're done
    ROL   REML              ; Shift remainder left
    ROL   REMH
    SUB   REML, BL          ; Try subtracting divisor
    SBC   REMH, BH
    BRCC  DIV1616_KEEP      ; If result >= 0, keep subtraction
    ADD   REML, BL          ; Else restore remainder
    ADC   REMH, BH
    CLC                     ; Clear Carry = 0 ? bit 0 shifted into quotient
    RJMP  DIV1616_LOOP

DIV1616_KEEP:
    SEC                     ; Set Carry = 1 ? bit 1 shifted into quotient
    RJMP  DIV1616_LOOP

DIV1616_DONE:
    RET