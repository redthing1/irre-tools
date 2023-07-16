%entry: main
	; .text
	; .file	"../test/leg_2.c"
	; .globl	add
	; .type	add,@function
add:
	sbi sp sp #16	; set up stack
	mov r2 r1		; r2 = b
	mov r3 r0		; r3 = a
	stw r0 sp #12	; var0 = a
	stw r1 sp #8	; var1 = b
	ldw r0 sp #12	; r0 = var0
	add r0 r0 r1	; r0 = a + b
	stw r2 sp #4	; var2 = b
	stw r3 sp #0	; var3 = a
	adi sp sp #16	; tear down stack
	ret				; return r0 ; a + b
.Lfunc_end0:
	; .size	add, .Lfunc_end0-add

	; .globl	main
	; .type	main,@function
main:
	sbi sp sp #20	; set up stack frame
	set r0 #0		; ZERO
	stw r0 sp #16	; var0 = 0
	set r0 #3
	stw r0 sp #12	; store a = 3
	set r0 #4
	stw r0 sp #8	; store b = 4
	ldw r1 sp #12	; r1 = a ; 3
	set r2 ::add	; r2 = &add
	stw r0 sp #0	; var1 = 4
	mov r0 r1		; r0 = r1 ; a
	ldw r1 sp #0	; r1 = var1 ; 4
	cal r2			; r0 = add() ; r1 = a, r2 = b
	stw r0 sp #4	; ? = r0
	adi sp sp #20	; tear down stack
	ret				; END
.Lfunc_end1:
	hlt ;.size	main, .Lfunc_end1-main


	; .ident	"clang version 3.8.1 (https://github.com/redthing1/clang-leg 43d93776c0f686e0097b8e3c96768b716ccd0a88) (https://github.com/redthing1/llvm-leg e9110cc431fbfe54a0c6e5d8dd476a1382dbbf60)"
	; .section	".note.GNU-stack","",@progbits
