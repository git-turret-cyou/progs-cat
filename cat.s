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

    mov r8, rax ; buf size
    mov r9, buf ; write pointer
    mov r10, buf ; read pointer
.loop:
    mov r11, r13 ; flags (for ANDing)
    and r11, showends
    cmp r11, 1
    jl .skipshowends
    mov rcx, [r10]
    and rcx, 0xff
    cmp rcx, 0x0a
    jne .skipshowends
    call .flushbuf
    mov rcx, "$"
    mov [smallbuf], rcx
    mov rax, smallbuf
    push r8
    push r9
    push r10
    call outpstring
    pop r10
    pop r9
    pop r8
.skipshowends:
    dec r8
    inc r10
    cmp r8, 0
    jl .contrwloop
    jmp .loop

.flushbuf:
    mov rdx, r10
    sub rdx, r9
    mov rdi, 1
    mov rsi, r9
    mov rax, 1
    push r8
    push r9
    push r10
    syscall
    pop r10
    pop r9
    pop r8
    mov r9, r10
    ret

.contrwloop:
    ; continue loop
    call .flushbuf
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
    cmp r10, "h"
    je .help
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
.help:
    or r13, 0xff
    jmp usage

.cont:
    add rbp, 8
    sub r12, 1
    jmp .loop

    ; actual FD processor loop
final:
    mov [smallbuf], r13
    mov rax, smallbuf
    call pstring
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
    ;usage w/ argv0
    mov rax, usagep1
    call pstring
    mov rax, r14
    call pstring
    mov rax, usagep2
    call pstring
    cmp r13, 0xff
    jne errorexit
    ; r13 is set to 0xff when -h flag is set
    mov rax, help
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

    ; pstring to stdout
outpstring:
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
    mov rdx, r8
    mov rsi, rax
    mov rdi, 1
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
usagep2: db " [-h] [-AbeEnstTuv] [file ...]", 10, 00
help: db "Concatenate FILE(s) to standard output.", 10, 10, "With no FILE, or when FILE is -, read standard input.", 10, 10, "  -A                       equivalent to -vET", 10, "  -b                       number (in hex) nonempty output lines, overrides -n", 10,  "  -e                       equivalent to -vE", 10, "  -E                       display $ at end of each line", 10, "  -n                       number (in hex) all output lines", 10, "  -s                       suppress repeated empty output lines", 10, "  -t                       equivalent to -vT", 10, "  -T                       display TAB characters as ^I", 10, "  -u                       (ignored)", 10, "  -v                       use ^ and M- notation, except for LFD and TAB", 10, "  -h                       display this help and exit", 10, 10, "Examples:", 10, "  cat f - g  Output f's contents, then standard input, then g's contents.", 10, "  cat        Copy standard input to standard output.", 10, 00
errormsg: db "An error has occured! Unfortunately, this program isnt complex enough to display the error yet. Try using strace!", 10, 00

    section .bss
smallbuf: resb 8
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
