#include "threads/loader.h"

#### Kernel loader.

#### This code should be stored in the first sector of a hard disk.
#### When the BIOS runs, it loads this code at physical address
#### 0x7c00-0x7e00 (512 bytes) and jumps to the beginning of it,
#### in real mode.  The loader loads the kernel into memory and jumps
#### to its entry point, which is the start function in start.S.
####
#### The BIOS passes in the drive that the loader was read from as
#### DL, with floppy drives numbered 0x00, 0x01, ... and hard drives
#### numbered 0x80, 0x81, ...  We want to support booting a kernel on
#### a different drive from the loader, so we don't take advantage of
#### this.

# Runs in real mode, which is a 16-bit segment.
	.code16		#16비트 환경임을 알려줌

# Set up segment registers.
# Set stack to grow downward from 60 kB (after boot, the kernel
# continues to use this stack for its initial thread).

	sub %ax, %ax		 # ax = 0으로 만들어줌
	mov %ax, %ds         # Data segment를 초기화
	mov %ax, %ss         # Stack segment를 초기화
	mov $0xf000, %esp    # Stack Pointer를 0xf000으로 설정

# Configure serial port so we can report progress without connected VGA(화면).
#시리얼 포트 초기화해서 터미널에 메세지를 뜨게 해줌
# See [IntrList] for details.
	sub %dx, %dx			# Serial port 0.(시리얼 포트 번호호)
	mov $0xe3, %al			# 9600 bps, N-8-1.(통신 설정)
					# AH is already 0 (Initialize Port).
	int $0x14			# Destroys AX.(dx를 al에 지정된 설정으로 초기화를 수행함

	call puts
	.string "PiLo"

#### Read the partition table on each system hard disk and scan for a
#### partition of type 0x20, which is the type that we use for a
#### Pintos kernel.
####
#### Read [Partitions] for a description of the partition table format
#### that we parse.
####
#### We print out status messages to show the disk and partition being
#### scanned, e.g. hda1234 as we scan four partitions on the first
#### hard disk.

	mov $0x80, %dl			# Hard disk 0.(디스크 번호)
read_mbr:					# kernel을 읽어올 준비를 함(커널이 있는 파티션을 찾음)
	sub %ebx, %ebx			# Sector 0.
	mov $0x2000, %ax		# Use 0x20000 for buffer.(세그먼트 주소)
	mov %ax, %es			# (세그먼트:오프셋) = (es, bx)
	call read_sector		# 윗 주소에 있는 데이터를 읽어옴
	jc no_such_drive 		# 예외 처리

	# Print hd[a-z].
	call puts
	.string " hd"
	mov %dl, %al
	add $'a' - 0x80, %al
	call putc

	# Check for MBR signature--if not present, it's not a
	# partitioned hard disk.
	cmpw $0xaa55, %es:510	# 주소가 유효한지 확인인
	jne next_drive			# 유효하지 않으면 다음 드라이브 확인

	mov $446, %si			# Offset of partition table entry 1.
	mov $'1', %al
check_partition:			# 파티션을 하나씩 검사
	# Is it an unused partition?
	cmpl $0, %es:(%si)
	je next_partition

	# Print [1-4].
	call putc

	# Is it a Pintos kernel partition?
	cmpb $0x20, %es:4(%si)
	jne next_partition

	# Is it a bootable partition?
	cmpb $0x80, %es:(%si)
	je load_kernel

next_partition:				# 다음 파티션으로 이동

	# No match for this partition, go on to the next one.
	add $16, %si			# Offset to next partition table entry.
	inc %al
	cmp $510, %si
	jb check_partition

next_drive:					# 다음 드라이브로 이동
	# No match on this drive, go on to the next one.
	inc %dl
	jnc read_mbr

no_such_drive:
no_boot_partition:			# 커널 코드를 못 찾거나 BIOS 호출을 실패했을 시, 예외처리리
	# Didn't find a Pintos kernel partition anywhere, give up.
	call puts
	.string "\rNot found\r"

	# Notify BIOS that boot failed.  See [IntrList].
	int $0x18

#### We found a kernel.  The kernel's drive is in DL.  The partition
#### table entry for the kernel's partition is at ES:SI.  Our job now
#### is to read the kernel from disk and jump to its start address.

load_kernel:				# 0x20000에 커널 파티션을 load함
	call puts
	.string "\rLoading"

	# Figure out number of sectors to read.  A Pintos kernel is
	# just an ELF format object, which doesn't have an
	# easy-to-read field to identify its own size (see [ELF1]).
	# But we limit Pintos kernels to 512 kB for other reasons, so
	# it's easy enough to just read the entire contents of the
	# partition or 512 kB from disk, whichever is smaller.
	mov %es:12(%si), %ecx		# EBP = number of sectors
	cmp $1024, %ecx			# Cap size at 512 kB
	jbe 1f					# 읽을 수 있는 섹터랑 섹터 수(1024개)와 비교해서 크면 1024로 제한한
	mov $1024, %cx
1:

	mov %es:8(%si), %ebx	# EBX = first sector
	mov $0x2000, %ax		# Start load address: 0x20000

next_sector:				# 각 섹터에서 메모리를 읽어옴
	# Read one sector into memory.
	mov %ax, %es			# ES:0000 -> load address
	call read_sector
	jc read_failed

	# Print '.' as progress indicator once every 16 sectors == 8 kB.
	test $15, %bl
	jnz 1f
	call puts
	.string "."
1:

	# Advance memory pointer and disk sector.
	add $0x20, %ax
	inc %bx
	loop next_sector

	call puts
	.string "\r"

#### Transfer control to the kernel that we loaded.  We read the start
#### address out of the ELF header (see [ELF1]) and convert it from a
#### 32-bit linear address into a 16:16 segment:offset address for
#### real mode, then jump to the converted address.  The 80x86 doesn't
#### have an instruction to jump to an absolute segment:offset kept in
#### registers, so in fact we store the address in a temporary memory
#### location, then jump indirectly through that location.  To save 4
#### bytes in the loader, we reuse 4 bytes of the loader's code for
#### this temporary pointer.

	mov $0x2000, %ax
	mov %ax, %es
	mov %es:0x18, %dx
	mov %dx, start
	movw $0x2000, start + 2
	ljmp *start				# start로 점프함

read_failed:				# 디스크 읽기 실패 시, 예외처리
start:
	# Disk sector read failed.
	call puts
1:	.string "\rBad read\r"

	# Notify BIOS that boot failed.  See [IntrList].
	int $0x18

#### Print string subroutine.  To save space in the loader, this
#### subroutine takes its null-terminated string argument from the
#### code stream just after the call, and then returns to the byte
#### just after the terminating null.  This subroutine preserves all
#### general-purpose registers.

puts:	xchg %si, %ss:(%esp)	# 문자열 출력력
	push %ax
next_char:
	mov %cs:(%si), %al
	inc %si
	test %al, %al
	jz 1f
	call putc
	jmp next_char
1:	pop %ax
	xchg %si, %ss:(%esp)
	ret

#### Character output subroutine.  Prints the character in AL to the
#### VGA display and serial port 0, using BIOS services (see
#### [IntrList]).  Preserves all general-purpose registers.
####
#### If called upon to output a carriage return, this subroutine
#### automatically supplies the following line feed.

putc:	pusha			# 레지스터에 있는 데이터 출력력

1:	sub %bh, %bh			# Page 0.
	mov $0x0e, %ah			# Teletype output service.
	int $0x10

	mov $0x01, %ah			# Serial port output service.
	sub %dx, %dx			# Serial port 0.
2:	int $0x14			# Destroys AH.
	test $0x80, %ah			# Output timed out?
	jz 3f
	movw $0x9090, 2b		# Turn "int $0x14" above into NOPs.

3:
	cmp $'\r', %al
	jne popa_ret
	mov $'\n', %al
	jmp 1b

#### Sector read subroutine.  Takes a drive number in DL (0x80 = hard
#### disk 0, 0x81 = hard disk 1, ...) and a sector number in EBX, and
#### reads the specified sector into memory at ES:0000.  Returns with
#### carry set on error, clear otherwise.  Preserves all
#### general-purpose registers.

read_sector:			# 디스크 섹터를 읽어옴
	pusha
	sub %ax, %ax
	push %ax			# LBA sector number [48:63]
	push %ax			# LBA sector number [32:47]
	push %ebx			# LBA sector number [0:31]
	push %es			# Buffer segment
	push %ax			# Buffer offset (always 0)
	push $1				# Number of sectors to read
	push $16			# Packet size
	mov $0x42, %ah			# Extended read
	mov %sp, %si			# DS:SI -> packet
	int $0x13			# Error code in CF
	popa				# Pop 16 bytes, preserve flags
popa_ret:
	popa
	ret				# Error code still in CF

#### Command-line arguments and their count.
#### This is written by the `pintos' utility and read by the kernel.
#### The loader itself does not do anything with the command line.
	.org LOADER_ARG_CNT - LOADER_BASE
	.fill LOADER_ARG_CNT_LEN, 1, 0

	.org LOADER_ARGS - LOADER_BASE
	.fill LOADER_ARGS_LEN, 1, 0

#### Partition table.
	.org LOADER_PARTS - LOADER_BASE
	.fill LOADER_PARTS_LEN, 1, 0

#### Boot-sector signature for BIOS inspection.
	.org LOADER_SIG - LOADER_BASE
	.word 0xaa55
