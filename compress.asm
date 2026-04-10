; ===============================================================================================
;      ___      ___ _______   ________  ________  _______   ________     
;     |\  \    /  /|\  ___ \ |\   ____\|\   __  \|\  ___ \ |\   __  \    
;     \ \  \  /  / | \   __/|\ \  \___|\ \  \|\  \ \   __/|\ \  \|\  \   
;      \ \  \/  / / \ \  \_|/_\ \_____  \ \  \\\  \ \  \_|/_\ \   _  _\  
;       \ \    / /   \ \  \_|\ \|____|\  \ \  \\\  \ \  \_|\ \ \  \\  \| 
;        \ \__/ /     \ \_______\____\_\  \ \__\\ _\\ \_______\ \__\\ _\ 
;         \|__|/       \|_______|\_________\|__|\|__|\|_______|\|__|\|__|
;                               \|_________|                             
;
;      ____  ____  ________  ___    ____  __    ______
;     / __ \/ __ \/ ____/  |/  /   / __ \/ /   / ____/
;    / / / / /_/ / /   / /|_/ /   / /_/ / /   / __/
;   / /_/ / ____/ /___/ /  / /   / _, _/ /___/ /___
;  /_____/_/    \____/_/  /_/   /_/ |_/_____/_____/
;
;      __  ____  ______  ____  ________    ______   _   __   ______   ____   _   __   ______
;     / / / /\ \/ / __ )/ __ \/  _/ __ \  / ____/  / | / /  / ____/  /  _/  / | / /  / ____/
;    / /_/ /  \  / __  / /_/ // // / / / / __/    /  |/ /  / / __    / /   /  |/ /  / __/
;   / __  /   / / /_/ / _, _// // /_/ / / /___   / /|  /  / /_/ /  _/ /   / /|  /  / /___
;  /_/ /_/   /_/_____/_/ |_/___/_____/ /_____/  /_/ |_/   \____/  /___/  /_/ |_/  /_____/
;
; ===============================================================================================
; Project      : VESQER Baremetal Compressor
; Module       : Compressor (Standalone)
; Author       : JM00NJ - https://github.com/JM00NJ
; Architecture : x86_64 Linux (Pure Assembly / Zero-Dependency)
; -----------------------------------------------------------------------------------------------
; Features:
;   - Algorithm   : Custom Differential Pulse-Code Modulation (DPCM) + RLE
;   - Native I/O  : Dynamic file descriptor handling via sys_open, read, write, close
;   - Evasion     : Zero libc dependencies, no predictable magic bytes
;   - Limits      : 5MB Input Buffer / 10MB Output Buffer (Overflow protection)
; -----------------------------------------------------------------------------------------------
; License: MIT License
; -----------------------------------------------------------------------------------------------
; Build: nasm -f elf64 compress.asm -o compress.o && ld compress.o -o compress
; Run  : ./compress
; ===============================================================================================


section .bss
    filename resb 256               ; path of file
    input_buffer resb 5242880       ; 5 MB  Buffer for raw input data - MAX 5 MB
    text_compressed resb 10485760   ; 10 MB Buffer for compressed output data - MAX 10 MB
    
    
section .data
    prompt db 'Enter path to file: '
    prompt_len equ $ - prompt
    out_filename db 'compressed_output.bin', 0

section .text
global _start

_start:
    ; ==========================================
    ; STEP 0: PROMPT USER FOR FILE PATH
    ; ==========================================
    mov rax, 1                  ; sys_write
    mov rdi, 1                  ; fd: stdout
    lea rsi, [prompt]
    mov rdx, prompt_len
    syscall

    ; ==========================================
    ; STEP 1: READ FILE PATH FROM STDIN
    ; ==========================================
    mov rax, 0                  ; sys_read
    mov rdi, 0                  ; fd: stdin
    lea rsi, [filename]
    mov rdx, 256
    syscall

    ; --- STRIP NEWLINE (\n) CHARACTER ---
    dec rax                             ; Get index of the last character (newline)
    mov byte [filename + rax], 0        ; Replace '\n' with null terminator

    ; ==========================================
    ; STEP 2: OPEN INPUT FILE
    ; ==========================================
    mov rax, 2                  ; sys_open
    lea rdi, [filename]
    xor rsi, rsi                ; flags: O_RDONLY (0)
    xor rdx, rdx                ; mode: 0
    syscall

    test rax, rax
    js _exit_error              ; Jump to error handler if file open fails

    mov r12, rax                ; Backup file descriptor to r12

    ; ==========================================
    ; STEP 3: READ INPUT FILE
    ; ==========================================
    mov rax, 0                  ; sys_read
    mov rdi, r12                
    lea rsi, [input_buffer]     
    mov rdx, 4096               
    syscall

    test rax, rax
    jle _exit_error             ; Exit if file is empty or read fails

    mov r13, rax                ; Backup total bytes read to r13 (sys_close overwrites rcx)

    ; ==========================================
    ; STEP 4: CLOSE INPUT FILE
    ; ==========================================
    mov rax, 3                  ; sys_close
    mov rdi, r12                
    syscall                     

    ; ==========================================
    ; STEP 5: SETUP COMPRESSION POINTERS
    ; ==========================================
    mov rcx, r13                ; Restore total bytes read into loop counter (rcx)
    
    mov r8b, 0                  ; Initialize RLE counter
    xor r9b, r9b                ; Initialize Active Delta
    lea rsi, [input_buffer]     ; Source pointer
    lea rdi, [text_compressed]  ; Destination pointer

_anchor_setup:
    ; Set the first byte as the initial anchor
    mov al, byte[rsi]           
    inc rsi                     

    mov byte [rdi], al          
    inc rdi                     

    mov bl, al                  

    dec rcx                     
    jz _end
    mov al, byte[rsi]
    mov dl, al                  
    sub al, bl                  ; Calculate initial delta
    mov r9b, al

_compress_loop:
    test rcx, rcx
    jz _end
    mov al, byte[rsi]
    mov dl, al                  
    sub al, bl                  ; Current byte - Previous byte
    cmp al, r9b
    jne _flush                  ; If delta changes, flush the current run

_inc_r8b:
    inc r8b                     ; Increment RLE counter
    inc rsi
    dec rcx
    jz _end
    mov bl, dl                  ; Update anchor
    cmp r8b, 255                ; Check for 8-bit overflow
    jne _compress_loop

_flush_255:
    ; Handle 255 byte limit reached for a single delta run
    mov byte [rdi], r8b     
    inc rdi
    mov byte [rdi], r9b     
    inc rdi
    mov r8b, 0                  ; Reset RLE counter, keep the same delta
    jmp _compress_loop

_flush:
    ; Write current run length and delta to memory
    mov byte [rdi], r8b     
    inc rdi                 
    mov byte [rdi], r9b     
    inc rdi                 

    ; Start new sequence
    mov r9b, al
    mov r8b, 1
    mov bl, dl

    inc rsi
    dec rcx
    jz _end
    jmp _compress_loop

_end:
    ; Write the final sequence to memory
    mov byte [rdi], r8b
    inc rdi
    mov byte [rdi], r9b
    inc rdi

    ; --- CALCULATE COMPRESSED LENGTH ---
    mov rdx, rdi                
    lea rsi, [text_compressed]  
    sub rdx, rsi                ; End address - Start address = Total bytes
    
    mov r14, rdx                ; Backup compressed length to r14

    ; --- OPEN / CREATE OUTPUT FILE ---
    mov rax, 2                  ; sys_open
    lea rdi, [out_filename]     
    mov rsi, 65                 ; flags: O_CREAT (64) | O_WRONLY (1) = 65
    mov rdx, 420                ; mode: 0644 (Octal) -> rw-r--r--
    syscall

    test rax, rax               
    js _exit_error              

    mov r15, rax                ; Backup output file descriptor to r15

    ; --- WRITE COMPRESSED DATA ---
    mov rax, 1                  ; sys_write
    mov rdi, r15                
    lea rsi, [text_compressed]  
    mov rdx, r14                ; Restore compressed length
    syscall

    ; --- CLOSE OUTPUT FILE ---
    mov rax, 3                  ; sys_close
    mov rdi, r15                
    syscall
    
    ; --- EXIT GRACEFULLY ---
    mov rax, 60                 ; sys_exit
    xor rdi, rdi
    syscall

_exit_error:
    ; Error handler
    mov rax, 60
    mov rdi, 1                  ; Exit code 1
    syscall
