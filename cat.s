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

    ; TODO flag handling
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
    ; TODO: cmd flag consumer

    ; r12 = argc
    mov rbp, rsp
    mov r13, [rbp]
    mov r12, [rbp]
    cmp r12, 2
    jl .stdin

    add rbp, 8 * 2 ; jump past 1st arg

.loop:
    ; if no more entries; exit
    cmp r12, 2
    jl exit
    mov r10, [rbp]
    cmp r10, 1
    jl .cont

    ; arguments starting with "-" are special cases
    mov r11, [rbp]
    mov r11, [r11]
    and r11, 0xff
    cmp r11, 0x2d ;'-'
    je .stdin

    ; open(rbp, 0, 0)
    mov rax, 2
    mov rdi, [rbp]
    mov rsi, 0
    mov rdx, 0
    syscall

    ; make sure fd exists
    cmp rax, 1
    jl error
    ; print file
    call process_fd
    ; returns input
    ; close(rax)
    mov rdi, rax
    mov rax, 3
    syscall

    ; prepare registers for next loop
.cont:
    add rbp, 8
    sub r12, 1
    jmp .loop

.stdin:
    mov rax, 0
    call process_fd
    jmp .cont

usage:
    ; TODO: usage message
    jmp errorexit
error:
    ;exit(1)
    ; TODO: process RAX to print meaningful message
errorexit:
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
