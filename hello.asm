
[org 0x0100]
jmp main

; ==============================================================================
; DATA SECTION: VARIABLES & GAME STATE
; ==============================================================================

; --- Game Status Flags ---
is_game_active:   db 0       ; 0 = Menu, 1 = Playing
end_of_game_flag: db 0
game_quit_flag:   db 0
game_restart_flag:db 0
menu_instruction_flag: db 0

; --- Ball Physics ---
ball_x:           dw 0       ; Column (0-79)
ball_y:           dw 0       ; Row (0-24)
ball_dir_x:       db 0       ; 0 = Left, 1 = Right
ball_dir_y:       db 0       ; 0 = Up, 1 = Down
ball_mem_pos:     dw 0       ; Current video memory address of ball
ball_old_pos:     dw 0       ; Previous address (to erase)
ball_next_pos:    dw 0       ; Calculated next position
is_ball_stuck:    db 0       ; 1 = Ball glued to paddle
ball_stuck_offset:dw 0       ; Position relative to paddle

; --- Paddle Physics ---
paddle_center_mem: dw 3580   ; Video memory address of paddle center
wall_left_limit:   dw 3524   ; Screen boundary left
wall_right_limit:  dw 3652   ; Screen boundary right
key_left_pressed:  dw 0      ; 1 if Left Arrow held
key_right_pressed: dw 0      ; 1 if Right Arrow held
paddle_draw_left:  dw 0      ; Left edge of paddle (for drawing)
paddle_draw_right: dw 0      ; Right edge of paddle
paddle_mid_mem:    dw 0      ; Middle point memory address
bounce_dir_flag:   db 0      ; Used to calculate angle bounce

; --- Player Stats ---
player_lives:     db 3
score:            dw 0
total_bricks:     dw 24
bonus_score:      dw 0

; --- Powerups ---
powerup_active:   db 0       ; "Solid Base" powerup active?
powerup_timer:    db 0       ; Timer for powerup duration

; --- Time & System ---
old_keyboard_isr: dd 0
old_timer_isr:    dd 0
tick_counter:     db 0       ; Loop counter for speed
clock_seconds:    dw 0
clock_ticks:      db 0

; --- Brick Layouts (Memory Offsets) ---
bricks_start_loc: dw 810 , 828 , 846 , 864 , 882 , 900 , 918 , 936 , 1290 , 1308 , 1326 , 1344 , 1362, 1380, 1398 , 1416 , 1770 , 1788 , 1806 , 1824 , 1842 , 1860 , 1878 , 1896
bricks_end_loc:   dw 822 , 840 , 858 , 876 , 894 , 912 , 930 , 948 , 1302 , 1320 , 1338 , 1356 , 1374 , 1392 , 1414 , 1428 , 1782 , 1800  , 1818 , 1836 ,1854 , 1872 , 1890 , 1908

; --- Strings ---
str_welcome:      db 'WELCOME TO BRICK BREAKER', 0
str_options:      db 'PLEASE SELECT OPTIONS', 0
str_instruction:  db 'PRESS I FOR INSTRUCTIONS', 0
str_play:         db 'PRESS ENTER TO PLAY GAME', 0
str_lose:         db 'YOU LOSE', 0
str_score_lbl:    db 'SCORE', 0
str_lives_lbl:    db 'LIVES', 0
str_time_lbl:     db 'TIME ', 0
str_total_lives:  db 'YOUR TOTAL LIVES ARE 3', 0
str_bonus_note:   db 'BONUS AWARDED IF BREAK ALL BRICKS IN 2 MINS', 0
str_solid_base:   db 'HITTING RED BRICK WILL SOLIDIFY YOUR BASE', 0
str_space_bar:    db 'PRESS SPACE BAR TO RELEASE BALL', 0
str_controls:     db 'USE RIGHT & LEFT ARROW TO MOVE BAR', 0
str_total_score:  db 'YOUR TOTAL SCORES :', 0
str_lives_rem:    db 'LIVES REMAINING', 0
str_exit:         db 'PRESS E TO EXIT', 0
str_quit_game:    db 'PRESS ENTER+Q TO QUIT GAME', 0
str_restart:      db 'PRESS ENTER+R TO RESTART YOUR GAME', 0

; ==============================================================================
; UTILITY FUNCTIONS (Sound, Drawing, Math)
; ==============================================================================

play_sound:
    push ax
    push bx
    mov al, 182
    out 43h, al
    mov ax, 4560
    out 42h, al
    mov al, ah
    out 42h, al
    in al, 61h
    or al, 00000011
    out 61h, al
    mov bx, 2
sound_delay_outer:
    mov cx, 65535
sound_delay_inner:
    dec cx
    jne sound_delay_inner
    dec bx
    jne sound_delay_outer
    in al, 61h
    and al, 11111100b
    out 61h, al 
    pop bx
    pop ax
    ret 

clear_screen: 
    push es
    push ax
    push cx
    push di
    mov ax, 0xb800
    mov es, ax 
    xor di, di 
    mov ax, 0x0720 ; Space char
    mov cx, 2000 
    cld 
    rep stosw 
    pop di 
    pop cx
    pop ax
    pop es
    ret 

; Print String (Standard Attribute)
print_string:
    push bp
    mov bp, sp
    push es
    push ax
    push cx
    push si
    push di
    mov ax, 0xb800
    mov es, ax 
    mov di, [bp+8] ; Screen Position
    mov si, [bp+6] ; String Offset
    mov cx, [bp+4] ; Length
    mov ah, 0x07   ; Attribute (Grey on Black)
next_char: 
    mov al, [si] 
    mov [es:di], ax 
    add di, 2 
    add si, 1 
    loop next_char 
    pop di
    pop si
    pop cx
    pop ax
    pop es
    pop bp
    ret 6

; Print String (Blinking/Bright Attribute)
print_string_blink:
    push bp
    mov bp, sp
    push es
    push ax
    push cx
    push si
    push di
    mov ax, 0xb800
    mov es, ax 
    mov di, [bp+8] 
    mov si, [bp+6] 
    mov cx, [bp+4] 
    mov ah, 0x8e   ; Attribute (Yellow/Blinking)
next_char_blink: 
    mov al, [si] 
    mov [es:di], ax 
    add di, 2 
    add si, 1 
    loop next_char_blink 
    pop di
    pop si
    pop cx
    pop ax
    pop es
    pop bp
    ret 6

; Print Number (e.g., Score)
print_number: 
    push bp
    mov bp, sp
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax, 0xb800
    mov es, ax 
    mov ax, [bp+4] ; Number to print
    mov bx, 10 
    mov cx, 0 
digit_loop: 
    mov dx, 0 
    div bx 
    add dl, 0x30 
    push dx 
    inc cx 
    cmp ax, 0 
    jnz digit_loop 
    mov di, [bp+6] ; Position
print_pos_loop: 
    pop dx 
    mov dh, 0x07 
    mov [es:di], dx 
    add di, 2 
    loop print_pos_loop 
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop bp
    ret 4

; ==============================================================================
; DRAWING FUNCTIONS (Walls, Bricks, Paddle)
; ==============================================================================

draw_walls:
    push ax
    push es
    push di
    mov ax, 0xb800
    mov es, ax
    
    ; Draw Top Wall
    mov ah, 0x60 ; Brown background
    mov al, 0x20 ; Space
    mov di, 482
top_wall_loop:
    mov word[es:di], ax
    add di, 2
    cmp di, 636
    jne top_wall_loop
    
    ; Draw Bottom Wall (Color depends on powerup)
    cmp byte[cs:powerup_active], 1
    jne normal_base
    mov ah, 0x40 ; Red background (Powerup)
    jmp draw_bottom
normal_base:
    mov ah, 0x60 ; Brown background
draw_bottom:
    mov di, 3682
bottom_wall_loop:
    mov word[es:di], ax
    add di, 2
    cmp di, 3836
    jne bottom_wall_loop
    
    ; Draw Side Walls
    mov ah, 0x60
    mov al, 0x20
    mov di, 482
left_wall_loop:
    mov word[es:di], ax
    add di, 160
    cmp di, 3842
    jne left_wall_loop
        
    mov di, 636
right_wall_loop:
    mov word[es:di], ax
    add di, 160
    cmp di, 3996
    jne right_wall_loop
    
    pop di
    pop es
    pop ax
    ret

draw_initial_bricks:
    push es
    push cx
    push bx
    push si
    push di
    mov ax, 0xb800
    mov es, ax
    mov di, 810
    mov si, 0
    mov bx, 0
    cld
    
    ; Loop logic simplified for readability
    ; This logic draws the blocks based on hardcoded memory ranges
brick_row_1:
    cmp di, 936
    ja brick_row_2
    mov ah, 0x90 ; Blue
    mov al, 0x20
    mov cx, 6
    rep stosw
    mov cx, 3
    mov ax, 0x0720 ; Space
    rep stosw
    add si, 2
    jmp brick_row_1
    
brick_row_2:
    mov di, 1290
brick_row_2_loop:
    cmp di, 1416
    ja brick_row_3
    mov ah, 0xe0 ; Yellow
    mov al, 0x20
    mov cx, 6
    rep stosw
    mov cx, 3
    mov ax, 0x0720 
    rep stosw
    add si, 2
    jmp brick_row_2_loop
    
brick_row_3:
    mov di, 1770
brick_row_3_loop:
    cmp di, 1896
    ja special_brick
    mov ah, 0x50 ; Magenta
    mov al, 0x20
    mov cx, 6
    rep stosw
    mov cx, 3
    mov ax, 0x0720 
    rep stosw
    add si, 2
    jmp brick_row_3_loop
    
special_brick:
    mov di, 846
    mov cx, 6
    mov al, 0x20
    mov ah, 0x40 ; Red (Powerup brick)
    rep stosw
    
    pop di
    pop si
    pop bx
    pop cx
    pop es
    ret

clear_paddle_gfx:
    push bp
    mov bp, sp
    push es
    push ax
    push di
    push cx
    mov ax, 0xb800
    mov es, ax
    mov ax, 0x0720
    mov cx, 13
    mov di, [bp+4] ; Address to clear
    rep stosw
    mov di, [cs:ball_stuck_offset] ; Clear ball if stuck
    mov word[es:di], ax
    pop cx
    pop di
    pop ax
    pop es
    pop bp
    ret 2

draw_paddle_gfx:
    push bp
    mov bp, sp
    push es
    push ax
    push di
    push cx
    mov ax, 0xb800
    mov es, ax
    mov al, 0x20
    mov ah, 0xb0 ; Cyan Paddle Color
    mov cx, 13
    mov di, [bp+4] ; Address to draw
    
    mov word[cs:paddle_draw_left], di
    rep stosw
    sub di, 2
    mov word[cs:paddle_draw_right], di
    
    mov ax, word[cs:paddle_draw_right]
    sub ax, 12
    mov word[cs:paddle_mid_mem], ax
    
    ; If ball is stuck, draw it on top
    cmp byte[cs:is_ball_stuck], 1
    jne end_draw_paddle
    
    ; Calculate ball position relative to paddle
    sub ax, 160
    mov di, ax
    shr ax, 1
    sub ax, 1680
    mov cx, ax
    
    mov al, 'O'
    mov ah, 0x07
    mov word[es:di], ax
    mov [cs:ball_stuck_offset], di
    mov word[cs:ball_y], 21
    mov word[cs:ball_x], cx
    mov word[cs:ball_old_pos], di
    
end_draw_paddle:
    pop cx
    pop di
    pop ax
    pop es
    pop bp
    ret 2

; ==============================================================================
; PHYSICS & GAMEPLAY LOGIC
; ==============================================================================

update_paddle_movement:
    push ax
    push di
    
    cmp word[cs:key_right_pressed], 1
    je move_paddle_right
    cmp word[cs:key_left_pressed], 1
    je move_paddle_left
    jmp exit_paddle_logic

move_paddle_right:
    mov ax, word[cs:paddle_center_mem]
    add ax, 8
    cmp ax, word[cs:wall_right_limit]
    ja exit_paddle_logic
    
    mov di, word[cs:paddle_center_mem]
    push di
    call clear_paddle_gfx
    push ax
    call draw_paddle_gfx
    mov word[cs:paddle_center_mem], ax
    jmp exit_paddle_logic

move_paddle_left:
    mov ax, word[cs:paddle_center_mem]
    sub ax, 8
    cmp ax, word[cs:wall_left_limit]
    jb exit_paddle_logic
    
    mov di, word[cs:paddle_center_mem]
    push di
    call clear_paddle_gfx
    push ax
    call draw_paddle_gfx
    mov word[cs:paddle_center_mem], ax

exit_paddle_logic:
    pop di
    pop ax
    ret

; Convert X/Y to Video Memory Address
; Input: Stack[4] = X, Stack[6] = Y
; Output: [ball_next_pos]
calc_mem_offset:
    push bp
    mov bp, sp
    push ax
    mov al, 80
    mul byte[bp+4] ; Multiply Y * 80
    add ax, [bp+6] ; Add X
    shl ax, 1      ; Multiply by 2 (2 bytes per char)
    mov word[cs:ball_next_pos], ax
    pop ax
    pop bp
    ret 4

calc_next_ball_pos:
    push ax
    push bx
    push cx
    
    mov al, [cs:ball_dir_x]
    mov ah, [cs:ball_dir_y]
    mov bx, [cs:ball_x]
    mov cx, [cs:ball_y]

    ; Check Walls (Left/Right)
    cmp word[cs:ball_x], 3
    jne check_right_wall
    mov al, 1
    jmp check_top_wall
check_right_wall:
    cmp word[cs:ball_x], 77
    jne check_top_wall
    mov al, 0
            
check_top_wall:
    cmp word[cs:ball_y], 4
    jne check_bottom_wall
    mov ah, 1
    jmp apply_movement
check_bottom_wall:
    cmp word[cs:ball_y], 22
    jne apply_movement
    mov ah, 0
    
apply_movement:
    cmp al, 1
    jne move_left
    add bx, 1
    jmp check_y_move
move_left:
    sub bx, 1
            
check_y_move:
    cmp ah, 1
    jne move_up
    add cx, 1
    jmp do_calc
move_up:
    sub cx, 1

do_calc:
    push bx ; X
    push cx ; Y
    call calc_mem_offset
    pop cx
    pop bx
    pop ax
    ret

determine_bounce_dir:
    push ax
    mov ax, word[cs:ball_next_pos]
    cmp ax, [cs:paddle_mid_mem]
    ja bounce_right
    cmp ax, [cs:paddle_draw_left]
    jb end_bounce_chk
    mov byte[cs:bounce_dir_flag], 0
    jmp end_bounce_chk
bounce_right:
    cmp ax, [cs:paddle_draw_right]
    ja end_bounce_chk
    mov byte[cs:bounce_dir_flag], 1
end_bounce_chk:
    pop ax
    ret

handle_brick_collision:
    push es
    push ax
    push dx
    push cx
    push si
    push bx
    mov ax, 0xb800
    mov es, ax
    
    mov cx, 24
    mov si, 0
    mov dx, [cs:ball_next_pos]
    
brick_check_loop:
    mov ax, word[cs:bricks_start_loc + si]
    mov bx, word[cs:bricks_end_loc + si]
    add si, 2
    
    cmp dx, ax
    jae check_brick_end
    loop brick_check_loop
    jmp brick_func_end

check_brick_end:
    cmp dx, bx
    jbe remove_brick
    loop brick_check_loop
    jmp brick_func_end

remove_brick: 
    ; Check if special red brick (846)
    cmp ax, 846
    jne not_special
    mov byte[cs:powerup_active], 1
not_special:
    
    sub si, 2
    mov di, word[cs:bricks_start_loc + si]
    mov cx, 6
    mov ax, 0x0720
    rep stosw
    call play_sound
    add word[cs:score], 5
    dec word[cs:total_bricks]
    
    ; Update Score Display
    mov ax, 174
    push ax
    push word[cs:score]
    call print_number
    
brick_func_end:
    pop bx
    pop si
    pop cx
    pop dx
    pop ax
    pop es
    ret

update_ball_physics:
    push es
    push ax
    push bx
    push cx
    push di
    
    mov ax, 0xb800
    mov es, ax
    
    ; Erase Old Ball
    mov di, [cs:ball_old_pos]
    mov word[es:di], 0x0720
    
    call calc_next_ball_pos
    mov di, [cs:ball_next_pos]
    mov ax, word[es:di]
    
    ; Check Collision Type
    cmp ah, 0x07 ; Empty Space?
    je check_movement_flags
    cmp ah, 0xb0 ; Paddle?
    je hit_paddle
    
    ; Must be Brick
    call handle_brick_collision
    jmp update_flags
    
hit_paddle:
    call determine_bounce_dir
    cmp byte[cs:bounce_dir_flag], 1
    jne set_left_bounce
    mov byte[cs:ball_dir_x], 1
    jmp update_flags
set_left_bounce:
    mov byte[cs:ball_dir_x], 0
    
update_flags:
    cmp byte[cs:ball_dir_y], 1
    jne set_down
    mov byte[cs:ball_dir_y], 0
    jmp check_movement_flags
set_down:
    cmp byte[cs:ball_dir_y], 0
    jne check_movement_flags
    mov byte[cs:ball_dir_y], 1

check_movement_flags:
    ; Wall Checks
    cmp word[cs:ball_x], 3
    jne check_right_w
    mov byte[cs:ball_dir_x], 1
    jmp check_y_w
check_right_w:
    cmp word[cs:ball_x], 77
    jne check_y_w
    mov byte[cs:ball_dir_x], 0
            
check_y_w:
    cmp word[cs:ball_y], 4
    jne check_bottom_w
    mov byte[cs:ball_dir_y], 1
    jmp do_ball_print
check_bottom_w:
    ; Check if ball hit bottom (Life Lost?)
    cmp byte[cs:powerup_active], 0
    jne powerup_save
    
    cmp word[cs:ball_y], 22
    jne do_ball_print
    
    ; Life Lost Logic
    mov byte[cs:is_ball_stuck], 1 
    
    ; Reset Ball to Paddle
    mov ax, word[cs:paddle_mid_mem]
    sub ax, 160
    mov di, ax
    shr ax, 1
    sub ax, 1680
    mov cx, ax

    mov al, 'O'
    mov ah, 0x07
    mov word[es:di], ax
    mov [cs:ball_stuck_offset], di
    mov word[cs:ball_y], 21
    mov word[cs:ball_x], cx
    mov word[cs:ball_old_pos], di
    
    sub byte[cs:player_lives], 1
    jmp ball_exit
    
powerup_save:
    cmp word[cs:ball_y], 23
    jne do_ball_print
    mov byte[ball_dir_y], 0 ; Bounce off bottom if powerup active

do_ball_print:
    ; Update Coordinates
    cmp byte[cs:ball_dir_x], 1
    jne dec_x
    add word[cs:ball_x], 1
    jmp check_y_inc
dec_x:
    sub word[cs:ball_x], 1
            
check_y_inc:
    cmp byte[cs:ball_dir_y], 1
    jne dec_y
    add word[cs:ball_y], 1
    jmp calc_final_pos
dec_y:
    sub word[cs:ball_y], 1
    
calc_final_pos:
    mov ax, word[cs:ball_y]
    mov bx, 80
    mul bx
    add ax, word[cs:ball_x]
    shl ax, 1
    mov di, ax
    mov word[cs:ball_old_pos], ax
    
    mov ah, 0x07
    mov al, 'O'
    mov word[es:di], ax
    
ball_exit:
    pop di
    pop cx
    pop bx
    pop ax
    pop es
    ret 

; ==============================================================================
; INTERRUPT HANDLERS
; ==============================================================================

keyboard_handler: 
    push ax
    push es
    
    mov word[cs:key_right_pressed], 0
    mov word[cs:key_left_pressed], 0
    mov ax, 0xb800
    mov es, ax 
    
    in al, 0x60 ; Read Key
    
    cmp byte[is_game_active], 0
    jne game_mode_input
    
    ; Menu Input
    cmp al, 0x1c ; Enter
    jne check_instr_key
    mov byte[is_game_active], 1
    jmp kb_exit
check_instr_key:
    cmp al, 0x17 ; 'I'
    jne kb_exit
    mov byte[menu_instruction_flag], 1
    cmp byte[is_game_active], 1
    jne kb_exit

game_mode_input:
    cmp al, 0x4b ; Left
    jne try_right
    mov word[cs:key_left_pressed], 1
    call update_paddle_movement
    jmp kb_exit
try_right: 
    cmp al, 0x4d ; Right
    jne try_space
    mov word[cs:key_right_pressed], 1
    call update_paddle_movement
    jmp kb_exit
try_space:
    cmp al, 0x39 ; Space
    jne try_exit
    mov byte[cs:is_ball_stuck], 0
    jmp kb_exit
    
try_exit: 
    cmp al, 0x12 ; 'E'
    jne try_quit
    mov byte[cs:end_of_game_flag], 1
    jmp kb_exit
try_quit:
    cmp al, 0x10 ; 'Q'
    jne try_restart
    mov byte[cs:game_quit_flag], 1
    jmp kb_exit
try_restart:
    cmp al, 0x13 ; 'R'
    jne kb_nomatch
    mov byte[cs:game_restart_flag], 1
    jmp kb_exit
    
kb_nomatch: 
    pop es
    pop ax
    jmp far [cs:old_keyboard_isr] 
    
kb_exit:
    mov al, 0x20
    out 0x20, al 
    pop es
    pop ax 
    iret 

timer_handler: 
    cmp byte[cs:is_game_active], 1
    jne timer_process_logic
    
    ; Timer Updates (Seconds/Bonus)
    inc byte[cs:clock_ticks]
    cmp byte[cs:clock_ticks], 18
    jne check_powerup_timer
    add word[cs:clock_seconds], 1
    mov byte[cs:clock_ticks], 0
    
check_powerup_timer:
    cmp byte[cs:powerup_active], 1
    jne timer_process_logic
    inc byte[cs:powerup_timer]
    cmp byte[cs:powerup_timer], 180
    jne timer_process_logic
    mov byte[cs:powerup_active], 0
    
timer_process_logic:
    push ax
    mov ax, 402
    push ax
    push word[cs:clock_seconds]
    call print_number
    pop ax

    cmp byte[cs:is_ball_stuck], 0
    jne timer_end
    cmp byte[cs:is_game_active], 1
    jne timer_end
    
    inc byte[cs:tick_counter]
    cmp byte[cs:tick_counter], 2
    jne timer_end
    
    call update_ball_physics
    call draw_walls
    mov byte[cs:tick_counter], 0
    
timer_end:
    mov al, 0x20
    out 0x20, al 
    iret 

; ==============================================================================
; MENU SCREENS
; ==============================================================================

draw_lives_ui:
    push ax
    push es
    mov ax, 0xb800
    mov es, ax
    mov cx, 3
    mov ax, 0x0720
    mov di, 292
    rep stosw
    mov cl, byte[cs:player_lives]
    mov ch, 0
    mov ah, 0x07
    mov al, '*'
    mov di, 292
    rep stosw
    pop es
    pop ax
    ret

show_start_menu:
    push ax
    call clear_screen
    
    mov ax, 690
    push ax
    mov ax, str_welcome
    push ax
    mov ax, 24
    push ax
    call print_string_blink
    
    mov ax, 1010
    push ax
    mov ax, str_options
    push ax
    mov ax, 21
    push ax
    call print_string
    
    mov ax, 1330
    push ax
    mov ax, str_play
    push ax
    mov ax, 24
    push ax
    call print_string
    
    mov ax, 1650
    push ax
    mov ax, str_instruction_prompt
    push ax
    mov ax, 35
    push ax
    call print_string
    
    pop ax
    ret

str_instruction_prompt: db 'PRESS I TO GO INTO INSTRUCTION BOX', 0

show_instructions:
    push ax
    call clear_screen
    
    mov ax, 370
    push ax
    mov ax, str_instruction
    push ax
    mov ax, 11
    push ax
    call print_string_blink
    
    mov ax, 690
    push ax
    mov ax, str_total_lives
    push ax
    mov ax, 22
    push ax
    call print_string
    
    mov ax, 1010
    push ax
    mov ax, str_play
    push ax
    mov ax, 24
    push ax
    call print_string
    
    mov ax, 1330
    push ax
    mov ax, str_solid_base
    push ax
    mov ax, 41
    push ax
    call print_string
    
    mov ax, 1650
    push ax
    mov ax, str_bonus_note
    push ax
    mov ax, 43
    push ax
    call print_string
    
    mov ax, 1970
    push ax
    mov ax, str_space_bar
    push ax
    mov ax, 31
    push ax
    call print_string
    
    mov ax, 2290
    push ax
    mov ax, str_controls
    push ax
    mov ax, 34
    push ax
    call print_string
    
    mov ax, 2610
    push ax
    mov ax, str_exit
    push ax
    mov ax, 15
    push ax
    call print_string
    
    pop ax
    ret

show_game_over_menu:
    push ax
    call clear_screen
    
    ; Display "YOU LOSE" if lives = 0 or bricks left
    cmp byte[player_lives], 1
    jne check_win_condition
    mov ax, 1990
    push ax
    mov ax, str_lose
    push ax
    mov ax, 8
    push ax
    call print_string_blink
check_win_condition:
    cmp word[total_bricks], 0
    jne display_results
    mov ax, 1990
    push ax
    mov ax, str_lose
    push ax
    mov ax, 8
    push ax
    call print_string_blink
    
display_results:
    mov ax, 690
    push ax
    mov ax, str_total_score
    push ax
    mov ax, 17
    push ax
    call print_string
    
    mov ax, 728
    push ax
    push word[score]
    call print_number
    
    mov ax, 1330
    push ax
    mov ax, str_lives_rem
    push ax
    mov ax, 15
    push ax
    call print_string
    
    mov ax, 1392
    push ax
    push word[player_lives]
    call print_number
    
    mov ax, 1650
    push ax
    mov ax, str_restart
    push ax
    mov ax, 34
    push ax
    call print_string
    
    mov ax, 1970
    push ax
    mov ax, str_quit_game
    push ax
    mov ax, 26
    push ax
    call print_string
    
wait_for_end_input:
    cmp byte[cs:game_restart_flag], 1
    je do_game_restart
    cmp byte[cs:game_quit_flag], 1
    je do_game_quit
    jmp wait_for_end_input

do_game_quit:
    pop ax
    ret
    
do_game_restart:
    pop ax
    mov word[clock_seconds], 0
    mov byte[clock_ticks], 0
    mov byte[is_game_active], 1
    mov word[total_bricks], 24
    mov byte[player_lives], 3
    mov word[score], 0
    mov byte[end_of_game_flag], 0
    mov word[bonus_score], 0
    ret

draw_ui_static_text:
    push ax
    mov ax, 280
    push ax
    mov ax, str_lives_lbl
    push ax
    mov ax, 5
    push ax
    call print_string_blink
    
    mov ax, 162
    push ax
    mov ax, str_score_lbl
    push ax
    mov ax, 5
    push ax
    call print_string_blink
    
    mov ax, 390
    push ax
    mov ax, str_time_lbl
    push ax
    mov ax, 5
    push ax
    call print_string_blink
    pop ax
    ret

; ==============================================================================
; MAIN LOOP
; ==============================================================================

main:
    xor ax, ax
    mov es, ax
    
    ; Save Old Interrupts
    mov ax, [es:9*4]
    mov [old_keyboard_isr], ax
    mov ax, [es:9*4+2]
    mov [old_keyboard_isr+2], ax
    
    mov ax, [es:8*4]
    mov [old_timer_isr], ax
    mov ax, [es:8*4+2]
    mov [old_timer_isr+2], ax
    
    ; Install New Interrupts
    cli 
    mov word [es:9*4], keyboard_handler
    mov [es:9*4+2], cs 
    mov word [es:8*4], timer_handler
    mov [es:8*4+2], cs
    sti 
    
    call show_start_menu
    
menu_loop:
    cmp byte[menu_instruction_flag], 1
    je enter_instruction_screen
    cmp byte[is_game_active], 0
    je menu_loop
    cmp byte[end_of_game_flag], 1
    je enter_end_game
    jmp start_game_logic

enter_instruction_screen:
    call show_instructions
instr_wait:
    cmp byte[is_game_active], 1
    je start_game_logic
    jne instr_wait

start_game_logic:
    mov byte[game_restart_flag], 0
    mov byte[game_quit_flag], 0
    call clear_screen
    call draw_ui_static_text
    call draw_lives_ui
    
    mov ax, 174
    push ax
    push word[score]
    call print_number
    
    call draw_walls
    call draw_initial_bricks
    mov byte[is_ball_stuck], 1
    call update_paddle_movement

game_loop:
    cmp word[total_bricks], 0
    je enter_end_game 
    cmp byte[end_of_game_flag], 1
    je enter_end_game
    cmp byte[player_lives], 0
    je enter_end_game
    jmp game_loop

enter_end_game:
    mov byte[is_game_active], 0
    call show_game_over_menu
    call clear_screen
    cmp byte[game_restart_flag], 1
    je start_game_logic
    
    ; Restore Interrupts & Exit
    mov ax, [old_keyboard_isr]
    mov bx, [old_keyboard_isr+2]
    mov cx, [old_timer_isr]
    mov dx, [old_timer_isr+2]
    cli 
    mov [es:9*4], ax
    mov [es:9*4+2], bx
    mov [es:8*4], cx
    mov [es:8*4+2], dx
    sti
    
    mov ax, 0x4c00
    int 0x21
```