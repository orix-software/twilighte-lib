
.importzp ptr1,ptr2,ptr3
.import popax,popa

.include "include/twil.inc"
.include "telestrat.inc"

.include "../libs/usr/arch/include/ch376.inc"

.import _ch376_wait_response
.import _ch376_set_bytes_read
.import _ch376_file_open


.import twil_save_registers
.import twil_restore_registers

; void _twil_program_rambank_id(char *file, unsigned char idbank);

;.export _twil_program_rambank_id

.proc _twil_program_rambank_id

	sta		sector_to_update

	jsr 	popax ; Get file
	sta     ptr1
	stx		ptr1+1

    jsr     popa ; get bank
    sta     current_bank


	sei
	jsr     twil_save_registers
	; on swappe pour que les banques 8,7,6,5 se retrouvent en bas en id : 1, 2, 3, 4
	


    lda     VIA2::PRA
    and     #%11111000
    ora     current_bank
    sta     VIA2::PRA
    
	

	
    lda     sector_to_update ; pour debug FIXME, cela devrait être à 4
    sta  	TWILIGHTE_BANKING_REGISTER

	lda		TWILIGHTE_REGISTER
	ora		#%00100000
	sta		TWILIGHTE_REGISTER

    lda     #CH376_SET_FILE_NAME        ;$2f
    sta     CH376_COMMAND
    lda     #'/'

    sta     CH376_DATA
	lda		#$00
    sta     CH376_DATA
	jsr		_ch376_file_open


reset_label:

    lda     #CH376_SET_FILE_NAME        ;$2f
    sta     CH376_COMMAND

	ldy		#$00
@L1:	
	lda     (ptr1),y
    beq 	@S1
  	
  	cmp     #'a'                        ; 'a'
  	bcc     @do_not_uppercase
  	cmp     #'z'+1                        ; 'z'
  	bcs     @do_not_uppercase
  	sbc     #$1F
@do_not_uppercase:
	sta		CH376_DATA
	iny
	bne		@L1
	lda		#$00
@S1:
	sta		CH376_DATA
	
	jsr		_ch376_file_open

    cmp		#CH376_ERR_MISS_FILE
    bne 	start
	jsr		twil_restore_registers
	lda		#$01
	cli
	rts


start:



	lda		#$00
	sta		ptr3

	lda		#$C0
	sta		ptr3+1	

    lda		#$00
    ldy     #$40
    jsr		_ch376_set_bytes_read

@loop:
    cmp		#CH376_USB_INT_DISK_READ
    bne		@finished

    lda		#CH376_RD_USB_DATA0
    sta		CH376_COMMAND
    lda		CH376_DATA
	sta		nb_bytes
    ; Tester si userzp == 0?

    ldy    #$00

  @read_byte:
	
    lda		CH376_DATA
	sta		(ptr3),y
    iny

@skip_change_bank:

    dec		nb_bytes
    bne		@read_byte
    
    tya     
    clc
    adc     ptr3
    bcc     @skip_inc
    inc     ptr3+1
@skip_inc:
    sta     ptr3    

    lda		#CH376_BYTE_RD_GO
    sta		CH376_COMMAND
    jsr		_ch376_wait_response

    ; _ch376_wait_response renvoie 1 en cas d'erreur et le CH376 ne renvoie pas de valeur 0
    ; donc le bne devient un saut inconditionnel!
    bne		@loop
 @finished:

	jsr		twil_restore_registers

	lda		#$00
	cli
	rts


str_slash:
	.asciiz "/"

.endproc

current_bank:
    .res	1
sector_to_update:
    .res    1
nb_bytes:
    .res    1
