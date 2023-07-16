	; .text
	; .file	"../test/leg_2.c"
	; .globl	add
	; .type	add,@function
add:
	sbi sp sp #16	; set up stack
	mov r2 r1		; r2 = r1
	mov r3 r0		; r3 = r0
	stw r0 sp #12	
	stw r1 sp #8
	ldw r0 sp #12
	add r0 r0 r1
	stw r2 sp #4
	stw r3 sp #0
	adi sp sp #16
	ret
.Lfunc_end0:
	; .size	add, .Lfunc_end0-add

	; .globl	main
	; .type	main,@function
main:
	sbi sp sp #20	; set up stack frame
	set r0 #0		; ZERO
	stw r0 sp #16	; ? = 0
	set r0 #3
	stw r0 sp #12	; store a = 3
	set r0 #4
	stw r0 sp #8	; store b = 4
	ldw r1 sp #12	; r1 = a ; 3
	set r2 ::add	; r2 = &add
	stw r0 sp #0	; ? = 4
	mov r0 r1		; r0 = r1 ; a
	ldw r1 sp #0	; r1 = ?
	cal r2			; r0 = add()
	stw r0 sp #4	; ? = r0
	adi sp sp #20	; tear down stack
	ret				; END
.Lfunc_end1:
	hlt ;.size	main, .Lfunc_end1-main


	; .ident	"clang version 3.8.1 (https://github.com/xdrie/clang-leg 43d93776c0f686e0097b8e3c96768b716ccd0a88) (https://github.com/xdrie/llvm-leg e9110cc431fbfe54a0c6e5d8dd476a1382dbbf60)"
	; .section	".note.GNU-stack","",@progbits
