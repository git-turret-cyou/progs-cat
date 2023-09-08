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
    ; r12 = argc
    mov rbp, rsp
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
    cmp r10, "b"
    je .numbernonblankonly
    cmp r10, "E"
    je .showends
    cmp r10, "n"
    je .numberlines
    cmp r10, "s"
    je .squeezeblanks
    cmp r10, "T"
    je .showtabs
    cmp r10, "v"
    je .shownonprinting
    cmp r10, "A"
    je .showall
    cmp r10, "e"
    je .ve
    cmp r10, "t"
    je .vt
    cmp r10, "u"
    je .inloop
    jmp usage

.numbernonblankonly:
    or r13, numbernonblankonly
    jmp .inloop
.showends:
    or r13, showends
    jmp .inloop
.numberlines:
    or r13, numberlines
    jmp .inloop
.squeezeblanks:
    or r13, squeezeblanks
    jmp .inloop
.showtabs:
    or r13, showtabs
    jmp .inloop
.shownonprinting:
    or r13, shownonprinting
    jmp .inloop
.showall:
    or r13, shownonprinting
    or r13, showends
    or r13, showtabs
    jmp .inloop
.ve:
    or r13, shownonprinting
    or r13, showends
    jmp .inloop
.vt:
    or r13, shownonprinting
    or r13, showtabs
    jmp .inloop

.cont:
    add rbp, 8
    sub r12, 1
    jmp .loop

    ; actual FD processor loop
final:
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

.stdin:
    mov rax, 0
    call process_fd
    jmp .cont

usage:
    ; TODO: usage message
    mov rax, usagemsg
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
    mov rax, r13
    mov [reg], rax
    mov rax, 1
    mov rdi, 2
    mov rsi, reg
    mov rdx, 8
    syscall
    ;exit(0)
    mov rax, 60
    mov rdi, 0
    syscall

    section .data
usagemsg: db "Usage: % [-AbeEnstTuv] [file ...]", 10, 00
errormsg: db "An error has occured! Unfortunately, this program isnt complex enough to display the error yet. Try using strace!", 10, 00

    section .bss
reg: resb 8
bufSize: equ 65536
buf: resb bufSize

numbernonblankonly:     equ 0b000001 ; -b
showends:               equ 0b000010 ; -E
numberlines:            equ 0b000100 ; -n
squeezeblanks:          equ 0b001000 ; -s
showtabs:               equ 0b010000 ; -T
shownonprinting:        equ 0b100000 ; -v
; -A = -vET
; -e = -vE
; -t = -vT
