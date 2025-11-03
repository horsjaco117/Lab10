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
 
;Bank 1 - Set TRIS, pullups, etc.
BSF STATUS, 5   ; Set RP0=1
BCF STATUS, 6   ; Clear RP1=0, now bank 1
MOVLW 0xFF      ; For TRISB: bits 3-0 input, 7-4 output
MOVWF TRISB     ; Set TRISB (address 0x086)
CLRF TRISA      ; Set TRISA=0x00, all PORTA outputs (adjust if some inputs needed)
CLRF TRISC      ; PORTC all outputs
MOVLW 0xFF      ; Enable pullups on PORTB
MOVWF WPUB      ; WPUB (0x095)
MOVLW 0X30
MOVWF IOCB       ; Disable interrupt on change B (0x096)
CLRF OPTION_REG ; Clear OPTION_REG (0x081), e.g., for prescaler
CLRF PSTRCON    ; Disable PWM if needed
MOVLW 0X10
MOVWF PIE2
;Bank 3 - Clear analog selects
BSF STATUS, 5   ; RP0=1
BSF STATUS, 6   ; RP1=1, now bank 3
CLRF ANSEL      ; Clear ANSEL (0x188), make PORTA digital
CLRF ANSELH     ; Clear ANSELH (0x189), make PORTB digital
MOVLW 0X00
MOVWF EECON1
;Bank 2 - Comparator setup if needed
BCF STATUS, 5   ; RP0=0
BSF STATUS, 6   ; RP1=1, now bank 2
CLRF CM2CON1    ; Clear comparator
;Bank 0 - Clear ports, disable modules
BCF STATUS, 5   ; RP0=0
BCF STATUS, 6   ; RP1=0, bank 0
CLRF PORTA      ; Clear PORTA
CLRF PORTB      ; Clear PORTB
CLRF PORTC      ; Clear PORTC
CLRF CCP1CON    ; Disable PWM1
CLRF CCP2CON    ; Disable PWM2
CLRF RCSTA      ; Disable USART
CLRF SSPCON     ; Disable SSP
CLRF T1CON      ; Disable Timer1
BSF PIE1, 0     ; Enable custom peripheral interrupt if needed
CLRF PIR2
;BCF INTCON, 0
;BSF INTCON, 4
MOVLW 0x88      ; GIE=1, PEIE=1
MOVWF INTCON    ; Enable interrupts

;Main Program Loop (Loops forever)

SUB:
MOVWF PORTC	;Move W to F (PortC) 
        
MAINLOOP:

BCF PORTA, 5
    
;TESTLOOP:
;    BTFSS PORTA, 1
;    GOTO BUTTON_PRESSED
;    BCF PORTA, 5 ;IF BUTTON ISN'T PRESSED CLEAR LIGHT
;BUTTON_PRESSED:
;   
;    BSF PIR1, 0
;     ; Scan Row 3 (keys 7,8,9) - RB4=1, RB5=1, RB6=0
    MOVLW 0x06
    MOVWF PORTA
 ;   MOVLW 0x60
 ;   MOVWF PORTB
    
;SCAN:
; CALL DELAY
    BTFSS PORTB,3 ; Key 7
    GOTO DISP_9
    BTFSS PORTB,2 ; Key 8
    GOTO DISP_8
    BTFSS PORTB,1 ; Key 9
    GOTO DISP_7
    
     
    
    ; Scan Row 2 (keys 4,5,6) - RB4=1, RB5=0, RB6=1
    MOVLW 0x05
    MOVWF PORTA
   ; MOVLW 0x50
   ; MOVWF PORTB
; CALL DELAY
    BTFSS PORTB,3 ; Key 4
    GOTO DISP_6
    BTFSS PORTB,2 ; Key 5
    GOTO DISP_5
    BTFSS PORTB,1 ; Key 6
    GOTO DISP_4
    
   ; Scan Row 1 (keys 1,2,3) - RB4=0, RB5=1, RB6=1
																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																																    MOVLW 0x03
    MOVWF PORTA ; Debounce
   ; MOVLW 0x30
    ;MOVWF PORTB
    
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
  
  ;  BCF PORTA, 5
    
    BCF INTCON, 0
    RETFIE

END ;End of code. This is required