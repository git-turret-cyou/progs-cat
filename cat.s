    global _start
    section .text
_start:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg
    mov rdx, msgSize
    syscall

    mov rax, 60
    mov rdi, 0
    syscall

    section .data
msg: db "Hello, world!", 10
msgSize: EQU $ - msg
