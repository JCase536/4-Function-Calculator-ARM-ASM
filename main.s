
;Author: Jeffrey Thao, Jon Case
;Purpose: Acts as a 4-function calculator for single precision floating point operations

;;; Directives
			PRESERVE8
			THUMB       

; left number, right number
; operator
			AREA	MYDATA, DATA, READONLY
input		DCFS		1.18, 3.23
			DCB			'*'

			ALIGN

; Vector Table Mapped to Address 0 at Reset
; Linker requires __Vectors to be exported

			AREA    RESET, DATA, READONLY
			EXPORT  __Vectors
			
__Vectors
			DCD  0x20001000     ; stack pointer value when stack is empty
			DCD  Reset_Handler  ; reset vector
			
			ALIGN

; The program
; Linker requires Reset_Handler
			AREA    MYCODE, CODE, READONLY

			EXPORT Reset_Handler
			ENTRY
Reset_Handler
			LDR			R11, =input
			LDR			R4, [R11], #4
			LDR			R5, [R11], #4
			LDR			R6, [R11]
			
			LDR			R7, ='+'					;Determine operation
			CMP			R6, R7
			BLEQ		_add
			
			LDR			R7, ='-'
			CMP			R6, R7
			BLEQ		_sub
			
			LDR			R7, ='*'
			CMP			R6, R7
			BLEQ		_mul
			
			LDR			R7, ='/'
			CMP			R6, R7
			BLEQ		_div
			
			LDR			R1, =0x20000000
			STR			R0, [R1]
			B			stop
_add												;add/sub
			PUSH		{LR, R6}
			LDR			R3, =0x7F800000				;Extract the exponent bits
			AND			R1, R4, R3
			AND			R2, R5, R3
			LSR			R1, #23						;Shift from bits 23-30 to bits 0-7
			LSR			R2, #23
			SUB			R1, #127					;Subtract the bias to get real exponent
			SUB			R2, #127
			CMP			R1, R2						;Determine which number has a greater value based on exponent
			SUBGE		R3, R1, R2
			SUBLT		R3, R2, R1
			MOVGE		R2, R1
			PUSH		{R3}
			LDR			R3, =0x007FFFFF				;Extract the mantissa bits
			ANDGE		R0, R5, R3
			ANDGE		R1, R4, R3
			LDRGE		R6, =0						;R0 is the second number
			ANDLT		R0, R4, R3
			ANDLT		R1, R5, R3
			LDRLT		R6, =0x80000000				;R0 is the first number
			
			POP			{R3}
			PUSH		{R6}
equalize
			ADD			R0, #0x00800000
			ADD			R1, #0x00800000	
			LSR			R0, R3						;Shift lower number to same exponent magnitude as higher number
			
			LDR			R8, =0x80000000
			AND			R6, R4, R8
			AND			R7, R5, R8
			CMP			R6, R7
			
			POP			{R8}
			ADDEQ		R1, R0						;Add mantissa bits
			MOVEQ		R8, R6
			LDREQ		R9, =0
			LDREQ		R10, =0x01000000
			BEQ			shift_add
			
			CMP			R8, #0x80000000
			BLEQ		swap
			
			CMP			R1, R0
			SUBGE		R1, R1, R0
			LDRGE		R9, =0						;(+ if R8 and R9 are both 0 or both 1) (- otherwise)
			SUBLT		R1, R0, R1
			LDRLT		R9, =0x80000000
			
			LDR			R8, =0x80000000
			CMP			R6, R8
			LDREQ		R8, =0x80000000
			LDRNE		R8, =0
			EOR			R8, R8, R9					;Determine sign bit result
			
			LDR			R9, =0
			LDR			R10, =0x00800000
shift_sub
			CMP			R1, R10
			BGE			added
			CMP			R9, #23
			BEQ			zero_result
			ADD			R9, #1
			LSL			R1, #1
			B			shift_sub
shift_add
			CMP			R1, R10
			BLT			added
			SUB			R9, #1
			LSR			R1, #1
			B			shift_add
added
			SUB			R2, R9
			SUB			R2, #1
			ADD			R2, #127					;Add in exponent bias
			LSL			R2, #23						;Realign exponent to bits 23-30
			ADD			R0, R1, R2					;Combine mantissa and exponent result to get final answer
			ADD			R0, R8
			LDR			R8, =0x00800000
			CMP			R1, R8
			LDREQ		R0, =0
			POP			{LR, R6}
			BX			LR
_sub
			PUSH		{LR}
			LDR			R1, =0x80000000
			EOR			R5, R1
			BL			_add
			POP			{LR}
			BX			LR
zero_result
			LDR			R0, =0
			POP			{LR, R6}
			BX			LR
_mul
			PUSH		{LR, R6}
			CMP			R4, #0
			LDREQ		R0, =0
			BEQ			zero_result
			CMP			R5, #0
			LDREQ		R0, =0
			BEQ			zero_result
			LDR			R3, =0x7F800000				;Extract the exponent bits
			AND			R1, R4, R3
			AND			R2, R5, R3
			LSR			R1, #23						;Shift from bits 23-30 to bits 0-7
			LSR			R2, #23						;(X + 127) + (Y + 127) X + Y + 2*127
			SUB			R1, #127					;Subtract the bias to get real exponent
			SUB			R2, #127
			ADD			R2, R1
			LDR			R3, =0x007FFFFF				;Extract the mantissa bits
			AND			R0, R4, R3
			AND			R1, R5, R3
			ADD			R0, #0x00800000
			ADD			R1, #0x00800000
			LDR			R3, =0
			UMULL		R6, R7, R0, R1				;101010101 * 01001010 
			MLA			R7, R0, R3, R7
			MLA			R7, R1, R3, R7
			LDR			R3, =0
shift_left_reg										;Shift left register through the right register
			CMP			R7, #0
			LDREQ		R7, =0x1000000
			BEQ			shift_right_reg
			ADD			R3, #1
			LSR			R6, #1
			LSL			R0, R7, #31
			ORR			R6, R6, R0
			LSR			R7, #1
			B			shift_left_reg
shift_right_reg										;Shift the remaining to the right until aligned
			CMP			R6, #0
			LDRLT		R0, =0
			LDRGE		R0, =1
			CMP			R6, R7
			LDRLT		R1, =1
			LDRGE		R1, =0
			AND			R0, R1
			CMP			R0, #1
			BEQ			shifted_mul
			ADD			R3, #1
			LSR			R6, #1
			B			shift_right_reg
shifted_mul											;Combine resulting sign, exponent, and mantissa
			ADD			R2, R3
			SUB			R2, #23
			EOR			R0, R4, R5
			LDR			R3, =0x80000000
			AND			R0, R3
			ADD			R2, #127					;Add in exponent bias
			LSL			R2, #23						;Realign exponent to bits 23-30
			LDR			R7, =0x00800000
			SUB			R6, R7
			ORR			R0, R2
			ORR			R0, R6
			POP			{LR, R6}
			BX			LR
_div
			PUSH		{LR, R6}
			CMP			R4, #0						;0 / X = 0
			LDREQ		R0, =0
			BEQ			zero_result
			CMP			R5, #0						; X / 0 = Undefined
			LDREQ		R0, =0
			BEQ			undefined_result
			LDR			R3, =0x7F800000				;Extract the exponent bits
			AND			R1, R4, R3
			AND			R2, R5, R3
			SUB			R2, R1, R2
			LDR			R3, =0x007FFFFF				;Extract the mantissa bits
			AND			R0, R4, R3
			AND			R1, R5, R3
			ADD			R0, #0x00800000
			ADD			R1, #0x00800000
			BL			divide
			LDR			R3, =0x00800000
shift_left_div
			CMP			R0, R3
			LSLLT		R0, #1						; Larger mantissa / smaller mantissa => 1.XXXXXXX | Smaller / Larger => 0.(some amount of leading zeros)1XXXXXXXXX
			SUBLT		R2, R3
			BLT			shift_left_div
			EOR			R1, R4, R5
			LDR			R3, =0x80000000
			AND			R1, R3
			LDR			R3, =0x3F800000				;Exponent bias
			ADD			R2, R3						;Add in exponent bias
			LDR			R7, =0x00800000
			SUB			R0, R7
			ORR			R0, R1
			ORR			R0, R2
			POP			{LR, R6}
			BX			LR
divide
			PUSH		{LR, R2}
			LDR			R2, =0
			LDR			R3, =0
repeat_sub
			LSL			R2, #1	
			CMP			R0, R1
			SUBGE		R0, R1
			ADDGE		R2, #1
			LSL			R0, #1
			ADD			R3, #1
			CMP			R3, #24
			BLT			repeat_sub
			MOV			R0, R2
			POP			{LR, R2}
			BX			LR
swap
			PUSH		{LR, R1}
			MOV			R1, R6
			MOV			R6, R7
			MOV			R7, R1
			POP			{LR, R1}
			BX			LR
undefined_result
			LDR			R0, =0xF00DF00D				;-1.75710359889e+29
			POP			{LR, R6}
			BX			LR
stop
			END										;End of the program