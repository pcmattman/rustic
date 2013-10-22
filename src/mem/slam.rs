/*
 * Copyright (c) 2008-2013 James Molloy, Eduard Burtescu
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

#[macro_escape];

use core::atomics;
use core::fail::abort;
use core::heap::Allocator;
use core::intrinsics::size_of;
use cpu;

/// The structure of a free object (list node).
pub struct FreeNode {
    next: *mut FreeNode,
    prev: *mut FreeNode
}

/// The structure of an used object (allocation header).
pub struct UsedNode {
    cache: *mut Cache
}

impl UsedNode {
    fn from_data(data: *mut u8) -> *UsedNode {
        (data as uint - size_of::<UsedNode>()) as *UsedNode
    }

    fn get_data(node: *UsedNode) -> *mut u8 {
        (node as uint + size_of::<UsedNode>()) as *mut u8
    }
}

/// Size of each slab in 4096-byte pages.
static SLAB_SIZE: uint = 1u;

/// Minimum slab size in bytes.
static SLAB_MINIMUM_SIZE: uint = 4096 * SLAB_SIZE;

/// Minimum size of an object.
// FIXME(eddyb) get sizeof to work at compile time.
static OBJECT_MINIMUM_SIZE: uint = 4 + 4 + 4; // 8 + 8 + 4 on x64.
//static OBJECT_MINIMUM_SIZE: uint = size_of::<FreeNode>();

/// A cache allocates objects of a constant size.
pub struct Cache {
    object_size: uint,
    partial_lists: [*mut FreeNode, ..cpu::MAX_CPUS]
}

macro_rules! cache_list (
    ($($i:expr),*) => {
        [$(slam::Cache {
            object_size: 1u << $i,
            partial_lists: [0 as *mut slam::FreeNode, ..cpu::MAX_CPUS]
        }),*]
    }
)

impl Cache {
    #[inline(always)]
    fn slab_size(&self, object_size: uint) -> uint {
        //max(object_size, SLAB_MINIMUM_SIZE)
        if object_size >= SLAB_MINIMUM_SIZE {
            object_size
        } else {
            //assert!(object_size != 0);
            //assert!(SLAB_MINIMUM_SIZE % object_size == 0);
            SLAB_MINIMUM_SIZE
        }
    }

    unsafe fn free(&mut self, node: *UsedNode) {
        let cpu_id = cpu::id();

        let node = node as *mut FreeNode;
        (*node).prev = 0 as *mut FreeNode;

        // Put the freed node into the partial list.
        loop {
            let partial_ptr = self.partial_lists[cpu_id];
            (*node).next = partial_ptr;

            if atomics::compare_and_swap(&mut self.partial_lists[cpu_id], partial_ptr, node) == partial_ptr {
                if partial_ptr != 0 as *mut FreeNode {
                    (*partial_ptr).prev = node;
                }
                break;
            }
        }
    }
    /// \todo Implement.
    fn free_slab(&self, _slab: uint) {}
}

impl<Base: Allocator> Cache {
    #[inline(always)]
    // The object_size argument is a specialization optimization.
    // Always call with object_size == self.object_size.
    unsafe fn alloc(&mut self, base: &mut Base, object_size: uint) -> *UsedNode {
        let cpu_id = cpu::id();

        let mut node;

        // Take a free node from the partial list.
        loop {
            node = self.partial_lists[cpu_id];

            if node == 0 as *mut FreeNode {
                node = self.alloc_slab(base, object_size);
                break;
            }

            if atomics::compare_and_swap(&mut self.partial_lists[cpu_id], node, (*node).next) == node {
                break;
            }
        }

        let node = node as *mut UsedNode;
        (*node).cache = self as *mut Cache;

        node as *UsedNode
    }

    unsafe fn alloc_slab(&mut self, base: &mut Base, object_size: uint) -> *mut FreeNode {
        let slab_size = self.slab_size(object_size);

        let slab = base.alloc(slab_size) as uint;

        // All object in slab are free, generate Node*'s for each (except the first) and
        // link them together.
        let mut first = 0 as *mut FreeNode;
        let mut last = first;

        let slab_end = slab + slab_size;
        let mut p = slab + object_size;
        while p < slab_end {
            let node = p as *mut FreeNode;

            if first == 0 as *mut FreeNode {
                first = node;
            } else {
                (*last).next = node;
            }

            (*node).prev = last;
            last = node;

            p += object_size;
        }

        // Link this slab in as the first in the partial list.
        if first != 0 as *mut FreeNode {
            (*last).next = 0 as *mut FreeNode;

            let cpu_id = cpu::id();

            // We now need to do two atomic updates.
            loop {
                let partial_ptr = self.partial_lists[cpu_id];
                (*last).next = partial_ptr;
                if atomics::compare_and_swap(&mut self.partial_lists[cpu_id], partial_ptr, first) == partial_ptr {
                    if partial_ptr != 0 as *mut FreeNode {
                        (*partial_ptr).prev = last;
                    }
                    break;
                }
            }
        }

        // Return the first object for immediate allocation.
        slab as *mut FreeNode
    }
}

pub struct SlamAllocator<Base> {
    caches: [Cache, ..32],
    base: Base
}

macro_rules! SlamAllocator (
    ($base:expr) => (
        slam::SlamAllocator {
            caches: cache_list!(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31),
            base: $base
        }
    )
)

macro_rules! slam_specialize_cache_alloc (
    ($($i:expr),*) => {
        $(
            if lg2 == $i {
                self.cache_alloc_::<[u8, ..$i]>()
            }
        )else*
        else {
            abort()
        }
    }
)

impl<Base: Allocator> SlamAllocator<Base> {
    #[inline(never)]
    fn cache_alloc_<N>(&mut self) -> *mut u8 {
        UsedNode::get_data(unsafe {
            self.caches[size_of::<N>()].alloc(&mut self.base, 1 << size_of::<N>())
        })
    }

    fn cache_alloc(&mut self, lg2: uint) -> *mut u8 {
        slam_specialize_cache_alloc!(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31)
    }
}

impl<Base: Allocator> Allocator for SlamAllocator<Base> {
    #[inline(always)]
    fn alloc(&mut self, size: uint) -> *mut u8 {
        // Add in room for the allocation header.
        let size = size + size_of::<UsedNode>();
        //max(size, OBJECT_MINIMUM_SIZE)
        let size = if size < OBJECT_MINIMUM_SIZE {
            OBJECT_MINIMUM_SIZE
        } else {
            size
        };

        // Find nearest power of 2, if needed.
        let mut pow2 = 1u;
        let mut lg2 = 0u;
        while pow2 < size {
            pow2 <<= 1;
            lg2 += 1;
        }

        // Allocate 4GB and I'll kick your teeth in.
        //assert!(lg2 < 24);

        self.cache_alloc(lg2)
    }

    fn free(&mut self, ptr: *mut u8) {
        // Ensure this pointer is even on the heap...
        //if !cpu::vmm::ptr_is_in_heap(ptr) {
        //    fatal_nolock!("SlamAllocator::free - given pointer '" << ptr << "' was completely invalid.");
        //}

        let node = UsedNode::from_data(ptr);
        unsafe {
            (*(*node).cache).free(node);
        }
    }

    fn alloc_size_bounds(&mut self, ptr: *mut u8) -> (uint, uint) {
        let size = unsafe {
            (*(*UsedNode::from_data(ptr)).cache).object_size
        };
        ((size >> 1) - size_of::<UsedNode>(), size - size_of::<UsedNode>())
    }
}
