nasm -f elf64 cat.s -o cat.o
ld -sN cat.o -o cat
sstrip cat
