/*
 * Copyright (c) 2013 Eduard Burtescu
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
mod slam;

pub mod heap_impl {
    use core::heap::LinearAllocator;
    use cpu;
    use mem::slam;

    static STATIC_HEAP_SIZE: uint = 4 * 1024 * 1024; // 4MB.
    pub static mut allocator : slam::SlamAllocator<LinearAllocator<[u8, ..STATIC_HEAP_SIZE]>> = SlamAllocator!(LinearAllocator {
        offset: 0,
        data: [0, ..STATIC_HEAP_SIZE]
    });
}
