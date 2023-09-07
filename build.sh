nasm -f elf64 cat.s -o cat.o
ld cat.o -o cat
