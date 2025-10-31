;lAB 3
;Jacob Horsley
;RCET
;Fifth Semester
;Program/Project
;Git URL
    

    
;Device Setup
;--------------------------------------------------------------------------
;Configuration
    ; CONFIG1
  CONFIG  FOSC = XT   ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
;Include Statements
#include <xc.inc>


    
;Code Section
;--------------------------------------------------------------------------
    
; Start of Program
; Reset vector address
    PSECT resetVect, class=CODE, delta=2
    GOTO Start
; Interrupt vector
    PSECT isrVect, class=CODE, delta=2
    GOTO INTERRUPT
; Setup Code
    PSECT code, class=CODE, delta=2
Start:      
 
Setup:

;Bank 3
BSF STATUS, 5 	; Go to Bank 3
BSF STATUS, 6	 ; Go to Bank 3
MOVLW 0X0F	 ;Bits all 1's to set port B as inputs
MOVWF TRISB	 ;Sets all TRISB to 0
CLRF ANSELH	 ; Sets pin function, Digital I/O
CLRF INTCON	;Controls interupts, which are needed for output
CLRF OPTION_REG ;Move w to address 0x81

;Bank 2
BSF STATUS, 6 ;Go to Bank 2
BCF STATUS, 5 ; Go to Bank 2
CLRF CM2CON1  ; Set all bits to 0

;Bank 1
BSF STATUS, 5 ;Sets bit 5 for bank 1
BCF STATUS, 6 ;Clears bit 6 to access bank 1
MOVLW 0XFF    ;Enables all pull up resistors on port B
MOVWF WPUB;  weak pullups
CLRF IOCB; Disables interruption change B
CLRF PSTRCON ;Disables PWM
CLRF TRISC   ;Sets port c as an output
MOVWF TRISA ; Now correctly write to TRISA
MOVLW 0x0F
    
;BANK 0
BCF STATUS, 5 ;Clears bit 5 to acces bank 0
BCF STATUS, 6 ;Clears bit 6 to access bank 0
CLRF CCP1CON  ;Disables the other PWM module
CLRF PORTC    ;Clears the port c register
CLRF PORTA
CLRF CCP2CON  ;Disables the second PWM function
CLRF PORTB    ;Clears the bits in portB
CLRF RCSTA    ;Turns of the Control register
CLRF SSPCON   ;Turns off the serial control port
CLRF T1CON    ;Turns off timer control register
 BSF PIE1, 0 ;CUSTOM INTERRUPT
MOVLW 0XC0
MOVWF INTCON
;Main Program Loop (Loops forever)

SUB:
MOVWF PORTC	;Move W to F (PortC) 
        
MAINLOOP:

TESTLOOP:
    BTFSS PORTA, 1
    GOTO BUTTON_PRESSED
    BCF PORTA, 5 ;IF BUTTON ISN'T PRESSED CLEAR LIGHT
BUTTON_PRESSED:
   
    BSF PIR1, 0
     ; Scan Row 3 (keys 7,8,9) - RB4=1, RB5=1, RB6=0
    MOVLW 0x60
    MOVWF PORTB
    
SCAN:
; CALL DELAY
    BTFSS PORTB,3 ; Key 7
    GOTO DISP_9
    BTFSS PORTB,2 ; Key 8
    GOTO DISP_8
    BTFSS PORTB,1 ; Key 9
    GOTO DISP_7
    
     
    
    ; Scan Row 2 (keys 4,5,6) - RB4=1, RB5=0, RB6=1
    MOVLW 0x50
    MOVWF PORTB
; CALL DELAY
    BTFSS PORTB,3 ; Key 4
    GOTO DISP_6
    BTFSS PORTB,2 ; Key 5
    GOTO DISP_5
    BTFSS PORTB,1 ; Key 6
    GOTO DISP_4
    
   ; Scan Row 1 (keys 1,2,3) - RB4=0, RB5=1, RB6=1
    MOVLW 0x30
    MOVWF PORTB ; Debounce
    BTFSS PORTB,3 ; Key 1 (RB1=0)
    GOTO DISP_3
    BTFSS PORTB,2 ; Key 2
    GOTO DISP_2
    BTFSS PORTB,1 ; Key 3
    GOTO DISP_1
    
    
    GOTO DISP_0 ; **Change: Jump to DISP_0 instead of MAINLOOP**

;53 SHOWS AN S
;20 APPEARS AS BLANK
    
    
DISP_0: MOVLW 0X53
	GOTO DISPLAY
DISP_1: MOVLW 0x20 ; 1
        GOTO DISPLAY
DISP_2: MOVLW 0x32 ; 2
        GOTO DISPLAY
DISP_3: MOVLW 0x33 ; 3
        GOTO DISPLAY
DISP_4: MOVLW 0x34 ; 4 (if 0x04 shows 9, use 0x04 for 9, adjust others)
        GOTO DISPLAY
DISP_5: MOVLW 0x35 ; 5
        GOTO DISPLAY
DISP_6: MOVLW 0x36 ; 6
        GOTO DISPLAY
DISP_7: MOVLW 0x37 ; 7
        GOTO DISPLAY
DISP_8: MOVLW 0x38 ; 8
        GOTO DISPLAY
DISP_9: MOVLW 0x39 ; 9
        GOTO DISPLAY

DISPLAY:
    MOVWF PORTC
;    CALL DELAY      ; Stabilize output
    GOTO MAINLOOP

INTERRUPT:
LIGHT:
    BSF PORTA, 5
  
    RETFIE

END ;End of code. This is required