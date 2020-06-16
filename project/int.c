/* PIC相关 */

#include "bootpack.h"
#include <stdio.h>

void init_pic(void)
/* PIC的初始化 */
{
	io_out8(PIC0_IMR,  0xff  ); /* 禁止主PIC的所有中断 */
	io_out8(PIC1_IMR,  0xff  ); /* 禁止从PIC的所有中断 */

	io_out8(PIC0_ICW1, 0x11  ); /* 边沿触发模式 */
	io_out8(PIC0_ICW2, 0x20  ); /* IRQ 0-7由INT 20-27接收 */
	io_out8(PIC0_ICW3, 1 << 2); /* PIC1由IRQ2连接 */
	io_out8(PIC0_ICW4, 0x01  ); /* 无缓冲区模式 */

	io_out8(PIC1_ICW1, 0x11  ); /* 边沿触发模式 */
	io_out8(PIC1_ICW2, 0x28  ); /* IRQ 8-15由INT 28-2f接收 */
	io_out8(PIC1_ICW3, 2     ); /* PIC1由IRQ2连接 */
	io_out8(PIC1_ICW4, 0x01  ); /* 无缓冲区模式 */

	io_out8(PIC0_IMR,  0xfb  ); /* 11111011 除PIC1以外全部禁止 */
	io_out8(PIC1_IMR,  0xff  ); /* 11111111 禁止所有中断 */

	return;
}

void inthandler27(int *esp)
{
	io_out8(PIC0_OCW2, 0x67); /* 把IRQ-07信号接收完了的信息通知给PIC */
	return;
}
