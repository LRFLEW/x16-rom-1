; Commander X16 PETSCII/ISO Keyboard Table
; ***this file is auto-generated!***
;
; Name:   Hungarian
; Locale: hu-HU
; KLID:   40e

.segment "KBDMETA"

	.byte "HU", 0, 0, 0, 0
	.word kbtab_40e

.segment "KBDTABLES"

kbtab_40e:
	.incbin "asm/40E.bin.lzsa"

; PETSCII characters reachable on a C64 keyboard that are not reachable with this layout:
; graph: '\xa4\xa6\xa8\xa9\xba'
; Unicode characters reachable with this layout on Windows but not covered by PETSCII:
; '\x1b\x1c\x1d\_{|}~¤§¨°´¸ÁÄÉÍÓÖ×ÚÜßáäéíóö÷úüĐđŁłŐőŰűˇ˘˙˛˝€'

; PETSCII characters reachable on a C64 keyboard that are not reachable with this layout:
; chars: 'π'
; graph: '\xa1\xa2\xa3\xa5\xa6\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf'
; Unicode characters reachable with this layout on Windows but not covered by ISO-8859-15:
; '¤¨´¸ĐđŁłŐőŰűˇ˘˙˛˝'

