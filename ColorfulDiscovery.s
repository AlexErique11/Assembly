.data    
    format_c: .asciz "%c"     
    format_color: .asciz "\033[38;5;%dm\033[48;5;%dm"
    format_reset: .asciz "\033[0m"
    format_bold:   .asciz "\033[1m"
    format_faint:  .asciz "\033[2m"
    format_blink:  .asciz "\033[5m"
    format_blink_stop: .asciz "\033[25m"
    format_conceal: .asciz "\033[8m"
    format_reveal:  .asciz "\033[28m"

.text
   .include "final.s"

.global main

decode:
	pushq	%rbp 					# prologue
	movq	%rsp, %rbp		

    pushq   %r10                    # push the callee registers
	pushq   %r11
    pushq 	%r12					
	pushq 	%r13
	pushq 	%r14
	pushq 	%rbx
	pushq 	%rcx
	pushq 	%rdi
	pushq 	%rax
	subq 	$8, %rsp

	movl 	$0, %r12d				# r12d -> current index in the MESSAGE

loop:

	movq 	(%rdi), %rax            # rax = actual .quad from MESSAGE
    
	movb 	%al, %bl				# move the character in bl (rbx)
	
	shr 	$8, %rax
	movb 	%al, %cl				# move the number of prints in cl (rcx)
    
	shr 	$8, %rax
	movl 	%eax, %r14d				# move the next block in r14d (r14)

    shr 	$32, %rax
	movb 	%al, %r11b              # move the foreground in r11b (r11)

    shr 	$8, %rax
	movb 	%al, %r10b              # move the background in r10b (r10)

	movb 	%cl, %r13b				# copy for the number of prints in r13b (r13)


print_loop:
    cmp     $0, %r13b               # after we printed the character, we go to the next line
    je      _continue

    # foreground != background
    cmpb    %r10b, %r11b
    jne     normal_color_print         # if not the same --> normal print

    # foreground == background  -->  special effects
    cmpb    $0, %r11b
    je      reset_special              # 0: Reset to normal
    cmpb    $37, %r11b
    je      stop_blink_special         # 37: Stop blinking
    cmpb    $42, %r11b
    je      bold_special               # 42: Bold
    cmpb    $66, %r11b
    je      faint_special              # 66: Faint
    cmpb    $105, %r11b
    je      conceal_special            # 105: Conceal
    cmpb    $153, %r11b
    je      reveal_special             # 153: Reveal
    cmpb    $182, %r11b
    je      blink_special              # 182: Blink

    # if no special effects  -->  treat it like a normal color print (?)
    jmp     normal_color_print

reset_special:
    # Reset to normal ("\033[0m")
    pushq   %rdi
    pushq   %rax
    movq    $format_reset, %rdi    
    call    printf
    popq    %rax
    popq    %rdi
    jmp     print_char_loop            # Continue to print the character

stop_blink_special:
    # Stop blinking ("\033[25m")
    pushq   %rdi
    pushq   %rax
    movq    $format_blink_stop, %rdi  
    call    printf
    popq    %rax
    popq    %rdi
    jmp     print_char_loop             # Continue to print the character

bold_special:
    # Bold ("\033[1m")
    pushq   %rdi
    pushq   %rax
    movq    $format_bold, %rdi
    call    printf
    popq    %rax
    popq    %rdi
    jmp     print_char_loop             # Continue to print the character

faint_special:
    # Faint effect ("\033[2m")
    pushq   %rdi
    pushq   %rax
    movq    $format_faint, %rdi
    call    printf
    popq    %rax
    popq    %rdi
    jmp     print_char_loop             # Continue to print the character

conceal_special:
    # Conceal ("\033[8m")
    pushq   %rdi
    pushq   %rax
    movq    $format_conceal, %rdi
    call    printf
    popq    %rax
    popq    %rdi
    jmp     print_char_loop             # Continue to print the character

reveal_special:
    # Reveal ("\033[0m")
    pushq   %rdi
    pushq   %rax
    movq    $format_reveal, %rdi       
    call    printf
    popq    %rax
    popq    %rdi
    jmp     print_char_loop            # Continue to print the character

blink_special:
    # Blink ("\033[5m")
    pushq   %rdi
    pushq   %rax
    movq    $format_blink, %rdi
    call    printf
    popq    %rax
    popq    %rdi
    jmp     print_char_loop             # Continue to print the character

normal_color_print:
    # normal color printing
    pushq   %rdi
    pushq   %rax

    movq    $format_color, %rdi         
    movzbl  %r11b, %esi                 # foreground --> %esi register (zero extend)
    movzbl  %r10b, %edx                 # background --> %edx register (zero extend)
    call    printf                     
    popq    %rax
    popq    %rdi

    jmp     print_char_loop

print_char_loop:
    cmp     $0, %r13b
    je      print_loop              # if no more repetitions --> reset colors

    # Print the character
    pushq   %rdi
    pushq   %rax
    movq    $format_c, %rdi           
    movl    %ebx, %esi                # Character = %bl
    call    printf                    
    popq    %rax
    popq    %rdi

    dec     %r13b                     # print_count--
    jmp     print_char_loop           # Repeat until r13b becomes 0

_continue:
	cmp 	$0, %r14				# if the next address is null, then stop the program, MESSAGE decoded
	je 		done

	movq 	$8, %rax
	movq 	%r14, %r13				# create a local r13 to stock the next adress (r14)
	subq 	%r12, %r14				# calculate the difference you need to move between adresses
	movq 	%r13, %r12				# save the current adress in r12
	imulq 	%r14					# calculate in rax how much to jump

	addq 	%rax, %rdi

	jmp     loop                    # continue the loop until all rows are decoded


main:
	pushq	%rbp 					# prologue
	movq	%rsp, %rbp		

	movq	$MESSAGE, %rdi			# first parameter: address of the message
	call	decode					

	popq	%rbp					
	movq	$0, %rdi				
	call	exit	

done:
	addq 	$8, %rsp				# pop the callee saved registers
	popq 	%rax
	popq 	%rdi
	popq 	%rcx
	popq 	%rbx
	popq 	%r14
	popq 	%r13					
	popq 	%r12	
    popq    %r11
	popq    %r10
			

	movq	%rbp, %rsp				# epilogue
	popq	%rbp			
	ret
