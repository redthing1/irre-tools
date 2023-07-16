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
	set rv #0		; empty value
	stw rv sp #8	; empty slot
	stw rv sp #4	; c
	stw rv sp #0	; i
	jmi ::.LBB0_1
.LBB0_1:			; LOOP
	ldw rv sp #0	; load i
	set r1 #3 		; r1 = (loop_end - 1)
	tcu ad rv r1	; cmp i, rv
	bif ad ::.LBB0_4 #1	; if (i > rv) goto END
	jmi ::.LBB0_2
.LBB0_2:
	ldw rv sp #4 	; load c
	adi rv rv #16 	; c += 16
	stw rv sp #4 	; store c
	jmi ::.LBB0_3
.LBB0_3:
	ldw rv sp #0	; load i
	adi rv rv #1	; i += 1
	stw rv sp #0	; store i
	jmi ::.LBB0_1	; goto LOOP
.LBB0_4:			; END
	ldw rv sp #4 	; rv = c ; set the return value
	adi sp sp #12 	; tear down the stack frame
	ret				; return (this will effectively halt)
.Lfunc_end0:
	hlt ;.size	main, .Lfunc_end0-main


	; .ident	"clang version 3.8.1 (https://github.com/xdrie/clang-leg 43d93776c0f686e0097b8e3c96768b716ccd0a88) (https://github.com/xdrie/llvm-leg e9110cc431fbfe54a0c6e5d8dd476a1382dbbf60)"
	; .section	".note.GNU-stack","",@progbits
