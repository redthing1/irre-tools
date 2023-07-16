%entry: main
	; .text
	; .file	"../test/fib_2.c"
	; .globl	fib
	; .type	fib,@function
fib:
	sbi sp sp #24		; set up stk
	stw lr sp #20		; save original return address
	mov r1 r0			; r1 = n
	stw r0 sp #12		; store n
	set r2 #1			; r2 = 1
	tcu ad r0 r2		; cmp r0, r2 ; cmp r0, 1
	stw r1 sp #8		; ? = r1
	bif ad ::.LBB0_2 #1	; bge (r0 > 1)
	; jmi ::.LBB0_1
; .LBB0_1:
	ldw r0 sp #12		; r0 = n
	stw r0 sp #16		; result = n
	jmi ::.LBB0_3
.LBB0_2:				; recursive case
	ldw r0 sp #12		; r0 = n
	set r1 #-1			; r1 = -1
	add r0 r0 r1		; r0 = n - 1
	set r1 ::fib		; r1 = &fib
	stw r1 sp #4		; ? = r1
	cal r1				; fib()
	ldw r1 sp #12		; r1 = n
	set r2 #-2			; r2 = -2
	add r1 r1 r2		; r1 = (n - 2)
	stw r0 sp #0		; res1 = r0 ; fib(n-1)
	mov r0 r1			; r0 = r1 ; (n - 2)
	ldw r1 sp #4		; r1 = &fib
	cal r1				; fib()
	ldw r1 sp #0		; r1 = res1
	add r0 r1 r0		; r0 = res1 + res2
	stw r0 sp #16		; result = r0 ; res1 + res2
	; jmi ::.LBB0_3
.LBB0_3:				; base case
	ldw r0 sp #16		; r0 = result
	ldw lr sp #20		; load original return address
	adi sp sp #24		; tear down stack
	ret
.Lfunc_end0:
	; .size	fib, .Lfunc_end0-fib

	; .globl	main
	; .type	main,@function
main:
	sbi sp sp #8	; set up stk
	set r0 #0		; r0 = 0
	stw r0 sp #4	; ? = 0
	set r0 ::fib	; r0 = &fib
	set r1 #6		; r1 = N
	stw r0 sp #0	; var0 = &fib
	mov r0 r1		; r0 = r1 ; 2
	ldw r1 sp #0	; r1 = var0; &fib
	cal r1			; fib()
	adi sp sp #8	; tear down stk
	ret
.Lfunc_end1:
	hlt ;.size	main, .Lfunc_end1-main


	; .ident	"clang version 3.8.1 (https://github.com/redthing1/clang-leg 43d93776c0f686e0097b8e3c96768b716ccd0a88) (https://github.com/redthing1/llvm-leg e9110cc431fbfe54a0c6e5d8dd476a1382dbbf60)"
	; .section	".note.GNU-stack","",@progbits
