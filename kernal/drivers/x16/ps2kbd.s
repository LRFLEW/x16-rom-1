;----------------------------------------------------------------------
; PS/2 Keyboard Driver
;----------------------------------------------------------------------
; (C)2019 Michael Steil, License: 2-clause BSD

.include "banks.inc"
.include "io.inc"

; code
.import ps2_receive_byte; [ps2]
.import joystick_from_ps2_init, joystick_from_ps2; [joystick]
; data
.import mode; [declare]
.import fetch, fetvec; [memory]
.importzp tmp2

.import kbdbuf_put
.import shflag
.import keyhdl
.import check_charset_switch

.export kbd_config, kbd_scan, receive_scancode_resume, keymap

MODIFIER_SHIFT = 1 ; C64:  Shift
MODIFIER_ALT   = 2 ; C64:  Commodore
MODIFIER_CTRL  = 4 ; C64:  Ctrl
MODIFIER_WIN   = 8 ; C128: Alt
MODIFIER_CAPS  = 16; C128: Caps
MODIFIER_4080  = 32; 40/80 DISPLAY
MODIFIER_ALTGR = MODIFIER_ALT | MODIFIER_CTRL
; set of modifiers that are toggled on each key press
MODIFIER_TOGGLE_MASK = MODIFIER_CAPS | MODIFIER_4080

.segment "ZPKERNAL" : zeropage
ckbtab:	.res 2           ;    used for keyboard lookup

.segment "KVARSB0"

prefix:	.res 1           ;    PS/2: prefix code (e0/e1)
brkflg:	.res 1           ;    PS/2: was key-up event
curkbd:	.res 1           ;    current keyboard layout index

.segment "KEYMAP"
keymap_data:
; PETSCII
	.res 128 ; unshifted
	.res 128 ; shift
	.res 128 ; ctrl
	.res 128 ; alt
	.res 128 ; altgr
pettab_len = * - keymap_data
; ISO
	.res 128 ; unshifted
	.res 128 ; shift
	.res 128 ; ctrl
	.res 128 ; alt
	.res 128 ; altgr

caps:	.res 16 ; for which keys caps means shift
kbdnam:
	.res 6
keymap_len = * - keymap_data ; 10 * $80 + $10 + 6 = $516

.segment "PS2KBD"

kbd_config:
	KVARS_START
	jsr _kbd_config
	KVARS_END
	rts

keymap:
	KVARS_START
	jsr _keymap
	KVARS_END
	rts

kbd_scan:
	KVARS_START
	jsr _kbd_scan
	KVARS_END
	rts

;
; set keyboard layout .a
;  $ff: reload current layout (PETSCII vs. ISO might have changed)
;
_kbd_config:
	cmp #$ff
	bne :+
	lda curkbd
:	pha

	lda #<$c000
	sta tmp2
	lda #>$c000
	sta tmp2+1
	lda #tmp2
	sta fetvec

; get keymap
	pla
	sta curkbd
	asl
	asl
	asl             ;*8
	tay
	ldx #BANK_KEYBD
	jsr fetch
	bne :+
	sec             ;end of list
	rts
:
; get name
	ldx #0
:	phx
	ldx #BANK_KEYBD
	jsr fetch
	plx
	sta kbdnam,x
	inx
	iny
	cpx #6
	bne :-
; get address
	ldx #BANK_KEYBD
	jsr fetch
	pha
	iny
	ldx #BANK_KEYBD
	jsr fetch
	sta tmp2+1
	pla
	sta tmp2

; copy into banked RAM
	lda #<keymap_data
	sta ckbtab
	lda #>keymap_data
	sta ckbtab+1
	ldx #>(keymap_len+$ff)
	ldy #0
@l1:	phx
@l2:	ldx #BANK_KEYBD
	jsr fetch
	sta (ckbtab),y
	plx
	cpx #1 ; last bank?
	phx
	bne :+
	cpy #(<keymap_len)-1
	bne :+
	plx
	bra @end
:	iny
	bne @l2
	inc tmp2+1
	inc ckbtab+1
	plx
	dex
	bne @l1
@end:

	jsr joystick_from_ps2_init
	clc             ;ok
	rts

; cycle keyboard layouts
cycle_layout:
	ldx curkbd
	inx
	txa
:	jsr _kbd_config
	lda #0
	bcs :-          ;end of list? use 0
; put name into keyboard buffer
	lda #$8d ; shift + cr
	jsr kbdbuf_put
	ldx #0
:	lda kbdnam,x
	beq :+
	jsr kbdbuf_put
	inx
	cpx #6
	bne :-
:	lda #$8d ; shift + cr
	jmp kbdbuf_put

;---------------------------------------------------------------
; Get/Set keyboard layout
;
;   In:   .c  =0: set, =1: get
; Set:
;   In:   .x/.y  pointer to layout string (e.g. "DE_CH")
;   Out:  .c  =0: success, =1: failure
; Get:
;   Out:  .x/.y  pointer to layout string
;---------------------------------------------------------------
_keymap:
	bcc @set
	ldx #<kbdnam
	ldy #>kbdnam
	rts

@set:	php
	sei             ;protect ckbtab
	stx ckbtab
	sty ckbtab+1
	lda curkbd
	pha
	lda #0
@l1:	pha
	ldx ckbtab
	ldy ckbtab+1
	phx
	phy
	jsr _kbd_config
	bne @nend
	pla             ;not found
	pla
	pla
	pla
	jsr _kbd_config ;restore original keymap
	plp
	sec
	rts
@nend:
	ply
	plx
	sty ckbtab+1
	stx ckbtab
	ldy #0
@l2:	lda (ckbtab),y
	cmp kbdnam,y
	beq @ok
	pla             ;next
	inc
	bra @l1
@ok:	iny
	cmp #0
	bne @l2
	pla             ;found
	pla
	plp
	clc
	rts

_kbd_scan:
	jsr receive_down_scancode_no_modifiers
	bne :+
	rts
:
	tay

	cpx #0
	bne down_ext
; *** regular scancodes
	cpy #$01 ; f9
	beq cycle_layout
	cmp #$83 ; convert weird f7 scancode
	bne not_f7
	lda #$02 ; this one is unused
	tay
not_f7:
	cmp #$0d ; scancodes < $0D and > $68 are independent of modifiers
	bcc is_unshifted
	cmp #$68
	bcc not_numpad
is_unshifted:
	ldx #0
	bra bit_found ; use unshifted table

not_numpad:
	lda shflag
	cmp #MODIFIER_ALTGR
	bne naltgr
	ldx #4
	bra bit_found ; use AltGr table
naltgr:
	cmp #MODIFIER_CAPS
	beq handle_caps

	ldx #1
:	lsr
	bcs bit_found
	inx
	cpx #4
	bne :-
	ldx #0
bit_found:
.assert keymap_data = $a000, error; so we can ORA instead of ADC and carry
	txa
	lsr
	php
	ora #>keymap_data
	sta ckbtab+1
	plp
	lda #0
	ror
	sta ckbtab
	bit mode
	bvc :+
	lda ckbtab
	clc
	adc #<pettab_len
	sta ckbtab
	lda ckbtab+1
	adc #>pettab_len
	sta ckbtab+1
:	lda (ckbtab),y
	beq drv_end
	jmp kbdbuf_put

down_ext:
	cpx #$e1 ; prefix $E1 -> E1-14 = Pause/Break
	beq is_stop
	cmp #$4a ; Numpad /
	beq is_numpad_divide
	cmp #$5a ; Numpad Enter
	beq is_enter
	cpy #$69 ; special case shift+end = help
	beq is_end
	cpy #$6c ; special case shift+home = clr
	beq is_home
	cpy #$2f
	beq is_menu
	cmp #$68
	bcc drv_end
	cmp #$80
	bcs drv_end
	lda tab_extended-$68,y
	bne kbdbuf_put2
drv_end:
	rts

is_numpad_divide:
	lda #'/'
	bra kbdbuf_put2
is_menu:
	lda #$06
	bra kbdbuf_put2

; or $80 if shift is down
is_end:
	ldx #$04 * 2; end (-> help)
	bra :+
is_home:
	ldx #$13 * 2; home (-> clr)
	bra :+
is_enter:
	ldx #$0d * 2 ; return (-> shift+return)
	bra :+
is_stop:
	ldx #$03 * 2 ; stop (-> run)
:	lda shflag
	lsr ; shift -> C
	txa
	ror
kbdbuf_put2:
	jmp kbdbuf_put

; The caps table has one bit per scancode, indicating whether
; caps + the key should use the shifted or the unshifted table.
handle_caps:
	phy ; scancode

	tya
	and #7
	tay
	lda #$80
:	cpy #0
	beq :+
	lsr
	dey
	bra :-
:	tax

	pla ; scancode
	pha
	lsr
	lsr
	lsr
	tay
	txa
	ldx #0
	and caps,y
	beq :+
	inx
:	ply ; scancode
	jmp bit_found

;****************************************
; RECEIVE SCANCODE:
; out: X: prefix (E0, E1; 0 = none)
;      A: scancode low (0 = none)
;      C:   0: key down
;           1: key up
;****************************************
receive_scancode:
	ldx #1
	jsr ps2_receive_byte
	bcs rcvsc1 ; parity error
	bne rcvsc2 ; non-zero code
rcvsc1:	lda #0
	rts
rcvsc2:	cmp #$e0 ; extend prefix 1
	beq rcvsc3
	cmp #$e1 ; extend prefix 2
	bne rcvsc4
rcvsc3:	sta prefix
	beq receive_scancode ; always
rcvsc4:	cmp #$f0
	bne rcvsc5
	rol brkflg ; set to 1
	bne receive_scancode ; always
rcvsc5:	pha
	lsr brkflg ; break bit into C
	ldx prefix
	lda #0
	sta prefix
	sta brkflg
	pla ; lower byte into A
	jmp (keyhdl)	;Jump to key event handler
receive_scancode_resume:
	rts

;****************************************
; RECEIVE SCANCODE AFTER shflag
; * key down only
; * modifiers have been interpreted
;   and filtered
; out: X: prefix (E0, E1; 0 = none)
;      A: scancode low (0 = none)
;      Z: scancode available
;           0: yes
;           1: no
;****************************************
receive_down_scancode_no_modifiers:
	jsr receive_scancode
	ora #0
	beq no_key
	jsr joystick_from_ps2
	php
	jsr check_mod
	bcc no_mod
	bit #MODIFIER_TOGGLE_MASK
	beq ntoggle
	plp
	bcs key_up
	eor shflag
	bra mstore
ntoggle:
	plp
	bcc key_down
	eor #$ff
	and shflag
	bra mstore
key_down:
	ora shflag
mstore:	sta shflag
	jsr check_charset_switch
key_up:	lda #0 ; no key to return
	rts
no_mod:	plp
	bcs key_up
no_key:	rts ; original Z is retained

check_mod:
	cpx #$e1
	beq ckmod1
	cmp #$11 ; left alt (0011) or right alt (E011)
	bne nmd_alt
	cpx #$e0 ; right alt
	bne :+
	lda #MODIFIER_ALTGR
	bra :++
:	lda #MODIFIER_ALT
:	sec
	rts
nmd_alt:
	cmp #$14 ; left ctrl (0014) or right ctrl (E014)
	beq md_ctl
	cpx #0
	bne ckmod2
	cmp #$12 ; left shift (0012)
	beq md_sh
	cmp #$59 ; right shift (0059)
	beq md_sh
	cmp #$58 ; caps lock (0058)
	beq md_caps
	cmp #$7e ; scroll lock (007e)
	beq md_4080disp
ckmod1:	clc
	rts
ckmod2:	cmp #$1F ; left win (001F)
	beq md_win
	cmp #$27 ; right win (0027)
	bne ckmod1
md_win:	lda #MODIFIER_WIN
	bra :+
md_alt:	lda #MODIFIER_ALT
	bra :+
md_ctl:	lda #MODIFIER_CTRL
	bra :+
md_sh:	lda #MODIFIER_SHIFT
	bra :+
md_caps:
	lda #MODIFIER_CAPS
	bra :+
md_4080disp:
	lda #MODIFIER_4080
:	sec
	rts

tab_extended:
	;         end      lf hom              (END & HOME special cased)
	.byte $00,$00,$00,$9d,$00,$00,$00,$00 ; @$68
	;     ins del  dn      rt  up
	.byte $94,$19,$11,$00,$1d,$91,$00,$00 ; @$70
	;             pgd         pgu brk
	.byte $00,$00,$02,$00,$00,$82,$03,$00 ; @$78

