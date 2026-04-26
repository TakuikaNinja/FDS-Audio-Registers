; Main program code
;
; Formatting:
; - Width: 132 Columns
; - Tab Size: 4, using tab
; - Comments: Column 57

; enable backslash escape sequences
.feature string_escapes +

; Reset handler
; Much of the init tasks are already done by the BIOS reset handler, including the PPU warmup loops.
Reset:
		lda #$00										; clear RAM
		tax
@clrmem:
		sta $00,x
		sta $0100,x
		sta $0200,x
		sta $0300,x
		sta $0400,x
		sta $0500,x
		sta $0600,x
		sta $0700,x
		inx
		bne @clrmem
		
		jsr InitZPStack
		jsr MoveSpritesOffscreen
		jsr InitNametables
		jsr InitFDSAudio
		
		lda #BUFFER_SIZE								; set VRAM buffer size
		sta VRAM_BUFFER_SIZE

		jsr EnableNMI
		
Main:
		jsr ReadOrDownPads								; read controllers + expansion port
		jsr ProcessBGMode
		jsr WaitForNMI
		beq Main										; back to main loop
	
; NMI handler
NonMaskableInterrupt:
		pha												; back up A/X/Y
		txa
		pha
		tya
		pha
		
		lda NMIReady									; check if ready to do NMI logic (i.e. not a lag frame)
		beq NotReady
		
		jsr SpriteDMA
		
		lda NeedDraw									; transfer Data to PPU if required
		beq :+
		
		jsr WriteVRAMBuffer								; transfer data from VRAM buffer at $0302
		jsr SetScroll									; reset scroll after PPUADDR writes
		dec NeedDraw
		
:
		lda NeedPPUMask									; write PPUMASK if required
		beq :+
		
		lda PPU_MASK_MIRROR
		sta PPU_MASK
		dec NeedPPUMask

:
		dec NMIReady

NotReady:
		jsr SetScroll									; remember to set scroll on lag frames
		jsr UpdateFDSAudio
		
		pla												; restore X/Y/A
		tay
		pla
		tax
		pla
		
; IRQ handler (unused for now)
InterruptRequest:
		rti

; Init BIOS ZP & stack variables to the expected values after clearing them
.proc ZPStackData
	.byte $ff, $2e, 0, 0, 0, $06, $10, $c0, $80, $35, $53
.endproc

InitZPStack:
		ldx #.sizeof(ZPStackData)
@loop:
		lda ZPStackData,x
		sta a:FDS_EXT_MIRROR,x
		dex
		bpl @loop
		rts

EnableRendering:
		lda #%00011110									; enable rendering and queue it for next NMI
	.byte $2c											; [skip 2 bytes]

DisableSprites:
		lda #%00001010
	.byte $2c											; [skip 2 bytes]

DisableRendering:
		lda #%00000000									; disable background and queue it for next NMI

UpdatePPUMask:
		sta PPU_MASK_MIRROR
		lda #$01
		sta NeedPPUMask
		rts

MoveSpritesOffscreen:
		lda #$ff										; fill OAM buffer with $ff to move offscreen
		ldx #>oam
		ldy #>oam
		jmp MemFill

InitNametables:
		lda #$20										; top-left
		jsr InitNametable
		lda #$28										; bottom-left

InitNametable:
		ldx #$00										; clear nametable & attributes for high address held in A
		ldy #$00
		jmp VRAMFill

EnableNMI:
		bit PPU_STATUS									; in case this was called with the vblank flag set
:
		bit PPU_STATUS									; wait for vblank
		bpl :-
		lda PPU_CTRL_MIRROR								; enable NMI
		ora #%10000000
		sta PPU_CTRL_MIRROR								; write to mirror first for thread safety
		sta PPU_CTRL
		rts

WaitForNMI:
		inc NMIReady
:
		lda NMIReady
		bne :-
		rts

; Jump table for main logic
ProcessBGMode:
		lda Mode
		jsr JumpEngine
	.addr BGInit
	.addr DoNothing

; Initialise background to display the program name
BGInit:
		jsr DisableRendering
		jsr WaitForNMI
		jsr VRAMStructWrite
	.addr BGData
		inc Mode
		jmp EnableRendering								; remember to enable rendering for the next NMI

; Stay in this state forever
DoNothing:
		lda P1_PRESSED
		tay
		and #BUTTON_A
		sta AudioQueue									; A pressed = play note
		tya
		and #BUTTON_B
		beq :+
		lda FDS_IO_ENABLE_MIRROR						; B pressed = toggle sound registers
		eor #%00000010
		sta FDS_IO_ENABLE_MIRROR
		sta FDS_IO_ENABLE
:
		jsr ChangeModCounter							; up/down = manipulate mod counter
		jsr CopyBitfieldSprites
		; dump $4090-$4097
		vram_addr_string $2000, 12, 12, FDS_VOL_GAIN, 8
		
		inc NeedDraw
		rts

YPos := 43
StartingXPos := 96
XPos := temp+1
CopyBitfieldSprites:
		lda FDS_IO_ENABLE_MIRROR
		sta temp
		lda #StartingXPos
		sta XPos
		ldy #$08
		ldx #$00
@tile:
		lda #YPos
		sta oam,x										; Y position is constant
		
		lda #'0'										; calculate tile index
		asl temp
		adc #$00
		sta oam+1,x
		
		lda #$01										; attributes are constant
		sta oam+2,x
		
		lda XPos										; store current X position
		sta oam+3,x
		adc #$08										; offset next sprite by 1 tile (carry always clear)
		sta XPos
		
		inx
		inx
		inx
		inx
		dey
		bne @tile										; repeat for all 8 bits
		rts

ChangeModCounter:
		lda P1_PRESSED
		and #(BUTTON_UP | BUTTON_DOWN)
		cmp #BUTTON_UP
		bne :+
		
		ldx FDS_MOD_COUNTER_VAL
		dex
		stx FDS_MOD_COUNTER
:
		cmp #BUTTON_DOWN
		bne :+
		
		ldx FDS_MOD_COUNTER_VAL
		inx
		stx FDS_MOD_COUNTER
:
		rts

.include "fds-audio.asm"

; VRAM transfer structure
BGData:

; Just write to all 16 entries so PPUADDR safely leaves the palette RAM region
; PPUADDR ends at $3F20 before the next write (avoids rare palette corruption)
; (palette entries will never be changed anyway, so we might as well set them all)
Palettes:
	.dbyt $3f00
	encode_length INC1, COPY, PaletteDataSize

.proc PaletteData
	; BG
	.byte $0f, $0f, $0f, $0f ; blank entry to hide attribute blocks
	.repeat 3
	.byte $0f, $20, $20, $20
	.endrepeat
	
	; Sprites
	.byte $0f, $0f, $0f, $0f ; blank entry to hide nametable tiles
	.repeat 3
	.byte $0f, $00, $10, $20
	.endrepeat
.endproc
PaletteDataSize = .sizeof(PaletteData)

HexDumpAttributes:
	.dbyt $23db
	encode_length INC1, FILL, 2
	.byte ATTRIBUTE 3,3,0,0
	
	encode_terminator

