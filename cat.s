    global _start
    section .text
process_fd:
    ; rax = fd

    ; read(rax, buf, bufSize)
    mov rbx, rax
    mov rdi, rax
    mov rsi, buf
    mov rdx, bufSize
    mov rax, 0
    syscall

    ; check if stuff was read
    cmp rax, 1
    jl .ret

    ; TODO special case handling
    ; write(1, buf, rax)
    mov rdi, 1
    mov rsi, buf
    mov rdx, rax
    mov rax, 1
    syscall

    ; continue loop
    mov rax, rbx
    jmp process_fd
.ret:
    ; return rax
    mov rax, rbx
    ret

_start:
    ; r12 = argc
    mov rbp, rsp
    mov r12, [rbp]
    cmp r12, 2
    jl .stdin

    add rbp, 8 * 2 ; jump past 1st arg

.loop:
    ; if no more entries; exit
    cmp r12, 2
    jl exit

    ; arguments starting with "-" are special cases
    mov r11, [rbp]
    mov r11, [r11]
    and r11, 0xff
    cmp r11, 0x2d ;'-'
    je .special

    ; open(rbp, 0, 0)
    mov rax, 2
    mov rdi, [rbp]
    mov rsi, 0
    mov rdx, 0
    syscall

    ; make sure fd exists
    cmp rax, 1
    jl .error
    ; print file
    call process_fd
    ; returns input
    ; close(rax)
    mov rdi, rax
    mov rax, 3
    syscall

    ; prepare registers for next loop
    add rbp, 8
    sub r12, 1
    jmp .loop

    ; unreachable. insurance
    jmp exit

.special:
    ;special case handler (TODO)
    ; get second character
    mov r11, [rbp]
    add r11, 1
    mov r10, [r11]
    and r10, 0xff

    ; just a single -
    cmp r10, 0x00
    je .stdin

    jmp .usage
    ; stdin passthrough
.stdin:
    mov rax, 0
    call process_fd
    add rbp, 8
    sub r12, 1
    jmp .loop

.usage:
    ; TODO: usage message
    jmp .errorexit
.error:
    ;exit(1)
    ; TODO: process RAX to print meaningful message
.errorexit:
    mov rax, 60
    mov rdi, 1
    syscall

exit:
    ;exit(0)
    mov rax, 60
    mov rdi, 0
    syscall

    section .data

    section .bss
bufSize: equ 65536
buf: resb bufSize
