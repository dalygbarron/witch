; So just thinking if we are going to implement some kind of system where something can claim a sprite and then give it
; back when it's done with it, kind of like a pool, we could maintain an efficient list of in use and not in use sprites
; while still having contiguous data that can be DMAd into OAM by using a union on one of the fields other than the
; position and having the other type be a byte or two telling you the location of the next dead sprite. Every time you
; request a sprite you take it from the front of the list of dead sprites, and when you free one you return it to the
; front of the array.
.STRUCT sprite
    x DB
    y DB
    .UNION
        tile DB
        param DB
    .NEXTU
        nextDead DW
    .ENDU
.ENDST

