%entry: main
	; .text
	; .file	"../test/leg_1.c"
	; .globl	add_or_sub
	; .type	add_or_sub,@function
add_or_sub:
	sbi sp sp #36
	stw r4 sp #32
	stw r5 sp #28
	mov r3 r2
	mov r4 r1
	mov r5 r0
	stw r0 sp #20
	stw r1 sp #16
	stw r2 sp #12
	set r0 #0
	tcu ad r2 r0
	stw r3 sp #8
	stw r4 sp #4
	stw r5 sp #0
	bif ad ::.LBB0_2 #0
	jmi ::.LBB0_1
.LBB0_1:
	ldw r0 sp #20
	ldw r1 sp #16
	add r0 r0 r1
	stw r0 sp #24
	jmi ::.LBB0_3
.LBB0_2:
	ldw r0 sp #20
	ldw r1 sp #16
	sub r0 r0 r1
	stw r0 sp #24
	jmi ::.LBB0_3
.LBB0_3:
	ldw r0 sp #24
	ldw r5 sp #28
	ldw r4 sp #32
	adi sp sp #36
	ret
.Lfunc_end0:
	; .size	add_or_sub, .Lfunc_end0-add_or_sub

	; .globl	main
	; .type	main,@function
main:
	sbi sp sp #32	; set up stack
	stw r4 sp #28	; var0 = X
	set r0 #0		; r0 = 0
	stw r0 sp #24	; ? = 0
	set r1 #3		; r1 = 3
	stw r1 sp #20	; a = 3
	set r1 #4		; r1 = 4
	stw r1 sp #16	; b = 4
	ldw r2 sp #20	; r2 = a
	set r3 ::add_or_sub
	set r4 #1		; r4 = 1
	stw r0 sp #4	; bool_add = 0
	mov r0 r2		; r0 = r2 ; a
	mov r2 r4		; r2 = r4 ; 1
	stw r3 sp #0	; ? = &add_or_sub
	cal r3			; 
	stw r0 sp #12	; sum = add_or_sub()
	ldw r0 sp #20	; r0 = a
	ldw r1 sp #16	; r1 = b
	ldw r2 sp #4	; r2 = bool_add ; 0
	ldw r3 sp #0	; r3 = &add_or_sub
	cal r3
	stw r0 sp #8	; dif = add_or_sub()
	ldw r1 sp #12	; r1 = sum
	add r0 r1 r0	; r0 = sum + dif
	ldw r4 sp #28	; r4 = X
	adi sp sp #32	; tear down stack
	ret
.Lfunc_end1:
	hlt ;.size	main, .Lfunc_end1-main


	; .ident	"clang version 3.8.1 (https://github.com/xdrie/clang-leg 43d93776c0f686e0097b8e3c96768b716ccd0a88) (https://github.com/xdrie/llvm-leg e9110cc431fbfe54a0c6e5d8dd476a1382dbbf60)"
	; .section	".note.GNU-stack","",@progbits
