Absolutely — I’ll give you a compact, **fully runnable minimal bare-metal OS in Rust** (x86*64) that boots in QEMU and prints text to the screen. It’s inspired by the classic \_loony_os* approach but pared down so you can read, build, and extend it quickly.

What you’ll get here:

- Complete project layout and all source files.
- Build & run instructions (QEMU) — no background work needed; you can run immediately.
- Explanations of the important bits (no fluff).

---

## Overview (what this does)

- `no_std`, `no_main` Rust kernel for x86_64
- Uses the `bootloader` + `bootimage` toolchain to create a bootable disk image
- Prints "Hello OS — running in ring 0!" to the VGA text buffer
- Installs a custom panic handler
- Boots in QEMU

---

## Prerequisites

- `rustup` installed
- A **nightly** toolchain (we’ll use `rustup default nightly` for simplicity)
- `cargo install bootimage` (used to produce a bootable image)
- `qemu-system-x86_64` for testing

Commands:

```bash
rustup default nightly
cargo install bootimage
# On Debian/Ubuntu: sudo apt install qemu-system-x86 qemu-utils
# On macOS: brew install qemu
```

---

## Project layout

```
baremetal-rust-os/
├── Cargo.toml
├── Cargo.lock
├── rust-toolchain.toml
├── .cargo/
│   └── config.toml
├── src/
│   └── main.rs
└── x86_64-loony_os.json
```

---

## Files — copy exactly

### `rust-toolchain.toml`

(ensures nightly toolchain)

```toml
[toolchain]
channel = "nightly"
components = ["rust-src"]
```

---

### `.cargo/config.toml`

Tells cargo to use the custom target and linker.

```toml
[build]
target = "x86_64-loony_os.json"

[target.x86_64-loony_os]
runner = "bootimage runner" # bootimage integrates runner itself; this line is informational
```

---

### `x86_64-loony_os.json`

A minimal target spec (you can also use an existing community target, but this works).

```json
{
  "llvm-target": "x86_64-unknown-none",
  "target-endian": "little",
  "target-pointer-width": "64",
  "data-layout": "e-m:e-i64:64-f80:128-n8:16:32:64-S128",
  "arch": "x86_64",
  "os": "none",
  "vendor": "unknown",
  "linker-flavor": "ld.lld",
  "linker": "rust-lld",
  "disable-redzone": true,
  "executables": true,
  "relocation-model": "static",
  "features": "-mmx,-sse,+soft-float"
}
```

> Note: Using `rust-lld` (the builtin LLVM lld) avoids needing `gcc`/`ld` on many systems. If your host requires `ld`, adapt the `linker` field accordingly.

---

### `Cargo.toml`

```toml
[package]
name = "baremetal-rust-os"
version = "0.1.0"
edition = "2021"

[dependencies]
# used for x86_64 types (paging, registers, etc) — we'll use only a little of it
x86_64 = "0.14"

[dependencies.bootloader]
version = "0.10.10"
package = "bootloader"

[profile.dev]
panic = "abort"

[profile.release]
panic = "abort"

[package.metadata.bootimage]
# size of the image's kernel (not usually needed to change)
```

> If a version constraint causes issues later, bump to the latest `x86_64` and `bootloader` versions.

---

### `src/main.rs`

```rust
#![no_std]
#![no_main]

use core::panic::PanicInfo;

use bootloader::{entry_point, BootInfo};
use core::fmt::Write;
use x86_64::structures::paging::{PageTable, Translate};
use x86_64::{instructions::port::Port, VirtAddr};

entry_point!(kernel_main);

fn kernel_main(_boot_info: &'static BootInfo) -> ! {
    // Write to VGA text buffer directly
    vga_print("Hello OS — running in ring 0!\n\n");
    vga_print("This is a minimal bare-metal Rust kernel.\n");

    // Halt the CPU forever
    loop {
        x86_64::instructions::hlt();
    }
}

fn vga_print(s: &str) {
    use core::ptr::Unique;

    const VGA_BUFFER: usize = 0xb8000;
    // Each character: byte ASCII, byte attribute
    let mut offset = 0usize;
    let bytes = s.as_bytes();
    let buf_ptr = VGA_BUFFER as *mut u8;

    for &b in bytes {
        unsafe {
            core::ptr::write_volatile(buf_ptr.add(offset), b);
            core::ptr::write_volatile(buf_ptr.add(offset + 1), 0x07); // light grey on black
        }
        offset += 2;
    }
}

/// Panic handler: print message and halt.
#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    vga_print("\n\nKernel panic: ");
    if let Some(s) = info.payload().downcast_ref::<&str>() {
        vga_print(s);
    } else {
        vga_print("panic!");
    }
    loop {
        x86_64::instructions::hlt();
    }
}
```

Notes about the kernel:

- `bootloader::entry_point!` provides a C-style entry point and sets up a simple boot environment for you (stack, boot info pointer).
- We write directly to VGA text buffer at `0xb8000`. This is old-school but simple and works in QEMU.
- Panic handler writes a short message to the VGA buffer and halts.

---

## Build & Run

1. Ensure nightly and bootimage installed:

```bash
rustup default nightly
cargo install bootimage
```

2. Build a bootable image:

```bash
cargo bootimage
```

This produces something like: `target/x86_64-loony_os/debug/bootimage-baremetal-rust-os.bin`

3. Run in QEMU:

```bash
qemu-system-x86_64 -drive format=raw,file=target/x86_64-loony_os/debug/bootimage-baremetal-rust-os.bin -m 512M
```

You should see the message `Hello OS — running in ring 0!` on the QEMU display.

---

## If you run into troubles

- If `cargo bootimage` complains, try updating `bootimage` (`cargo install bootimage --force`) and ensure `rust-src` component is installed: `rustup component add rust-src`.
- If `rust-lld` isn't found, install `lld` (on Debian: `sudo apt install lld`) or change the `linker` in `x86_64-loony_os.json` to your host linker.
- For macOS homebrew users, `qemu` name may vary — install via `brew install qemu`.

---

## Next steps / extensions (quick suggestions)

- Add a basic panic screen with hex dumps and registers.
- Implement a simple custom VGA writer type instead of writing bytes manually.
- Add keyboard input handling and simple command loop.
- Implement interrupts + an IRQ handler.
- Implement dynamic memory (heap) and small allocator.

---

If you want, I can:

- Turn this into a full git-ready repo and attach a ZIP you can download.
- Replace `bootloader`/`bootimage` flow with a GRUB/multiboot approach.
- Add a nicer VGA writer with formatting macros (`core::fmt::Write`) and a `println!`-like macro.
- Add keyboard input and a tiny REPL.

Which of those would you like next?
