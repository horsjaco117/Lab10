; LAB 3
; Jacob Horsley
; RCET
; Fifth Semester
; Program/Project
; Git URL
   
   
; Device Setup
;--------------------------------------------------------------------------
; Configuration
    ; CONFIG1
  CONFIG FOSC = XT ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG WDTE = OFF ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG PWRTE = OFF ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG MCLRE = ON ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG CP = OFF ; Code Protection bit (Program memory code protection is disabled)
  CONFIG CPD = OFF ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG BOREN = OFF ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG IESO = OFF ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG FCMEN = OFF ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG LVP = OFF ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)
; CONFIG2
  CONFIG BOR4V = BOR40V ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG WRT = OFF ; Flash Program Memory Self Write Enable bits (Write protection off)
// config statements should precede project file includes.
; Include Statements
#include <xc.inc>
   
; Code Section
;--------------------------------------------------------------------------
   
; Variables
    PSECT udata_bank0
_ADDRESS: DS 1 ; Address variable
_DATA: DS 1    ; Data variable
POSITION: DS 1 ; Current position for sequential write
TEMP: DS 1     ; Delay temp
TEMP2: DS 1    ; Delay temp2
SAVE_W: DS 1   ; Interrupt save W
SAVE_STATUS: DS 1 ; Interrupt save STATUS
DUMP_GIE_SAVE: DS 1 ; Save GIE for dump
   
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
; Bank 1 - Set TRIS, pullups, etc.
    BSF STATUS, 5 ; Set RP0=1
    BCF STATUS, 6 ; Clear RP1=0, now bank 1
    MOVLW 0xFF ; For TRISB: all inputs
    MOVWF TRISB ; Set TRISB (0x086)
    CLRF TRISA ; All PORTA outputs
    CLRF TRISC ; All PORTC outputs
    MOVLW 0xFF ; Enable pullups on PORTB
    MOVWF WPUB ; WPUB (0x095)
    MOVLW 0x30 ; Enable IOC on B4,B5
    MOVWF IOCB ; IOCB (0x096)
    CLRF OPTION_REG ; Pullups enabled, prescaler etc.
    CLRF PSTRCON ; Disable PWM
; Bank 3 - Clear analog selects
    BSF STATUS, 6 ; RP1=1, now bank 3
    CLRF ANSEL ; PORTA digital
    CLRF ANSELH ; PORTB digital
; Bank 2 - Comparator setup
    BCF STATUS, 5 ; RP0=0, RP1=1, bank 2
    CLRF CM2CON1 ; Clear comparator
; Bank 0 - Clear ports, disable modules
    BCF STATUS, 6 ; Bank 0
    CLRF PORTA
    CLRF PORTB
    CLRF PORTC
    CLRF CCP1CON
    CLRF CCP2CON
    CLRF RCSTA
    CLRF SSPCON
    CLRF T1CON ; Timer1 disabled
    BSF PIE1, 0 ; TMR1IE if needed, but timer off
    MOVLW 0x88 ; GIE=1, RBIE=1
    MOVWF INTCON ; Enable interrupts
; Initialize variables
    CLRF _ADDRESS
    CLRF _DATA ; Initial data
    CLRF POSITION
   
; Main Program Loop
MAINLOOP:
   
KEYSCAN:
    BCF PORTA, 5
   
; Scan Row 3 (adjusted for correct key mapping)
    MOVLW 0x06
    MOVWF PORTA
    CALL DELAY ; Debounce delay
    BTFSS PORTB,3 ; Check column
    GOTO DISP_9
    BTFSS PORTB,2
    GOTO DISP_8
    BTFSS PORTB,1
    GOTO DISP_7
   
; Scan Row 2
    MOVLW 0x05
    MOVWF PORTA
    CALL DELAY
    BTFSS PORTB,3
    GOTO DISP_6
    BTFSS PORTB,2
    GOTO DISP_5
    BTFSS PORTB,1
    GOTO DISP_4
   
; Scan Row 1
    MOVLW 0x03
    MOVWF PORTA
    CALL DELAY
    BTFSS PORTB,3
    GOTO DISP_3
    BTFSS PORTB,2
    GOTO DISP_2
    BTFSS PORTB,1
    GOTO DISP_1
   
    GOTO KEYSCAN ; No key, loop without write
   
DISP_0: MOVLW 0x53 ; Unused, but kept for reference
        GOTO DISPLAY
DISP_1: MOVLW 0x31 ; '1'
        GOTO DISPLAY
DISP_2: MOVLW 0x32 ; '2'
        GOTO DISPLAY
DISP_3: MOVLW 0x33 ; '3'
        GOTO DISPLAY
DISP_4: MOVLW 0x34 ; '4'
        GOTO DISPLAY
DISP_5: MOVLW 0x35 ; '5'
        GOTO DISPLAY
DISP_6: MOVLW 0x36 ; '6'
        GOTO DISPLAY
DISP_7: MOVLW 0x37 ; '7'
        GOTO DISPLAY
DISP_8: MOVLW 0x38 ; '8'
        GOTO DISPLAY
DISP_9: MOVLW 0x39 ; '9'
        GOTO DISPLAY
DISPLAY:
    MOVWF _DATA
    MOVF POSITION, W
    MOVWF _ADDRESS
    CALL WRITE_EEPROM
    CALL READ_EEPROM ; Display on PORTC
    INCF POSITION, F ; Next address
    MOVF POSITION, W
    SUBLW 0x09 ; W = 9 - POSITION
    BTFSC STATUS, 0 ; If C=1 (<=9), goto NO_DUMP
    GOTO NO_DUMP
    CALL DUMP ; Dump after 10th write
    CLRF POSITION
NO_DUMP:
    GOTO KEYSCAN
   
WRITE_EEPROM:
    MOVF _ADDRESS, W
    BCF STATUS, 5
    BSF STATUS, 6 ; Bank 2
    MOVWF EEADR
    BCF STATUS, 5
    BCF STATUS, 6 ; Bank 0
    MOVF _DATA, W
    BCF STATUS, 5
    BSF STATUS, 6 ; Bank 2
    MOVWF EEDATA
    BSF STATUS, 5
    BSF STATUS, 6 ; Bank 3
    BCF EECON1, 7 ; EEPM=0
    BSF EECON1, 2 ; WREN=1
    BCF INTCON, 7 ; Disable interrupts for sequence
    MOVLW 0x55
    MOVWF EECON2
    MOVLW 0xAA
    MOVWF EECON2
    BSF EECON1, 1 ; WR=1
    BSF INTCON, 7 ; Re-enable
    NOP
    BTFSC EECON1, 1
    GOTO $-2 ; Poll until WR=0
    BCF EECON1, 2 ; WREN=0
    BCF STATUS, 5
    BCF STATUS, 6 ; Bank 0
    RETURN
   
READ_EEPROM:
    ; Removed unnecessary disable/re-enable
    MOVF _ADDRESS, W
    BCF STATUS, 5
    BSF STATUS, 6 ; Bank 2
    MOVWF EEADR
    BSF STATUS, 5
    BSF STATUS, 6 ; Bank 3
    BSF EECON1, 0 ; RD=1
    BCF STATUS, 5
    BSF STATUS, 6 ; Bank 2
    MOVF EEDATA, W
    BCF STATUS, 5
    BCF STATUS, 6 ; Bank 0
    MOVWF PORTC
    RETURN
   
DUMP:
    BSF PORTA, 5 ; Indicate dump start
    CLRF DUMP_GIE_SAVE
    BTFSC INTCON, 7
    BSF DUMP_GIE_SAVE, 0
    BCF INTCON, 7 ; Disable interrupts
    CLRF _ADDRESS ; Start from 0
DUMP_LOOP:
    CALL READ_EEPROM ; Show on PORTC
    CALL DELAY_LONG ; Wait to view
    INCF _ADDRESS, F
    MOVF _ADDRESS, W
    SUBWF POSITION, W
    BTFSS STATUS, 2 ; If Z=1 (equal), done
    GOTO DUMP_LOOP
    BCF INTCON, 0 ; Clear any pending RBIF
    BTFSC DUMP_GIE_SAVE, 0
    BSF INTCON, 7 ; Restore GIE
    BCF PORTA, 5 ; Off
    RETURN
   
INTERRUPT:
    MOVWF SAVE_W
    SWAPF STATUS, W
    MOVWF SAVE_STATUS
    BCF STATUS, 5
    BCF STATUS, 6 ; Bank 0
    CALL DUMP ; Call dump on interrupt
    BCF INTCON, 0 ; Clear RBIF
    SWAPF SAVE_STATUS, W
    MOVWF STATUS
    SWAPF SAVE_W, F
    SWAPF SAVE_W, W
    RETFIE
   
DELAY: ; Short delay for debounce
    MOVLW 0x80 ; Adjust for timing
    MOVWF TEMP
DLOOP:
    DECFSZ TEMP, F
    GOTO DLOOP
    RETURN
   
DELAY_LONG: ; Longer delay for viewing
    MOVLW 0x8F
    MOVWF TEMP2
DL_OUTER:
    MOVLW 0x8F
    MOVWF TEMP
DL_INNER:
    DECFSZ TEMP, F
    GOTO DL_INNER
    DECFSZ TEMP2, F
    GOTO DL_OUTER
    RETURN
END