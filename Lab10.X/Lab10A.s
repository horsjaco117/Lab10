;=====================================================================
; LAB 10 ? EEPROM Keypad Logger with 'S' Flash & RB7 Start
; Jacob Horsley ? RCET ? Fifth Semester
; Git: https://github.com/horsjaco117/Lab10
;Lab 10 EEPROM
;=====================================================================
#include <xc.inc>
;---------------------------------------------------------------------
; Variables (Bank 0)
;---------------------------------------------------------------------
PSECT udata_bank0
_ADDRESS: DS 1 ; EEPROM address to read from or write to
_DATA: DS 1 ; Data to write to EEPROM
POSITION: DS 1 ; 0?9 write pointer for tracking stored key count
TEMP: DS 1 ; Delay temp + saved row value during key scanning
TEMP2: DS 1 ; Delay temp2 for longer delays
SAVE_W: DS 1 ; ISR context save for W register
SAVE_STATUS: DS 1 ; ISR context save for STATUS register
DUMP_GIE_SAVE: DS 1 ; Save GIE during dump operation
STATE: DS 1 ; 0 = flash S, 1 = keyscan mode selector
STOP: DS 1 ;FOR THE STOPPING OF WRITING to EEPROM
;---------------------------------------------------------------------
; Reset & Interrupt vectors
;---------------------------------------------------------------------
PSECT resetVect, class=CODE, delta=2
    GOTO Start ; Jump to the start of the program on reset
PSECT isrVect, class=CODE, delta=2
    GOTO INTERRUPT ; Jump to interrupt service routine on interrupt
;---------------------------------------------------------------------
; Code section
;---------------------------------------------------------------------
PSECT code, class=CODE, delta=2
;=====================================================================
; INITIALISATION
;=====================================================================
Start:
    ;--- Bank 1 -------------------------------------------------------
    BSF STATUS,5 ; Select Bank 1
    BCF STATUS,6 ; Ensure Bank 1 is selected (RP1=0, RP0=1)
    MOVLW 0xFF ; Load 0xFF into W
    MOVWF TRISB ; Set PORTB as all inputs
    CLRF TRISA ; Set PORTA as all outputs
    CLRF TRISC ; Set PORTC as all outputs
    MOVLW 0xFF ; Load 0xFF into W
    MOVWF WPUB ; Enable weak pull-ups on PORTB
    MOVLW 0x30 ; Load 0x30 into W (for RB5 and RB4 interrupts)
    MOVWF IOCB ; Enable interrupt-on-change for RB5 and RB4
    CLRF OPTION_REG ; Clear OPTION_REG (enables pull-ups, sets prescaler)
    CLRF PSTRCON ; Clear parallel slave port control
    ;--- Bank 3 -------------------------------------------------------
    BSF STATUS,6 ; Select Bank 3 (RP1=1, RP0=1)
    CLRF ANSEL ; Disable analog inputs on PORTA
    CLRF ANSELH ; Disable analog inputs on PORTB
    ;--- Bank 2 -------------------------------------------------------
    BCF STATUS,5 ; Select Bank 2 (RP1=1, RP0=0)
    CLRF CM2CON1 ; Disable comparator module 2
    ;--- Bank 0 -------------------------------------------------------
    BCF STATUS,6 ; Select Bank 0 (RP1=0, RP0=0)
    CLRF PORTA ; Clear PORTA outputs
    CLRF PORTB ; Clear PORTB outputs
    CLRF PORTC ; Clear PORTC outputs
    CLRF CCP1CON ; Disable CCP1 module
    CLRF CCP2CON ; Disable CCP2 module
    CLRF RCSTA ; Disable serial port receiver
    CLRF SSPCON ; Disable synchronous serial port
    CLRF T1CON ; Disable Timer1
    MOVLW 0x88 ; Load 0x88 into W (enable GIE and RBIE)
    MOVWF INTCON ; Enable global and PORTB change interrupts
    ;--- Initialise variables -----------------------------------------
    CLRF _ADDRESS ; Clear EEPROM address
    CLRF _DATA ; Clear data to write
    MOVLW 0X0A ; Load 10 into W
    MOVWF POSITION ; Set initial position to 10 (beyond 0-9 range)
    CLRF STATE ; start in flash-S mode (STATE=0)
;=====================================================================
; MAIN LOOP
;=====================================================================
MAINLOOP:
    BTFSC STATE,0 ; Test if STATE bit 0 is set (keyscan mode)
    GOTO KEYSCAN_MODE ; If set, go to keyscan mode
    GOTO FLASH_S_MODE ; Otherwise, go to flash S mode
;=====================================================================
; FLASH ?S? MODE ? wait for RB7 press
;=====================================================================
FLASH_S_MODE:
    MOVLW 0x20 ; space (off) ASCII code
    MOVWF PORTC ; Display space on 7-segment (turn off)
    CALL DELAY_LONG ; Call long delay
    MOVLW 0x53 ; 'S' ASCII code
    MOVWF PORTC ; Display 'S' on 7-segment
    CALL DELAY_LONG ; Call long delay
    BTFSC PORTB,7 ; Test if RB7 is pressed (0=pressed)
    GOTO FLASH_S_MODE ; If not pressed, continue flashing
    CALL DELAY ; Debounce delay
    BTFSC PORTB,7 ; Check again if RB7 is still pressed
    GOTO FLASH_S_MODE ; If not, continue flashing
    BSF STATE,0 ; Set STATE to 1 (enter keyscan mode)
    CLRF POSITION ; Reset position to 0
    GOTO MAINLOOP ; Return to main loop
;=====================================================================
; KEYSCAN MODE
;=====================================================================
KEYSCAN_MODE:
    BCF PORTA,5 ; Clear RA5 (possibly for LED or indicator)
    ;--- Row 3 --------------------------------------------------------
    MOVLW 0x06 ; Row 3 select value
    MOVWF PORTA ; Select row 3 on PORTA
    MOVWF TEMP ; Save row value in TEMP
    CALL DELAY ; Delay for settling
    BTFSS PORTB,3 ; Check column 3 (RB3)
    GOTO DISP_9 ; If pressed, handle '9'
    BTFSS PORTB,2 ; Check column 2 (RB2)
    GOTO DISP_8 ; If pressed, handle '8'
    BTFSS PORTB,1 ; Check column 1 (RB1)
    GOTO DISP_7 ; If pressed, handle '7'
    BTFSS PORTB,0 ; Check column 0 (RB0)
    GOTO DISP_C ; If pressed, handle 'C'
   
    ;--- Row 2 --------------------------------------------------------
    MOVLW 0x05 ; Row 2 select value
    MOVWF PORTA ; Select row 2 on PORTA
    MOVWF TEMP ; Save row value in TEMP
    CALL DELAY ; Delay for settling
    BTFSS PORTB,3 ; Check column 3
    GOTO DISP_6 ; If pressed, handle '6'
    BTFSS PORTB,2 ; Check column 2
    GOTO DISP_5 ; If pressed, handle '5'
    BTFSS PORTB,1 ; Check column 1
    GOTO DISP_4 ; If pressed, handle '4'
    BTFSS PORTB,0 ; Check column 0
    GOTO DISP_B ; If pressed, handle 'B'
    ;--- Row 1 --------------------------------------------------------
    MOVLW 0x03 ; Row 1 select value
    MOVWF PORTA ; Select row 1 on PORTA
    MOVWF TEMP ; Save row value in TEMP
    CALL DELAY ; Delay for settling
    BTFSS PORTB,3 ; Check column 3
    GOTO DISP_3 ; If pressed, handle '3'
    BTFSS PORTB,2 ; Check column 2
    GOTO DISP_2 ; If pressed, handle '2'
    BTFSS PORTB,1 ; Check column 1
    GOTO DISP_1 ; If pressed, handle '1'
    BTFSS PORTB,0 ; Check column 0
    GOTO DISP_A ; If pressed, handle 'A'
   
    BTFSC STOP, 1 ; Check if STOP bit 1 is set
    GOTO DISP_S ; If set, handle 'S'
    GOTO KEYSCAN_MODE ; No key pressed, loop back
;=====================================================================
; KEY HANDLERS ? One per key
;=====================================================================
DISP_1:
    MOVLW 0x31 ; ASCII '1'
    GOTO HANDLE_KEY ; Go to key handler
DISP_2:
    MOVLW 0x32 ; ASCII '2'
    GOTO HANDLE_KEY ; Go to key handler
DISP_3:
    MOVLW 0x33 ; ASCII '3'
    GOTO HANDLE_KEY ; Go to key handler
DISP_4:
    MOVLW 0x34 ; ASCII '4'
    GOTO HANDLE_KEY ; Go to key handler
DISP_5:
    MOVLW 0x35 ; ASCII '5'
    GOTO HANDLE_KEY ; Go to key handler
DISP_6:
    MOVLW 0x36 ; ASCII '6'
    GOTO HANDLE_KEY ; Go to key handler
DISP_7:
    MOVLW 0x37 ; ASCII '7'
    GOTO HANDLE_KEY ; Go to key handler
DISP_8:
    MOVLW 0x38 ; ASCII '8'
    GOTO HANDLE_KEY ; Go to key handler
DISP_9:
    MOVLW 0x39 ; ASCII '9'
    GOTO HANDLE_KEY ; Go to key handler
   
DISP_A: MOVLW 0x0A ; Code for 'A'
           GOTO HANDLE_KEY ; Go to key handler
DISP_B: MOVLW 0x0B ; Code for 'B'
           GOTO HANDLE_KEY ; Go to key handler
DISP_C: MOVLW 0x0C ; Code for 'C'
           GOTO HANDLE_KEY ; Go to key handler
DISP_D: MOVLW 0x0D ; Code for 'D' (though not used in scan, included)
           GOTO HANDLE_KEY ; Go to key handler
   
DISP_S:
    CLRF STOP ; Clear STOP register
    MOVLW 0X53 ; ASCII 'S'
    GOTO HANDLE_KEY ; Go to key handler
;=====================================================================
; HANDLE_KEY ? Write once, wait for release
;=====================================================================
HANDLE_KEY:
    MOVWF _DATA ; Store key value in _DATA
    MOVF POSITION,W ; Load current position
    MOVWF _ADDRESS ; Set EEPROM address to position
    CALL WRITE_EEPROM ; Write data to EEPROM
    CALL READ_EEPROM ; Read back and display on PORTC
    INCF POSITION,F ; Increment position
    MOVF POSITION,W ; Load position
    XORLW 0x0A ; Compare to 10
    BTFSS STATUS,2 ; If not 10, skip
    GOTO NO_DUMP2 ; Continue without dump
    CALL DUMP ; Dump contents if 10 keys stored
    BCF STATE,0 ; Reset to flash S mode
    GOTO MAINLOOP ; Return to main loop
NO_DUMP2:
; CLRF STOP ; Commented: Clear STOP
    CALL WAIT_KEY_RELEASE ; Wait for key release (debounce)
    GOTO MAINLOOP ; Return to main loop
;=====================================================================
; WAIT_KEY_RELEASE ? Wait until key is released
;=====================================================================
WAIT_KEY_RELEASE:
    CALL DELAY ; Initial debounce delay
RELEASE_LOOP:
    MOVF TEMP,W ; Restore saved row
    MOVWF PORTA ; Re-select row
    CALL DELAY ; Delay for settling
    MOVF PORTB,W ; Read PORTB
    ANDLW 0x0E ; Mask RB1,RB2,RB3 (columns)
    XORLW 0x0E ; Check if all high (no press)
    BTFSS STATUS,2 ; If not all high, loop
    GOTO RELEASE_LOOP ; Continue waiting
    CALL DELAY ; Final debounce
    RETURN ; Return when released
;=====================================================================
; WRITE_EEPROM
;=====================================================================
WRITE_EEPROM:
    MOVF _ADDRESS,W ; Load address
    BCF STATUS,5 ; Select Bank 2 for EEADR
    BSF STATUS,6 ; RP1=1, RP0=0 (Bank 2)
    MOVWF EEADR ; Set EEPROM address
    BCF STATUS,5 ; Select Bank 0 for _DATA
    BCF STATUS,6 ; Bank 0
    MOVF _DATA,W ; Load data
    BCF STATUS,5 ; Select Bank 2 for EEDATA
    BSF STATUS,6 ; Bank 2
    MOVWF EEDATA ; Set EEPROM data
    BSF STATUS,5 ; Select Bank 3 for EECON1
    BSF STATUS,6 ; Bank 3 (RP1=1, RP0=1)
    BCF EECON1,7 ; Select data EEPROM
    BSF EECON1,2 ; Enable write
    BCF INTCON,7 ; Disable global interrupts
    MOVLW 0x55 ; Write sequence 1
    MOVWF EECON2 ;
    MOVLW 0xAA ; Write sequence 2
    MOVWF EECON2 ;
    BSF EECON1,1 ; Start write
    BSF INTCON,7 ; Re-enable global interrupts
    NOP ; No operation
WRITE_POLL:
    BTFSC EECON1,1 ; Poll for write complete
    GOTO WRITE_POLL ; Wait if not done
    BCF EECON1,2 ; Disable write
    BCF STATUS,5 ; Return to Bank 0
    BCF STATUS,6 ;
    RETURN ; Return after write
;=====================================================================
; READ_EEPROM
;=====================================================================
READ_EEPROM:
    MOVF _ADDRESS,W ; Load address
    BCF STATUS,5 ; Select Bank 2
    BSF STATUS,6 ;
    MOVWF EEADR ; Set EEPROM address
    BSF STATUS,5 ; Select Bank 3
    BSF STATUS,6 ;
    BSF EECON1,0 ; Start read
    BCF STATUS,5 ; Select Bank 2
    BSF STATUS,6 ;
    MOVF EEDATA,W ; Read data into W
    BCF STATUS,5 ; Select Bank 0
    BCF STATUS,6 ;
    MOVWF PORTC ; Output to PORTC (7-segment)
    RETURN ; Return after read
;=====================================================================
; DUMP
;=====================================================================
DUMP:
    BSF PORTA,5 ; Set RA5 (possibly indicator LED)
    CLRF DUMP_GIE_SAVE ; Clear GIE save
    BTFSC INTCON,7 ; Check if GIE was set
    BSF DUMP_GIE_SAVE,0 ; Save GIE state
    BCF INTCON,7 ; Disable global interrupts
    CLRF _ADDRESS ; Start from address 0
DUMP_LOOP:
    CALL READ_EEPROM ; Read and display on PORTC
    CALL DELAY_LONG ; Long delay between displays
    INCF _ADDRESS,F ; Increment address
    MOVF _ADDRESS,W ; Load address
    SUBWF POSITION,W ; Compare to position (stored count)
    BTFSS STATUS,2 ; If not equal, continue
    GOTO DUMP_LOOP ; Loop until all dumped
    BCF INTCON,0 ; Clear RBIF
    BTFSC DUMP_GIE_SAVE,0 ; Restore GIE if was set
    BSF INTCON,7 ;
    BCF PORTA,5 ; Clear RA5
    RETURN ; Return after dump
;=====================================================================
; INTERRUPT (optional)
;=====================================================================
INTERRUPT:
    MOVWF SAVE_W ; Save W register
    SWAPF STATUS,W ; Save STATUS (swap to avoid changing flags)
    MOVWF SAVE_STATUS ; Store saved STATUS
   
   ; BTFSS PORTB, 5 ; Commented: Check RB5
   ; GOTO _DUMP ; If clear, go to dump
  ; GOTO _RETURN ; Otherwise return
   ; GOTO _DUMP ; Direct jump to dump (commented)
    _DUMP:
    BCF STATUS,5 ; Select Bank 0
    BCF STATUS,6 ;
    CALL DUMP ; Call dump routine
   
    MOVLW 0X0A ; Load 10
    MOVF _ADDRESS, W ; Move address (redundant?)
    MOVLW 0X0A ; Load 10
    MOVF POSITION, W ; Move position (redundant?)
   
    MOVLW 0XFF ; Load 0xFF
    MOVWF STOP ; Set STOP to 0xFF
   
    BCF INTCON,0 ; Clear RBIF
    GOTO _RETURN ; Go to return
   
    _RETURN:
    MOVLW 0X0A ; Load 10 (redundant?)
    MOVF _ADDRESS, W ; Move address
    MOVLW 0X0A ; Load 10
    MOVF POSITION, W ; Move position
    BCF STATE, 0 ; Reset to flash S mode
    BCF INTCON, 0 ; Clear RBIF
    MOVLW 0X53 ; 'S'
    MOVWF PORTC ; Display 'S'
    SWAPF SAVE_STATUS,W ; Restore STATUS
    MOVWF STATUS ;
    SWAPF SAVE_W,F ; Restore W (swap nibbles)
    SWAPF SAVE_W,W ;
    RETFIE ; Return from interrupt
   
;=====================================================================
; DELAYS
;=====================================================================
DELAY:
    MOVLW 0x80 ; Load counter for short delay
    MOVWF TEMP ; Store in TEMP
DLOOP:
    DECFSZ TEMP,F ; Decrement and skip if zero
    GOTO DLOOP ; Loop until zero
    RETURN ; Return after delay
DELAY_LONG:
    MOVLW 0xFF ; Load outer counter
    MOVWF TEMP2 ; Store in TEMP2
DL_OUTER:
    MOVLW 0xFF ; Load inner counter
    MOVWF TEMP ; Store in TEMP
DL_INNER:
    DECFSZ TEMP,F ; Decrement and skip if zero
    GOTO DL_INNER ; Inner loop
    DECFSZ TEMP2,F ; Decrement outer and skip if zero
    GOTO DL_OUTER ; Outer loop
    RETURN ; Return after long delay
END