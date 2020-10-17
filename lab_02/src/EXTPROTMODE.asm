.386P

; FARJMP на сегмент, смещение.
FARJMP MACRO LABEL, SEGMENT  
    DB  0EAH 
    DD  OFFSET LABEL
    DW  SEGMENT
ENDM

; Печать строки на экран.
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

; Ожидание ввода символа с клавиатуры.
WAITKEY MACRO 
    PUSH    EAX
    MOV     AH, 10H
    INT     16H
    POP     EAX
ENDM

; Очистить экран.
CLS MACRO 
    MOV AX, 3
    INT 10H
ENDM

; Загрузить дескриптор в таблицу.
LDGDT MACRO GDT_DESC
    SHL EAX, 4                        ; EAX - линейный базовый адрес (*2^4 = 16) (в EAX был SEG => он выравнен по параграфу => линейный адрес SEG * 16).
    MOV WORD PTR GDT_DESC.BASE_L, AX  ; Загрузка младшей часть базы.
    SHR EAX, 16                       ; Старшую половину EAX в AX.
    MOV BYTE PTR GDT_DESC.BASE_M, AL  ; Загрузка средней часть базы.
    MOV BYTE PTR GDT_DESC.BASE_H, AH  ; Загрузка старшей часть базы.
ENDM

; Загрузка в регистр GTDR линейного базового адреса GDT и ее размер.
INITGDTR MACRO REG                      ; В REG полный линейный адрес GDT.
    MOV     DWORD PTR GDTR + 2, REG     ; Кладём полный линейный адрес в старшие 4 байта переменной GDTR.
    MOV     WORD PTR  GDTR, GDT_SIZE-1   ; В младшие 2 байта заносим размер GDT, из-за определения GDT_SIZE (через $) настоящий размер на 1 байт меньше.
    LGDT    FWORD PTR GDTR              ; Загрузим GDT.
ENDM

LDIDT MACRO IDT_DESC
    MOV	IDT_DESC.OFFS_L, AX ; Загрузить младшую часть смещения.
    SHR	EAX, 16             ; Переместить старшую часть в младшую.
    MOV	IDT_DESC.OFFS_H, AX ; Загрузить старшую часть смещения.
ENDM

INITIDTR MACRO REG                  ; В REG полный линейный адрес IDT.
    MOV DWORD PTR IDTR + 2, REG     ; Загрузить полный линейный адрес в старшие 4 байта переменной IDTR.
    MOV WORD PTR  IDTR, IDT_SIZE-1	; В младшие 2 байта заносим размер IDT.
ENDM

;перепрограммируем контроллер.
SETINTBASE MACRO BASE
	; Чтобы начать инициализацию PIC, нужно на порт команды 20h отправить команду 11h.
	; Она заставляет контроллер ждать слова инициализации.
	MOV	AL, 11H						; Команда - инициализировать ведущий контроллер.
	OUT	20H, AL						; Отправить команду по шине данных ведущему контроллеру.

	; Отправляем новый базовый линейный адрес.
	MOV	AL, BASE					; Базовый вектор (начальное смещение для обработчика) установить в 32.
	OUT	21H, AL						; Отправить базовый вектор ведущему контроллеру.
	
	MOV	AL, 4						; 4 = 0000 0100.
	OUT	21H, AL                     ; Сообщить MASK_MASTER PIC, что MASK_SLAVE подключён к IRQ2.

	MOV	AL, 1						; Указываем, что нужно будет посылать.
	OUT	21H, AL                     ; Команду завершения обработчика прерывания.
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

; ====== Структура дескриптора сегмента в GDT ======
SEGDESCR STRUC    
    LIM 	DW 0	; Граница (биты 0..15)  - размер сегмента в байтах.
    BASE_L 	DW 0	; Младшие 16 битов адресной базы - базовый адрес задаётся в виртуальном адресном пространстве.
    BASE_M 	DB 0	; Следующие 8 битов адресной базы.
    ATTR_1	DB 0	; Атрибуты.
    ATTR_2	DB 0	; Атрибуты.
    BASE_H 	DB 0	; Последние 8 битов адресной базы.
SEGDESCR ENDS

; ====== Дескриптор прерываний в IDT ======
INTDESCR STRUC 
    OFFS_L 	DW 0  ; Младшие 16 битов адреса, куда происходит переход в случае возникновения прерывания.
    SEL		DW 0  ; Селектор сегмента с кодом прерывания/переключатель сегмента ядра.
    CNTR    DB 0  ; Счётчик, не используется в данной программе.
    ATTR	DB 0  ; Атрибуты (указывает, какой будет тип).
    OFFS_H 	DW 0  ; Старшие 16 битов адреса, куда происходит переход.
INTDESCR ENDS

; Сегмент стека (так как есть CALL).
STACK SEGMENT  PARA STACK 'STACK'
    STACK_START DB  100H DUP(?)
    STACK_SIZE=$-STACK_START
STACK 	ENDS

; Сегмент данных.
DATA SEGMENT PARA 'DATA'

	;====== Глобальная таблица дескрипторов сегментов (GDT) ======

    ; Обязательный нулевой дескриптор.
    GDT_NULL  SEGDESCR<>
    
    ; 16-битный сегмент кода - для реального режима.
    GDT_CS_16BIT SEGDESCR<RMCODE_SIZE-1,0,0,10011000B,00000000B,0>

    ; 16-битный сегмент данных, размером 4ГБ - для реального режима.
    ; 00 в аттр_1 - DPL = 0.
    GDT_DS_16BIT SEGDESCR<0FFFFH,0,0,10010010B,10001111B,0>

    ; 32-битный сегмент кода - для защищенного режима.
    GDT_CS_32BIT SEGDESCR<PMCODE_SIZE-1,0,0,10011000B,01000000B,0>    

    ; 32-битный сегмент данных - для защищенного режима.
    GDT_DS_32BIT SEGDESCR<DATA_SIZE-1,0,0,10010010B,01000000B,0>

    ; 32-битный сегмент стека - для защищенного режима.
    GDT_SS_32BIT SEGDESCR<STACK_SIZE-1,0,0,10010110B,01000000B,0>
        
    ; 32-битный сегмент видеопамяти (видеобуфера).
    GDT_VB_32BIT SEGDESCR<3999,8000H,0BH,10010010B,01000000B,0>

    GDT_SIZE=$-GDT_NULL ; Hазмер таблицы  GDT.
    GDTR	DF 0        ; Nут будет храниться базовый линейный адрес и размер таблицы GDT.

    ; Cмещения дескрипторов сегментов в таблице.
    ; GDT - размер дескриптора 8 байт.
	; В селекторе первые 3 бита == 0, потому что работает с глобальной табл сегментов (TI = 0), RPL = 0.
	; Ккогда кратно 8 , это 3 бита == 0.
    ; Селекторы.
    SEL_CS_16BIT    EQU    8   
    SEL_DS_16BIT    EQU   16   
    SEL_CS_32BIT    EQU   24
    SEL_DS_32BIT    EQU   32
    SEL_SS_32BIT    EQU   40
    SEL_VIDEOBUFFER EQU   48

	; ====== Таблица дескрипторов прерываний (IDT) ======
    
    IDT	LABEL BYTE    ; Метка (чтобы можно было получить размер IDT), говорит, что это начало таблицы.

    ; Первые 32 дескриптора - исключения, в программе не используются.
	; + заглушка для 13.
	; trap gate 32р.
	TRAP_F INTDESCR 12 DUP (<0,SEL_CS_32BIT,0,10001111B,0>) 
	TRAP_13 INTDESCR<0,SEL_CS_32BIT,0,10001111B,0>
	TRAP_S INTDESCR 19 DUP (<0,SEL_CS_32BIT,0,10001111B,0>) 

    ; Дескриптор прерывания от таймера.
    INT08 INTDESCR<0,SEL_CS_32BIT,0,10001110B,0> ; Аппаратное прерывание (interrupt gate 32р).

    ; Дескриптор прерывания от клавиатуры.
    INT09 INTDESCR<0,SEL_CS_32BIT,0,10001110B,0> 

    IDT_SIZE=$-IDT ; Размер таблицы IDT.

    IDTR DF 0                   ; Будет хранить базовый линейный адрес (4 байта) таблицы IDT и ее размер (2 байта).
	                            ; Содержимое регистра IDTR в реальном режиме.
    IDTR_BACKUP DW	3FFH, 0, 0  ; Чтобы запомнить предыдущее значение и восстановить его при переходе обратно в реальный режим, 3FF - первый КБ (размер), нулевой адрес.

    MASK_MASTER	DB 0            ; маска прерывания ведущего контроллера.
    MASK_SLAVE	DB 0	        ; маска прерывания ведомого контроллера.
        
	; Номер скан кода (с клавиатры) символа ASCII == номеру соответствующего элемента в таблице.
	ASCII	DB 0, 0, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 0, 0
			DB 81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 91, 93, 0, 0, 65, 83
			DB 68, 70, 71, 72, 74, 75, 76, 59, 39, 96, 0, 92, 90, 88, 67
			DB 86, 66, 78, 77, 44, 46, 47

    FLAG_ENTER_PR   DB 0				 
    CNT_TIME        DD 0		        ; Счетчик тиков таймера (4 байта).
    SYML_POS        DD 2 * (80 * 10)    ; Позиция выводимого символа.

    ; Выводимые сообщения.
    MSG_IN_RM   DB 27, '[35;40m!REAL MODE! ', 27, '[0m$'
    MSG_MOVE_PM DB 27, '[35;40m!TO ENTER PROTECTED MODE PRESS ANY KEY!', 27, '[0m$'
    MSG_OUT_PM  DB 27, '[35;40m!BACK TO REAL MODE! ', 27, '[0m$'

    DATA_SIZE=$-GDT_NULL                ; Размер сегмента данных.
DATA ENDS

PMCODE SEGMENT PARA PUBLIC 'CODE' USE32
    ASSUME CS:PMCODE, DS:DATA, SS:STACK

    STARTPM:
        ; В регистры сегмента загружаем селекторы.
        MOV	AX, SEL_DS_32BIT 
        MOV	DS, AX
        MOV	AX, SEL_VIDEOBUFFER
        MOV	ES, AX
        MOV	AX, SEL_SS_32BIT
        MOV	SS, AX
        MOV	EAX, STACK_SIZE
        MOV	ESP, EAX

        STI ; Разрешить прерывания, запрещенные в реальном режиме.
            ; Выход из цикла - по нажатию ENTER.

        ; Вывод строк - сохранение символов в видеопамять.
        MEMSTR

        ; Подсчет и вывод объема доступной памяти.
        CALL COUNTMEM

        ; Возвращение в реальный режим происходит по нажатию.
        ; клавиши ENTER - это будет обработано в коде обработчика прервания.
        ; чтобы программа не завершалась до этого момента, нужен бескончный цикл.
    PROCCESS:
        TEST FLAG_ENTER_PR, 1
        JZ	PROCCESS

        ; Запрещаем прерывания.
        ; Немаскируемые уже запрещены.
        CLI ; сброс флага прерывания IF = 0.
        FARJMP RETURNRM, SEL_CS_16BIT
		
		EXCEPT_1 PROC
			IRET
		EXCEPT_1 ENDP
	
		EXCEPT_13 PROC
			POP EAX
			IRET
		EXCEPT_13 ENDP
    
		; Обработчик системного таймера.
        NEW_INT08 PROC USES EAX 

            ; Получили текущее количество тиков.
            MOV     EAX, CNT_TIME
            PUSH    EAX
            ; Вывели время.
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
            ; Увеличили текущее количество счетчиков.
                INC EAX

            ; Сохранили.
            MOV CNT_TIME, EAX

            ; Отправили EOI ведущему контроллеру прерываний.
            MOV	AL, 20H 
            OUT	20H, AL
            
            IRETD
        NEW_INT08 ENDP

        NEW_INT09 PROC USES EAX EBX EDX 
            IN	AL, 60H             ; Получить скан-код нажатой клавиши из порта клавиатуры.

            CMP	AL, 1CH 	        ; Сравниваем с кодом ENTER.
            JNE	PRINTVAL            ; Если не ENTER - выведем, то что ввели.
            OR FLAG_ENTER_PR, 1     ; Если ENTER - устанавливаем флаг, возврата в реальный режим.
            JMP ALLOWKB
            
            PRINTVAL:
                CMP AL, 80H  ; Сравним какой скан-код пришел: нажатой клавиши или отжатой?
                JA ALLOWKB 	 ; Если отжатой, то ничего не выводим.
                                
                XOR AH, AH	 ; Если нажатой, то выведем на экран.
                
                XOR EBX, EBX
                MOV BX, AX
                
                MOV DL, ASCII[EBX]  ; Получим ASCII код нажатой клавиши по скан коду из таблицы.
                MOV EBX, SYML_POS   ; Текущая позиция вывода символа.
                MOV ES:[EBX], DL

                ADD EBX, 2          ; Увеличим текущую позицию вывода текста.
                MOV SYML_POS, EBX

            ALLOWKB: 
                IN	AL, 61H ; Сообщаем контроллеру о приёме скан кода:.
                OR	AL, 80H ; Установкой старшего бита .
                OUT	61H, AL ; Содержимого порта b.
                AND AL, 7FH ; И последующим его сбросом.
                OUT	61H, AL

                MOV	AL, 20H ; END OF INTERRUPT ведущему контроллеру прерываний (закончили обработку прерывания).
                OUT	20H, AL

                IRETD
        NEW_INT09 ENDP

        COUNTMEM PROC USES DS EAX EBX 
            MOV AX, SEL_DS_16BIT
            MOV DS, AX
			
			; Подсчет памяти.
			; Первый мегабайт пропустить; начиная со второго мегабайта сохранить байт или слово памяти, записать в этот.
			; Байт или слово сигнатуру, прочитать сигнатуру и сравнить с сигнатурой в программе, если сигнатуры совпали, то это – память.
            
            MOV EBX, 100001H    ; Пропустить первый мегабайт, чтобы не изменить BIOS! (попытаемся изменить данные BIOS, к. READONLY память).
            MOV DL, 10101110B   ; То, что будем печатать в память (сигнатура).
            
            MOV	ECX, 0FFEFFFFEH ; Количество оставшейся памяти (до превышения лимита в 4ГБ) - защита от переполнения.

            MEMITER:
                MOV DH, DS:[EBX]    ; Сохраняем байт памяти.

                MOV DS:[EBX], DL    ; Пишем в память.
                CMP DS:[EBX], DL    ; Проверяем - если записано то, что мы пытались записать.
                                    ; То это доступная память.
                JNZ PRINTMEM        ; Иначе мы дошли до конца памяти - надо вывести.
            
                MOV	DS:[EBX], DH    ; Восстановить байт памяти.
                INC EBX             ; Если удалось записать - увеличиваем счетчик памяти .
            LOOP MEMITER

            PRINTMEM:
                MOV EAX, EBX        ; Переводим в MB.
                XOR EDX, EDX

                MOV EBX, 100000H    ; 1MB.
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


        ; Вывод значения EAX в видеобуффер.
        ; В EBX позиция вывода на экран.
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
                ADD DL, '0'         ; Преобразуем число в цифру.
                MOV ES:[EBX], DL    ; Записать в видеобуффер.
                ROR EAX, 4          ; Циклически сдвинуть вправо.
                SUB EBX, 2          ; Печатаем след символ.
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
		
		; Загружаем адреса сегментов.
        MOV	AX, RMCODE 
        LDGDT GDT_CS_16BIT          ; В дескриптор сегмента.

        MOV AX, PMCODE
        LDGDT GDT_CS_32BIT

        MOV AX, DATA
        LDGDT GDT_DS_32BIT

        MOV AX, STACK
        LDGDT GDT_SS_32BIT

        MOV AX, DATA  
        SHL EAX, 4                  ; Линейный базовый адрес сегмента DATA (* 16).
        ADD	EAX, OFFSET GDT_NULL    ; В EAX - лин баз адрес начала gdt.
        INITGDTR EAX
		
        LEA EAX, ES:EXCEPT_1
        LDIDT TRAP_F
        
        LEA EAX, ES:EXCEPT_1
        LDIDT TRAP_S
        
        LEA EAX, ES:EXCEPT_13
        LDIDT TRAP_13;.

        ; Загружаем дескриптор прерывания, нужно только смещение, т.к. селектор кода уже указан.
        LEA EAX, ES:NEW_INT08   ; В EAX смещение 8 обработчика.
        LDIDT INT08             ; Прерывание таймера.

        LEA EAX, ES:NEW_INT09
        LDIDT INT09             ; Прерывание клавиатуры.
        
        MOV AX, DATA
        SHL EAX, 4
        ADD	EAX, OFFSET IDT     ; В EAX полный линейный адрес IDT.
        INITIDTR EAX
        
        ; Для возврата в защищенный.
        ; Сохраним маски прерываний контроллеров.
        IN	AL, 21H         ; Получить набор масок (флагов) MASK_MASTER 21h - номер шины, IN на неё даст нам набор масок (флагов).
        MOV	MASK_MASTER, AL ; Сохраняем в переменной MASK_MASTER (понадобится для возвращения в RM).
        IN	AL, 0A1H        ; Аналогично ведомого, IN даёт набор масок для ведомого.
        MOV	MASK_SLAVE, AL

        ; Перепрограммируем PIC (контроллер).
        ; Вектор прерывания = базовый вектор прерывания + № IRQ.
        ; IRQ0 - системный таймер, 8 + 0 = 8ое исключение => SYSTEM FAULT, паника системы.
        ; Необходимо перепрограмироваить пик на новый новый базовый вектор 32.
        SETINTBASE 32 

        ; Запретим все прерывания в ведущем контроллере, кроме IRQ0 (таймер) и IRQ1 (клавиатура).
        ; Установление новых масок.
        MOV	AL, 0FCH
        OUT	21H, AL
        ; Запретим все прерывания в ведомом контроллере.
        MOV	AL, 0FFH
        OUT	0A1H, AL
        
        ; Загрузим IDT.
        LIDT FWORD PTR IDTR
        
        ; Открытие линии a20.
        ; Включает механизм циклического оборачивания адреса => можно адресоваться к расширенной памяти (за пределы 1МБ).
        IN	AL, 92H						
        OR	AL, 2						
        OUT	92H, AL						

        CLI         ; Отключить маскируемые прерывания.
        IN	AL, 70H ; И немаскируемые прерывания.
        OR	AL, 80H
        OUT	70H, AL

        ; Переход в защищенный режим.
        MOV	EAX, CR0
        OR EAX, 1       ; Перейти в непосредственно защищенный режим (PE делаем == 1).
        MOV	CR0, EAX

        DB	66H
        FARJMP STARTPM, SEL_CS_32BIT

    RETURNRM:
        ; Возвращаемся в реальный режим .
        MOV	EAX, CR0
        AND	AL, 0FEH    ; Сбрасываем флаг защищенного режима.
        MOV	CR0, EAX

        ; Этот дальний переход необходим для модификации теневого регистра CS.
        DB	0EAH	; far jmp rmcode:$+4.
        DW	$+4	    ; *Выполнить следующую после DW	RMCODE команду.
        DW	RMCODE

        MOV	EAX, DATA	; Загружаем в сегментные регистры сегменты.
        MOV	DS, AX          
        MOV EAX, PMCODE
        MOV	ES, AX
        MOV	AX, STACK   ; Сдеалем адресуемым стек.
        MOV	SS, AX
        MOV	AX, STACK_SIZE
        MOV	SP, AX

        ; Перепрограммируем контроллер.
        SETINTBASE 8    ; Теперь базовый вектор прерывания снова = 8 - смещение, .
                        ; По которому вызываются стандартные обработчики прерываний в реалмоде.

        MOV	AL, MASK_MASTER ; Восстанавить маски контроллеров прерываний.
        OUT	21H, AL
        MOV	AL, MASK_SLAVE
        OUT	0A1H, AL

        ; Загружаем таблицу дескриптров прерываний реального режима.
        LIDT	FWORD PTR IDTR_BACKUP

        IN	AL, 70H ; Разрешить немаскируемые прерывания.
        AND	AL, 7FH
        OUT	70H, AL
        STI         ; И маскируемые.

    CLS
    PRINTSTR MSG_OUT_PM
    
    MOV	AX, 4C00H
    INT	21H

    RMCODE_SIZE=$-START ; Длина сегмента RMCODE.
RMCODE	ENDS
END START