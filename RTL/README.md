# A4092 CPLD RTL

Verilog RTL for the A4092 Zorro III SCSI controller. The design targets a
**Xilinx XC95144XL** CPLD and bridges a **NCR 53C710** (or 53C770) SCSI
controller to the Amiga Zorro III bus. It is a modern re-implementation of the
glue logic found on the Commodore A4091.

## Architecture Overview

```
                        Zorro III Bus
                 ───────────┬───────────
                            │
                     ┌──────┴──────┐
                     │  A4092 CPLD │
                     │  (XC95144XL)│
                     │             │
          ┌──────────┤  Top-level  ├───────────┐
          │          │  A4092.v    │           │
          │          └──┬───┬───┬──┘           │
          │             │   │   │              │
     ┌────┴────┐  ┌─────┴┐  │ ┌-┴─────┐  ┌─────┴────┐
     │Autoconf │  │Buffer│  │ │ DMA   │  │Interrupt │
     │         │  │Ctrl  │  │ │Arbiter│  │Handling  │
     └─────────┘  └──────┘  │ └───┬───┘  └──────────┘
                            │     │
                       ┌────┴-┐ ┌─┴──────┐
                       │SCSI  │ │  DMA   │
                       │Access│ │ Master │
                       └──────┘ └────────┘
                           │
                    ───────┴───────
                     NCR 53C710/770
```

## Module Descriptions

| Module | File | Description |
|---|---|---|
| **A4092** | `A4092.v` | Top-level module. Clock generation, address decoding, data bus muxing, and Zorro III signal assignment. |
| **autoconfig** | `autoconfig.v` | Zorro III Autoconfig (plug-and-play). Presents manufacturer/product ID and accepts base address assignment from the OS. |
| **buffercontrol** | `buffercontrol.v` | Controls external data and address bus buffers -- output enable, direction, and data latching for both slave and DMA master cycles. |
| **dmaarbiter** | `dmaarbiter.v` | Arbitrates between the NCR SCSI chip's DMA requests and the Zorro III bus. Handles bus request/grant handshaking on the 7 MHz arbitration clock. |
| **dmamaster** | `dmamaster.v` | Generates Zorro III bus master cycle timing (FCS, DOE, DS) when the NCR chip performs DMA transfers. |
| **scsiaccess** | `scsiaccess.v` | Manages CPU (slave) access to NCR SCSI registers. Generates AS/DS/SREG strobes to the SCSI chip and converts SLACK to Zorro DTACK. |
| **interrupthandling** | `interrupthandling.v` | Handles SCSI interrupts. Supports both directly-forwarded INT2 and the Zorro III Quick Interrupt protocol with programmable interrupt vectors. |
| **sidregister** | `sidregister.v` | Software-accessible SCSI ID / configuration register. Replaces the hardware DIP switch with a virtual register; also controls external SCSI bus termination. |
| **spirom** | `spirom.v` | SPI flash ROM interface. Bit-bangs SPI read commands to serve firmware to the CPU over Zorro III. |
| **parallelrom** | `parallelrom.v` | Parallel flash ROM interface (active when `USE_SPIROM` is not defined). Directly drives CE/OE/WE lines with configurable wait states. |

## Address Map

Within the card's Autoconfig-assigned 16 MB address space:

| Offset | Range | Peripheral |
|---|---|---|
| `$000000` | `$000000 - $7FFFFF` | Boot ROM (SPI or parallel flash) |
| `$800000` | `$800000 - $87FFFF` | NCR 53C710/770 SCSI registers |
| `$880000` | `$880000 - $8BFFFF` | Interrupt control register |
| `$8C0000` | `$8C0000 - $8FFFFF` | SCSI ID / configuration register |

Address decoding uses `A[23]`, `A[19]`, and `A[18]` in the top-level module.

## Compile-Time Options

Defined at the top of `A4092.v`:

| Define | Default | Description |
|---|---|---|
| `USE_SPIROM` | Defined | Use SPI flash for boot ROM. Undefine for parallel flash. |
| `USE_DIP_SWITCH` | Undefined | Use a physical DIP switch for SCSI ID instead of the virtual `sidregister`. |
| `A22_21_MISSING` | Defined | Address lines A22/A21 are not routed to the CPLD; synthesizes workaround logic. |
| `53C770` | Undefined | When defined, BCLK is an external input from a 53C770. Otherwise the CPLD generates 25 MHz by dividing the 50 MHz oscillator. |

## Autoconfig Identity

| Field | Value |
|---|---|
| Manufacturer ID | 514 (Commodore) |
| Product ID | 84 |
| Serial | 14 |
| ROM vector offset | 512 ($200) |

## Clocks

- **CLK_50M** -- 50 MHz oscillator input, used by SPI ROM and interrupt logic.
- **CLK** (25 MHz) -- Generated internally by dividing CLK_50M by 2 (or external input when `53C770` is defined). Drives the NCR SCSI chip as BCLK and clocks most bus-cycle state machines.
- **C7M** (7.09 MHz) -- Zorro III arbitration clock from the backplane. Used exclusively by the DMA arbiter for bus request timing.

## Building

Requires the Xilinx ISE toolchain (XST, ngdbuild, cpldfit, hprep6).

```
make                 # Synthesize and produce A4092.jed
make timing          # Run timing analysis
make flash           # Program the CPLD via JTAG
make clean           # Remove build artifacts
```

The Makefile exposes four build targets: `A4092`, `A4770`, `A4092_Buster9`, and
`A4770_Buster9`. The `A4092` target maps to the SPI-ROM, no-DIP-switch
configuration formerly named `A4092c`.
