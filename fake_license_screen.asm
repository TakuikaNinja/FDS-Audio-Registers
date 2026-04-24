; Fake license screen for FDS
; by TakuikaNinja

; The fake license screen sequence is ubiquitous with unlicensed FDS games, 
; so why can't us homebrew devs also have some fun here?
; Just plop this in as the IRQ vector at $dffe, and overwrite it afterwards if needed.

; Explanation:
; This uses a newly discovered IRQ hijack method which requires a file to be loaded starting from $0200-$07ff,
; and "overflow" into mirrored zeropage at $0800. The FDS BIOS fails to account for this.
; The file load destination pointer at ($0A) is modified to point to the mirrored stack page at $0900, 
; which allows the IRQ flag at $0101 ($0901) to be overwritten with $c0.
; Doing so causes the next IRQ from the disk load process to execute the IRQ vector stored at $dffe, 
; which points to this custom program in system RAM. (I sure hope you're clearing system RAM during reset...)

; The proper license screen bypass is already done by the time the fake one is displayed, 
; so feel free to skip the whole thing with a soft-reset.

; Set the following flag to 0 to skip the message:
SHOW_MESSAGE = 0

Bypass:
		sei												; IRQ already does this but mask them anyway
		ldx #$00
		stx $4023
		lda #$83
		sta $4023										; reset disk registers
		lda #$2e
		sta $4025										; turn off drive motor
		dex
		txs												; S = $ff
		
		lda #$35										; tell the FDS that the BIOS "did its job"
		sta $0102
		lda #$ac
		sta $0103
		
.if SHOW_MESSAGE = 1
		jsr FakeLicenseScreen
.endif
		
		jmp ($fffc)										; jump to reset FDS

.if SHOW_MESSAGE = 1
FakeLicenseScreen:
		jsr VINTWait
		jsr DisPFObj
		jsr VRAMStructWrite
	.addr FakeLicenseScreenPalettes
		jsr InitFakeLicenseScreens
		jsr VRAMStructWrite
	.addr FakeLicenseScreenTilemap

		lda #$20										; init timer
		sta $a2

ScrollLoop:
		jsr VINTWait
		jsr EnPF
		jsr SetScroll
		ldx $fc											; Y scroll
		inx
		inx
		cpx #$b0										; scroll until message is at the correct level
		bcs :+
		stx $fc		
:
		ldx #$80										; $80 = primary counter (9->0 loop)
		lda #$9f										; $81-$9f = always ticked (??->0)
		ldy #$bf										; $a0-$bf = ticked by primary "underflow" (??->0)
		jsr CounterLogic
		lda $a2
		bne ScrollLoop									; loop until timer expires
		rts

InitFakeLicenseScreens:
		lda #$20
		jsr InitFakeLicenseScreen
		lda #$28
		
InitFakeLicenseScreen:
		ldx #' '
		ldy #$00
		jmp VRAMFill

; VRAM transfer structures for fake license screen
FakeLicenseScreenPalettes:
	.dbyt $3f00
	encode_length INC1, COPY, 4
	.byte $0f, $00, $10, $20
	encode_terminator

; Bottom-left nametable tiles
FakeLicenseScreenTilemap:
	encode_static_string $2800, 12, 0, INC1, COPY, "HOMEBREW"
	encode_static_string $2800, 7, 1, INC1, COPY, "DISK CARD SOFTWARE"
	encode_static_string $2800, 2, 3, INC1, COPY, "THIS PRODUCT IS THE ORIGINAL"
	encode_static_string $2800, 2, 4, INC1, COPY, "WORK OF HOMEBREW DEVELOPERS"
	encode_static_string $2800, 2, 5, INC1, COPY, "AND IS NOT LICENSED BY THE"
	encode_static_string $2800, 2, 6, INC1, COPY, "MANUFACTURER OF THIS SYSTEM."
	encode_terminator
.endif

; Might as well provide valid pointers, it's not like we're strapped for space here
DiskID:
FileList:
.res 10, $ff

; This section is required for the IRQ hijack method!
; Padding
PAD = $0200
.res Bypass+PAD-*, 0
.assert * = $0800, error, "Cannot overwrite mirrored ZP!"

; Values to overwrite in ZP mirror at $0800
ZPOverwrite:
.addr DiskID ; (the disk load attempt counter makes this redundant)
.addr FileList ; (checked for each file header block)
.byte $fa ; temp S-1, needed in order to return from disk errors
.byte 1 ; disk load attempt counter, allow it to decrement to 0 in case of an error
.byte 1 ; # of remaining files, including this one (e.g. 1 if no more files come after this one)
.byte 4 ; current file block
.byte BOOT_ID ; boot read file code
.byte 0 ; dummy read flag
.byte $ff ; load destination lo byte (address + 1 = $0900)

; Now we can overwrite the stack variables mirrored at $0900
StackOverwrite:
.byte $c0 ; NMI flag (use vector at $dffa)
.byte $c0 ; IRQ flag (use vector at $dffe)

