# dpcm-rle-hybrid-x64-compressor
A standalone, pure x86-64 Assembly implementation of a DPCM+RLE hybrid compression and decompression engine. Built with zero external dependencies (no libc), this tool provides extremely low-level, high-speed data processing optimized for sequential and repetitive file structures.


## 🎯 Optimal Use Cases (Hangi Dosyalar İçin Uygun?)

This hybrid algorithm (Differential Pulse-Code Modulation + Run-Length Encoding) does not use a dictionary (like LZ77/Deflate). Instead, it relies on predictive mathematical deltas. 

Therefore, it is highly sensitive to the **type of data** being compressed:

**✅ Excellent Compression (Highly Recommended):**
* **Log Files (`.log`, `.txt`):** Repeated timestamps, IP addresses, and identical error messages are compressed massively.
* **Database Exports (`.csv`, `.tsv`):** Sequentially incrementing IDs and repeated delimiters compress perfectly due to DPCM predicting the fixed increments.
* **Source Code / HTML / JSON:** Structured text with heavy indentation (spaces/tabs) and predictable character sets.
* **Bitmap/Raw Uncompressed Media:** Certain raw sensor data or uncompressed 8-bit monochromatic bitmaps with smooth gradients.

**❌ Poor Compression (Not Recommended):**
* **Already Compressed Files (`.zip`, `.gz`, `.jpeg`, `.mp4`):** These files lack redundancy. The algorithm will actually increase their size.
* **Encrypted Data:** Randomly distributed high-entropy data cannot be predicted by DPCM or grouped by RLE.
* **Compiled Binaries (`.exe`, `.so`, `.elf`):** High entropy machine code with jumping memory addresses reduces the effectiveness of simple delta encoding.

## 🤔 Why did I create this repo?

Honesty time: I didn't originally set out to write a historical compression algorithm. I was actually brainstorming ways to stealthily exfiltrate large files for a custom C2 (Command & Control) project I'm working on. 

While bouncing ideas off Gemini late at night, I had what felt like a brilliant "lightbulb" moment: *"What if I just set a static ASCII character as an anchor, calculate the difference of the upcoming characters, and just count how many times that difference repeats?"* My main goal was to keep the logic as simple and the shellcode as tiny as possible. I felt like a genius... right up until I realized I had just accidentally reinvented **DPCM + RLE**, which was already invented by telecom engineers back in the 1970s! :D

Even though I wasn't the first to think of the math, writing this completely from scratch in pure x86-64 Assembly—with zero external libraries—turned out to be an amazing challenge. It works perfectly as a lightweight, stealthy, and zero-dependency evasion tool for C2 communications.
