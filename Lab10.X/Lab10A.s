;=====================================================================
; LAB 10 ? EEPROM Keypad Logger with 'S' Flash & RB7 Start
; Jacob Horsley ? RCET ? Fifth Semester
; Git: https://github.com/horsjaco117/Lab10
; FINAL VERSION: One write per key press, key release debounce
;=====================================================================

#include <xc.inc>

;---------------------------------------------------------------------
; Variables (Bank 0)
;---------------------------------------------------------------------
PSECT udata_bank0
_ADDRESS:       DS 1   ; EEPROM address
_DATA:          DS 1   ; Data to write
POSITION:       DS 1   ; 0?9 write pointer
TEMP:           DS 1   ; Delay temp + saved row value
TEMP2:          DS 1   ; Delay temp2
SAVE_W:         DS 1   ; ISR context
SAVE_STATUS:    DS 1   ; ISR context
DUMP_GIE_SAVE:  DS 1   ; Save GIE during dump
STATE:          DS 1   ; 0 = flash S, 1 = keyscan

;---------------------------------------------------------------------
; Reset & Interrupt vectors
;---------------------------------------------------------------------
PSECT resetVect, class=CODE, delta=2
    GOTO Start

PSECT isrVect, class=CODE, delta=2
    GOTO INTERRUPT

;---------------------------------------------------------------------
; Code section
;---------------------------------------------------------------------
PSECT code, class=CODE, delta=2

;=====================================================================
; INITIALISATION
;=====================================================================
Start:
    ;--- Bank 1 -------------------------------------------------------
    BSF  STATUS,5
    BCF  STATUS,6
    MOVLW 0xFF
    MOVWF TRISB
    CLRF  TRISA
    CLRF  TRISC
    MOVLW 0xFF
    MOVWF WPUB
    MOVLW 0x30
    MOVWF IOCB
    CLRF  OPTION_REG
    CLRF  PSTRCON

    ;--- Bank 3 -------------------------------------------------------
    BSF  STATUS,6
    CLRF  ANSEL
    CLRF  ANSELH

    ;--- Bank 2 -------------------------------------------------------
    BCF  STATUS,5
    CLRF  CM2CON1

    ;--- Bank 0 -------------------------------------------------------
    BCF  STATUS,6
    CLRF  PORTA
    CLRF  PORTB
    CLRF  PORTC
    CLRF  CCP1CON
    CLRF  CCP2CON
    CLRF  RCSTA
    CLRF  SSPCON
    CLRF  T1CON
    MOVLW 0x88
    MOVWF INTCON

    ;--- Initialise variables -----------------------------------------
    CLRF _ADDRESS
    CLRF _DATA
    MOVLW 0X0A
    MOVWF POSITION
    CLRF STATE             ; start in flash-S mode

;=====================================================================
; MAIN LOOP
;=====================================================================
MAINLOOP:
    BTFSC STATE,0
    GOTO  KEYSCAN_MODE
    GOTO  FLASH_S_MODE

;=====================================================================
; FLASH ?S? MODE ? wait for RB7 press
;=====================================================================
FLASH_S_MODE:
    MOVLW 0x20            ; space (off)
    MOVWF PORTC
    CALL  DELAY_LONG

    MOVLW 0x53            ; 'S'
    MOVWF PORTC
    CALL  DELAY_LONG

    BTFSC PORTB,7
    GOTO  FLASH_S_MODE

    CALL  DELAY
    BTFSC PORTB,7
    GOTO  FLASH_S_MODE

    BSF   STATE,0         ; enter keyscan
    CLRF  POSITION
    GOTO  MAINLOOP

;=====================================================================
; KEYSCAN MODE
;=====================================================================
KEYSCAN_MODE:
    BCF   PORTA,5

    ;--- Row 3 --------------------------------------------------------
    MOVLW 0x06
    MOVWF PORTA
    MOVWF TEMP            ; ? SAVE ROW
    CALL  DELAY
    BTFSS PORTB,3
    GOTO  DISP_9
    BTFSS PORTB,2
    GOTO  DISP_8
    BTFSS PORTB,1
    GOTO  DISP_7

    ;--- Row 2 --------------------------------------------------------
    MOVLW 0x05
    MOVWF PORTA
    MOVWF TEMP            ; ? SAVE ROW
    CALL  DELAY
    BTFSS PORTB,3
    GOTO  DISP_6
    BTFSS PORTB,2
    GOTO  DISP_5
    BTFSS PORTB,1
    GOTO  DISP_4

    ;--- Row 1 --------------------------------------------------------
    MOVLW 0x03
    MOVWF PORTA
    MOVWF TEMP            ; ? SAVE ROW
    CALL  DELAY
    BTFSS PORTB,3
    GOTO  DISP_3
    BTFSS PORTB,2
    GOTO  DISP_2
    BTFSS PORTB,1
    GOTO  DISP_1

    GOTO  KEYSCAN_MODE

;=====================================================================
; KEY HANDLERS ? One per key
;=====================================================================
DISP_1:
    MOVLW 0x31
    GOTO  HANDLE_KEY

DISP_2:
    MOVLW 0x32
    GOTO  HANDLE_KEY

DISP_3:
    MOVLW 0x33
    GOTO  HANDLE_KEY

DISP_4:
    MOVLW 0x34
    GOTO  HANDLE_KEY

DISP_5:
    MOVLW 0x35
    GOTO  HANDLE_KEY

DISP_6:
    MOVLW 0x36
    GOTO  HANDLE_KEY

DISP_7:
    MOVLW 0x37
    GOTO  HANDLE_KEY

DISP_8:
    MOVLW 0x38
    GOTO  HANDLE_KEY

DISP_9:
    MOVLW 0x39
    GOTO  HANDLE_KEY

;=====================================================================
; HANDLE_KEY ? Write once, wait for release
;=====================================================================
HANDLE_KEY:
    MOVWF _DATA
    MOVF  POSITION,W
    MOVWF _ADDRESS
    CALL  WRITE_EEPROM
    CALL  READ_EEPROM

    INCF  POSITION,F

    MOVF  POSITION,W
    XORLW 0x0A
    BTFSS STATUS,2
    GOTO  NO_DUMP2

    CALL  DUMP
    BCF   STATE,0
    GOTO  MAINLOOP

NO_DUMP2:
    CALL  WAIT_KEY_RELEASE
    GOTO  MAINLOOP

;=====================================================================
; WAIT_KEY_RELEASE ? Wait until key is released
;=====================================================================
WAIT_KEY_RELEASE:
    CALL  DELAY

RELEASE_LOOP:
    MOVF  TEMP,W          ; restore saved row
    MOVWF PORTA
    CALL  DELAY
    MOVF  PORTB,W
    ANDLW 0x0E            ; mask RB1,RB2,RB3
    XORLW 0x0E            ; all high ? 0
    BTFSS STATUS,2
    GOTO  RELEASE_LOOP

    CALL  DELAY
    RETURN

;=====================================================================
; WRITE_EEPROM
;=====================================================================
WRITE_EEPROM:
    MOVF  _ADDRESS,W
    BCF   STATUS,5
    BSF   STATUS,6
    MOVWF EEADR
    BCF   STATUS,5
    BCF   STATUS,6

    MOVF  _DATA,W
    BCF   STATUS,5
    BSF   STATUS,6
    MOVWF EEDATA
    BSF   STATUS,5
    BSF   STATUS,6

    BCF   EECON1,7
    BSF   EECON1,2
    BCF   INTCON,7
    MOVLW 0x55
    MOVWF EECON2
    MOVLW 0xAA
    MOVWF EECON2
    BSF   EECON1,1
    BSF   INTCON,7
    NOP
WRITE_POLL:
    BTFSC EECON1,1
    GOTO  WRITE_POLL
    BCF   EECON1,2
    BCF   STATUS,5
    BCF   STATUS,6
    RETURN

;=====================================================================
; READ_EEPROM
;=====================================================================
READ_EEPROM:
    MOVF  _ADDRESS,W
    BCF   STATUS,5
    BSF   STATUS,6
    MOVWF EEADR
    BSF   STATUS,5
    BSF   STATUS,6
    BSF   EECON1,0
    BCF   STATUS,5
    BSF   STATUS,6
    MOVF  EEDATA,W
    BCF   STATUS,5
    BCF   STATUS,6
    MOVWF PORTC
    RETURN

;=====================================================================
; DUMP
;=====================================================================
DUMP:
    BSF   PORTA,5
    CLRF  DUMP_GIE_SAVE
    BTFSC INTCON,7
    BSF   DUMP_GIE_SAVE,0
    BCF   INTCON,7

    CLRF  _ADDRESS
DUMP_LOOP:
    CALL  READ_EEPROM
    CALL  DELAY_LONG
    INCF  _ADDRESS,F
    MOVF  _ADDRESS,W
    SUBWF POSITION,W
    BTFSS STATUS,2
    GOTO  DUMP_LOOP

    BCF   INTCON,0
    BTFSC DUMP_GIE_SAVE,0
    BSF   INTCON,7
    BCF   PORTA,5
    RETURN

;=====================================================================
; INTERRUPT (optional)
;=====================================================================
INTERRUPT:
    MOVWF SAVE_W
    SWAPF STATUS,W
    MOVWF SAVE_STATUS
    BCF   STATUS,5
    BCF   STATUS,6
    CALL  DUMP
    BCF   INTCON,0
    SWAPF SAVE_STATUS,W
    MOVWF STATUS
    SWAPF SAVE_W,F
    SWAPF SAVE_W,W
    RETFIE

;=====================================================================
; DELAYS
;=====================================================================
DELAY:
    MOVLW 0x80
    MOVWF TEMP
DLOOP:
    DECFSZ TEMP,F
    GOTO   DLOOP
    RETURN

DELAY_LONG:
    MOVLW 0xFF
    MOVWF TEMP2
DL_OUTER:
    MOVLW 0xFF
    MOVWF TEMP
DL_INNER:
    DECFSZ TEMP,F
    GOTO   DL_INNER
    DECFSZ TEMP2,F
    GOTO   DL_OUTER
    RETURN

END