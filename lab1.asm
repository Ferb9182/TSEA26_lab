	.code
	set sp,stackarea		; We obviously need some space for the stack...
	nop
	call initfirkernel
	call initsanitycheck	; Set up random values in almost all registers

;;; ----------------------------------------------------------------------
;;; Main loop. This loop ensures that handle_sample is called 1000 times.
;;; ----------------------------------------------------------------------
	set r31,100
loop
	call handle_sample

	add r31,-1
	jump.ne loop		

	call sanitycheck  ; Ensure no register was clobbered
	out 0x13,r0	   ; Signals that we are at the end of the loop


;;; ----------------------------------------------------------------------
;;; We assume that the handle_sample signal is called with a frequency
;;; of 500 Hz from a timer interrupt. It can thus not assume anything
;;; about the contents of the registers and must also save all registers
;;; that are modified.
;;; 
;;; Once all registers are saved it calls fir_kernel to perform the actual
;;; filtering.
;;; ----------------------------------------------------------------------
handle_sample
	; ret 
	push r0
	push r1

	move r0,ar0
	move r1,ar1
	push r0
	push r1

	move r0,step0
	move r1,step1
	push r0
	push r1

	move r0,bot1
	move r1,top1
	push r0
	push r1

	move r0,acr0
	move r1,mul65536 acr0
	push r0
	push r1

	move r0,guards01
	move r1,loopn
	push r0
	push r1

	move r0,loopb
	move r1,loope
	push r0
	push r1

	move r0,r31
	nop
	push r0

		;;;  FIXME - You may want to save other registers here as well.
		;;; (Alternatively, you might want to save less registers here in order
		;;; to improve the performance if you can get away with it somehow...)

	;;; Put sample into ring buffer
	
	call fir_kernel

	pop r0
	nop
	move r31,r0

	pop r1
	pop r0
	move loope,r1
	move loopb,r0

	pop r1
	pop r0
	move loopn,r1
	move guards01,r0

	pop r1
	pop r0
	move acr0.l,r1
	move acr0.h,r0

	pop r1
	pop r0
	move top1,r1
	move bot1,r0

	pop r1
	pop r0
	move step1,r1
	move step0,r0
	
	pop r1
	pop r0
	move ar1,r1
	move ar0,r0

	pop r1
	pop r0

	ret


;;; ----------------------------------------------------------------------
;;; Allocate variables used by the fir_kernel here
;;; ----------------------------------------------------------------------
	
	.ram0
current_location
	.skip 1

;;; ----------------------------------------------------------------------
;;; Initialization function for the fir kernel. Right now it only sets
;;; the current_location variable but you may want to do something more
;;; here in the lab.
;;; ----------------------------------------------------------------------
	.code
initfirkernel
	set r1,ringbuffer
	nop
	st0 (current_location),r1
	ret

;;; ----------------------------------------------------------------------
;;; This is the filter kernel. It assumes that the following registers
;;; can be changed: r0, r1, ar0, ar1, step0, step1, bot1, top1, acr0,
;;; loopn/b/e. If you need to modify other registers, change
;;; handle_sample above!
;;; ----------------------------------------------------------------------
	.code
fir_kernel
	

	;; Set ringbuffer pointer wrap-around
	set r1,top_ringbuffer
	set r0,ringbuffer
	move top1,r1
	move bot1,r0
	set r1,1
	nop
	move step1,r1
	move step0,r1

	set r31,10


	ld0 r1,(current_location)
	nop
	
fir_kernel_loop
	move ar1,r1




	;;; FIXME - You need to implement the rest of this function
	in r0,0x10		; Read input sample -> r0	
	nop
	;; Store sample
	st1 (ar1),r0


	set r1,coefficients
	nop
	move ar0,r1



	;; Clear accumulator
	clr acr0

	;; for each sample {
		;; multiply sample by weight which is stored .coefficients
	;; }

	
	repeat FIR_loop,31
	convss acr0,(ar0++%),(ar1++%)
FIR_loop
	move r1,ar1
	nop
	
	convss acr0,(ar0++%),(ar1++%)
	nop
	nop



	;;  Hint: Remember to set ar0, step0, step1, bot1, and top1
	;;  appropriately before starting the convolution.

	;; Hint: The syntax of the repeat instruction is:
	;;	 repeat label_at_end_of_loop, number_of_iteration

	;; Hint: For the final iteration you do not want to increment
	;; the address register that points to the ring buffer. (As
	;; you want to note the value of the address register at this point
	;; and save it to current_location.) However, the convss
	;; instruction forces you to either use a post increment addressing 
	;; mode or modulo addressing mode.
	;; 
	;; You can achieve the same effect by instead copying the value
	;; just before running the final convss instruction like this:
	;; 
	;;	 move r5,ar1
	;;	 convss ...  (ar1++%)
	;;	 Store r5 here
	

	;; Hint: You may need some scaling in this instruction. Without scaling
	;; this will move bit 31-16 into r0 (after saturation and rounding)
	move r0,sat rnd div4 acr0
	nop

	out 0x11,r0		; Output a sample

	add r31,-1
	jump.ne fir_kernel_loop
	st0 (current_location),r1
	ret
	

;;; ----------------------------------------------------------------------
;;; Allocate space for ringbuffer. We put this in DM1 since the
;;; filter coefficients are stored in DM0 (as we only have a rom in DM0)
;;; ----------------------------------------------------------------------
	.ram1
ringbuffer
	.skip 31
top_ringbuffer			; Convenient label
	.skip 1
	

;;; ----------------------------------------------------------------------
;;; The filter coefficients should be stored here in read only memory
;;; ----------------------------------------------------------------------
	.rom0
coefficients
;;;  FIXME: Here you need to fill in the coefficients.
;;;  Note: For your final solution you need to use .dw here to
;;;  demonstrate that you understand fixed point twos complement
;;;  arithmetic. No negative numbers may be entered here! (Hexadecimal
;;;  numbers are ok though.)
;;; 
;;;  Hint: During development you might find it easier to use .df and
;;;  .scale instead though
;;; 
;;;  Hint: You might find it easy to use fprintf() in matlab to
;;;  create this part. (fprintf in matlab can handle vectors)
	.dw 0xfec4
	.dw 0xfef6
	.dw 0xff3f
	.dw 0x0000
	.dw 0x01b0
	.dw 0x04c4
	.dw 0x0999
	.dw 0x105e
	.dw 0x1906
	.dw 0x2340
	.dw 0x2e77
	.dw 0x39e0
	.dw 0x4492
	.dw 0x4d9d
	.dw 0x542b
	.dw 0x579e
	.dw 0x579e
	.dw 0x542b
	.dw 0x4d9d
	.dw 0x4492
	.dw 0x39e0
	.dw 0x2e77
	.dw 0x2340
	.dw 0x1906
	.dw 0x105e
	.dw 0x0999
	.dw 0x04c4
	.dw 0x01b0
	.dw 0x0000
	.dw 0xff3f
	.dw 0xfef6
	.dw 0xfec4
	
;;; ----------------------------------------------------------------------
;;; Stack space
;;; ----------------------------------------------------------------------
	.ram1
stackarea
	.skip 100		; Should be plenty enough for a stack in this lab!

	
#include "sanitycheck.asm"


