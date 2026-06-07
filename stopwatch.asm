;                    708800                     
;                    000007                    
;                    10004                     
;                  5000000047     7            
;             7000000042400000007 7001         
;           700097     |    74000707007       
;         7000                  000771        
;        7001 \        8        / 7007         
;       7007   \       0       /   7007        
;      7002            5            7007       
;      700             1             001           
;      000---         707         ---000       
;      700             0             003     
;       700                         7007        
;        7007    /           \    7001         
;         70007 /             \ 70007          
;           70005      |      10001            
;            7 00000001718000000               
;                 78000000087                  

;------------ Setup Timers ------------
;TIMER 0 (10ms interrupt for stopwatch timekeeping)
T0_G    EQU 0   ; GATE
T0_C    EQU 0   ; COUNTER/-TIMER 
T0_M    EQU 1   ; MODE 1 (16-bit)
TIM0    EQU T0_M+T0_C*4+T0_G*8 

;TIMER 1 (50ms interrupt for 10s sound signal)
T1_G    EQU 0   ; GATE 
T1_C    EQU 0   ; COUNTER/-TIMER 
T1_M    EQU 1   ; MODE 1 (16-bit)
TIM1    EQU T1_M+T1_C*4+T1_G*8 

TMOD_SET    EQU TIM0+TIM1*16

; 10[ms] = 10 000[uS]*(11.0592[MHz]/12) = 9 216 cycles = 36 * 256 
TH0_SET     EQU 256-36
TL0_SET     EQU 0

; 50[ms] = 50 000[uS]*(11.0592[MHz]/12) = 46 080 cycles = 180 * 256
TH1_SET     EQU 256-180
TL1_SET     EQU 0
;---------------------------------------

BUZZ    EQU P1.5 ; Define Buzzer pin (Active Low) 

; Variables in the RAM
SEC_COUNT  EQU 30H ; Seconds counter (0-99)
CS_COUNT   EQU 31H ; Centiseconds counter (0-99)
T1_TICKS   EQU 32H ; Counter for 50ms ticks to reach 10s limit
BEEP_DUR   EQU 33H ; Counter for buzzer ON duration

    LJMP START

    ORG 0BH ; Timer 0 Interrupt Vector
    LJMP TIMER0_ISR

    ORG 1BH ; Timer 1 Interrupt Vector
    LJMP TIMER1_ISR

    ORG 100H ; Jump to the start of the program

START:
    LCALL LCD_INIT 
    LCALL LCD_CLR 
    
    ; Setup TMOD mode for both timers
    MOV TMOD, #TMOD_SET
    
    ; Setup initial timer values
    MOV TH0, #TH0_SET
    MOV TL0, #TL0_SET
    MOV TH1, #TH1_SET
    MOV TL1, #TL1_SET
    
    ; Initialize variables to 0
    MOV SEC_COUNT, #0
    MOV CS_COUNT, #0
    MOV T1_TICKS, #0
    MOV BEEP_DUR, #0
    
    SETB BUZZ ; Turn off the Buzzer
    
    SETB EA  ; Global interrupt enable
    SETB ET0 ; Enable Timer 0 interrupt
    SETB ET1 ; Enable Timer 1 interrupt
    
    LCALL DISPLAY_TIME ; Show "00,00" on the LCD

MAIN_LOOP:
    LCALL WAIT_KEY
    
    ; Check if button 'A' (10) was pressed to start/pause the stopwatch
    CJNE A, #10, CHECK_RESET
    
    ; Toggle the running state based on TR0 flag
    JNB TR0, START_TIMERS
    
STOP_TIMERS:
    CLR TR0
    CLR TR1
    SETB BUZZ ; Turn off the Buzzer

    SJMP MAIN_LOOP

START_TIMERS:
    SETB TR0
    SETB TR1

    SJMP MAIN_LOOP

CHECK_RESET:
    ; Check if button 'B' (11) was pressed to reset the stopwatch
    CJNE A, #11, MAIN_LOOP
    
    ; Reset all counters and update the LCD back to "00,00"
    MOV SEC_COUNT, #0
    MOV CS_COUNT, #0
    MOV T1_TICKS, #0
    MOV BEEP_DUR, #0

    LCALL DISPLAY_TIME
    SJMP MAIN_LOOP

DISPLAY_TIME:
    MOV A, #80H 
    LCALL WRITE_INSTR
    
    MOV A, SEC_COUNT
    LCALL PRINT_DEC
    
    MOV A, #','
    LCALL WRITE_DATA
    
    MOV A, CS_COUNT
    LCALL PRINT_DEC

    RET ; Return from subroutine

PRINT_DEC:
    MOV B, #10
    DIV AB
    ADD A, #'0'
    LCALL WRITE_DATA
    MOV A, B
    ADD A, #'0'
    LCALL WRITE_DATA

    RET 

TIMER0_ISR:
    ; PUSH used registers to prevent corrupting the main program
    PUSH ACC
    PUSH PSW
    PUSH B ; Register B is utilized inside the PRINT_DEC

    ; Reload timer 0 values for next 10ms tick
    MOV TH0, #TH0_SET
    MOV TL0, #TL0_SET
    
    ; Increase centiseconds
    INC CS_COUNT
    MOV A, CS_COUNT
    CJNE A, #100, T0_ISR_END
    
    ; 100 Centiseconds = 1 Second
    MOV CS_COUNT, #0
    INC SEC_COUNT
    MOV A, SEC_COUNT
    CJNE A, #100, T0_ISR_END
    
    ; Roll over to 0 after 99 seconds
    MOV SEC_COUNT, #0

T0_ISR_END:
    ; Update the LCD display with the new time values
    LCALL DISPLAY_TIME

    POP B
    POP PSW
    POP ACC

    RETI ; Return from interrupt

TIMER1_ISR:
    PUSH ACC
    PUSH PSW

    ; Reload timer 1 values for next 50ms tick
    MOV TH1, #TH1_SET
    MOV TL1, #TL1_SET
    
    ; Check if the Buzzer is currently sounding
    MOV A, BEEP_DUR
    JZ T1_COUNT
    
    ; Decrease the remaining beep duration
    DEC BEEP_DUR
    MOV A, BEEP_DUR
    JNZ T1_COUNT
    
    ; Beep duration has ended, turn off buzzer
    SETB BUZZ

T1_COUNT:
    ; Increment the 50ms counter
    INC T1_TICKS
    MOV A, T1_TICKS
    CJNE A, #200, T1_ISR_END ; 200 ticks * 50ms = 10 000ms = 10s
    
    ; 10 seconds limit reached
    MOV T1_TICKS, #0
    CLR BUZZ ; Turn ON buzzer
    MOV BEEP_DUR, #4 ; Beep will last for 4 * 50ms = 200ms

T1_ISR_END:
    POP PSW
    POP ACC

    RETI

STOP:
    SJMP $ 
    NOP 