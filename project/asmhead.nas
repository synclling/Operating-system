; haribote-os boot asm
; TAB=4

[INSTRSET "i486p"]				; 使用486指令

VBEMODE	EQU		0x105			; 1024 x 768 x 8bit彩色
; VBE的画面模式
;	0x100 :  640 x 400 x 8bit彩色
;	0x101 :  640 x 480 x 8bit彩色
;	0x103 :  800 x 600 x 8bit彩色
;	0x105 : 1024 x 768 x 8bit彩色
;	0x107 : 1280 x 1024 x 8bit彩色

BOTPAK	EQU		0x00280000		; bootpack的地址
DSKCAC	EQU		0x00100000		; 
DSKCAC0	EQU		0x00008000		; 

; 关于BOOT_INFO的信息
CYLS	EQU		0x0ff0			; 保存柱面数的地址
LEDS	EQU		0x0ff1			; 保存键盘上各种指示灯的状态的地址
VMODE	EQU		0x0ff2			; 保存关于颜色数目的信息（颜色的位数）的地址
SCRNX	EQU		0x0ff4			; 保存分辨率X的地址
SCRNY	EQU		0x0ff6			; 保存分辨率Y的地址
VRAM	EQU		0x0ff8			; 保存图像缓冲区的开始地址的地址

		ORG		0xc200			; 加载到指定的内存

; 以下为VBE功能调用，确认机器是否支持VBE

		MOV		AX,0x9000
		MOV		ES,AX
		MOV		DI,0			; ES:DI 指向VBE信息块的地址
		MOV		AX,0x4f00		; AH=0x4f :VBE标准，AH必须等于0x4f
		INT		0x10
		CMP		AX,0x004f		; AH=0x00调用成功，若AL=0x4f表示支持VBE
		JNE		scrn320

; 检查VBE的版本

		MOV		AX,[ES:DI+4]
		CMP		AX,0x0200		; 2.0或以上的版本
		JB		scrn320			; if (AX < 0x0200) goto scrn320

; 获取VBE某个特定模式的信息，该信息会被写入ES:DI开始的256字节中

		MOV		CX,VBEMODE		; 画面模式号码
		MOV		AX,0x4f01		; AH=0x4f :VBE标准，AH必须等于0x4f
		INT		0x10
		CMP		AX,0x004f		; AH=0x00调用成功，若AL=0x4f表示支持VBE
		JNE		scrn320

; 特定模式信息的确认

		CMP		BYTE [ES:DI+0x19],8
		JNE		scrn320
		CMP		BYTE [ES:DI+0x1b],4
		JNE		scrn320
		MOV		AX,[ES:DI+0x00]
		AND		AX,0x0080		; 检查模式属性的bit7是否为0
		JZ		scrn320

; 切换画面模式

		MOV		BX,VBEMODE+0x4000
		MOV		AX,0x4f02		; AH=0x4f :VBE标准，AH必须等于0x4f
		INT		0x10			; AL=0x02设置VBE模式的功能调用
		MOV		BYTE [VMODE],8	; 保存画面模式
		MOV		AX,[ES:DI+0x12]	; 分辨率X
		MOV		[SCRNX],AX
		MOV		AX,[ES:DI+0x14]	; 分辨率Y
		MOV		[SCRNY],AX
		MOV		EAX,[ES:DI+0x28]; VRAM地址
		MOV		[VRAM],EAX
		JMP		keystatus

scrn320:
		MOV		AL,0x13			; 显示方式为 320x200 256色图形（VGA）
		MOV		AH,0x00			; AH=0x00 :设置显示方式
		INT		0x10			; BIOS功能调用0x10
		MOV		BYTE [VMODE],8	; 保存画面模式
		MOV		WORD [SCRNX],320
		MOV		WORD [SCRNY],200
		MOV		DWORD [VRAM],0x000a0000

; 获取键盘上各种指示灯的状态

keystatus:
		MOV		AH,0x02			; AH=0x02 :获取键盘标志字节
		INT		0x16 			; keyboard BIOS
		MOV		[LEDS],AL		; 键盘标志字节保存到[LEDS]

; PIC关闭一切中断
;	根据AT兼容机的规格，如果要初始化PIC，
;	必须再CLI之前进行，否则有时会挂起。
;	随后进行PIC的初始化

		MOV		AL,0xff			; 某位值为1表示该位对应的IRQ信号被屏蔽
		OUT		0x21,AL			; 禁止主PIC的全部中断
		NOP						; NOP空操作指令，什么都不做
		OUT		0xa1,AL			; 禁止从PIC的全部中断

		CLI						; 禁止CPU级别的中断

; 为了让CPU能够访问1MB以上的内存空间，设定A20GATE状态为ON

		CALL	waitkbdout
		MOV		AL,0xd1
		OUT		0x64,AL
		CALL	waitkbdout
		MOV		AL,0xdf			; enable A20
		OUT		0x60,AL
		CALL	waitkbdout

; 切换到保护模式

		LGDT	[GDTR0]			; 设定临时的GDT
		MOV		EAX,CR0
		AND		EAX,0x7fffffff	; 设bit31为0（禁止分页）
		OR		EAX,0x00000001	; 设bit0为1（切换到保护模式）
		MOV		CR0,EAX
		JMP		pipelineflush
pipelineflush:
		MOV		AX,1*8			;  可读写的段 32bit
		MOV		DS,AX
		MOV		ES,AX
		MOV		FS,AX
		MOV		GS,AX
		MOV		SS,AX

; bootpack的转送

		MOV		ESI,bootpack	; 源地址
		MOV		EDI,BOTPAK		; 目的地址
		MOV		ECX,512*1024/4	; 数据大小（以双字为单位）
		CALL	memcpy

; 磁盘数据最终转送到它本来的位置去

; 首先从启动扇区开始

		MOV		ESI,0x7c00		; 源地址
		MOV		EDI,DSKCAC		; 目的地址
		MOV		ECX,512/4		; 数据大小（以双字为单位）
		CALL	memcpy

; 剩下的所有

		MOV		ESI,DSKCAC0+512	; 源地址
		MOV		EDI,DSKCAC+512	; 目的地址
		MOV		ECX,0			; ECX初始化0
		MOV		CL,BYTE [CYLS]	; 读取柱面数
		IMUL	ECX,512*18*2/4	; 数据大小（以双字为单位）
		SUB		ECX,512/4		; 减去启动区的512字节
		CALL	memcpy

; 必须由asmhead来完成的工作，至此全部完毕
;	以后就交由bootpack来完成

; bootpack的启动

		MOV		EBX,BOTPAK
		MOV		ECX,[EBX+16]
		ADD		ECX,3			; ECX += 3;
		SHR		ECX,2			; ECX /= 4;
		JZ		skip			; 没有要转送的东西时
		MOV		ESI,[EBX+20]	; 源地址
		ADD		ESI,EBX
		MOV		EDI,[EBX+12]	; 目的地址
		CALL	memcpy
skip:
		MOV		ESP,[EBX+12]	; 栈的初始值
		JMP		DWORD 2*8:0x0000001b

waitkbdout:
		IN		 AL,0x64
		AND		 AL,0x02
		JNZ		waitkbdout		; AND的结果如果不是0，则跳转到waitkbdout
		RET

memcpy:
		MOV		EAX,[ESI]
		ADD		ESI,4
		MOV		[EDI],EAX
		ADD		EDI,4
		SUB		ECX,1
		JNZ		memcpy			; 减法的运算结果如果不是0，则跳转memcpy
		RET
; memcpy

		ALIGNB	16
GDT0:
		RESB	8				; NULL selector
		DW		0xffff,0x0000,0x9200,0x00cf	; 可读写的段（segment）32bit
		DW		0xffff,0x0000,0x9a28,0x0047	; 可执行的段（segment）32bit（bootpack使用）

		DW		0
GDTR0:
		DW		8*3-1
		DD		GDT0

		ALIGNB	16
bootpack:
