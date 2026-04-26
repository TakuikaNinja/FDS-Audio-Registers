; FDS audio handling

; constants
VOL_GAIN = $3f
VOL_ENV = $3f
MOD_SPEED = $3f
; close to A-4
FREQUENCY = $0407
MOD_FREQ = $03ff

InitFDSAudio:
		lda #%10000001									; "reset" audio registers
		sta FDS_IO_ENABLE_MIRROR
		sta FDS_IO_ENABLE
		
		; the following writes should go all through anyway
		; mute channel (match BIOS init)
		lda #$80
		sta FDS_VOL_ENV
		lda #$e8
		sta FDS_ENV_SPEED
		
		lda #$00
		sta AudioQueue

InitWave:
		lda #$80
		sta FDS_MASTER_VOL								; enable wavetable writes
		ldy #63
@wave_loop:
		lda Waveform,y
		sta FDS_WAVE_RAM,y
		dey
		bpl @wave_loop
		
		lda #$00
		sta FDS_MASTER_VOL								; set write protect & max master volume
		
InitModTable:
		lda #$80
		sta FDS_MOD_FREQ_HI								; halt mod table counter
		
		lda #$6f
		sta FDS_MOD_COUNTER								; this mod table counter write should be ignored
		
		; it appears that mod table writes don't work as expected otherwise
		lda #%10000011
		sta FDS_IO_ENABLE_MIRROR
		sta FDS_IO_ENABLE
		
		ldy #$00
@mod_loop:
		lda ModTable,y
		sta FDS_MOD_TABLE
		iny
		cpy #32
		bne @mod_loop
		
;		lda #$00
;		sta FDS_MOD_COUNTER								; set mod table counter
		
		rts

UpdateFDSAudio:
		lda AudioQueue
		beq @exit
		
		; clear queue
		lda #$00
		sta AudioQueue
		
		; set pitch
		lda #<FREQUENCY
		sta FDS_FREQ_LOW
		lda #>FREQUENCY
		sta FDS_FREQ_HI
		
		; set modulation frequency, then speed
		lda #<MOD_FREQ
		sta FDS_MOD_FREQ_LOW
		lda #>MOD_FREQ
		sta FDS_MOD_FREQ_HI
		lda #($80 | MOD_SPEED)
		sta FDS_MOD_ENV
		
		; set volume gain, then envelope
		lda #($80 | VOL_GAIN)
		sta FDS_VOL_ENV
		lda #VOL_ENV
		sta FDS_VOL_ENV
@exit:
		rts

; Default DnFT FDS waveform
Waveform:
	.byte 0, 1, 12, 22, 32, 36, 39, 39, 42, 47, 47, 50, 48, 51, 54, 58
	.byte 54, 55, 49, 50, 52, 61, 63, 63, 59, 56, 53, 51, 48, 47, 41, 35
	.byte 35, 35, 41, 47, 48, 51, 53, 56, 59, 63, 63, 61, 52, 50, 49, 55
	.byte 54, 58, 54, 51, 48, 50, 47, 47, 42, 39, 39, 36, 32, 22, 12, 1

; Default DnFT sine mod table
ModTable:
	.byte 4, 7, 7, 7, 7, 7, 7, 0, 0, 0, 1, 1, 1, 1, 1, 1
	.byte 4, 1, 1, 1, 1, 1, 1, 0, 0, 0, 7, 7, 7, 7, 7, 7

