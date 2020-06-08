; haribote-ipl
; TAB=4

CYLS	EQU		10				; 柱面数，10个柱面

		ORG		0x7c00			; 加载到指定内存地址0x7c00

; 以下为标准FAT12格式的软盘

		JMP		entry
		DB		0x90
		DB		"HARIBOTE"		; 启动区的名称可以是任意的字符串（8字节）
		DW		512				; 每个扇区（sector）的大小（必须为512字节）
		DB		1				; 簇（cluster）的大小（必须为1个扇区）
		DW		1				; FAT的起始位置（一般从第一个扇区开始）
		DB		2				; FAT的个数（必须为2）
		DW		224				; 根目录的大小（一般设为224项）
		DW		2880			; 该磁盘的大小（必须为2880扇区）
		DB		0xf0			; 磁盘的种类（必须为0xf0）
		DW		9				; FAT的长度（必须为9扇区）
		DW		18				; 1个磁道（track）的扇区数（必须为18扇区）
		DW		2				; 磁头数（必须为2）
		DD		0				; 不使用分区（必须为0）
		DD		2880			; 重写一次磁盘大小
		DB		0,0,0x29		; 0:中断13的驱动器号 0:未使用 0x29:扩展引导标志
		DD		0xffffffff		; 卷标序号
		DB		"HARIBOTEOS "	; 磁盘的名称（11字节）
		DB		"FAT12   "		; 磁盘格式名称（8字节）
		RESB	18				; 先空出18字节的0x00

; 程序核心

entry:
		MOV		AX,0			; 初始化寄存器
		MOV		SS,AX
		MOV		SP,0x7c00
		MOV		DS,AX

; 读磁盘

		MOV		AX,0x0820
		MOV		ES,AX
		MOV		CH,0			; 柱面0
		MOV		DH,0			; 磁头0
		MOV		CL,2			; 扇区2
readloop:
		MOV		SI,0			; 记录失败次数
retry:
		MOV		AH,0x02			; AH=0x02 :读磁盘扇区功能
		MOV		AL,1			; 扇区数，每次读取一个扇区
		MOV		BX,0			; 数据缓冲区地址ES:BX
		MOV		DL,0x00			; 驱动器号
		INT		0x13			; BIOS功能调用0x13
		JNC		next			; 没出错时跳转next
		ADD		SI,1			; SI加1
		CMP		SI,5			; SI与5比较
		JAE		error			; SI >= 5时跳转error
		MOV		AH,0x00			; AH=0x00 :磁盘复位功能
		MOV		DL,0x00			; 驱动器号
		INT		0x13			; BIOS功能调用0x13
		JMP		retry
next:
		MOV		AX,ES
		ADD		AX,0x0020		; 内存地址往后移动0x0200
		MOV		ES,AX			; 写回ES
		ADD		CL,1			; CL加1
		CMP		CL,18			; CL与18比较
		JBE		readloop		; CL <= 18时跳转readloop
		MOV		CL,1			; 从第一个扇区开始
		ADD		DH,1			; 磁头号加1，读取磁盘反面
		CMP		DH,2			; DH与2比较
		JB		readloop		; DH < 2时跳转readloop
		MOV		DH,0			; 磁头号复位
		ADD		CH,1			; 柱面数加1
		CMP		CH,CYLS			; CH与CYLS比较
		JB		readloop		; CH < CYLS时跳转readloop




		JMP		0xc200

error:
		MOV		SI,msg
putloop:
		MOV		AL,[SI]			; 读取SI地址的内容到AL
		ADD		SI,1			; SI加1
		CMP		AL,0			; 是否为最后一个字符
		JE		fin
		MOV		AH,0x0e			; AH=0x0e :显示一个字符功能
		MOV		BX,15			; BH:页号 BL:前景色
		INT		0x10			; BIOS功能调用0x10
		JMP		putloop
fin:
		HLT						; 让cpu停止，等待指令
		JMP		fin				; 无线循环
msg:
		DB		0x0a, 0x0a		; 2个换行
		DB		"load error"
		DB		0x0a			; 换行
		DB		0

		RESB	0x7dfe-$		; 从这里到0x7dfe之前全部填充0x00

		DB		0x55, 0xaa		; 系统引导标志
