[org 0x0100]
jmp main

; ==============================================================================
; DATA SECTION: VARIABLES & GAME STATE
; ==============================================================================

; --- Game Status Flags ---
is_game_active:       db 0       ; 0 = Menu, 1 = Playing
end_of_game_flag:     db 0       ; 1 = Player died or pressed 'E'
game_quit_flag:       db 0       ; 1 = Player pressed 'Q' to exit to DOS
game_restart_flag:    db 0       ; 1 = Player pressed 'R' to restart
menu_instruction_flag:db 0       ; 1 = Player wants to see instructions

; --- Ball Physics ---
ball_x:               dw 0       ; Ball Column (0-79)
ball_y:               dw 0       ; Ball Row (0-24)
ball_dir_x:           db 0       ; 0 = Moving Left, 1 = Moving Right
ball_dir_y:           db 0       ; 0 = Moving Up, 1 = Moving Down
ball_mem_pos:         dw 0       ; Current Video Memory Address (0xb800 offset)
ball_old_pos:         dw 0       ; Previous Address (used to erase ball)
ball_next_pos:        dw 0       ; Calculated Future Address (used for collision check)
is_ball_stuck:        db 0       ; 1 = Ball is glued to paddle (start state)
ball_stuck_offset:    dw 0       ; Relative position of ball on paddle

; --- Paddle Physics ---
paddle_center_mem:    dw 3580    ; Memory address of the center of the paddle
wall_left_limit:      dw 3524    ; Left boundary address (Paddle cannot pass)
wall_right_limit:     dw 3652    ; Right boundary address
key_left_pressed:     dw 0       ; Flag: Left Arrow Key State
key_right_pressed:    dw 0       ; Flag: Right Arrow Key State
paddle_draw_left:     dw 0       ; Calculated Left Edge (for collision logic)
paddle_draw_right:    dw 0       ; Calculated Right Edge
paddle_mid_mem:       dw 0       ; Calculated Middle Point
bounce_dir_flag:      db 0       ; Helper to decide bounce angle

; --- Player Stats ---
player_lives:         db 3
score:                dw 0
total_bricks:         dw 24
bonus_score:          dw 0

; --- Powerups ---
powerup_active:       db 0       ; 1 = "Solid Base" is active
powerup_timer:        db 0       ; Timer to count down powerup duration

; --- Time & System ---
old_keyboard_isr:     dd 0       ; Storage for original Keyboard Interrupt
old_timer_isr:        dd 0       ; Storage for original Timer Interrupt
tick_counter:         db 0       ; Loop counter (speed control)
clock_seconds:        dw 0       ; Seconds elapsed
clock_ticks:          db 0       ; Ticks (18 per second)

; --- Brick Layouts (Memory Offsets) ---
; These are pre-calculated memory addresses where bricks exist
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
str_instruction_prompt: db 'PRESS I TO GO INTO INSTRUCTION BOX', 0

; ==============================================================================
; UTILITY FUNCTIONS
; ==============================================================================

; --- Play Sound ---
; Uses the PC Speaker (Ports 42h, 43h, 61h) to beep
play_sound:
    push ax
    push bx
    mov al, 182
    out 43h, al
    mov ax, 4560        ; Frequency
    out 42h, al
    mov al, ah
    out 42h, al
    in al, 61h
    or al, 00000011     ; Turn speaker ON
    out 61h, al
    mov bx, 2
sound_delay_outer:
    mov cx, 65535
sound_delay_inner:      ; Waste CPU cycles to create duration
    dec cx
    jne sound_delay_inner
    dec bx
    jne sound_delay_outer
    in al, 61h
    and al, 11111100b   ; Turn speaker OFF
    out 61h, al 
    pop bx
    pop ax
    ret 

; --- Clear Screen ---
; Fills the video memory (0xb800) with empty spaces
clear_screen: 
    push es
    push ax
    push cx
    push di
    mov ax, 0xb800
    mov es, ax 
    xor di, di 
    mov ax, 0x0720      ; 07 = Grey Color, 20 = Space Char
    mov cx, 2000        ; 2000 words = full screen (80x25)
    cld 
    rep stosw 
    pop di 
    pop cx
    pop ax
    pop es
    ret 

; --- Print String (Standard) ---
; Stack Inputs: [Position], [String Offset], [Length]
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
    mov di, [bp+8]      ; Screen Position
    mov si, [bp+6]      ; String Offset
    mov cx, [bp+4]      ; Length
    mov ah, 0x07        ; Attribute (Grey on Black)
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

; --- Print String (Blinking) ---
; Same as above, but uses Yellow/Blinking attribute
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
    mov ah, 0x8e        ; Attribute 8E (Blinking Yellow)
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

; --- Print Number ---
; Converts value in stack to ASCII and prints it
; Stack Inputs: [Position], [Number]
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
    mov ax, [bp+4]      ; Number to print
    mov bx, 10 
    mov cx, 0 
digit_loop: 
    mov dx, 0 
    div bx              ; Divide by 10 to isolate digit
    add dl, 0x30        ; Convert to ASCII
    push dx 
    inc cx 
    cmp ax, 0 
    jnz digit_loop 
    mov di, [bp+6]      ; Position
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
; DRAWING FUNCTIONS
; ==============================================================================

; --- Draw Walls ---
; Draws the box border around the play area.
; Checks powerup_active to decide bottom wall color.
draw_walls:
    push ax
    push es
    push di
    mov ax, 0xb800
    mov es, ax
    
    ; Top Wall
    mov ah, 0x60        ; Brown background
    mov al, 0x20 
    mov di, 482
top_wall_loop:
    mov word[es:di], ax
    add di, 2
    cmp di, 636
    jne top_wall_loop
    
    ; Bottom Wall (Color Logic)
    cmp byte[powerup_active], 1
    jne normal_base
    mov ah, 0x40        ; Red background if Powerup Active
    jmp draw_bottom
normal_base:
    mov ah, 0x60        ; Brown background Normal
draw_bottom:
    mov di, 3682
bottom_wall_loop:
    mov word[es:di], ax
    add di, 2
    cmp di, 3836
    jne bottom_wall_loop
    
    ; Side Walls
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

; --- Draw Initial Bricks ---
; Renders the colorful brick layout based on memory hardcodes
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
    
brick_row_1:
    cmp di, 936
    ja brick_row_2
    mov ah, 0x90        ; Blue Bricks
    mov al, 0x20
    mov cx, 6
    rep stosw
    mov cx, 3
    mov ax, 0x0720 
    rep stosw
    add si, 2
    jmp brick_row_1
    
brick_row_2:
    mov di, 1290
brick_row_2_loop:
    cmp di, 1416
    ja brick_row_3
    mov ah, 0xe0        ; Yellow Bricks
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
    mov ah, 0x50        ; Magenta Bricks
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
    mov ah, 0x40        ; Red Powerup Brick
    rep stosw
    
    pop di
    pop si
    pop bx
    pop cx
    pop es
    ret

; --- Clear Paddle ---
; Overwrites the paddle at [bp+4] with spaces
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
    mov di, [bp+4] 
    rep stosw
    
    ; Also clear the stuck ball if applicable
    mov di, [ball_stuck_offset] 
    mov word[es:di], ax
    pop cx
    pop di
    pop ax
    pop es
    pop bp
    ret 2

; --- Draw Paddle ---
; Draws the paddle at [bp+4] and calculates edges/center
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
    mov ah, 0xb0        ; Cyan Color
    mov cx, 13
    mov di, [bp+4]      ; Center Address
    
    ; Save edges for collision logic
    mov word[paddle_draw_left], di
    rep stosw
    sub di, 2
    mov word[paddle_draw_right], di
    
    mov ax, word[paddle_draw_right]
    sub ax, 12
    mov word[paddle_mid_mem], ax
    
    ; If ball is stuck, draw it on top of paddle
    cmp byte[is_ball_stuck], 1
    jne end_draw_paddle
    
    sub ax, 160
    mov di, ax
    shr ax, 1
    sub ax, 1680
    mov cx, ax
    
    mov al, 'O'
    mov ah, 0x07
    mov word[es:di], ax
    mov [ball_stuck_offset], di
    mov word[ball_y], 21
    mov word[ball_x], cx
    mov word[ball_old_pos], di
    
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

; --- Update Paddle Movement ---
; Reads key flags and moves paddle left/right
update_paddle_movement:
    push ax
    push di
    
    cmp word[key_right_pressed], 1
    je move_paddle_right
    cmp word[key_left_pressed], 1
    je move_paddle_left
    jmp exit_paddle_logic

move_paddle_right:
    mov ax, word[paddle_center_mem]
    add ax, 8                       ; Move 4 chars right
    cmp ax, word[wall_right_limit]
    ja exit_paddle_logic
    
    mov di, word[paddle_center_mem]
    push di
    call clear_paddle_gfx
    push ax
    call draw_paddle_gfx
    mov word[paddle_center_mem], ax
    jmp exit_paddle_logic

move_paddle_left:
    mov ax, word[paddle_center_mem]
    sub ax, 8                       ; Move 4 chars left
    cmp ax, word[wall_left_limit]
    jb exit_paddle_logic
    
    mov di, word[paddle_center_mem]
    push di
    call clear_paddle_gfx
    push ax
    call draw_paddle_gfx
    mov word[paddle_center_mem], ax

exit_paddle_logic:
    pop di
    pop ax
    ret

; --- Calculate Memory Offset ---
; Converts X/Y coordinates into 0xb800 offset
; Formula: (Y * 80 + X) * 2
calc_mem_offset:
    push bp
    mov bp, sp
    push ax
    mov al, 80
    mul byte[bp+4] 
    add ax, [bp+6] 
    shl ax, 1 
    mov word[ball_next_pos], ax
    pop ax
    pop bp
    ret 4

; --- Calculate Next Ball Position ---
; Applies direction vectors (ball_dir_x/y) to X/Y to predict next spot
calc_next_ball_pos:
    push ax
    push bx
    push cx
    
    mov al, [ball_dir_x]
    mov ah, [ball_dir_y]
    mov bx, [ball_x]
    mov cx, [ball_y]

    ; Check Walls
    cmp word[ball_x], 3
    jne check_right_wall
    mov al, 1
    jmp check_top_wall
check_right_wall:
    cmp word[ball_x], 77
    jne check_top_wall
    mov al, 0
            
check_top_wall:
    cmp word[ball_y], 4
    jne check_bottom_wall
    mov ah, 1
    jmp apply_movement
check_bottom_wall:
    cmp word[ball_y], 22
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

; --- Determine Bounce Direction ---
; Calculates if ball hit left or right side of paddle
determine_bounce_dir:
    push ax
    mov ax, word[ball_next_pos]
    cmp ax, [paddle_mid_mem]
    ja bounce_right
    cmp ax, [paddle_draw_left]
    jb end_bounce_chk
    mov byte[bounce_dir_flag], 0
    jmp end_bounce_chk
bounce_right:
    cmp ax, [paddle_draw_right]
    ja end_bounce_chk
    mov byte[bounce_dir_flag], 1
end_bounce_chk:
    pop ax
    ret

; --- Handle Brick Collision ---
; Identifies which brick was hit, removes it, and adds score
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
    mov dx, [ball_next_pos]
    
brick_check_loop:
    mov ax, word[bricks_start_loc + si]
    mov bx, word[bricks_end_loc + si]
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
    ; Check if powerup brick (Address 846)
    cmp ax, 846
    jne not_special
    mov byte[powerup_active], 1
not_special:
    
    sub si, 2
    mov di, word[bricks_start_loc + si]
    mov cx, 6
    mov ax, 0x0720
    rep stosw
    call play_sound
    add word[score], 5
    dec word[total_bricks]
    
    ; Update Score on Screen
    mov ax, 174
    push ax
    push word[score]
    call print_number
    
brick_func_end:
    pop bx
    pop si
    pop cx
    pop dx
    pop ax
    pop es
    ret

; --- Update Ball Physics (Main Logic) ---
; Moves ball, checks collisions, updates display
update_ball_physics:
    push es
    push ax
    push bx
    push cx
    push di
    
    mov ax, 0xb800
    mov es, ax
    
    ; Erase Old Ball
    mov di, [ball_old_pos]
    mov word[es:di], 0x0720
    
    call calc_next_ball_pos
    mov di, [ball_next_pos]
    mov ax, word[es:di]
    
    ; Check what is at the next position
    cmp ah, 0x07 ; Empty Space?
    je check_movement_flags
    cmp ah, 0xb0 ; Paddle?
    je hit_paddle
    
    ; It must be a Brick
    call handle_brick_collision
    jmp update_flags
    
hit_paddle:
    call determine_bounce_dir
    cmp byte[bounce_dir_flag], 1
    jne set_left_bounce
    mov byte[ball_dir_x], 1
    jmp update_flags
set_left_bounce:
    mov byte[ball_dir_x], 0
    
update_flags:
    cmp byte[ball_dir_y], 1
    jne set_down
    mov byte[ball_dir_y], 0
    jmp check_movement_flags
set_down:
    cmp byte[ball_dir_y], 0
    jne check_movement_flags
    mov byte[ball_dir_y], 1

check_movement_flags:
    ; Wall Bounce Checks
    cmp word[ball_x], 3
    jne check_right_w
    mov byte[ball_dir_x], 1
    jmp check_y_w
check_right_w:
    cmp word[ball_x], 77
    jne check_y_w
    mov byte[ball_dir_x], 0
            
check_y_w:
    cmp word[ball_y], 4
    jne check_bottom_w
    mov byte[ball_dir_y], 1
    jmp do_ball_print
check_bottom_w:
    ; Check if ball hit bottom
    cmp byte[powerup_active], 0
    jne powerup_save
    
    cmp word[ball_y], 22
    jne do_ball_print
    
    ; DIED: Reset ball to paddle
    mov byte[is_ball_stuck], 1 
    
    mov ax, word[paddle_mid_mem]
    sub ax, 160
    mov di, ax
    shr ax, 1
    sub ax, 1680
    mov cx, ax

    mov al, 'O'
    mov ah, 0x07
    mov word[es:di], ax
    mov [ball_stuck_offset], di
    mov word[ball_y], 21
    mov word[ball_x], cx
    mov word[ball_old_pos], di
    
    sub byte[player_lives], 1
    jmp ball_exit
    
powerup_save:
    cmp word[ball_y], 23
    jne do_ball_print
    mov byte[ball_dir_y], 0 ; Bounce off bottom

do_ball_print:
    ; Update X/Y Variables
    cmp byte[ball_dir_x], 1
    jne dec_x
    add word[ball_x], 1
    jmp check_y_inc
dec_x:
    sub word[ball_x], 1
            
check_y_inc:
    cmp byte[ball_dir_y], 1
    jne dec_y
    add word[ball_y], 1
    jmp calc_final_pos
dec_y:
    sub word[ball_y], 1
    
calc_final_pos:
    ; Convert X/Y to Mem Address and Draw
    mov ax, word[ball_y]
    mov bx, 80
    mul bx
    add ax, word[ball_x]
    shl ax, 1
    mov di, ax
    mov word[ball_old_pos], ax
    
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
; INTERRUPT HANDLERS (ENGINE)
; ==============================================================================

; --- Keyboard Handler (INT 9) ---
; Detects keys and updates flags.
; Uses PUSH CS / POP DS to fix segment addressing.
keyboard_handler: 
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds          ; Save Old DS
    push es
    
    push cs
    pop ds           ; Point DS to CS (Fixes variable access)
    
    mov word[key_right_pressed], 0
    mov word[key_left_pressed], 0
    mov ax, 0xb800
    mov es, ax 
    
    in al, 0x60      ; Read Key Scan Code
    
    cmp byte[is_game_active], 0
    jne game_mode_input
    
    ; Menu Keys
    cmp al, 0x1c     ; Enter
    jne check_instr_key
    mov byte[is_game_active], 1
    jmp kb_exit
check_instr_key:
    cmp al, 0x17     ; 'I'
    jne kb_exit
    mov byte[menu_instruction_flag], 1
    cmp byte[is_game_active], 1
    jne kb_exit

game_mode_input:
    cmp al, 0x4b     ; Left Arrow
    jne try_right
    mov word[key_left_pressed], 1
    call update_paddle_movement
    jmp kb_exit
try_right: 
    cmp al, 0x4d     ; Right Arrow
    jne try_space
    mov word[key_right_pressed], 1
    call update_paddle_movement
    jmp kb_exit
try_space:
    cmp al, 0x39     ; Spacebar
    jne try_exit
    mov byte[is_ball_stuck], 0
    jmp kb_exit
    
try_exit: 
    cmp al, 0x12     ; 'E'
    jne try_quit
    mov byte[end_of_game_flag], 1
    jmp kb_exit
try_quit:
    cmp al, 0x10     ; 'Q'
    jne try_restart
    mov byte[game_quit_flag], 1
    jmp kb_exit
try_restart:
    cmp al, 0x13     ; 'R'
    jne kb_exit
    mov byte[game_restart_flag], 1
    
kb_exit:
    mov al, 0x20
    out 0x20, al     ; Send EOI
    
    pop es
    pop ds           ; Restore Old DS
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax 
    iret 

; --- Timer Handler (INT 8) ---
; Runs 18.2 times/second. Updates Ball and Time.
; Uses PUSH CS / POP DS to fix segment addressing.
timer_handler: 
    push ax
    push ds          ; Save Old DS
    
    push cs
    pop ds           ; Point DS to CS
    
    cmp byte[is_game_active], 1
    jne timer_process_logic
    
    ; Timer Counting
    inc byte[clock_ticks]
    cmp byte[clock_ticks], 18
    jne check_powerup_timer
    add word[clock_seconds], 1
    mov byte[clock_ticks], 0
    
check_powerup_timer:
    cmp byte[powerup_active], 1
    jne timer_process_logic
    inc byte[powerup_timer]
    cmp byte[powerup_timer], 180
    jne timer_process_logic
    mov byte[powerup_active], 0
    
timer_process_logic:
    push ax
    mov ax, 402
    push ax
    push word[clock_seconds]
    call print_number
    pop ax

    cmp byte[is_ball_stuck], 0
    jne timer_end
    cmp byte[is_game_active], 1
    jne timer_end
    
    ; Game Speed Control (Every 2 ticks)
    inc byte[tick_counter]
    cmp byte[tick_counter], 2
    jne timer_end
    
    call update_ball_physics
    call draw_walls
    mov byte[tick_counter], 0
    
timer_end:
    mov al, 0x20
    out 0x20, al 
    
    pop ds           ; Restore Old DS
    pop ax
    iret 

; ==============================================================================
; MENU SCREEN HELPERS
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
    mov cl, byte[player_lives]
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
    cmp byte[game_restart_flag], 1
    je do_game_restart
    cmp byte[game_quit_flag], 1
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
; MAIN ENTRY POINT
; ==============================================================================

main:
    xor ax, ax
    mov es, ax
    
    ; 1. Save Old Interrupts
    mov ax, [es:9*4]
    mov [old_keyboard_isr], ax
    mov ax, [es:9*4+2]
    mov [old_keyboard_isr+2], ax
    
    mov ax, [es:8*4]
    mov [old_timer_isr], ax
    mov ax, [es:8*4+2]
    mov [old_timer_isr+2], ax
    
    ; 2. Install New Interrupts
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
    
    ; 3. Restore Old Interrupts
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
    
    ; 4. Exit to DOS
    mov ax, 0x4c00
    int 0x21