.section .data
    file1:      .asciz "line 0\n\n\n extra"

    file2:      .asciz "line 1\n line 2"
    character: .asciz "%c"
    character2: .asciz "%c\n"
    decimal: .asciz "%d "
    decimal2: .asciz "%d\n"
    digit: .asciz "%dc%d\n"
    format: .asciz "< "
    format2: .asciz "> "
    format3: .asciz "---\n"
    test: .asciz "this function is called\n"
    enter: .asciz "\n"
    i_string:  .asciz "-i"      # The string for -i flag
    B_string:  .asciz "-B"      # The string for -B flag
    inputs:  .asciz "-i -B"      # The string for -B flag
    string: .asciz "%s\n"

.section .bss
    cleaned_file1: .space 30000  # Space for cleaned file (adjust size as needed)
    cleaned_file2: .space 30000  # Space for cleaned file (adjust size as needed)

.section .text
.global main

main:

   // the number of arguments starts in %rdi and the arguments are in %rsi (rsi is a pointer to the first argument, which is the name of the program)

    pushq	%rbp 					# prologue
	movq    %rsp, %rbp

    movq    %rdi, %rbx             
    cmp     $1, %rbx
    je  no_arguments                 # if there is only one argument (the name, ship the arguments phase)
    movq    8(%rsi), %rcx              # set the argument for first flag
    movq    16(%rsi), %rdx             # set the argument for second flag

no_arguments:
    subq    $1, %rbx   

    movq    $0, %r8           # Set 'ignore case' flag (-i) to 0   
    movq    $0, %r9           # Set 'ignore blank lines' flag (-B) to 0

    movq    $file1, %r12       # Pass pointer to file1
    movq    $file2, %r13       # Pass pointer to file2
check_flags:

    cmp     $0, %rbx                # if there are no more arguments we continue the program
    je  continue_start

    movb    (%rcx), %al      # Load the current argument (argv[i]) into r11
    cmpb    $'-', %al        # Compare it with '-'
    jne     next_arg          # If it's not '-', jump to the next argument


    movb    1(%rcx), %al      # Load the second byte (the "i") from %r10+1
    cmpb    $'i', %al         # Compare it with 'i'
    je  set_flag_i          # If it's 'i', set the i flag

    cmpb    $'B', %al         # Compare it with 'B'
    je  set_flag_B          # If it's 'B', set the B flag

    # Move to the next argument
    jmp     next_arg

set_flag_i:
    movq    $1, %r8        # Set %r8 (the -i flag) to 1
    jmp     next_arg

set_flag_B:
    movq    $1, %r9        # Set %r9 (the -B flag) to 1
    jmp     next_arg

next_arg:
    subq    $1, %rbx
    movq    %rdx, %rcx         # check for the second flag (that was in %rcx)
    jmp     check_flags         # Repeat the check for the next argument   

continue_start:

    // when call diff:
    // %r8 is the -i flag
    // %r9 is the -B flag
    // %r12 is file1
    // %r13 is file2

    // rdx has to be -i
    // rcx has to be -B
    // rdi and rsi need to have file1 and file2
    // I move everything to the correct register and in diff I move them back because that's how my code works and it's easier than to change everything
    movq    %r8, %rdx
    movq    %r9, %rcx
    movq    %r12, %rdi
    movq    %r13, %rsi

    pushq   %rax
    pushq   %rbx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15

    call diff

    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rbx
    popq    %rax

    jmp finish      # exit the program
    
diff:

    pushq	%rbp 					# prologue
	movq	%rsp, %rbp
    
    pushq   %rax
    pushq   %rbx
    pushq   %rdi
    pushq   %rsi
    pushq   %rcx
    pushq   %rdx            # push all the registers because why not
    pushq   %r10
    pushq   %r11
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15

    movq    %rdx, %r8          # Here I move everything back so in the registers I work with
    movq    %rcx, %r9
    movq    %rdi, %r12
    movq    %rsi, %r13


    movq    $1, %r14           # The current line number
    movq    $0, %r15           # %r15 is 1 if the current line has to change and has to be printed



    cmp     $1, %r9         # if the -B flag is 1, we delete from the texts every empty line
    je      flag_check_B

before_diff2:       # we need this in case %r12 and %r13 change if the -B flag is 1 and they get pointers to the cleaned files instead of the normal ones
    movq    %r12, %rcx           # Set both pointers that point to the start of the line
    movq    %r13, %rdx

diff2:

    movb    (%r12), %al
    movb    (%r13), %bl


    testb   %bl, %bl      #if the line in file2 reached the null character (end), we have to also bring the pointer in file1 to the end of the line 
    je      verifier1

    testb   %al, %al      #if the line in file1 reached the null character (end), we have to also bring the pointer in file2 to the end of the line 
    je      verifier2


    cmpb    %al, %bl
    jne     different       # if the characters are different


    cmp     $'\n', %bl      #if the line in file2 reached the end of the line, we have to also bring the pointer in file1 to the end of the line
    je      skip_text1

    cmp     $'\n', %al
    je      skip_text2

    

    jmp     next_char       # go to the next character

next_char:
    movb    (%r12), %al
    movb    (%r13), %bl

    testb   %al, %al      # if file1 reached the null character, we don't increase the line number for file1
    je      increase_second

increase_first:
    incq    %r12

increase_second:    
    testb   %bl, %bl      # if file2 reached the null character, we don't increase the line number for file2
    je      returner                                
    incq    %r13

returner:
    jmp     diff2           # go back to processing the next character


verifier1:          # we got here because file2 reached the null character
    testb   %al, %al
    je      skip_text1

    cmp     $'\n', %al
    je      skip_text1

    jmp     different       # if file1 hasn't reached the null character or the end of the line, that means the current lines are different

verifier2:          # we got here because file1 reached the null character
    testb   %bl, %bl
    je      skip_text2

    cmp     $'\n', %bl
    je      skip_text2

    jmp     different       # if file2 hasn't reached the null character or the end of the line, that means the current lines are different

different:

    cmp     $0, %r8     # if the -i flag is 0, we know the characters are different so we jump to the function that increases %r15 and tells us that the lines are different
    je      add_r15

    cmpb    $'A', %al
    jl      capital_bl

    cmpb    $'Z', %al
    jg      capital_bl

    addb    $32, %al       # we only change the character in file1 if it's a capital letter

    cmp     %al, %bl        # If the characters are the same we do not increase the %r15 (we don't consider the characters to be different)
    je      al_different_i   # and we go to reverse the change in %al and make it a capital letter again 

    addq    $1, %r15
    jmp     different_i

capital_bl:     # we reached here because %al is not a capital letter

    cmpb    $'A', %bl
    jl      add_r15

    cmpb    $'Z', %bl
    jg      add_r15

    addb    $32, %bl       # we only change the character in file2 if it's a capital letter

    cmp     %al, %bl        # If the characters are the same we do not increase the %r15 (we don't consider the characters to be different)
    je      bl_different_i   # and we go to reverse the change in %al and make it a capital letter again 

    addq    $1, %r15
    jmp     different_i


al_different_i:
    sub     $32, %al
    jmp     different_i

bl_different_i:
    sub     $32, %bl
    jmp     different_i

add_r15:
    addq    $1, %r15

different_i:        # we reached here knowing if the current characters are considered to be different or not
                    # we do the same thing we do in diff2, except now %r15 is set or not set  (depends on the -i flag and the characters)
    testb   %bl, %bl
    je      skip_text1

    testb   %al, %al
    je      skip_text2


    cmp     $'\n', %bl
    je      skip_text1

    cmp     $'\n', %al
    je      skip_text2

    jmp     next_char


skip_text1:     # if file2 has reached either the end of the line or the null character, we have to move the file1 pointer to the end of the line as well

    movb    (%r12), %al

    cmp     $'\n', %al
    je      condition
    testb   %al, %al
    je      if_final
    inc     %r12
    jmp     skip_text1

skip_text2:     # if file1 has reached either the end of the line or the null character, we have to move the file2 pointer to the end of the line as well
                                
    movb    (%r13), %bl

    cmp     $'\n', %bl
    je      condition
    testb   %bl, %bl
    je      if_final     #if file2 reached the null character, we chech if we should print sth or not
    inc     %r13
    jmp     skip_text2

if_final:       # we reached here because one of the files reached the null pointer and we either print something (if %r15 tells us to) or we are done

    cmp     $0, %r15
    jne     printer
    jmp     done

condition:       # we reached here when both files reached the end of the line (\n) and print something (if %r15 tells us to) 
    cmp     $0, %r15
    jne     printer

line_reset:     # if we don't print anything we set everything up to begin comparing the next lines of the files

    movq    %r12, %rcx     # we move %rcx (that points to the start of the current line in file1) to the start of the next line
    movq    %r13, %rdx     # we move %rdx (that points to the start of the current line in file2) to the start of the next line
    movb    (%rcx), %al
    movb    (%rdx), %bl

    testb   %al, %al
    je      skip1
    inc     %rcx        # if file1 didn't reach the null pointer, we go to the next character so %rcx points to the first character in the line, not '\n'

skip1:
    testb   %bl, %bl
    je      skip2
    inc     %rdx        # if file2 didn't reach the null pointer, we go to the next character so %rdx points to the first character in the line, not '\n'

skip2:
    addq    $1, %r14       # we increase the line number
    jmp     next_char

printer:        # this prints the output with the correct format

    pushq   %rax
    pushq   %rbx
    pushq   %rdi
    pushq   %rsi
    pushq   %rcx
    pushq   %rdx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    movq    $digit, %rdi           #printig the '1c1'
    movq    %r14, %rsi
    movq    %r14, %rdx
    call    printf
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rdx
    popq    %rcx
    popq    %rsi
    popq    %rdi
    popq    %rbx
    popq    %rax

    pushq   %rax
    pushq   %rbx
    pushq   %rdi
    pushq   %rsi
    pushq   %rcx
    pushq   %rdx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    movq    $format, %rdi           # printing the '< '
    call    printf
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rdx
    popq    %rcx
    popq    %rsi
    popq    %rdi
    popq    %rbx
    popq    %rax

    movb    (%rcx), %al
    testb   %al, %al
    je      slashn           # we make sure not to print the null character


print_loop_first:

    movb    (%rcx), %al

    testb   %al, %al      # we make sure not to print the null character
    je      slashn

    cmp     $'\n', %al      # if file1 reached the end of the line, we increase %rcx so it points to the first character in the line, not '\n'
    je add_one_character_file1

    pushq   %rax
    pushq   %rbx
    pushq   %rdi
    pushq   %rsi
    pushq   %rcx
    pushq   %rdx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    movq    $character, %rdi           # printing each character for the first file
    movsbl  %al, %esi         # Zero-extend the byte to an int for printing
    call    printf
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rdx
    popq    %rcx
    popq    %rsi
    popq    %rdi
    popq    %rbx
    popq    %rax

    inc     %rcx

    jmp     print_loop_first
    

add_one_character_file1:
    inc     %rcx

slashn:
    pushq   %rax
    pushq   %rbx
    pushq   %rdi
    pushq   %rsi
    pushq   %rcx
    pushq   %rdx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    movq    $enter, %rdi           # printing the '\n'
    call    printf
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rdx
    popq    %rcx
    popq    %rsi
    popq    %rdi
    popq    %rbx
    popq    %rax

ski:


    pushq   %rax
    pushq   %rbx
    pushq   %rdi
    pushq   %rsi
    pushq   %rcx
    pushq   %rdx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    movq    $format3, %rdi           # printing the '---'
    call    printf
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rdx
    popq    %rcx
    popq    %rsi
    popq    %rdi
    popq    %rbx
    popq    %rax

skip_the_first:
    pushq   %rax
    pushq   %rbx
    pushq   %rdi
    pushq   %rsi
    pushq   %rcx
    pushq   %rdx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    movq    $format2, %rdi           # printing the '> '
    call    printf
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rdx
    popq    %rcx
    popq    %rsi
    popq    %rdi
    popq    %rbx
    popq    %rax

print_loop_second:  

    movb    (%rdx), %bl

    testb   %bl, %bl      # we make sure not to print the null character
    je      done_second

    cmp     $'\n', %bl      # if file2 reached the end of the line, we increase %rdx so it points to the first character in the line, not '\n'
    je      add_one_character_file2

    pushq   %rax
    pushq   %rbx
    pushq   %rdi
    pushq   %rsi
    pushq   %rcx
    pushq   %rdx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    movq    $character, %rdi           # printing each character for the second file
    movsbl  %bl, %esi         # Zero-extend the byte to an int for printing
    call    printf
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rdx
    popq    %rcx
    popq    %rsi
    popq    %rdi
    popq    %rbx
    popq    %rax

    inc     %rdx

    
    jmp     print_loop_second

add_one_character_file2:
    inc     %rdx

done_second:

    pushq   %rax
    pushq   %rbx
    pushq   %rdi
    pushq   %rsi
    pushq   %rcx
    pushq   %rdx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    movq $enter, %rdi           # printing the '\n'
    call printf
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rdx
    popq    %rcx
    popq    %rsi
    popq    %rdi
    popq    %rbx
    popq    %rax


    addq    $1, %r14       # we add 1 to the line number
    movq    $0, %r15       # we reset %r15
    jmp     next_char


done:

    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %r11
    popq    %r10
    popq    %rdx
    popq    %rcx
    popq    %rsi
    popq    %rdi
    popq    %rbx
    popq    %rax

    movq	%rbp, %rsp				# epilogue
	popq	%rbp
    ret

finish:

    movq	%rbp, %rsp				# epilogue
	popq	%rbp
    # Exit the program
    movq    $60, %rax          # Exit syscall number (60)
    movq    $0, %rdi         # Exit code 0
    call exit

//////////////////////////////////////////////////////                                                           /////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////     Here we modify the texts to exclude any empty lines   /////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////                                                           /////////////////////////////////////////////////////////////////////
flag_check_B:

    movq    %r12, %r10       # Pass pointer to file1
    movq    %r13, %r11       # Pass pointer to file2

function_B1:

    movq    $cleaned_file1, %r12    # Pointer to cleaned_file1 which is empty
    movq    $cleaned_file2, %r13    # Pointer to cleaned_file2 which is empty

    movq    $0, %r15       # %r15 becomes 1 if the line is not empty and should be copied to the cleaned_files

loop_B1:

    movb    (%r10),  %al

    testb   %al, %al      # if we reached the end of file1 we add the null character and continue to file2
    je      add_null1

    cmpb    $'\n', %al     # if we reached the end of the line we verify it the line was empty or not
    je      verify_line1

    movq    $1, %r15                # Reset blank flag, as it's not a blank line
    movb    %al, (%r12)             # Copy character to cleaned_file
    inc     %r10                     # Increment pointer in cleaned_file
    inc     %r12                     # Increment pointer in original file
    jmp     loop_B1

verify_line1:
    cmp     $1, %r15
    je      not_blank1

    inc     %r10        # if the lien was blank we just skip the '\n'
    jmp     loop_B1

not_blank1:         # if the line was not blank we reset %r15 and move the '\n' to the cleaned_file
    
    movq    $0, %r15                # Reset blank flag, as it's a new line
    movb    %al, (%r12)             # Copy character to cleaned_file
    inc     %r10                     # Increment pointer in cleaned_file
    inc     %r12                     # Increment pointer in original file
    jmp     loop_B1

add_null1:
    movb    $0, (%r12)         # we add the null character at the end

    movq    $0, %r15

loop_B2:

    movb    (%r11),  %bl

    testb   %bl, %bl      # if we reached the end of file2 we add the null character and continue to diff
    je      add_null2

    cmpb    $'\n', %bl     # if we reached the end of the line we verify it the line was empty or not
    je      verify_line2

    movq    $1, %r15                # Reset blank flag, as it's not a blank line
    movb    %bl, (%r13)             # Copy character to cleaned_file
    inc     %r11                     # Increment pointer in cleaned_file
    inc     %r13                     # Increment pointer in original file
    jmp     loop_B2

verify_line2:
    cmp     $1, %r15
    je      not_blank2

    inc     %r11        # if the lien was blank we just skip the '\n'
    jmp     loop_B2

not_blank2:         # if the line was not blank we reset %r15 and move the '\n' to the cleaned_file
    
    movq    $0, %r15                # Reset blank flag, as it's a new line
    movb    %bl, (%r13)             # Copy character to cleaned buffer
    inc     %r11                     # Increment pointer in cleaned buffer
    inc     %r13                     # Increment pointer in original file
    jmp     loop_B2 

add_null2:
    movb    $0, (%r13)         # we add the null character at the end

    movq    $cleaned_file1, %r12       # reset the pointers to the begining of the texts
    movq        $cleaned_file2, %r13

    movq    $0, %r15       # reset %r15 to prepare it for diff

    jmp     before_diff2
