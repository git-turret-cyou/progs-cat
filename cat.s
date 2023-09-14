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

    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    mov rsi, buf
    syscall
    mov rax, rbx
    jmp process_fd

.ret:
    ; return rax
    mov rax, rbx
    ret

_start:
    ; r12 = argc
    mov rbp, rsp
    ; r14 = argv0
    mov r14, [rsp+8]
    mov r12, [rbp]
    cmp r12, 2
    jl final.stdin

    ; r13 = our flag holder
    xor r13, r13

    add rbp, 8 * 2
    ; flag consumer loop
.loop:
    cmp r12, 2
    jl final

    mov r11, [rbp]
    mov r11, [r11]
    and r11, 0xff
    cmp r11, "-"
    jne .cont

    ; solid - is stdin
    ; shouldnt be consumed
    mov r11, [rbp]
    add r11, 1
    mov r11, [r11]
    and r11, 0xff
    cmp r11, 0x00
    je .cont

    mov r11, [rbp]
    xor r9, r9
    mov [rbp], r9 ; consume argument (should be ignored in final loop)
    ; inner loop to process all flags
.inloop:
    inc r11
    mov r10, [r11]
    and r10, 0xff
    cmp r10, 0x00
    je .cont

    ; basically switch() { case }
    cmp r10, "u"
    je .inloop
    jmp usage

.cont:
    add rbp, 8
    sub r12, 1
    jmp .loop

    ; actual FD processor loop
final:
    ; check for actual arguments
    mov rbp, rsp
    mov r12, [rbp]
    add rbp, 8 * 2
    xor rdx, rdx
.loop2:
    cmp r12, 2
    jl .cont2
    add rdx, [rbp]
    add rbp, 8
    sub r12, 1
    jmp .loop2

.cont2:
    cmp rdx, 1
    jl .sstdin
    ; fix rbp and r12
    mov rbp, rsp
    mov r12, [rbp]
    add rbp, 8 * 2 ; jump past 1st arg

.loop:
    ; if no more entries; exit
    cmp r12, 2
    jl exit
    mov r10, [rbp]
    cmp r10, 1
    jl .cont

    ; at this point, all arguments starting with -
    ; should only be -\0 (stdin)
    ; (we can be lazy and skip checking)
    mov r11, [rbp]
    mov r11, [r11]
    and r11, 0xff
    cmp r11, "-"
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

.sstdin:
    mov r12, 1
.stdin:
    mov rax, 0
    call process_fd
    jmp .cont

usage:
    ;usage w/ argv0
    mov rax, usagep1
    call pstring
    mov rax, r14
    call pstring
    mov rax, usagep2
    call pstring
    jmp errorexit
error:
    ;exit(1)
    ; TODO: process RAX to print meaningful message
    mov rax, errormsg
    call pstring
errorexit:
    mov rax, 60
    mov rdi, 1
    syscall

    ; function to print null terminated string
    ; arg: rax is pointer
pstring:
    ; r8 is length
    ; r9 is a cached buffer for operations

    xor r8, r8
    mov r9, rax
.loop:
    mov r10, [r9]
    and r10, 0xff
    cmp r10, 0x00
    je .fin

    inc r8
    inc r9
    jmp .loop

.fin:
    ; print to stderr
    mov rdx, r8
    mov rsi, rax
    mov rdi, 2
    mov rax, 1
    syscall

    ret

exit:
    ;exit(0)
    mov rax, 60
    mov rdi, 0
    syscall

    section .data
usagep1: db "Usage: ", 00
usagep2: db " [-u] [file ...]", 10, 00
errormsg: db "An error has occured! Unfortunately, this program isnt complex enough to display the error yet. Try using strace!", 10, 00

    section .bss
smallbuf: resb 8
bufSize: equ 65536
buf: resb bufSize
