.intel_syntax noprefix
.global json_prettify

.text

//int json_prettify(const char* json, char* out);
/* to access character = [rdi+x]*/
/*
    TODO : check rbp, r15, r11 conditions
*/
json_prettify:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    mov r10, 1
    mov rcx, 0

    // r12 : square bracket count
    mov r12, 0
    // r13 : curly bracket count
    mov r13, 0
    // r14 : tab count
    mov r14, 0
    // r15
    /* boolean -->
        a : 0 --> not in object
            1 --> in object
        --------------------------
        b : 0 --> key required
            1 --> value required
            2 --> is there a comma
        --------------------------
        c : 0 --> not in array
            1 --> in array
    */
    mov r15, 0

    // rbp : control so we know if it's in object, array, or none
    /*
        mov [rbp-x] to access

        { --> {
        } --> }
        [ --> [
        ] --> ]
        k --> key
        : --> :
        v --> value
        , --> ,

    */
    mov rbp, rsp
    sub rbp, 64
    // rbx is indexing for rbp
    mov rbx, 0
    jmp .value_iterator

/* iterate through json and processes it */
.value_iterator:
    sub rsp, 8
    call whitespace_skip
    add rsp, 8

    mov cl, [rdi]

    cmp r10, 7
    cmp cl, ','
    je .comma

    /* check if curly bracket */
    mov r10, 2
    cmp cl, '{'
    je .process_object

    /* check if square bracket */
    mov r10, 3
    cmp cl, '['
    je .process_array

    /* check if literal */
    mov r10, 4
    cmp cl, 't'
    je .process_literal
    cmp cl, 'f'
    je .process_literal
    cmp cl, 'n'
    je .process_literal

    /* check if string */
    mov r10, 5
    cmp cl, '"'
    je .process_string

    /* check if number */
    mov r10, 6
    cmp cl, '-'
    je .process_number
    cmp cl, '0'
    jb .error
    cmp cl, '9'
    jbe .process_number


    mov r10, 420
    jmp .error


.comma:
    /* find out if comma is in object or array */
    mov r8, rbp
    mov r9, 0
    .check_rbp:
        cmp r9, rbx
        je .error
        cmp byte ptr [r8], '{'
        je .comma_object
        cmp byte ptr [r8], '['
        je .comma_array
        inc r8
        dec r9
        jmp .check_rbp
    
    .comma_object:
        /* 
            rbp = {kv^
            we want to make it {^
        */

        mov byte ptr [rsi], ','
        inc rsi
        inc rdi

        sub rsp, 8
        call whitespace_skip
        add rsp, 8

        /* {kv^ --> {^ */
        add rbp, 2
        sub rbx, 2

        /* check again for key */
        jmp .object_not_empty

    .comma_array:


     

/*======================================================================*/

.process_object:
    /* once opening { is found, we store it in rbp
       and also write it on the rsi. */

    mov byte ptr [rbp], '{'
    mov byte ptr [rsi], '{'
    dec rbp
    inc rbx
    inc rsi
    inc rdi
    inc r14


    sub rsp, 8
    call whitespace_skip
    add rsp, 8

    /* check if object is empty */
    cmp byte ptr [rdi], '}'
    jne .object_not_empty

    /* if object is empty, we write } */
    mov byte ptr [rsi], '}'
    /* change {^ --> v^ */
    mov byte ptr [rbp+1], 'v'

    inc rsi
    inc rdi

    dec r14

    sub rsp, 8
    call whitespace_skip
    add rsp, 8

    /* check if there's a comma, bracket, braces, or 0*/
    cmp byte ptr [rdi], ','
    je .curly_comma_empty
    cmp byte ptr [rdi], '}'
    je .curly_brace_empty
    cmp byte ptr [rdi], ']'
    je .end
    cmp byte ptr [rdi], 0
    je .curly_end

    /* if there's none of the above, then it's an error */
    mov r10, 20
    jmp .error
    /* TODO : IMPLEMENT COMMA FEATURE */

    .curly_comma_empty:
        /* {^ --> v^ */
        mov byte ptr [rbp+1], 'v'
        jmp .comma

    .curly_brace_empty:
        /* {^ --> ^ */
        inc rbp
        dec rbx
        jmp .process_object_close

    .curly_end:
        /* {^ --> ^ */
        inc rbp
        dec rbx
        jmp .end

    /* if object is not empty then process key */
    .object_not_empty:
    /* check if key is string */
    mov r10, 21
    cmp byte ptr [rdi], '"'
    jne .error

    /* if key is string, then process it */
    mov byte ptr [rsi], '\n'
    inc rsi

    /* write tabs */
    mov r10, 22
    cmp r14, 0
    jl .error
    mov rdx, r14
    .curly_key_tabbing:
        cmp rdx, 0
        je .curly_key_tabbing_end
        mov byte ptr [rsi], ' '
        inc rsi
        mov byte ptr [rsi], ' '
        inc rsi
        mov byte ptr [rsi], ' '
        inc rsi
        mov byte ptr [rsi], ' '
        inc rsi
        dec rdx
        jmp .curly_key_tabbing
    .curly_key_tabbing_end:

    /* write key */
    mov byte ptr [rbp], 'k'
    dec rbp
    inc rbx

    jmp .process_string


        

    .process_object_close:
        mov r10, 23
        mov byte ptr [rsi], '\n'
        inc rsi
        dec r14

        /* write tabs */
        cmp r14, 0
        jl .error
        mov rdx, r14
        .curly_close_tabbing:
            cmp rdx, 0
            je .curly_close_tabbing_end
            mov byte ptr [rsi], ' '
            inc rsi
            mov byte ptr [rsi], ' '
            inc rsi
            mov byte ptr [rsi], ' '
            inc rsi
            mov byte ptr [rsi], ' '
            inc rsi
            dec rdx
            jmp .curly_close_tabbing
        .curly_close_tabbing_end:
        mov byte ptr [rsi], '}'
        inc rsi
        inc rdi

        /*  right now, 
            rbp = ...{kv^ 
            ^ = cursor
        */
        
        sub rsp, 8
        call whitespace_skip
        add rsp, 8

        /* check if there's a comma, bracket, braces, or 0*/
        cmp byte ptr [rdi], ','
        je .curly_close_comma
        cmp byte ptr [rdi], '}'
        je .process_object_close_intermediate
        cmp byte ptr [rdi], ']'
        je .process_array
        cmp byte ptr [rdi], 0
        je .end_intermediate

        /* if there's none of the above, then it's an error */
        mov r10, 24
        jmp .error


        .curly_close_comma:
            /*  if comma is found, then that signifies that
                there's another key-value pair in the object
                and that the previous key-value pair is done: 
                    ...{kv^ --> ...v^ 
                so that the key will be searched again */

        /* ...{kv^ --> ...v^ */

        add rbp, 2
        sub rbx, 2
        mov byte ptr [rbp+1], 'v'
        jmp .comma

        .process_object_close_intermediate:
            /* collapse ...{kv^ --> ^ */
            add rbp, 3
            sub rbx, 3
            jmp .process_object_close

        .end_intermediate:
            /* collapse ...{kv^ --> ^ */
            add rbp, 3
            sub rbx, 3
            jmp .end
        



/*======================================================================*/

.process_array:
    jmp .end

/*======================================================================*/

.process_string:
    mov byte ptr [rsi], '\"'
    inc rsi
    inc rdi

    .char_loop:
        /* check if char is escape char */
        cmp byte ptr [rdi], '\\'
        je .escape_char
        /* check if char is end of string */
        cmp byte ptr [rdi], '\"'
        je .end_of_string

        /* illegal char */
        mov r10, 50
        cmp byte ptr [rdi], 0x1F
        jbe .error

        /* copy char */
        mov cl, [rdi]
        mov [rsi], cl
        inc rsi
        inc rdi

        jmp .char_loop

    /* process escaped characters */
    .escape_char:
        mov byte ptr [rsi], '\\'
        inc rsi
        inc rdi

        mov cl, [rdi]
        cmp cl, '\"'
        je .escaped_next
        cmp cl, '\\'
        je .escaped_next
        cmp cl, '/'
        je .escaped_next
        cmp cl, 'b'
        je .escaped_next
        cmp cl, 'f'
        je .escaped_next
        cmp cl, 'n'
        je .escaped_next
        cmp cl, 'r'
        je .escaped_next
        cmp cl, 't'
        je .escaped_next
        cmp cl, 'u'
        je .escaped_next

        mov r10, 51
        jmp .error


    .escaped_next:
        mov cl, [rdi]
        inc rdi
        cmp cl, 'u'
        je .unicode_char
        mov [rsi], cl
        inc rsi
        jmp .char_loop

    .unicode_char:
        mov byte ptr [rsi], 'u'
        inc rsi

        /* check if there are 4 hex*/
        mov rdx, 4
        four_hex:
            mov cl, [rdi]
            mov r10, 52
            cmp cl, '0'
            jb .error
            mov r10, 53
            cmp cl, '9'
            jbe .is_hex
            mov r10, 54
            cmp cl, 'A'
            jb .error
            mov r10, 55
            cmp cl, 'F'
            jbe .is_hex
            mov r10, 56
            cmp cl, 'a'
            jb .error
            mov r10, 57
            cmp cl, 'f'
            jbe .is_hex

            /* not hex */
            mov r10, 58
            jmp .error

        .is_hex:
            mov [rsi], cl
            inc rsi
            inc rdi
            dec rdx
            cmp rdx, 0
            jne four_hex

        jmp .char_loop

.end_of_string:
    mov byte ptr [rsi], '\"'
    inc rsi
    inc rdi

    /* erase whitespace and check if this is a key string or a value string*/
    sub rsp, 8
    call whitespace_skip
    add rsp, 8

    cmp byte ptr [rdi], ':'
    je .key_string

    mov byte ptr [rbp], 'v'
    dec rbp
    inc rbx

    cmp byte ptr [rdi], ','
    je .comma
    cmp byte ptr [rdi], '}'
    je .process_object_close
    cmp byte ptr [rdi], ']'
    je .end
    cmp byte ptr [rdi], 0
    je .end


    mov r10, 59
    jmp .error

    .key_string:
        mov r10, 800
        cmp byte ptr [rbp+1], 'k'
        jne .error

        mov byte ptr [rsi], ':'
        inc rsi
        inc rdi

        jmp .value_iterator




/*====================================================================== */


.process_number:

    mov byte ptr [rbp], 'v'
    dec rbp
    inc rbx

    /* check if first char is negative sign */
    cmp byte ptr [rdi], '-'
    jne .zero_check
    mov byte ptr [rsi], '-'
    inc rsi
    inc rdi

    /* check if first digit is zero */
    .zero_check:
        cmp byte ptr [rdi], '0'
        jne .first_digit_check
        mov byte ptr [rsi], '0'
        inc rsi
        inc rdi

    /* check if 0 is the only digit */
    sub rsp, 8
    call whitespace_skip
    add rsp, 8

    cmp byte ptr [rdi], ','
    je .comma
    cmp byte ptr [rdi], '}'
    je .process_object_close
    cmp byte ptr [rdi], ']'
    je .end
    cmp byte ptr [rdi], 0
    je .end

    cmp byte ptr [rdi], '.'
    je .decimal_check
    cmp byte ptr [rdi], 'e'
    je .exponent_check
    cmp byte ptr [rdi], 'E'
    je .exponent_check
    jmp .error

    /* check if first digit is between 1-9 */
    .first_digit_check:
        mov r10, 62
        cmp byte ptr [rdi], '1'
        jb .error

        mov r10, 63
        cmp byte ptr [rdi], '9'
        ja .error

        mov cl , [rdi]
        mov [rsi], cl
        inc rsi
        inc rdi

    .digit_check_before_decimal:
    /* check if number is only a digit */
        sub rsp, 8
        call whitespace_skip
        add rsp, 8

        cmp byte ptr [rdi], ','
        je .comma
        cmp byte ptr [rdi], '}'
        je .process_object_close
        cmp byte ptr [rdi], ']'
        je .end
        cmp byte ptr [rdi], 0
        je .end

        mov cl, [rdi]
        cmp cl, '.'
        je .decimal_check
        cmp cl, 'e'
        je .exponent_check
        cmp cl, 'E'
        je .exponent_check

        mov r10, 64
        cmp cl, '0'
        jb .error
        mov r10, 65
        cmp cl, '9'
        ja .error

        mov cl, [rdi]
        mov [rsi], cl
        inc rsi
        inc rdi
        jmp .digit_check_before_decimal

    /*check the decimals*/
    .decimal_check:
        mov byte ptr [rsi], '.'
        inc rsi
        inc rdi
        mov r10, 66
        cmp byte ptr [rdi], '0'
        jb .error
        mov r10, 67
        cmp byte ptr [rdi], '9'
        ja .error
        mov cl, [rdi]
        mov [rsi], cl
        inc rsi
        inc rdi

    .digit_check_after_decimal:
        sub rsp, 8
        call whitespace_skip
        add rsp, 8

        cmp byte ptr [rdi], ','
        je .comma
        cmp byte ptr [rdi], '}'
        je .process_object_close
        cmp byte ptr [rdi], ']'
        je .end
        cmp byte ptr [rdi], 0
        je .end

        mov cl, [rdi]
        cmp cl, 'e'
        je .exponent_check
        cmp cl, 'E'
        je .exponent_check
        mov r10, 68
        cmp cl, '0'
        jb .error
        mov r10, 69
        cmp cl, '9'
        ja .error

        mov cl, [rdi]
        mov [rsi], cl
        inc rsi
        inc rdi
        jmp .digit_check_after_decimal

    /* check the exponent */
    .exponent_check:
        mov [rsi], cl
        inc rsi
        inc rdi
        mov cl, [rdi]
        cmp cl, '-'
        je .e_negative
        cmp cl, '+'
        je .e_positive
        jmp .e_after_sign

        .e_negative:
            mov [rsi], cl
            inc rsi
            inc rdi
            jmp .e_after_sign

        .e_positive:
            mov [rsi], cl
            inc rsi
            inc rdi

        .e_after_sign:
            mov r10, 70
            cmp byte ptr [rdi], '0'
            jb .error
            mov r10, 71
            cmp byte ptr [rdi], '9'
            ja .error
            mov cl, [rdi]
            mov [rsi], cl
            inc rsi
            inc rdi

            .e_digit_check:
                sub rsp, 8
                call whitespace_skip
                add rsp, 8

                cmp byte ptr [rdi], ','
                je .comma
                cmp byte ptr [rdi], '}'
                je .process_object_close
                cmp byte ptr [rdi], ']'
                je .end
                cmp byte ptr [rdi], 0
                je .end

                mov r10, 72
                cmp byte ptr [rdi], '0'
                jb .error
                mov r10, 73
                cmp byte ptr [rdi], '9'
                ja .error
                mov cl, [rdi]
                mov [rsi], cl
                inc rsi
                inc rdi
                jmp .e_digit_check




/*======================================================================*/




.process_literal:
    // check if literal is "true"
    mov r8d, 0x65757274
    cmp [rdi], r8d
    je .found_true_null
    // check if literal is "null"
    mov r8d, 0x6c6c756e
    cmp [rdi], r8d
    je .found_true_null
    // check if literal is "fals"
    mov r8d, 0x736c6166
    cmp [rdi], r8d
    mov r9b, 'e'
    cmp [rdi+4], r9b
    je .found_false

    // throw error if literal is not true, false or null somehow
    mov r10, 40
    jmp .error

    .found_true_null:
        mov [rsi], r8d
        add rsi, 4
        add rdi, 4

        mov byte ptr [rbp], 'v'
        dec rbp
        inc rbx

        sub rsp, 8
        call whitespace_skip
        add rsp, 8

            mov r10, 41
            cmp byte ptr [rdi], ','
            je .comma
            mov r10, 42
            cmp byte ptr [rdi], '}'
            je .process_object_close
            mov r10, 43
            cmp byte ptr [rdi], ']'
            je .end
            mov r10, 44
            cmp byte ptr [rdi], 0
            je .end
            jmp .error

    .found_false:
        mov [rsi], r8d
        add rsi, 4
        mov [rsi], r9b
        add rsi, 1
        add rdi, 5
        mov r10, 45

        mov byte ptr [rbp], 'v'
        dec rbp
        inc rbx

        sub rsp, 8
        call whitespace_skip
        add rsp, 8

            cmp byte ptr [rdi], ','
            je .comma
            cmp byte ptr [rdi], '}'
            je .process_object_close
            cmp byte ptr [rdi], ']'
            je .end
            cmp byte ptr [rdi], 0
            je .end
            jmp .error


.error:
    mov cl, [rbp]
    mov [rsi], cl

    add rbp, rbx
    mov rax, r10
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

.end:
    mov byte ptr [rsi], '\n'
    inc rsi
    mov byte ptr [rsi], 0
    mov rax, 0
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx

    ret
ret

whitespace_skip:
    .whitespace_skip:
    cmp byte ptr [rdi], 0x20 // space
    je .increment
    cmp byte ptr [rdi], 0x09 // tab
    je .increment
    cmp byte ptr [rdi], 0x0a // newline
    je .increment
    cmp byte ptr [rdi], 0x0d // carriage return
    je .increment

    ret
    .increment:
    inc rdi
    jmp .whitespace_skip
ret
