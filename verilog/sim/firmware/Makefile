CC      = riscv64-unknown-elf-gcc
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump

CFLAGS  = -march=rv32i_zicsr -mabi=ilp32 -O2 -ffreestanding -nostdlib -Wall
LDFLAGS = -T link.ld -nostdlib

all: firmware.hex firmware.bin firmware.dump

firmware.elf: boot.s main.c link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) boot.s main.c -o firmware.elf

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary firmware.elf firmware.bin

firmware.hex: firmware.bin
	hexdump -v -e '1/4 "%08x\n"' firmware.bin > firmware.hex
	cp firmware.hex ../../soc/firmware.hex 2>/dev/null || true
	cp firmware.hex ../firmware.hex 2>/dev/null || true

firmware.dump: firmware.elf
	$(OBJDUMP) -D -S firmware.elf > firmware.dump

clean:
	rm -f firmware.elf firmware.bin firmware.hex firmware.dump
