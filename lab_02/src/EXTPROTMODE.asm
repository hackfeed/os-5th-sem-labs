.386P

FARJMP MACRO LABEL, SEGMENT  
    DB  0EAH 
    DD  OFFSET LABEL
    DW  SEGMENT
ENDM

PRINTSTR MACRO STR 
    MOV AH, 09H
    LEA DX, STR
    INT 21H
	XOR DX, DX
    MOV AH, 2
    MOV DL, 13
    INT 21H
    MOV DL, 10
    INT 21H
ENDM

WAITKEY MACRO 
    PUSH    EAX
    MOV     AH, 10H
    INT     16H
    POP     EAX
ENDM

CLS MACRO 
    MOV AX, 3
    INT 10H
ENDM

LDGDT MACRO GDT_DESC
    SHL EAX, 4                        
    MOV WORD PTR GDT_DESC.BASE_L, AX  
    SHR EAX, 16                       
    MOV BYTE PTR GDT_DESC.BASE_M, AL  
    MOV BYTE PTR GDT_DESC.BASE_H, AH  
ENDM

INITGDTR MACRO REG                      
    MOV     DWORD PTR GDTR + 2, REG     
    MOV     WORD PTR  GDTR, GDT_SIZE-1  
    LGDT    FWORD PTR GDTR              
ENDM

LDIDT MACRO IDT_DESC
    MOV	IDT_DESC.OFFS_L, AX 
    SHR	EAX, 16             
    MOV	IDT_DESC.OFFS_H, AX 
ENDM

INITIDTR MACRO REG                  
    MOV DWORD PTR IDTR + 2, REG     
    MOV WORD PTR  IDTR, IDT_SIZE-1	
ENDM

SETINTBASE MACRO BASE
	MOV	AL, 11H						
	OUT	20H, AL						

	MOV	AL, BASE					
	OUT	21H, AL						
	
	MOV	AL, 4						
	OUT	21H, AL                     

	MOV	AL, 1						
	OUT	21H, AL                     
ENDM

MEMSTR MACRO 
    MOV DI, 0
    MOV AH, 00000101B
    MOV AL, 'M'
    STOSW
    MOV AL, 'E'
    STOSW
    MOV AL, 'M'
    STOSW
    MOV AL, 'O'
    STOSW
    MOV AL, 'R'
    STOSW
    MOV AL, 'Y'
    STOSW
    MOV AL, ':'
    STOSW              
ENDM

SEGDESCR STRUC    
    LIM 	DW 0	
    BASE_L 	DW 0	
    BASE_M 	DB 0	
    ATTR_1	DB 0	
    ATTR_2	DB 0	
    BASE_H 	DB 0	
SEGDESCR ENDS

INTDESCR STRUC 
    OFFS_L 	DW 0  
    SEL		DW 0  
    CNTR    DB 0  
    ATTR	DB 0  
    OFFS_H 	DW 0  
INTDESCR ENDS

STACK SEGMENT  PARA STACK 'STACK'
    STACK_START DB  100H DUP(?)
    STACK_SIZE=$-STACK_START
STACK 	ENDS

DATA SEGMENT PARA 'DATA'
    GDT_NULL  SEGDESCR<>
    GDT_CS_16BIT SEGDESCR<RMCODE_SIZE-1,0,0,10011000B,00000000B,0>
    GDT_DS_16BIT SEGDESCR<0FFFFH,0,0,10010010B,10001111B,0>
    GDT_CS_32BIT SEGDESCR<PMCODE_SIZE-1,0,0,10011000B,01000000B,0>    
    GDT_DS_32BIT SEGDESCR<DATA_SIZE-1,0,0,10010010B,01000000B,0>
    GDT_SS_32BIT SEGDESCR<STACK_SIZE-1,0,0,10010110B,01000000B,0>
    GDT_VB_32BIT SEGDESCR<3999,8000H,0BH,10010010B,01000000B,0>
    GDT_SIZE=$-GDT_NULL 
    GDTR	DF 0        

    SEL_CS_16BIT    EQU    8   
    SEL_DS_16BIT    EQU   16   
    SEL_CS_32BIT    EQU   24
    SEL_DS_32BIT    EQU   32
    SEL_SS_32BIT    EQU   40
    SEL_VIDEOBUFFER EQU   48
   
    IDT	LABEL BYTE
	TRAP_F INTDESCR 13 DUP (<0,SEL_CS_32BIT,0,10001111B,0>) 
	TRAP_13 INTDESCR<0,SEL_CS_32BIT,0,10001111B,0>
	TRAP_S INTDESCR 18 DUP (<0,SEL_CS_32BIT,0,10001111B,0>) 

    INT08 INTDESCR<0,SEL_CS_32BIT,0,10001110B,0>     
    INT09 INTDESCR<0,SEL_CS_32BIT,0,10001110B,0> 

    IDT_SIZE=$-IDT 

    IDTR DF 0                   
	                            
    IDTR_BACKUP DW	3FFH, 0, 0  

    MASK_MASTER	DB 0            
    MASK_SLAVE	DB 0	        
        
	ASCII	DB 0, 0, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 0, 0
			DB 81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 91, 93, 0, 0, 65, 83
			DB 68, 70, 71, 72, 74, 75, 76, 59, 39, 96, 0, 92, 90, 88, 67
			DB 86, 66, 78, 77, 44, 46, 47

    FLAG_ENTER_PR   DB 0				 
    CNT_TIME        DD 0		        
    SYML_POS        DD 2 * (80 * 10)    

    MSG_IN_RM   DB 27, '[35;40m!REAL MODE! ', 27, '[0m$'
    MSG_MOVE_PM DB 27, '[35;40m!TO ENTER PROTECTED MODE PRESS ANY KEY!', 27, '[0m$'
    MSG_OUT_PM  DB 27, '[35;40m!BACK TO REAL MODE! ', 27, '[0m$'

    DATA_SIZE=$-GDT_NULL                
DATA ENDS

PMCODE SEGMENT PARA PUBLIC 'CODE' USE32
    ASSUME CS:PMCODE, DS:DATA, SS:STACK

    STARTPM:      
        MOV	AX, SEL_DS_32BIT 
        MOV	DS, AX
        MOV	AX, SEL_VIDEOBUFFER
        MOV	ES, AX
        MOV	AX, SEL_SS_32BIT
        MOV	SS, AX
        MOV	EAX, STACK_SIZE
        MOV	ESP, EAX

        STI 
                    
        MEMSTR
        CALL COUNTMEM
    PROCCESS:
        TEST FLAG_ENTER_PR, 1
        JZ	PROCCESS

        CLI 
        FARJMP RETURNRM, SEL_CS_16BIT
		
		EXCEPT_1 PROC
			IRET
		EXCEPT_1 ENDP
	
		EXCEPT_13 PROC
			POP EAX
			IRET
		EXCEPT_13 ENDP
    		
        NEW_INT08 PROC USES EAX         
            MOV     EAX, CNT_TIME
            PUSH    EAX
            
            MOV     EDI, 80 * 2
            XOR     EAX, EAX
            TEST    CNT_TIME, 05
            JZ      X
            TEST    CNT_TIME, 09
            JNZ     SKIP
            
            MOV AL, ' '
            JMP PR
            X:
                MOV AL, 'X'
            PR:
                MOV AH, 7
                STOSW		
                    
            SKIP:	
                POP EAX
            
                INC EAX

            
            MOV CNT_TIME, EAX

            MOV	AL, 20H 
            OUT	20H, AL
            
            IRETD
        NEW_INT08 ENDP

        NEW_INT09 PROC USES EAX EBX EDX 
            IN	AL, 60H             

            CMP	AL, 1CH 	        
            JNE	PRINTVAL            
            OR FLAG_ENTER_PR, 1     
            JMP ALLOWKB
            
            PRINTVAL:
                CMP AL, 80H
                JA ALLOWKB 	 
                                
                XOR AH, AH	 
                
                XOR EBX, EBX
                MOV BX, AX
                
                MOV DL, ASCII[EBX]  
                MOV EBX, SYML_POS   
                MOV ES:[EBX], DL

                ADD EBX, 2          
                MOV SYML_POS, EBX

            ALLOWKB: 
                IN	AL, 61H 
                OR	AL, 80H 
                OUT	61H, AL 
                AND AL, 7FH 
                OUT	61H, AL

                MOV	AL, 20H 
                OUT	20H, AL

                IRETD
        NEW_INT09 ENDP

        COUNTMEM PROC USES DS EAX EBX 
            MOV AX, SEL_DS_16BIT
            MOV DS, AX
			            
            MOV EBX, 100001H    
            MOV DL, 10101110B   
            
            MOV	ECX, 0FFEFFFFEH 

            MEMITER:
                MOV DH, DS:[EBX]    

                MOV DS:[EBX], DL    
                CMP DS:[EBX], DL    
                                    
                JNZ PRINTMEM        
            
                MOV	DS:[EBX], DH    
                INC EBX             
            LOOP MEMITER

            PRINTMEM:
                MOV EAX, EBX        
                XOR EDX, EDX

                MOV EBX, 100000H    
                DIV EBX

                MOV EBX, 2 * 10
                CALL PRINTEAX

                MOV EBX, 2 * 20
                MOV AL, 'M'
                MOV ES:[EBX], AL

                MOV EBX, 2 * 20 + 2
                MOV AL, 'B'
                MOV ES:[EBX], AL
            RET
        COUNTMEM ENDP

        PRINTEAX PROC USES ECX EBX EDX     
            ADD EBX, 10H 
            MOV ECX, 8   
            
            PRINTSYM: 
                MOV DL, AL
                AND DL, 0FH      
                
                CMP DL, 10
                JL ZEROSYM
                ADD DL, 'A' - '0' - 10 

            ZEROSYM:
                ADD DL, '0'         
                MOV ES:[EBX], DL    
                ROR EAX, 4          
                SUB EBX, 2          
                LOOP PRINTSYM
            RET
        PRINTEAX ENDP

    PMCODE_SIZE=$-STARTPM 	
PMCODE ENDS

RMCODE SEGMENT PARA PUBLIC 'CODE' USE16
    ASSUME CS:RMCODE, DS:DATA, SS: STACK

    START:
        MOV AX, DATA
        MOV DS, AX

        MOV AX, PMCODE
        MOV ES, AX

        PRINTSTR MSG_IN_RM  
        PRINTSTR MSG_MOVE_PM

        WAITKEY
        CLS 

        XOR	EAX, EAX
				
        MOV	AX, RMCODE 
        LDGDT GDT_CS_16BIT          

        MOV AX, PMCODE
        LDGDT GDT_CS_32BIT

        MOV AX, DATA
        LDGDT GDT_DS_32BIT

        MOV AX, STACK
        LDGDT GDT_SS_32BIT

        MOV AX, DATA  
        SHL EAX, 4                  
        ADD	EAX, OFFSET GDT_NULL    
        INITGDTR EAX
		
        LEA EAX, ES:EXCEPT_1
        LDIDT TRAP_F
        
        LEA EAX, ES:EXCEPT_1
        LDIDT TRAP_S
        
        LEA EAX, ES:EXCEPT_13
        LDIDT TRAP_13
        
        LEA EAX, ES:NEW_INT08   
        LDIDT INT08             

        LEA EAX, ES:NEW_INT09
        LDIDT INT09             
        
        MOV AX, DATA
        SHL EAX, 4
        ADD	EAX, OFFSET IDT     
        INITIDTR EAX
        
        IN	AL, 21H         
        MOV	MASK_MASTER, AL 
        IN	AL, 0A1H        
        MOV	MASK_SLAVE, AL

        SETINTBASE 32 
        
        MOV	AL, 0FCH
        OUT	21H, AL
        
        MOV	AL, 0FFH
        OUT	0A1H, AL
                
        LIDT FWORD PTR IDTR
        
        IN	AL, 92H						
        OR	AL, 2						
        OUT	92H, AL						

        CLI         
        IN	AL, 70H 
        OR	AL, 80H
        OUT	70H, AL

        MOV	EAX, CR0
        OR EAX, 1       
        MOV	CR0, EAX

        DB	66H
        FARJMP STARTPM, SEL_CS_32BIT

    RETURNRM:
        
        MOV	EAX, CR0
        AND	AL, 0FEH    
        MOV	CR0, EAX
        
        DB	0EAH	
        DW	$+4	    
        DW	RMCODE

        MOV	EAX, DATA	
        MOV	DS, AX          
        MOV EAX, PMCODE
        MOV	ES, AX
        MOV	AX, STACK   
        MOV	SS, AX
        MOV	AX, STACK_SIZE
        MOV	SP, AX
        
        SETINTBASE 8    
                        
        MOV	AL, MASK_MASTER 
        OUT	21H, AL
        MOV	AL, MASK_SLAVE
        OUT	0A1H, AL

        LIDT	FWORD PTR IDTR_BACKUP

        IN	AL, 70H 
        AND	AL, 7FH
        OUT	70H, AL
        STI         

    CLS
    PRINTSTR MSG_OUT_PM
    
    MOV	AX, 4C00H
    INT	21H

    RMCODE_SIZE=$-START 
RMCODE	ENDS
END START