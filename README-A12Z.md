# melonx-a12z

A clone of MeloNX that runs **only on the Apple A12Z** — the 2020 iPad Pro — and refuses to
launch on anything else.

It exists to answer one question: **why does MeloNX fail on the A12Z and nowhere else?**

## Why restrict it

Because a result is only evidence if it could only have come from an A12Z. A build that runs
everywhere collects reports from A17 owners saying "works fine", which tells nobody anything
about the chip in question. This one shows a device report instead of the emulator on any other
hardware, so every report from it is an A12Z report.

Accepted device identifiers: `iPad8,9`, `iPad8,10`, `iPad8,11`, `iPad8,12`.

**`iPad8,1`–`iPad8,8` are deliberately excluded.** Those are the 2018 iPad Pro — A12X, the same
die with one fewer GPU core enabled. It is also GPU family 5, but has 4 GB of RAM against the
A12Z's 6 GB, and that difference is central to the leading hypothesis below.

## The leading hypothesis

Stated as a hypothesis, because it has not been tested on hardware.

**The bug is probably not chip-specific at all. It is GPU-family-specific, and only the A12Z has
enough memory to reach it.**

- A12Z is **Apple GPU family 5**. Family 6 (A13) is where Metal gained **Tier 2 argument
  buffers** and SIMD-group functions in fragment shaders.
- On **Tier 1**, MoltenVK's resource limits collapse to roughly **96/128 textures and 16
  samplers**. Sixteen samplers is nothing for a Switch title.
- MeloNX's `MVKInitialization.cs` sets `config.UseMetalArgumentBuffers = true` unconditionally,
  with no device check anywhere in the tree.
- A12 (iPhone XS) and A12X (2018 iPad Pro) are *also* family 5 and Tier 1 — but they have 4 GB
  of RAM, so nobody seriously runs a Switch emulator on them. They die of memory long before a
  GPU-tier problem can surface.

So the A12Z is plausibly the **only Tier 1 device with enough memory to get far enough to expose
a Tier 1 limitation**. That is exactly the shape of a bug that looks like it belongs to one chip.

**Evidence that cuts both ways:** on 2025-11-02, in commit `10e6ff78` titled only *"A lot"*,
Stossy11 commented out `config.UseMetalArgumentBuffers = true` with no stated reason. So this
precise setting has already been toggled once by someone chasing something. If the A12Z still
fails on a build where it is off, argument buffers are not the cause — and that is a result worth
having too.

## What this build changes

Nothing about emulation. Only the things needed to get a clean answer:

| Change | Why |
|---|---|
| A12Z-only gate | Any result is unambiguously about the A12Z |
| Device profile logged at launch via `NSLog`, before SDL or Metal is touched | If startup crashes, this is still the last thing in the log |
| `MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS` set explicitly from a toggle | The prime suspect, controlled directly instead of left to the C# default. **Defaults to off**, so the first run tests the Tier 1-safe configuration |
| `MVK_USE_METAL_PRIVATE_API` togglable | The other setting here whose behaviour can plausibly differ by GPU family |

Environment variables override whatever `MVKInitialization.cs` sets, so no C# change is needed to
A/B them.

## How to use it

1. Install on a 2020 iPad Pro. It will refuse anything else and show you why.
2. Read the device profile on the wrong-device screen or in the log. **Confirm `argument buffers:
   tier1`.** If an A12Z ever reports `tier2`, the hypothesis above is wrong and should be
   abandoned outright.
3. Run with argument buffers **off** (the default). Note what happens.
4. Toggle them **on**. Note what happens.
5. If the two runs differ, the cause is found. If they are identical, the cause is elsewhere and
   the next suspects are the JIT/TXM path and family-5's missing SIMD-group functions.

Report the device profile with any result — the tier and family lines are the parts that matter.

## Status

**Nothing here is proven.** No build from this clone has run on an A12Z yet. The hypothesis is
built from reading MeloNX's source, Apple's Metal feature tables, and MoltenVK's documentation.
It is written down so it can be *falsified quickly*, not because it is believed.

## Licence

MeloNX is GPLv3; this clone inherits it. Upstream: MeloNX by Stossy11, via
[VertexSelection/MeloVertex](https://github.com/VertexSelection/MeloVertex).
