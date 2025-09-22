.data
	array: .zero 30000

.text
	format_str: .asciz "We should be executing the following code:\n %s"
	character: .asciz "%c"

.global brainfuck


brainfuck:
	pushq %rbp
	movq %rsp, %rbp			#prologue
	push %rbx
	push %r13
	push %r14
	push %r14


	movq %rdi, %r13         # %r13 holds the pointer to the Brainfuck code
	
	movq $array, %r14          # Store the tape pointer in %r14

	movq $0, %rbx			 # in %rbx we hold the current level of []


parse_loop:
	movb (%r13), %al         # Load the current character of the code
    test %al, %al
    jz brainfuck_end        # If the character is null, exit the loop

	cmpb $'>', %al
    je increment_ptr        # Jump to increment pointer if '>'
    cmpb $'<', %al
    je decrement_ptr        # Jump to decrement pointer if '<'
    cmpb $'+', %al
    je increment_value      # Jump to increment value if '+'
    cmpb $'-', %al
    je decrement_value      # Jump to decrement value if '-'
    cmpb $'.', %al
    je output_value         # Jump to output value if '.'
    cmpb $',', %al
    je input_value          # Jump to input value if ','
    cmpb $'[', %al
	je loop_start           # Jump to loop start if '['
	cmpb $']', %al
    je loop_stop             # Jump to loop end if ']'

    jmp next_char           # Continue to the next character

next_char:
	inc %r13
	jmp parse_loop

increment_ptr:
	incq %r14			# basically is add $8, %r14
	jmp next_char

decrement_ptr:
	decq %r14
	jmp next_char

increment_value:
	movb (%r14), %al
	incb %al
	movb %al, (%r14)
	jmp next_char

decrement_value:
	movb (%r14), %al
	decb %al
	movb %al, (%r14)
	jmp next_char

output_value:
	movb (%r14), %al
	movq $character, %rdi
	movsbl %al, %esi         # Zero-extend the byte to an int for printing
    call printf
    jmp next_char

input_value:
    movq $character, %rdi
	movq %r14, %rsi
    call scanf               # Call scanf to read a character
    jmp next_char


loop_start:
	# Check if the value at the data pointer is zero; if so, jump to the matching ']'
	addq $1, %rbx
    movb (%r14), %al
			
    cmp $0, %al
    je skip_loop
	jmp next_char

skip_loop:
	inc %r13
	movq %rbx, %rcx;			#in %rcx we remember the level we have to skip


skip_forward:				# to skip to the correct ]
	movb (%r13), %al
	cmpb $'[', %al
	je adder
	cmpb $']', %al
	je decreaser

	inc %r13
	jmp skip_forward

adder:					# to increase the level
	addq $1, %rbx
	inc %r13
	jmp skip_forward

decreaser:					# to decrease the level and verify if we got to the one we need to skip
	cmp %rbx, %rcx
	je end_loop
	subq $1, %rbx
	inc %r13
	jmp skip_forward

end_loop:
	inc %r13
	jmp parse_loop

loop_stop:
	movb (%r14), %al

	cmp $0, %al
	jne repeat
	decq %rbx
	jmp next_char

repeat:
	decq %r13
	movq %rbx, %rcx			# in %rcx we remember the level we have to skip
	decq %rcx

go_back:				# to skip to the correct ]
	movb (%r13), %al
    cmpb $']', %al
	je adder2
	cmpb $'[', %al
	je decreaser2

	decq %r13
	jmp go_back


adder2:					# to increase the level
	addq $1, %rbx
	dec %r13
	jmp go_back

decreaser2:					# to decrease the level and verify if we got to the one we need to skip
	subq $1, %rbx
	cmp %rbx, %rcx
	je parse_loop
	dec %r13
	jmp go_back


brainfuck_end:

	movq $0, %rdi

	popq %r14
	popq %r14
	popq %r13
	popq %rbx
	movq %rbp, %rsp			#epilogue
	popq %rbp
	ret
