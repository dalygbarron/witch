;==LoRom==      ; We'll get to HiRom some other time.
 
.MEMORYMAP                          ; Begin describing the system architecture.
  SLOTSIZE $8000                    ; The slot is $8000 bytes in size. More details on slots later.
  DEFAULTSLOT 0
  SLOT 0 $8000                      ; Defines Slot 0's starting address.
  SLOT 1 $0
.ENDME
 
.ROMBANKSIZE $8000                  ; Every ROM bank is 32 KBytes in size
.ROMBANKS 8                         ; 2 Mbits - Tell WLA we want to use 8 ROM Banks
 
.SNESHEADER
    ID "SNES"                       ; 1-4 letter string, just leave it as "SNES".
    NAME "Shadow of the Witch  "    ; Program Title - can't be over 21 bytes.
    SLOWROM
    LOROM
    CARTRIDGETYPE $00               ; $00 = ROM only, see WLA documentation for others
    ROMSIZE $08                     ; $08 = 2 Mbits,  see WLA doc for more..
    SRAMSIZE $00                    ; No SRAM         see WLA doc for more..
    COUNTRY $01                     ; $01 = U.S.  $00 = Japan  $02 = Australia, Europe, Oceania and Asia  $03 = Sweden  $04 = Finland  $05 = Denmark  $06 = France  $07 = Holland  $08 = Spain  $09 = Germany, Austria and Switzerland  $0A = Italy  $0B = Hong Kong and China  $0C = Indonesia  $0D = Korea
    LICENSEECODE $00                ; Just use $00
    VERSION $00                     ; $00 = 1.00, $01 = 1.01, etc.
.ENDSNES
 
.SNESNATIVEVECTOR
    COP EmptyHandler
    BRK EmptyHandler
    ABORT EmptyHandler
    NMI VBlank
    IRQ EmptyHandler
.ENDNATIVEVECTOR
 
.SNESEMUVECTOR
    COP EmptyHandler
    ABORT EmptyHandler
    NMI EmptyHandler
    RESET Start
    IRQBRK EmptyHandler
.ENDEMUVECTOR
 
.BANK 0 SLOT 0
.ORG 0
.SECTION "EmptyVectors" SEMIFREE
 
EmptyHandler:
    rti

.ENDS

.EMPTYFILL $00                      ; fill unused areas with $00 which is BRK