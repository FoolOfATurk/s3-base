; ---------------------------------------------------------------------------
; Level Select
; ---------------------------------------------------------------------------

; Constants
LevelSelect_Offset:				= *
LevelSelect_VRAM:				= 0

; Variables
LevelSelect_ZoneCount:			= ZoneCount
LevelSelect_ActDEZCount:			= 4	; DEZ

LevelSelect_CharacterCount:		= 7
LevelSelect_MusicTestCount:		= LevelSelect_CharacterCount+1
LevelSelect_SoundTestCount:		= LevelSelect_MusicTestCount+1
LevelSelect_SampleTestCount:		= LevelSelect_SoundTestCount+1
LevelSelect_MaxCount:			= 11
LevelSelect_MaxCharacters:		= 4
LevelSelect_MaxMusicNumber:		= (mus__Last-mus__First)
LevelSelect_MaxSoundNumber:		= (sfx__Last-sfx__First)
LevelSelect_MaxSampleNumber:	= (dac__Last-dac__First)

; RAM
	phase ramaddr(RAM_start)

vLevelSelect_buffer:				ds.b $1000	; foreground buffer (copy)
vLevelSelect_buffer2:				ds.b $1000	; foreground buffer (main)

	dephase

	phase ramaddr(Object_load_addr_front)

vLevelSelect_music_count:			ds.w 1
vLevelSelect_sound_count:			ds.w 1
vLevelSelect_sample_count:		ds.w 1
vLevelSelect_control_timer:			ds.w 1
vLevelSelect_saved_act:			ds.w 1
vLevelSelect_vertical_count:		ds.w 1
vLevelSelect_horizontal_count:		ds.w $10

	dephase
	!org	LevelSelect_Offset

; =============== S U B R O U T I N E =======================================

LevelSelect_Screen:
		music	mus_Stop											; stop music
		jsr	(Clear_Kos_Module_Queue).w								; clear KosM PLCs
		ResetDMAQueue												; clear DMA queue
		jsr	(Pal_FadeToBlack).w
		disableInts
		move.l	#VInt,(V_int_addr).w
		move.l	#HInt,(H_int_addr).w
		disableScreen
		jsr	(Clear_DisplayData).w
		lea	Level_VDP(pc),a1
		jsr	(Load_VDP).w
		jsr	(Clear_Palette).w
		clearRAM RAM_start, (RAM_start+$1000)						; clear foreground buffer
		clearRAM Object_RAM, Object_RAM_end
		clearRAM Lag_frame_count, Lag_frame_count_end
		clearRAM Camera_RAM, Camera_RAM_end
		clearRAM Oscillating_variables, Oscillating_variables_end
		moveq	#0,d0
		move.b	d0,(Water_full_screen_flag).w
		move.b	d0,(Water_flag).w
		move.w	d0,(Current_zone_and_act).w
		move.w	d0,(Apparent_zone_and_act).w
		move.b	d0,(Last_star_post_hit).w
		move.b	d0,(Debug_mode_flag).w

		; load main art
		lea	(ArtKosM_LevelSelectText).l,a1
		move.w	#tiles_to_bytes(1),d2
		jsr	(Queue_Kos_Module).w

		; load main palette
		lea	(Pal_LevelSelect).l,a1
		lea	(Target_palette).w,a2
		jsr	(PalLoad_Line32).w

		; load text
		bsr.w	LevelSelect_LoadText
		move.w	#palette_line_1+LevelSelect_VRAM,d3
		bsr.w	LevelSelect_LoadMainText
		move.w	#palette_line_0+LevelSelect_VRAM,d3
		bsr.w	LevelSelect_LoadCharacter
		move.w	#palette_line_0+LevelSelect_VRAM,d3
		bsr.w	LevelSelect_MarkFields.drawmusic
		move.w	#palette_line_0+LevelSelect_VRAM,d3
		bsr.w	LevelSelect_MarkFields.drawsound
		move.w	#palette_line_0+LevelSelect_VRAM,d3
		bsr.w	LevelSelect_MarkFields.drawsample
		move.w	#palette_line_1,d3
		bsr.w	LevelSelect_MarkFields

.waitplc
		move.b	#VintID_Fade,(V_int_routine).w
		jsr	(Process_Kos_Queue).w
		jsr	(Wait_VSync).w
		jsr	(Process_Kos_Module_Queue).w
		tst.w	(Kos_modules_left).w
		bne.s	.waitplc
		move.b	#VintID_LevelSelect,(V_int_routine).w
		jsr	(Wait_VSync).w
		enableScreen
		jsr	(Pal_FadeFromBlack).w

.loop
		move.b	#VintID_LevelSelect,(V_int_routine).w
		jsr	(Wait_VSync).w
		lea	LSScroll_Data(pc),a2
		jsr	(HScroll_Deform).w
		moveq	#palette_line_0,d3
		bsr.w	LevelSelect_MarkFields
		bsr.s	LevelSelect_Controls
		move.w	#palette_line_1,d3
		bsr.w	LevelSelect_MarkFields
		cmpi.w	#LevelSelect_ZoneCount,(vLevelSelect_vertical_count).w
		bhs.s	.loop
		tst.b	(Ctrl_1_pressed).w
		bpl.s	.loop

		; set
		move.b	#3,(Life_count).w

		; clear
		moveq	#0,d0
		move.w	d0,(Ring_count).w
		move.l	d0,(Timer).w
		move.l	d0,(Score).w
		move.b	d0,(Continue_count).w
		move.w	d0,(Current_zone_and_act).w
		move.w	d0,(Apparent_zone_and_act).w
		move.l	#5000,(Next_extra_life_score).w

		; load zone and act
		move.b	#id_LevelScreen,(Game_mode).w						; set screen mode to level
		move.w	(vLevelSelect_vertical_count).w,d2
		move.b	d2,(sp)												; multiply by $100
		move.w	(sp),d2
		clr.b	d2
		add.w	(vLevelSelect_saved_act).w,d2
		move.w	d2,(Current_zone_and_act).w
		move.w	d2,(Apparent_zone_and_act).w
		rts

; ---------------------------------------------------------------------------
; Check vertical line
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================

LevelSelect_Controls:

		; set vertical line
		moveq	#LevelSelect_MaxCount-1,d2							; set max count
		move.w	(vLevelSelect_vertical_count).w,d3
		lea	(vLevelSelect_control_timer).w,a3
		bsr.w	LevelSelect_FindUpDownControls
		move.w	d3,(vLevelSelect_vertical_count).w

		; check vertical line
		cmpi.w	#LevelSelect_ZoneCount,d3
		blo.s		.getact
		subq.w	#LevelSelect_CharacterCount,d3
		blo.s		.return
		add.w	d3,d3
		add.w	d3,d3
		jmp	.index(pc,d3.w)
; ---------------------------------------------------------------------------

.index
		bra.s	.getcharacter											; 0

.return
		rts		; nop
		bra.s	.getmusic											; 2
		rts		; nop
		bra.w	.getsound											; 4

; ---------------------------------------------------------------------------
; Play sample
; ---------------------------------------------------------------------------

.getsample															; 8
		moveq	#LevelSelect_MaxSampleNumber,d2						; set max count
		move.w	(vLevelSelect_sample_count).w,d3
		lea	(vLevelSelect_control_timer).w,a3
		bsr.w	LevelSelect_FindLeftRightControls
		move.w	d3,(vLevelSelect_sample_count).w

		; check ctrl
		moveq	#btnABC,d1
		and.b	(Ctrl_1_pressed).w,d1
		beq.s	.return

		; play sample
		move.w	d3,d0
		addi.w	#dac__First,d0										; $80 is reserved for pause
		jmp	(SMPS_PlayDACSample).w									; play sample

; ---------------------------------------------------------------------------
; Get act
; ---------------------------------------------------------------------------

.getact
		lea	(vLevelSelect_horizontal_count).w,a0
		move.w	(vLevelSelect_vertical_count).w,d4
		add.w	d4,d4
		move.w	(a0,d4.w),d3
		move.w	.maxacts(pc,d4.w),d2									; set max count
		lea	(vLevelSelect_control_timer).w,a3
		bsr.w	LevelSelect_FindLeftRightControls
		move.w	d3,(a0,d4.w)
		move.w	d3,(vLevelSelect_saved_act).w
		rts
; ---------------------------------------------------------------------------

.maxacts
		dc.w LevelSelect_ActDEZCount-1	; DEZ

		zonewarning .maxacts,(2*1)

; ---------------------------------------------------------------------------
; Load Character
; ---------------------------------------------------------------------------

.getcharacter
		moveq	#LevelSelect_MaxCharacters-1,d2						; set max count
		move.w	(Player_mode).w,d3
		lea	(vLevelSelect_control_timer).w,a3
		bsr.w	LevelSelect_FindLeftRightControls
		move.w	d3,(Player_mode).w

.return2
		rts

; ---------------------------------------------------------------------------
; Play music
; ---------------------------------------------------------------------------

.getmusic
		moveq	#LevelSelect_MaxMusicNumber,d2						; set max count
		move.w	(vLevelSelect_music_count).w,d3
		lea	(vLevelSelect_control_timer).w,a3
		bsr.s	LevelSelect_FindLeftRightControls
		move.w	d3,(vLevelSelect_music_count).w

		; check ctrl
		moveq	#btnABC,d1
		and.b	(Ctrl_1_pressed).w,d1
		beq.s	.return2

		; check stop music
		btst	#button_B,d1
		bne.s	.stop												; branch if B is pressed

		; play music
		move.w	d3,d0
		addq.w	#mus__First,d0										; $00 is reserved for silence
		jmp	(SMPS_QueueSound1).w									; play music
; --------------------------------------------------------------------------

.stop
		music	mus_Stop,1

; ---------------------------------------------------------------------------
; Play sound
; ---------------------------------------------------------------------------

.getsound
		moveq	#LevelSelect_MaxSoundNumber,d2						; set max count
		move.w	(vLevelSelect_sound_count).w,d3
		lea	(vLevelSelect_control_timer).w,a3
		bsr.s	LevelSelect_FindLeftRightControls
		move.w	d3,(vLevelSelect_sound_count).w

		; check ctrl
		moveq	#btnABC,d1
		and.b	(Ctrl_1_pressed).w,d1
		beq.s	LevelSelect_FindUpDownControls.returnup

		; play sfx
		move.w	d3,d0
		addi.w	#sfx__First,d0										; skip music
		jmp	(SMPS_QueueSound2).w									; play sfx

; ---------------------------------------------------------------------------
; Control (up/down)
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================

LevelSelect_FindUpDownControls:
		moveq	#btnUD,d1
		and.b	(Ctrl_1_pressed).w,d1
		beq.s	.notpressed
		move.w	#16,(a3)
		bra.s	.pressed
; --------------------------------------------------------------------------

.notpressed
		moveq	#btnUD,d1
		and.b	(Ctrl_1_held).w,d1
		beq.s	.returnup
		subq.w	#1,(a3)
		bpl.s	.returnup
		addq.w	#4,(a3)

.pressed
		btst	#button_up,d1
		beq.s	.notdown
		subq.w	#1,d3
		bpl.s	.returnup
		move.w	d2,d3

.returnup
		rts
; ---------------------------------------------------------------------------

.notdown
		addq.w	#1,d3
		cmp.w	d2,d3
		bls.s		.returndown
		moveq	#0,d3

.returndown
		rts

; ---------------------------------------------------------------------------
; Control (left/right)
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================

LevelSelect_FindLeftRightControls:
		moveq	#btnLR,d1
		and.b	(Ctrl_1_pressed).w,d1
		beq.s	.notpressed
		move.w	#16,(a3)
		bra.s	.pressed
; --------------------------------------------------------------------------

.notpressed
		moveq	#btnLR,d1
		and.b	(Ctrl_1_held).w,d1
		beq.s	.returnleft
		subq.w	#1,(a3)
		bpl.s	.returnleft
		addq.w	#4,(a3)

.pressed
		btst	#button_left,d1
		beq.s	.notright
		subq.w	#1,d3
		bpl.s	.returnleft
		move.w	d2,d3

.returnleft
		rts
; ---------------------------------------------------------------------------

.notright
		addq.w	#1,d3
		cmp.w	d2,d3
		bls.s		.returnright
		moveq	#0,d3

.returnright
		rts

; ---------------------------------------------------------------------------
; Draw line and numbers
; ---------------------------------------------------------------------------

LevelSelect_MappingOffsets:
		dc.w planeLocH40(0,5)
		dc.w planeLocH40(0,7)
		dc.w planeLocH40(0,9)
		dc.w planeLocH40(0,11)
		dc.w planeLocH40(0,13)
		dc.w planeLocH40(0,15)
		dc.w planeLocH40(0,17)
		dc.w planeLocH40(0,20)
		dc.w planeLocH40(0,22)
		dc.w planeLocH40(0,24)
		dc.w planeLocH40(0,26)

; =============== S U B R O U T I N E =======================================

LevelSelect_MarkFields:
		lea	(vLevelSelect_buffer).l,a1
		lea	vLevelSelect_buffer2-vLevelSelect_buffer(a1),a2

		; get text pos
		move.w	(vLevelSelect_vertical_count).w,d0
		add.w	d0,d0
		move.w	LevelSelect_MappingOffsets(pc,d0.w),d0

		; RAM shift
		adda.w	d0,a1
		adda.w	d0,a2

		; load line
		moveq	#(64/8)-1,d2

.copy
	rept 8
		move.w	(a1)+,d0
		add.w	d3,d0												; VRAM shift
		move.w	d0,(a2)+
	endr
		dbf	d2,.copy

	if LevelSelect_VRAM<>0
		ori.w	#LevelSelect_VRAM,d3
	endif

		; check vertical line
		move.w	(vLevelSelect_vertical_count).w,d0
		cmpi.w	#LevelSelect_ZoneCount,d0
		blo.w	LevelSelect_LoadAct
		subq.w	#LevelSelect_CharacterCount,d0
		blo.s		.return
		add.w	d0,d0
		jmp	.index(pc,d0.w)
; ---------------------------------------------------------------------------

.index
		bra.s	LevelSelect_LoadCharacter				; 0
		bra.s	.drawmusic							; 2
		bra.s	.drawsound							; 4

; ---------------------------------------------------------------------------
; Draw sample
; ---------------------------------------------------------------------------

.drawsample											; 8
		lea	(vLevelSelect_buffer2+$D30).l,a5
		move.w	(vLevelSelect_sample_count).w,d0
		bra.s	.drawnumbers

; ---------------------------------------------------------------------------
; Draw sound
; ---------------------------------------------------------------------------

.drawsound
		lea	(vLevelSelect_buffer2+$C30).l,a5
		move.w	(vLevelSelect_sound_count).w,d0
		bra.s	.drawnumbers

; ---------------------------------------------------------------------------
; Draw music
; ---------------------------------------------------------------------------

.drawmusic
		lea	(vLevelSelect_buffer2+$B30).l,a5
		move.w	(vLevelSelect_music_count).w,d0

.drawnumbers
		move.w	d0,d2
		move.w	d0,-(sp)
		clr.w	d0
		move.b	(sp)+,d0
		bsr.s	.getnumber
		move.b	d2,d0
		lsr.b	#4,d0
		bsr.s	.getnumber
		move.b	d2,d0

.getnumber
		andi.w	#$F,d0
		cmpi.b	#10,d0
		blo.s		.skipsymbols
		addq.b	#6,d0

.skipsymbols
		addq.b	#1,d0
		add.w	d3,d0
		move.w	d0,(a5)+

.return
		rts

; ---------------------------------------------------------------------------
; Draw character
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================

LevelSelect_LoadCharacter:
		lea	(vLevelSelect_buffer2+$A30).l,a5
		move.w	(Player_mode).w,d0
		add.w	d0,d0
		move.w	LevelSelect_LoadCharacterText(pc,d0.w),d0
		lea	LevelSelect_LoadCharacterText(pc,d0.w),a0
		bra.w	LevelSelect_LoadMainText.loadtext
; ---------------------------------------------------------------------------

LevelSelect_LoadCharacterText: offsetTable
		offsetTableEntry.w LevelSelect_Player1		; 0
		offsetTableEntry.w LevelSelect_Player2		; 2
		offsetTableEntry.w LevelSelect_Player3		; 4
		offsetTableEntry.w LevelSelect_Player4		; 6
		offsetTableEntry.w LevelSelect_Player5		; 8
; ---------------------------------------------------------------------------

LevelSelect_Player1:	levselstr "SONIC AND TAILS"
LevelSelect_Player2:	levselstr "SONIC ALONE"
LevelSelect_Player3:	levselstr "TAILS ALONE"
LevelSelect_Player4:	levselstr "KNUX ALONE"
LevelSelect_Player5:	levselstr "KNUX AND TAILS"
	even

; ---------------------------------------------------------------------------
; Draw act
; ---------------------------------------------------------------------------

; =============== S U B R O U T I N E =======================================

LevelSelect_LoadAct:
		lea	(vLevelSelect_buffer2+$2B0).l,a5
		lea	(vLevelSelect_horizontal_count).w,a0
		move.w	(vLevelSelect_vertical_count).w,d0
		move.w	d0,d1
		move.b	d0,(sp)												; multiply by $100
		move.w	(sp),d0
		clr.b	d0
		adda.w	d0,a5
		add.w	d1,d1
		move.w	(a0,d1.w),d0
		add.w	d1,d1
		add.w	d1,d1
		add.w	d0,d0
		add.w	d1,d0
		move.w	LevelSelect_ActTextIndex(pc,d0.w),d0
		lea	LevelSelect_ActTextIndex(pc,d0.w),a0
		bra.s	LevelSelect_LoadMainText.loadtext

; =============== S U B R O U T I N E =======================================

LevelSelect_LoadMainText:
		lea	(vLevelSelect_buffer2+$80).l,a5
		lea	LevelSelect_MainText(pc),a0

.loadtext
		moveq	#0,d6
		move.b	(a0)+,d6

.tcopy
		moveq	#0,d0
		move.b	(a0)+,d0
		add.w	d3,d0
		move.w	d0,(a5)+
		dbf	d6,.tcopy
		rts
; --------------------------------------------------------------------------

LevelSelect_ActTextIndex: offsetTable
		offsetTableEntry.w LevelSelect_LoadAct1		; DEZ1
		offsetTableEntry.w LevelSelect_LoadAct2		; DEZ2
		offsetTableEntry.w LevelSelect_LoadAct3		; DEZ3
		offsetTableEntry.w LevelSelect_LoadAct4		; DEZ4

		zonewarning LevelSelect_ActTextIndex,(2*4)
; --------------------------------------------------------------------------

LevelSelect_LoadAct1:		levselstr "ACT 1"
LevelSelect_LoadAct2:		levselstr "ACT 2"
LevelSelect_LoadAct3:		levselstr "ACT 3"
LevelSelect_LoadAct4:		levselstr "ACT 4"
LevelSelect_MainText:		levselstr "SONIC TEST GAME - *** DEBUG MODE ***                            "
	even

; ---------------------------------------------------------------------------
; Load text
; ---------------------------------------------------------------------------

		save
		codepage	LEVELSCREEN

; =============== S U B R O U T I N E =======================================

LevelSelect_LoadText:
		lea	LevelSelect_MappingOffsets(pc),a0
		lea	(vLevelSelect_buffer).l,a1
		lea	LevelSelect_Text(pc),a2

	if LevelSelect_VRAM=0
		moveq	#0,d3
	else
		move.w	#LevelSelect_VRAM,d3
	endif

		moveq	#LevelSelect_MaxCount-1,d1

.load
		moveq	#0,d2
		move.b	(a2)+,d2		; text size
		move.w	d2,d4		; save text size
		move.w	(a0)+,d0		; offset
		lea	(a1,d0.w),a3		; RAM shift

.copy
		moveq	#0,d0
		move.b	(a2)+,d0		; load letter
		add.w	d3,d0
		move.w	d0,(a3)+
		dbf	d2,.copy

		; fill with spaces
		moveq	#64-2,d2		; maximum length of line (dbf + dbf)
		sub.w	d4,d2
		blo.s		.next

.sloop
		moveq	#' ',d0		; space
		add.w	d3,d0
		move.w	d0,(a3)+
		dbf	d2,.sloop

.next
		dbf	d1,.load
		copyTilemap	vram_fg, 512, 224

		; copy buffer
		lea	(vLevelSelect_buffer).l,a1
		lea	vLevelSelect_buffer2-vLevelSelect_buffer(a1),a2
		moveq	#($1000/(8*4))-1,d1

.bcopy
	rept 8
		move.l	(a1)+,(a2)+
	endr
		dbf	d1,.bcopy
		rts

		restore

; ---------------------------------------------------------------------------

LevelSelect_Text:
		levselstr "   DEATH EGG          - ACT 1"
		levselstr "   UNKNOWN LEVEL      - UNKNOWN"
		levselstr "   UNKNOWN LEVEL      - UNKNOWN"
		levselstr "   UNKNOWN LEVEL      - UNKNOWN"
		levselstr "   UNKNOWN LEVEL      - UNKNOWN"
		levselstr "   UNKNOWN LEVEL      - UNKNOWN"
		levselstr "   UNKNOWN LEVEL      - UNKNOWN"
		levselstr "   CHARACTER:         -"
		levselstr "   MUSIC TEST:        -"
		levselstr "   SOUND TEST:        -"
		levselstr "   SAMPLE TEST:       -"
	even
; ---------------------------------------------------------------------------

		; scroll data

LSScroll_Data: dScroll_Header
		dScroll_Data 8, 8, -$100, FG									; start pos, size, velocity, plane
LSScroll_Data_end
