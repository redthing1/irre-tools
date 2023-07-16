; stack layout
; #0: i
; #4: c
; #8: XXX
;


	; .text
	; .file	"../test/leg_3.c"
	; .globl	main
	; .type	main,@function
main:
	sbi sp sp #12	; set up the stack frame
	set r0 #0		; empty value
	stw r0 sp #8	; empty slot
	stw r0 sp #4	; c
	stw r0 sp #0	; i
	jmi ::.LBB0_1
.LBB0_1:			; LOOP
	ldw r0 sp #0	; load i
	set r1 #3 		; r1 = (loop_end - 1)
	tcu ad r0 r1	; cmp i, r0
	bif ad ::.LBB0_4 #1	; if (i > r0) goto END
	jmi ::.LBB0_2
.LBB0_2:
	ldw r0 sp #4 	; load c
	adi r0 r0 #16 	; c += 16
	stw r0 sp #4 	; store c
	jmi ::.LBB0_3
.LBB0_3:
	ldw r0 sp #0	; load i
	adi r0 r0 #1	; i += 1
	stw r0 sp #0	; store i
	jmi ::.LBB0_1	; goto LOOP
.LBB0_4:			; END
	ldw r0 sp #4 	; r0 = c ; set the return value
	adi sp sp #12 	; tear down the stack frame
	ret				; return (this will effectively halt)
.Lfunc_end0:
	hlt ;.size	main, .Lfunc_end0-main


	; .ident	"clang version 3.8.1 (https://github.com/redthing1/clang-leg 43d93776c0f686e0097b8e3c96768b716ccd0a88) (https://github.com/redthing1/llvm-leg e9110cc431fbfe54a0c6e5d8dd476a1382dbbf60)"
	; .section	".note.GNU-stack","",@progbits
