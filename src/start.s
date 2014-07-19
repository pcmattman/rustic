/*
 * Copyright (c) 2014 Matthew Iselin
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifndef STACK_BASE_TLS_OFFSET
#define STACK_BASE_TLS_OFFSET       0x30
#endif

.set ALIGN,    1<<0
.set MEMINFO,  1<<1
.set FLAGS,    ALIGN | MEMINFO
.set MAGIC,    0x1BADB002
.set CHECKSUM, -(MAGIC + FLAGS)

.section .multiboot
.align 4
.long MAGIC
.long FLAGS
.long CHECKSUM

.section .data
.align 4
stack_bottom:
.skip 131072 # 128 KiB
stack_top:

.align 4
.global tls_emul_segment
tls_emul_segment:
.skip 0x1000

// Initial GDT, before we load the real one later.
.align 4
initial_gdt:
    .long 0x0
    .long 0x0

    # Code.
    .word 0xFFFF
    .word 0x0
    .byte 0x00
    .byte 0x98
    .byte 0xCF
    .byte 0x00

    # Data.
    .word 0xFFFF
    .word 0x0
    .byte 0x00
    .byte 0x92
    .byte 0xCF
    .byte 0x00

    # Temporary TLS emulation segment
    .word 0xFFFF
    .word 0x0
    .byte 0x00
    .byte 0x92
    .byte 0xCF
    .byte 0x00
initial_gdt_end:

.align 4
gdtr:
    .word 0x21
    .long 0x0

.section .init
.global _start
.extern main
.type _start, @function
_start:
    cli

    mov $gdtr, %esi
    mov $initial_gdt, %edi

    // Fix up GDTR and the TLS emulation segment.
    movl %edi, 2(%esi)

    mov $tls_emul_segment, %edx
    movw %dx, 26(%edi)
    shr $16, %edx
    movb %dl, 28(%edi)

    // Load GDT
    lgdt (%esi)

    // Load new CS
    jmp $0x08, $.newgdt
    .newgdt:

    // Load new auxilliary registers.
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %ss

    // TODO: don't use %gs:30 - fix the target?
    // This is required as Rust's main() at least checks to see
    // if the stack needs to be expanded in its prologue. If it
    // decides it does, it calls __morestack.
    mov $0x18, %ax
    mov %ax, %gs

    // Set up stack.
    movl $stack_top, %esp
    movl $stack_bottom, %gs:STACK_BASE_TLS_OFFSET

    // Call into the Rust code.
    push %ebx
    push $1
    call main

    // Halt the system completely if we ever return from the C
    // glue code.
    cli
    hlt
    jmp .

.section .data
isr_rustentry:
    .long 0x0

.section .text
.global set_isr_handler
.type set_isr_handler, @function
set_isr_handler:
    mov 4(%esp), %eax
    mov $isr_rustentry, %ecx
    mov %eax, (%ecx)
    ret

.global lowlevel_isr_entry
.type lowlevel_isr_entry, @function
lowlevel_isr_entry:
    pusha

    push %ds
    push %es
    push %fs
    push %gs

    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs

    # Linux TLS emulation segment.
    mov $0x28, %ax
    mov %ax, %gs

    # Push interrupt number as the parameter.
    mov 48(%esp), %eax
    push %eax
    mov $isr_rustentry, %eax
    call *(%eax)
    add $4, %esp

    pop %gs
    pop %fs
    pop %es
    pop %ds

    popa

    add $8, %esp

    sti
    iret

.macro INTERRUPT_HANDLER num
	.global isr_\num
	isr_\num:
		cli
		pushl $0
		pushl $\num
		jmp lowlevel_isr_entry
.endm

.macro INTERRUPT_HANDLER_ERRORCODE num
	.global isr_\num
	isr_\num:
		cli
		nop; nop
		pushl $\num
		jmp lowlevel_isr_entry
.endm

.align 1024
.global isrs_base
isrs_base:
INTERRUPT_HANDLER 0
INTERRUPT_HANDLER 1
INTERRUPT_HANDLER 2
INTERRUPT_HANDLER 3
INTERRUPT_HANDLER 4
INTERRUPT_HANDLER 5
INTERRUPT_HANDLER 6
INTERRUPT_HANDLER 7
INTERRUPT_HANDLER_ERRORCODE 8
INTERRUPT_HANDLER 9
INTERRUPT_HANDLER_ERRORCODE 10
INTERRUPT_HANDLER_ERRORCODE 11
INTERRUPT_HANDLER_ERRORCODE 12
INTERRUPT_HANDLER_ERRORCODE 13
INTERRUPT_HANDLER_ERRORCODE 14
INTERRUPT_HANDLER 15
INTERRUPT_HANDLER 16
INTERRUPT_HANDLER 17
INTERRUPT_HANDLER 18
INTERRUPT_HANDLER 19
INTERRUPT_HANDLER 20
INTERRUPT_HANDLER 21
INTERRUPT_HANDLER 22
INTERRUPT_HANDLER 23
INTERRUPT_HANDLER 24
INTERRUPT_HANDLER 25
INTERRUPT_HANDLER 26
INTERRUPT_HANDLER 27
INTERRUPT_HANDLER 28
INTERRUPT_HANDLER 29
INTERRUPT_HANDLER 30
INTERRUPT_HANDLER 31

INTERRUPT_HANDLER 32
INTERRUPT_HANDLER 33
INTERRUPT_HANDLER 34
INTERRUPT_HANDLER 35
INTERRUPT_HANDLER 36
INTERRUPT_HANDLER 37
INTERRUPT_HANDLER 38
INTERRUPT_HANDLER 39
INTERRUPT_HANDLER 40
INTERRUPT_HANDLER 41
INTERRUPT_HANDLER 42
INTERRUPT_HANDLER 43
INTERRUPT_HANDLER 44
INTERRUPT_HANDLER 45
INTERRUPT_HANDLER 46
INTERRUPT_HANDLER 47
INTERRUPT_HANDLER 48
INTERRUPT_HANDLER 49
INTERRUPT_HANDLER 50
INTERRUPT_HANDLER 51
INTERRUPT_HANDLER 52
INTERRUPT_HANDLER 53
INTERRUPT_HANDLER 54
INTERRUPT_HANDLER 55
INTERRUPT_HANDLER 56
INTERRUPT_HANDLER 57
INTERRUPT_HANDLER 58
INTERRUPT_HANDLER 59
INTERRUPT_HANDLER 60
INTERRUPT_HANDLER 61
INTERRUPT_HANDLER 62
INTERRUPT_HANDLER 63
INTERRUPT_HANDLER 64
INTERRUPT_HANDLER 65
INTERRUPT_HANDLER 66
INTERRUPT_HANDLER 67
INTERRUPT_HANDLER 68
INTERRUPT_HANDLER 69
INTERRUPT_HANDLER 70
INTERRUPT_HANDLER 71
INTERRUPT_HANDLER 72
INTERRUPT_HANDLER 73
INTERRUPT_HANDLER 74
INTERRUPT_HANDLER 75
INTERRUPT_HANDLER 76
INTERRUPT_HANDLER 77
INTERRUPT_HANDLER 78
INTERRUPT_HANDLER 79
INTERRUPT_HANDLER 80
INTERRUPT_HANDLER 81
INTERRUPT_HANDLER 82
INTERRUPT_HANDLER 83
INTERRUPT_HANDLER 84
INTERRUPT_HANDLER 85
INTERRUPT_HANDLER 86
INTERRUPT_HANDLER 87
INTERRUPT_HANDLER 88
INTERRUPT_HANDLER 89
INTERRUPT_HANDLER 90
INTERRUPT_HANDLER 91
INTERRUPT_HANDLER 92
INTERRUPT_HANDLER 93
INTERRUPT_HANDLER 94
INTERRUPT_HANDLER 95
INTERRUPT_HANDLER 96
INTERRUPT_HANDLER 97
INTERRUPT_HANDLER 98
INTERRUPT_HANDLER 99
INTERRUPT_HANDLER 100
INTERRUPT_HANDLER 101
INTERRUPT_HANDLER 102
INTERRUPT_HANDLER 103
INTERRUPT_HANDLER 104
INTERRUPT_HANDLER 105
INTERRUPT_HANDLER 106
INTERRUPT_HANDLER 107
INTERRUPT_HANDLER 108
INTERRUPT_HANDLER 109
INTERRUPT_HANDLER 110
INTERRUPT_HANDLER 111
INTERRUPT_HANDLER 112
INTERRUPT_HANDLER 113
INTERRUPT_HANDLER 114
INTERRUPT_HANDLER 115
INTERRUPT_HANDLER 116
INTERRUPT_HANDLER 117
INTERRUPT_HANDLER 118
INTERRUPT_HANDLER 119
INTERRUPT_HANDLER 120
INTERRUPT_HANDLER 121
INTERRUPT_HANDLER 122
INTERRUPT_HANDLER 123
INTERRUPT_HANDLER 124
INTERRUPT_HANDLER 125
INTERRUPT_HANDLER 126
INTERRUPT_HANDLER 127
INTERRUPT_HANDLER 128
INTERRUPT_HANDLER 129
INTERRUPT_HANDLER 130
INTERRUPT_HANDLER 131
INTERRUPT_HANDLER 132
INTERRUPT_HANDLER 133
INTERRUPT_HANDLER 134
INTERRUPT_HANDLER 135
INTERRUPT_HANDLER 136
INTERRUPT_HANDLER 137
INTERRUPT_HANDLER 138
INTERRUPT_HANDLER 139
INTERRUPT_HANDLER 140
INTERRUPT_HANDLER 141
INTERRUPT_HANDLER 142
INTERRUPT_HANDLER 143
INTERRUPT_HANDLER 144
INTERRUPT_HANDLER 145
INTERRUPT_HANDLER 146
INTERRUPT_HANDLER 147
INTERRUPT_HANDLER 148
INTERRUPT_HANDLER 149
INTERRUPT_HANDLER 150
INTERRUPT_HANDLER 151
INTERRUPT_HANDLER 152
INTERRUPT_HANDLER 153
INTERRUPT_HANDLER 154
INTERRUPT_HANDLER 155
INTERRUPT_HANDLER 156
INTERRUPT_HANDLER 157
INTERRUPT_HANDLER 158
INTERRUPT_HANDLER 159
INTERRUPT_HANDLER 160
INTERRUPT_HANDLER 161
INTERRUPT_HANDLER 162
INTERRUPT_HANDLER 163
INTERRUPT_HANDLER 164
INTERRUPT_HANDLER 165
INTERRUPT_HANDLER 166
INTERRUPT_HANDLER 167
INTERRUPT_HANDLER 168
INTERRUPT_HANDLER 169
INTERRUPT_HANDLER 170
INTERRUPT_HANDLER 171
INTERRUPT_HANDLER 172
INTERRUPT_HANDLER 173
INTERRUPT_HANDLER 174
INTERRUPT_HANDLER 175
INTERRUPT_HANDLER 176
INTERRUPT_HANDLER 177
INTERRUPT_HANDLER 178
INTERRUPT_HANDLER 179
INTERRUPT_HANDLER 180
INTERRUPT_HANDLER 181
INTERRUPT_HANDLER 182
INTERRUPT_HANDLER 183
INTERRUPT_HANDLER 184
INTERRUPT_HANDLER 185
INTERRUPT_HANDLER 186
INTERRUPT_HANDLER 187
INTERRUPT_HANDLER 188
INTERRUPT_HANDLER 189
INTERRUPT_HANDLER 190
INTERRUPT_HANDLER 191
INTERRUPT_HANDLER 192
INTERRUPT_HANDLER 193
INTERRUPT_HANDLER 194
INTERRUPT_HANDLER 195
INTERRUPT_HANDLER 196
INTERRUPT_HANDLER 197
INTERRUPT_HANDLER 198
INTERRUPT_HANDLER 199
INTERRUPT_HANDLER 200
INTERRUPT_HANDLER 201
INTERRUPT_HANDLER 202
INTERRUPT_HANDLER 203
INTERRUPT_HANDLER 204
INTERRUPT_HANDLER 205
INTERRUPT_HANDLER 206
INTERRUPT_HANDLER 207
INTERRUPT_HANDLER 208
INTERRUPT_HANDLER 209
INTERRUPT_HANDLER 210
INTERRUPT_HANDLER 211
INTERRUPT_HANDLER 212
INTERRUPT_HANDLER 213
INTERRUPT_HANDLER 214
INTERRUPT_HANDLER 215
INTERRUPT_HANDLER 216
INTERRUPT_HANDLER 217
INTERRUPT_HANDLER 218
INTERRUPT_HANDLER 219
INTERRUPT_HANDLER 220
INTERRUPT_HANDLER 221
INTERRUPT_HANDLER 222
INTERRUPT_HANDLER 223
INTERRUPT_HANDLER 224
INTERRUPT_HANDLER 225
INTERRUPT_HANDLER 226
INTERRUPT_HANDLER 227
INTERRUPT_HANDLER 228
INTERRUPT_HANDLER 229
INTERRUPT_HANDLER 230
INTERRUPT_HANDLER 231
INTERRUPT_HANDLER 232
INTERRUPT_HANDLER 233
INTERRUPT_HANDLER 234
INTERRUPT_HANDLER 235
INTERRUPT_HANDLER 236
INTERRUPT_HANDLER 237
INTERRUPT_HANDLER 238
INTERRUPT_HANDLER 239
INTERRUPT_HANDLER 240
INTERRUPT_HANDLER 241
INTERRUPT_HANDLER 242
INTERRUPT_HANDLER 243
INTERRUPT_HANDLER 244
INTERRUPT_HANDLER 245
INTERRUPT_HANDLER 246
INTERRUPT_HANDLER 247
INTERRUPT_HANDLER 248
INTERRUPT_HANDLER 249
INTERRUPT_HANDLER 250
INTERRUPT_HANDLER 251
INTERRUPT_HANDLER 252
INTERRUPT_HANDLER 253
INTERRUPT_HANDLER 254
INTERRUPT_HANDLER 255
