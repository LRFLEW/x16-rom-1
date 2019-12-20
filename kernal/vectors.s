.global monitor

.import mouse_config, mouse_get; [mouse]
.import joystick_scan; [joystick]
.import mouse_config; [mouse]
.import joystick_scan, joystick_get; [joystick]
.import clock_update, clock_get_timer, clock_set_timer, clock_get_date_time, clock_set_date_time; [time]

.import GRAPH_init, GRAPH_clear, GRAPH_set_window, GRAPH_set_colors, GRAPH_draw_line, GRAPH_draw_rect, GRAPH_move_rect, GRAPH_draw_oval, GRAPH_draw_image, GRAPH_set_font, GRAPH_get_char_size, GRAPH_put_char

	.segment "JMPTBL"
; *** this is space for new X16 KERNAL vectors ***
; for now, these are private API, they have not been
; finalized

	.byte 0,0,0            ; $FEE1
	.byte 0,0,0            ; $FEE4
	.byte 0,0,0            ; $FEE7
	.byte 0,0,0            ; $FEEA
	.byte 0,0,0            ; $FEED
	.byte 0,0,0            ; $FEF0
	.byte 0,0,0            ; $FEF3

	;
	; graph low-level API
	;
	jmp (I_GRAPH_LL_init)                ; $FEF6: GRAPH_LL_init
	jmp (I_GRAPH_LL_get_info)            ; $FEF9: GRAPH_LL_get_info
	jmp (I_GRAPH_LL_set_palette)         ; $FEFC: GRAPH_LL_set_palette
	jmp (I_GRAPH_LL_cursor_position)     ; $FEFF: GRAPH_LL_cursor_position
	jmp (I_GRAPH_LL_cursor_next_line)    ; $FF02: GRAPH_LL_cursor_next_line
	jmp (I_GRAPH_LL_get_pixel)           ; $FF05: GRAPH_LL_get_pixel
	jmp (I_GRAPH_LL_get_pixels)          ; $FF08: GRAPH_LL_get_pixels
	jmp (I_GRAPH_LL_set_pixel)           ; $FF0B: GRAPH_LL_set_pixel
	jmp (I_GRAPH_LL_set_pixels)          ; $FF0E: GRAPH_LL_set_pixels
	jmp (I_GRAPH_LL_set_8_pixels)        ; $FF11: GRAPH_LL_set_8_pixels
	jmp (I_GRAPH_LL_set_8_pixels_opaque) ; $FF14: GRAPH_LL_set_8_pixels_opaque
	jmp (I_GRAPH_LL_fill_pixels)         ; $FF17: GRAPH_LL_fill_pixels
	jmp (I_GRAPH_LL_filter_pixels)       ; $FF1A: GRAPH_LL_filter_pixels
	jmp (I_GRAPH_LL_move_pixels)         ; $FF1D: GRAPH_LL_move_pixels

	;
	; graph high-level API
	;
	jmp GRAPH_init         ; $FF20: void GRAPH_init();
	jmp GRAPH_clear        ; $FF23: void GRAPH_clear();
	jmp GRAPH_set_window   ; $FF26: void GRAPH_set_window(word x, word y, word width, word height);
	jmp GRAPH_set_colors   ; $FF29: void GRAPH_set_colors(byte stroke, byte fill, byte background);
	jmp GRAPH_draw_line    ; $FF2C: void GRAPH_draw_line(word x1, word y1, word x2, word y2);
	jmp GRAPH_draw_rect    ; $FF2F: void GRAPH_draw_rect(word x, word y, word width, word height, word corner_radius, bool fill);
	jmp GRAPH_move_rect    ; $FF32: void GRAPH_move_rect(word sx, word sy, word tx, word ty, word width, word height);
	jmp GRAPH_draw_oval    ; $FF35: void GRAPH_draw_oval(word x, word y, word width, word height, bool fill);
	jmp GRAPH_draw_image   ; $FF38: void GRAPH_draw_image(word x, word y, word ptr, word width, word height);
	jmp GRAPH_set_font     ; $FF3B: void GRAPH_set_font(void ptr);
	jmp GRAPH_get_char_size; $FF3E: (byte baseline, byte width, byte height) GRAPH_get_char_size(byte c, byte format);
	jmp GRAPH_put_char     ; $FF41: void GRAPH_put_char(inout word x, inout word y, byte c);

	jmp monitor            ; $FF44: MONITOR

; $FF47-$FF7F contains the extended C128 KERNAL API. We are trying to support as many C128 calls as possible.
; Some make no sense on the X16 though, usually because their functionality is C128-specific.
	jmp restore_basic      ; $FF47: restore_basic                                  [unsupported C128: SPIN_SPOUT – setup fast serial ports for I/O]
	jmp close_all          ; $FF4A: [C128] CLOSE_ALL – close all files on a device
	jmp clock_set_date_time; $FF4D: clock_set_date_time - set date and time        [unsupported C128: C64MODE – reconfigure system as a C64]
	jmp clock_get_date_time; $FF50: clock_get_date_time - get date and time        [unsupported C128: DMA_CALL – send command to DMA device]
	jmp joystick_scan      ; $FF53: joystick_scan - query joysticks                [unsupported C128: BOOT_CALL – boot load program from disk]
	jmp joystick_get       ; $FF56: joystick_get - get state of one joystick       [unsupported C128: PHOENIX – init function cartridges]
	jmp lkupla             ; $FF59: [C128] LKUPLA - look up logical file address
	jmp lkupsa             ; $FF5C: [C128] LKUPSA - look up secondary address
	jmp screen_set_mode    ; $FF5F: screen_set_mode - get/set screen mode          [unsupported C128: SWAPPER]
	.byte 0,0,0            ; $FF62: [C128] DLCHR – init 80-col character RAM       [NYI]
	.byte 0,0,0            ; $FF65: [C128] PFKEY – program a function key          [NYI]
	jmp mouse_config       ; $FF68: mouse_config - configure mouse pointer         [unsupported C128: SETBNK – set bank for I/O operations]
	jmp mouse_get          ; $FF6B: mouse_get - get state of mouse                 [unsupported C128: GETCFG – lookup MMU data for given bank]
	jmp jsrfar             ; $FF6E: [C128] JSRFAR – gosub in another bank          [incompatible with C128]
	.byte 0,0,0            ; $FF71: placeholder: get number of RAM banks           [NYI; unsupported C128: JMPFAR – goto another bank]
	jmp indfet             ; $FF74: [C128] FETCH – LDA (fetvec),Y from any bank
	jmp stash              ; $FF77: [C128] STASH – STA (stavec),Y to any bank
	jmp cmpare             ; $FF7A: [C128] CMPARE – CMP (cmpvec),Y to any bank
	jmp primm              ; $FF7D: [C128] PRIMM – print string following the caller’s code

	;KERNAL revision
.ifdef PRERELEASE_VERSION
	.byte <(-PRERELEASE_VERSION)
.elseif .defined(RELEASE_VERSION)
	.byte RELEASE_VERSION
.else
	.byte $ff       ;custom pre-release version
.endif

	jmp cint
	jmp ioinit
	jmp ramtas

	jmp restor      ;restore vectors to initial system
	jmp vector      ;change vectors for user

	jmp setmsg      ;control o.s. messages
	jmp secnd       ;send sa after listen
	jmp tksa        ;send sa after talk
	jmp memtop      ;set/read top of memory
	jmp membot      ;set/read bottom of memory
	jmp kbd_scan    ;scan keyboard
	jmp settmo      ;set timeout in ieee
	jmp acptr       ;handshake ieee byte in
	jmp ciout       ;handshake ieee byte out
	jmp untlk       ;send untalk out ieee
	jmp unlsn       ;send unlisten out ieee
	jmp listn       ;send listen out ieee
	jmp talk        ;send talk out ieee
	jmp readst      ;return i/o status byte
	jmp setlfs      ;set la, fa, sa
	jmp setnam      ;set length and fn adr
open	jmp (iopen)     ;open logical file
close	jmp (iclose)    ;close logical file
chkin	jmp (ichkin)    ;open channel in
ckout	jmp (ickout)    ;open channel out
clrch	jmp (iclrch)    ;close i/o channel
basin	jmp (ibasin)    ;input from channel
bsout	jmp (ibsout)    ;output to channel
	jmp loadsp      ;load from file
	jmp savesp      ;save to file
	jmp clock_set_timer ;set internal clock (SETTIM)
	jmp clock_get_timer ;read internal clock (RDTIM)
stop	jmp (istop)     ;scan stop key
getin	jmp (igetin)    ;get char from q
clall	jmp (iclall)    ;close all files
	jmp clock_update ;increment clock (UDTIM)
jscrog	jmp scrorg      ;screen org
jplot	jmp plot        ;read/set x,y coord
jiobas	jmp iobase      ;return i/o base

	;signature
	.byte "MIST"

	.segment "VECTORS"
	.word nmi        ;program defineable
	.word start      ;initialization code
	.word puls       ;interrupt handler

