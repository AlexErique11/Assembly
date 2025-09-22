.bss
    char_buffer: .byte 0        # reserves 1 byte and initialises it with 0

.data
    format_string: .string "this are:  %s  %s  %s  %s  %d %u %s %s %% %c %c\0"
    input_1: .string "Gogu1\0" 
    input_2: .string "Gogu2\0"
    input_3: .string "Gogu3\0"
    input_4: .string "Gogu4\0"
    input_5: .quad 18446744073709551547    # -69          
    input_6: .quad 20
    input_7: .string "Gogu5\0"
    input_8: .string "Gogu6\0"
.text

.global main

my_printf:
	# prologue
	pushq	%rbp 			# push the base pointer (and align the stack)
	movq	%rsp, %rbp		# copy stack pointer value to base pointer

    pushq   %r9
    pushq   %r8
    pushq   %rcx
    pushq   %rdx
    pushq   %rsi

    movq    %rsp, %r11      # r11 = top of the stack we need

    # caleee saved registers 
    pushq   %rbx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15

    movq    %rdi, %r15              # r15 = format_string
    xorq    %r14, %r14              # r14 = nr of arguments
    movq    $char_buffer, %r13
    xorq    %r12, %r12               # r12 = final_string length

find_arguments:
    movb    (%r15), %al              # Load next byte of the format string
    testb   %al, %al                 # Check for null terminator
    je      done                     # If null terminator, stop the loop

    cmpb    $'%', %al               # Check if the character is '%'
    jne     next_char                # If not, move to the next character

    # If we find '%', check the next character for '%', 's', 'd', or 'u'
    inc     %r15                     # Move to the character after '%'
    movb    (%r15), %al             # Load the next character
    testb   %al, %al                 # Check for null terminator
    je      percent_argument          # If null terminator, stop the loop and print '%'
    
    cmpb    $'%', %al
    je      percent_argument
    cmpb    $'s', %al               # Check if it's 's'
    je      string_argument
    cmpb    $'d', %al               # Check if it's 'd'
    je      signed_int_argument 
    cmpb    $'u', %al               # Check if it's 'u'
    je      unsigned_int_argument        
    
    jmp     fake_argument


next_char:
    pushq   %r11      # why tf is this changed when syscall!!! (kill assembly inventer)
    movq    $0, (%r13)
    movb   %al, (%r13)     # Store the character in the buffer
    movq   $1, %rax             # Syscall number (1 = write)
    movq   $1, %rdi             # File descriptor (1 = stdout)
    movq   %r13, %rsi           # Address of the character to print
    movq   $1, %rdx             # Number of bytes (1 character)
    syscall                      # Perform the syscall
    popq    %r11

    inc     %r15                     # Move to the next character
    inc     %r12
    jmp     find_arguments           # Repeat loop

/* ---------------------------------------------------------------------- */

jump_over_in_stack_string:
    addq    $16, %r11
    movq    (%r11), %r10
    jmp     append_loop

string_argument:
    cmpq    $5, %r14
    je      jump_over_in_stack_string         # jump if 5 == r14
    movq    (%r11), %r10

    append_loop:
        movb    (%r10), %al           # Load the next byte (character) from the string into %al
        testb   %al, %al              # Check for the null terminator
        je      done_append_loop         # If null, we're done

        pushq   %r11
        movq    $0, (%r13)
        movb    %al, (%r13)     # Store the character in the buffer
        movq    $1, %rax             # Syscall number (1 = write)
        movq    $1, %rdi             # File descriptor (1 = stdout)
        movq    %r13, %rsi           # Address of the character to print
        movq    $1, %rdx             # Number of bytes (1 character)
        syscall                      # Perform the syscall
        popq    %r11
        
        inc     %r12            # increase final_string length      
        inc     %r10            # go to next char     
        jmp     append_loop           # Repeat for the next character

    done_append_loop:
        addq    $8, %r11        # go to the next argument
        inc     %r14
        inc     %r15
        jmp     find_arguments

/* ---------------------------------------------------------------------- */
jump_over_in_stack_unsigned:
    addq    $16, %r11
    movq    (%r11), %r10
    jmp     prepare_conversion_unsigned

unsigned_int_argument:
    xorq    %r10, %r10
    cmpq    $5, %r14
    je      jump_over_in_stack_unsigned
    movq    (%r11), %r10

prepare_conversion_unsigned:
    inc     %r14
    movq    %r10, %rax
    xorq    %rsi, %rsi          # Clear %rsi (used to store the remainder)
    xorq    %rcx, %rcx

    movq    $0, %rbx            # Prepare %rbx for reversing the digits
    movq    $10, %rcx           # Set divisor to 10

    cmpq    $0, %rax            # Check if the number is zero
    jne     integer_convert_loop

    jmp     add_zero
/* ----------------------------------------------------------------- */
jump_over_in_stack_signed:
    addq    $16, %r11
    movq    (%r11), %r10
    jmp     prepare_conversion_signed

signed_int_argument:
    xorq    %r10, %r10
    cmpq    $5, %r14
    je      jump_over_in_stack_signed
    movq    (%r11), %r10

prepare_conversion_signed:
    inc     %r14
    movq    %r10, %rax
    xorq    %rsi, %rsi          # Clear %rsi (used to store the remainder)
    xorq    %rcx, %rcx

    movq    $0, %rbx            # Prepare %rbx for reversing the digits
    movq    $10, %rcx           # Set divisor to 10

    cmpq    $0, %rax
    jge     integer_convert_loop

    cmpq    $0, %rax            # Check if the number is zero
    je      add_zero

    negq    %rax                # Convert to positive by negating %rax
    
    pushq   %rax
    pushq   %rdi
    pushq   %rdx
    pushq   %rcx
    pushq   %r11
    movq    $0, (%r13)
    movb    $'-', (%r13)     # Store the character in the buffer
    movq    $1, %rax             # Syscall number (1 = write)
    movq    $1, %rdi             # File descriptor (1 = stdout)
    movq    %r13, %rsi           # Address of the character to print
    movq    $1, %rdx             # Number of bytes (1 character)
    syscall                      # Perform the syscall
    popq    %r11
    popq    %rcx
    popq    %rdx
    popq    %rdi
    popq    %rax
    
    inc     %r12                # Increment the final_string length

    jmp     integer_convert_loop

/* ---------------------------------------------------------------- */
add_zero:
    pushq   %r11
    movq    $0, (%r13)
    movb    $'0', (%r13)     # Store the character in the buffer
    movq    $1, %rax             # Syscall number (1 = write)
    movq    $1, %rdi             # File descriptor (1 = stdout)
    movq    %r13, %rsi           # Address of the character to print
    movq    $1, %rdx             # Number of bytes (1 character)
    syscall                      # Perform the syscall
    popq    %r11

    inc     %r12
    inc     %r15
    addq    $8, %r11
    jmp     find_arguments

integer_convert_loop:
    xorq    %rdx, %rdx          # Clear the remainder (%rdx)
    divq    %rcx                # Divide %rax by 10. Result in %rax, remainder in %rdx
    addb    $'0', %dl           # Convert remainder to ASCII ('0' + remainder)
    
    pushq   %rdx                # Push the digit onto the stack (we need to reverse the order)
    inc     %rbx                # Increment the number of digits pushed

    testq   %rax, %rax          # Check if we are done (if the quotient is 0)
    jne     integer_convert_loop
 
reverse_digits:
    popq    %rdx                # Pop the digit from the stack
    
    pushq   %r11
    movq    $0, (%r13)
    movb    %dl, (%r13)     # Store the character in the buffer
    movq    $1, %rax             # Syscall number (1 = write)
    movq    $1, %rdi             # File descriptor (1 = stdout)
    movq    %r13, %rsi           # Address of the character to print
    movq    $1, %rdx             # Number of bytes (1 character)
    syscall                      # Perform the syscall
    popq    %r11

    inc     %r12                # Increase the final_string length
    dec     %rbx                # Decrement the digit counter
    testq   %rbx, %rbx          # Check if all digits have been reversed
    jne     reverse_digits

    inc     %r15 
    addq    $8, %r11
    jmp     find_arguments    

/* ---------------------------------------------------------------------- */

fake_argument:
    pushq   %rax
    pushq   %r11
    movq    $0, (%r13)
    movb    $'%', (%r13)     # Store the character in the buffer
    movq    $1, %rax             # Syscall number (1 = write)
    movq    $1, %rdi             # File descriptor (1 = stdout)
    movq    %r13, %rsi           # Address of the character to print
    movq    $1, %rdx             # Number of bytes (1 character)
    syscall                      # Perform the syscall
    popq    %r11
    popq    %rax
    
    inc     %r12
    jmp     next_char

percent_argument:
    testb   %al, %al
    je      done

    pushq   %r11
    movq    $0, (%r13)
    movb    %al, (%r13)     # Store the character in the buffer
    movq    $1, %rax             # Syscall number (1 = write)
    movq    $1, %rdi             # File descriptor (1 = stdout)
    movq    %r13, %rsi           # Address of the character to print
    movq    $1, %rdx             # Number of bytes (1 character)
    syscall                      # Perform the syscall
    popq    %r11

    inc     %r12
    inc     %r15
    jmp     find_arguments

done:
    # calee saved registers
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rbx
    
    # clear stack (cuz we wanna be sure)
    popq    %r9
    popq    %r8
    popq    %rcx
    popq    %rsi
    popq    %rdx

    # epilogue  
	movq	%rbp, %rsp		# clear local variables from stack
	popq	%rbp			# restore base pointer location 
	ret

main:
	pushq	%rbp 			# push the base pointer (and align the stack)
	movq	%rsp, %rbp		# copy stack pointer value to base pointer
  
    movq    $format_string, %rdi
    movq    $input_1, %rsi
    movq    $input_2, %rdx
    movq    $input_3, %rcx
    movq    $input_4, %r8
    movq    input_5, %r9

/*pt testat-----------------------------------------------------------*/
   movq    $input_8, %r10
    pushq   %r10
    movq    $input_8, %r10
    pushq   %r10
    movq    $input_7, %r10
    pushq   %r10
    movq    input_6, %r10
    pushq   %r10
    

    xorq    %r10, %r10
/*pt testat ---------------------------------------------------------*/
    

    call    my_printf

    movq	%rbp, %rsp		# clear local variables from stack
	popq	%rbp			# restore base pointer location 

	movq    $60, %rax             # Syscall number (60 = exit)
    xorq    %rdi, %rdi             # Exit status 0
    syscall  


	