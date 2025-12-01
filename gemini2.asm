[org 0x0100]
jmp main

; ==============================================================================
; DATA SECTION: VARIABLES & GAME STATE
; ==============================================================================

is_game_active:       db 0       
end_of_game_flag:     db 0       
game_quit_flag:       db 0       
game_restart_flag:    db 0       
menu_instruction_flag:db 0       

; --- Ball Physics ---
ball_x:               dw 0       
ball_y:               dw 0       
ball_dir_x:           db 0       
ball_dir_y:           db 0       
ball_mem_pos:         dw 0       
ball_old_pos:         dw 0       
ball_next_pos:        dw 0       
is_ball_stuck:        db 0       
ball_stuck_offset:    dw 0       
ball_is_vertical:     db 0       
ball_speed_delay:     db 2       ; 2 = Normal, 1 = Fast (Level 2)

; --- Paddle Physics ---
paddle_center_mem:    dw 3760    ; Left edge of paddle in memory
paddle_width_chars:   dw 9       ; Default 9
paddle_width_bytes:   dw 18      ; Default 18
paddle_half_bytes:    dw 8       ; Center offset
wall_left_limit:      dw 3680    
wall_right_limit:     dw 3822    ; 3840 - 18

key_left_pressed:     dw 0       
key_right_pressed:    dw 0       
paddle_draw_left:     dw 0       
paddle_draw_right:    dw 0       
paddle_mid_mem:       dw 0       
bounce_dir_flag:      db 0       

; --- Player Stats ---
player_lives:         db 3
score:                dw 0
total_bricks:         dw 59
current_level:        db 1       ; 1 or 2
bonus_score:          dw 0       

; --- Powerups ---
no_hit_timer:         dw 0       ; Counts ticks since last paddle hit
powerup_active:       db 0       ; 1 = Falling
powerup_y:            dw 0
powerup_x:            dw 40      ; Drop from center
powerup_old_pos:      dw 0
is_paddle_big:        db 0
big_paddle_timer:     dw 0       ; Duration counter for big paddle effect

; --- Time & System ---
old_keyboard_isr:     dd 0       
old_timer_isr:        dd 0       
tick_counter:         db 0       
clock_seconds:        dw 0       
clock_ticks:          db 0       

; ==============================================================================
; BRICK LAYOUTS
; ==============================================================================
bricks_start_loc: 
    ; Row 1
    dw 960, 976, 992, 1008, 1024, 1040, 1056, 1072, 1088, 1104
    ; Row 2
    dw 1120, 1130, 1140, 1150, 1160, 1170, 1180, 1190, 1200, 1210, 1220, 1230, 1240, 1250, 1260, 1270
    ; Row 3
    dw 1280, 1288, 1296, 1304, 1312, 1320, 1328, 1336, 1344, 1352, 1360, 1368, 1376, 1384, 1392, 1400, 1408, 1416, 1424, 1432
    ; Row 4
    dw 1440, 1456, 1464, 1480, 1488, 1504, 1512, 1528, 1536, 1552, 1560, 1576, 1584

bricks_end_loc:
    ; Row 1
    dw 975, 991, 1007, 1023, 1039, 1055, 1071, 1087, 1103, 1119
    ; Row 2
    dw 1129, 1139, 1149, 1159, 1169, 1179, 1189, 1199, 1209, 1219, 1229, 1239, 1249, 1259, 1269, 1279
    ; Row 3
    dw 1287, 1295, 1303, 1311, 1319, 1327, 1335, 1343, 1351, 1359, 1367, 1375, 1383, 1391, 1399, 1407, 1415, 1423, 1431, 1439
    ; Row 4
    dw 1455, 1463, 1479, 1487, 1503, 1511, 1527, 1535, 1551, 1559, 1575, 1583, 1599

; --- Strings ---
str_welcome:      db 'WELCOME TO BRICK BREAKER', 0
str_rules_title:  db 'RULES & CONTROLS:', 0
str_rule_1:       db '- BREAK ALL BRICKS TO WIN', 0
str_rule_2:       db '- 3 LIVES | SCORE POINTS', 0
str_controls_txt: db 'ARROWS: MOVE | ESC: EXIT', 0
str_cheat_txt:    db 'L: SKIP LEVEL (TEST)', 0
str_start_txt:    db 'PRESS ENTER TO START', 0

str_lose:         db 'GAME OVER', 0
str_win_msg:      db 'YOU WIN!', 0
str_level2_msg:   db 'LEVEL 2 START - SPEED UP!', 0
str_score_lbl:    db 'SCORE', 0
str_lives_lbl:    db 'LIVES', 0
str_time_lbl:     db 'TIME', 0
str_header_msg:   db '--- ASM BREAKOUT ---', 0 
str_total_score:  db 'FINAL SCORE:', 0
str_lives_rem:    db 'LIVES LEFT:', 0
str_restart:      db 'PRESS R TO RESTART', 0
str_quit_game:    db 'PRESS ESC TO QUIT', 0

; ==============================================================================
; SOUND ENGINE
; ==============================================================================

play_tone:
    push ax
    push cx
    mov al, 182
    out 43h, al
    mov ax, di          
    out 42h, al
    mov al, ah
    out 42h, al
    in al, 61h
    or al, 00000011     
    out 61h, al
sound_delay_loop:
    mov cx, 2000        
delay_inner:
    dec cx
    jnz delay_inner
    dec bx
    jnz sound_delay_loop
    in al, 61h
    and al, 11111100b   
    out 61h, al
    pop cx
    pop ax
    ret

sound_paddle_hit:
    push di
    push bx
    mov di, 3000        
    mov bx, 50          
    call play_tone
    pop bx
    pop di
    ret

sound_brick_break:
    push di
    push bx
    mov di, 4500        
    mov bx, 80          
    call play_tone
    pop bx
    pop di
    ret

sound_life_lost:
    push di
    push bx
    mov di, 9000        
    mov bx, 500         
    call play_tone
    pop bx
    pop di
    ret

play_game_over_tune:
    push di
    push bx
    mov di, 4000
    mov bx, 150
    call play_tone
    mov di, 3000
    mov bx, 150
    call play_tone
    mov di, 2000
    mov bx, 300
    call play_tone
    pop bx
    pop di
    ret

play_level_up_tune:
    push di
    push bx
    mov di, 2000
    mov bx, 100
    call play_tone
    mov di, 1500
    mov bx, 100
    call play_tone
    mov di, 1000
    mov bx, 200
    call play_tone
    pop bx
    pop di
    ret

; ==============================================================================
; UTILITY FUNCTIONS
; ==============================================================================

calculate_offset:
    push bp
    mov bp, sp
    push ax
    push bx
    mov ax, [bp+6]  
    mov bx, 80
    mul bx          
    add ax, [bp+4]  
    shl ax, 1       
    mov di, ax      
    pop bx
    pop ax
    pop bp
    ret 4

clear_screen: 
    push es
    push ax
    push cx
    push di
    mov ax, 0xb800
    mov es, ax 
    xor di, di 
    mov ax, 0x0720      
    mov cx, 2000        
    cld 
    rep stosw 
    pop di 
    pop cx
    pop ax
    pop es
    ret 

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
    push word [bp+10] 
    push word [bp+8]  
    call calculate_offset
    mov si, [bp+6]      
    mov cx, [bp+4]      
    mov ah, 0x07        
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
    ret 8 

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
    push word [bp+10] 
    push word [bp+8]  
    call calculate_offset
    mov si, [bp+6]      
    mov cx, [bp+4]      
    mov ah, 0x8e        
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
    ret 8

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
    push word [bp+8] 
    push word [bp+6] 
    call calculate_offset
    mov ax, [bp+4]      
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
    ret 6

; ==============================================================================
; DRAWING FUNCTIONS
; ==============================================================================

draw_initial_bricks:
    push es
    push cx
    push bx
    push si
    push di
    push ax
    push dx
    
    mov ax, 0xb800
    mov es, ax
    
    mov cx, 59      ; Loop for 59 bricks
    mov si, 0       ; Array index
    
draw_brick_loop:
    mov di, word[bricks_start_loc + si]
    mov bx, word[bricks_end_loc + si]
    
    mov ax, bx
    sub ax, di
    inc ax          
    shr ax, 1       
    mov dx, ax      ; DX = Width

    ; Gap Logic: dec dx
    dec dx          

    ; Determine Row
    cmp si, 20
    jb color_row_1
    cmp si, 52
    jb color_row_2
    cmp si, 92
    jb color_row_3
    jmp color_row_4

calc_color_toggle:
    push ax
    push dx
    mov ax, si
    shr ax, 1       
    test ax, 1
    jz is_even
    mov bl, 1       
    jmp cct_end
is_even:
    mov bl, 0       
cct_end:
    pop dx
    pop ax
    ret

; [TEXTURED PALETTES]
color_row_1: ; Red Theme (50 pts)
    call calc_color_toggle
    cmp bl, 0
    je r1_dark
    mov ah, 0xC4 
    jmp apply_textured_brick
r1_dark:
    mov ah, 0x4C 
    jmp apply_textured_brick

color_row_2: ; Brown/Yellow Theme (20 pts)
    call calc_color_toggle
    cmp bl, 0
    je r2_dark
    mov ah, 0xE6 
    jmp apply_textured_brick
r2_dark:
    mov ah, 0x6E 
    jmp apply_textured_brick

color_row_3: ; Blue Theme (10 pts)
    call calc_color_toggle
    cmp bl, 0
    je r3_dark
    mov ah, 0x91 
    jmp apply_textured_brick
r3_dark:
    mov ah, 0x19 
    jmp apply_textured_brick

color_row_4: ; Magenta Theme (5 pts)
    call calc_color_toggle
    cmp bl, 0
    je r4_dark
    mov ah, 0xD5 
    jmp apply_textured_brick
r4_dark:
    mov ah, 0x5D 
    jmp apply_textured_brick

apply_textured_brick:
    mov al, 0xB0    ; '░'
    push cx         
    mov cx, dx      
draw_texture_chars:
    stosw           
    loop draw_texture_chars
    pop cx          
    add si, 2       
    dec cx
    cmp cx, 0
    je draw_done
    jmp draw_brick_loop

draw_done:
    pop dx
    pop ax
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
    
    mov cx, [paddle_width_chars] ; Dynamic Width
    mov di, [bp+4] 
    rep stosw
    
    mov di, [ball_stuck_offset] 
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
    mov ah, 0x70        ; Grey Color
    
    mov cx, [paddle_width_chars] ; Dynamic Width
    mov di, [bp+4]      
    
    mov word[paddle_draw_left], di
    rep stosw
    sub di, 2
    mov word[paddle_draw_right], di
    
    mov ax, word[paddle_draw_right]
    sub ax, [paddle_half_bytes] ; Dynamic Offset
    mov word[paddle_mid_mem], ax
    
    cmp byte[is_ball_stuck], 1
    jne end_draw_paddle
    
    sub ax, 160 
    mov di, ax
    shr ax, 1
    sub ax, 1760 
    mov cx, ax
    
    mov al, 'O'
    mov ah, 0x07
    mov word[es:di], ax
    mov [ball_stuck_offset], di
    mov word[ball_y], 22
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
; POWERUP LOGIC
; ==============================================================================

spawn_powerup:
    cmp byte[powerup_active], 1
    je spawn_exit
    
    mov byte[powerup_active], 1
    mov word[powerup_y], 4      ; Start at top
    mov word[powerup_x], 40     ; Center
    
spawn_exit:
    ret

update_powerup:
    cmp byte[powerup_active], 0
    jne process_powerup
    jmp update_buff_timer

process_powerup:
    ; Erase Old 'P'
    mov ax, 0xb800
    mov es, ax
    mov di, [powerup_old_pos]
    mov word[es:di], 0x0720
    
    ; Move Down
    inc word[powerup_y]
    
    ; Calc Offset
    mov ax, [powerup_y]
    mov bx, 80
    mul bx
    add ax, [powerup_x]
    shl ax, 1
    mov di, ax
    mov [powerup_old_pos], di
    
    ; Draw New 'P'
    mov ah, 0xF0        ; White BG, Black Text
    mov al, 'P'
    mov word[es:di], ax
    
    ; Check Bottom
    cmp word[powerup_y], 24
    je remove_powerup
    
    ; Check Collision with Paddle (Row 23)
    cmp word[powerup_y], 23
    jne powerup_exit_trampoline
    
    ; Check X range
    cmp di, [paddle_draw_left]
    jb powerup_exit_trampoline
    cmp di, [paddle_draw_right]
    ja powerup_exit_trampoline
    
    ; CAUGHT!
    mov byte[is_paddle_big], 1
    mov byte[powerup_active], 0
    mov word[powerup_y], 0
    mov word[es:di], 0x0720 ; Erase P
    
    ; Grow Paddle
    mov word[paddle_width_chars], 15
    mov word[paddle_width_bytes], 30
    mov word[paddle_half_bytes], 14
    mov word[wall_right_limit], 3810 ; 3840 - 30
    
    mov word[big_paddle_timer], 270 ; 15 sec * 18 ticks = 270
    call sound_paddle_hit 
    jmp powerup_exit

powerup_exit_trampoline:
    jmp powerup_exit

remove_powerup:
    mov byte[powerup_active], 0
    mov word[powerup_y], 0
    mov di, [powerup_old_pos]
    mov word[es:di], 0x0720

update_buff_timer:
    cmp byte[is_paddle_big], 1
    jne powerup_exit
    dec word[big_paddle_timer]
    cmp word[big_paddle_timer], 0
    jne powerup_exit
    
    ; [FIXED] REVERT PADDLE LOGIC WITH CLEANUP
    ; 1. Clear the currently BIG paddle
    mov di, [paddle_center_mem]
    push di
    call clear_paddle_gfx
    ; 2. Reset variables to SMALL
    mov byte[is_paddle_big], 0
    mov word[paddle_width_chars], 9
    mov word[paddle_width_bytes], 18
    mov word[paddle_half_bytes], 8
    mov word[wall_right_limit], 3822
    ; 3. Draw the new SMALL paddle
    mov di, [paddle_center_mem]
    push di
    call draw_paddle_gfx

powerup_exit:
    ret

; ==============================================================================
; PHYSICS & GAMEPLAY LOGIC
; ==============================================================================

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
    add ax, 8                       
    cmp ax, word[wall_right_limit]
    jbe do_move_right       ; [FIXED] Clamp logic
    mov ax, word[wall_right_limit] ; Snap to limit if exceeded
    
do_move_right:
    mov di, word[paddle_center_mem]
    push di
    call clear_paddle_gfx
    push ax
    call draw_paddle_gfx
    mov word[paddle_center_mem], ax
    jmp exit_paddle_logic

move_paddle_left:
    mov ax, word[paddle_center_mem]
    sub ax, 8                       
    cmp ax, word[wall_left_limit]
    jae do_move_left        ; [FIXED] Clamp logic
    mov ax, word[wall_left_limit]
    
do_move_left:
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

calc_next_ball_pos:
    push ax
    push bx
    push cx
    
    cmp byte[ball_is_vertical], 1
    je skip_x_movement

    mov al, [ball_dir_x]
    mov bx, [ball_x]
    cmp al, 1
    jne move_left
    add bx, 1
    jmp check_x_walls
move_left:
    sub bx, 1

check_x_walls:
    cmp bx, 0     ; Left Edge
    jne check_right_wall
    mov al, 1     
    mov [ball_dir_x], al
    jmp skip_x_movement 
    
check_right_wall:
    cmp bx, 79    ; Right Edge
    jne skip_x_movement
    mov al, 0     
    mov [ball_dir_x], al

skip_x_movement:
    mov ah, [ball_dir_y]
    mov cx, [ball_y]
    
    cmp ah, 1
    jne move_up
    add cx, 1
    jmp check_y_walls
move_up:
    sub cx, 1

check_y_walls:
    cmp cx, 3     ; Top Edge
    jne check_bottom_wall
    mov ah, 1     ; Force Down
    mov [ball_dir_y], ah
    jmp do_calc
check_bottom_wall:
    cmp cx, 24    ; Bottom Edge (Death)
    jne do_calc
    mov ah, 0     

do_calc:
    cmp byte[ball_is_vertical], 1
    je calc_vertical_pos
    push bx 
    push cx 
    call calc_mem_offset
    pop cx
    pop bx
    pop ax
    ret

calc_vertical_pos:
    push word[ball_x]
    push cx           
    call calc_mem_offset
    pop cx
    add sp, 2         
    pop ax
    ret

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

handle_brick_collision:
    push es
    push ax
    push dx
    push cx
    push si
    push bx
    mov ax, 0xb800
    mov es, ax
    
    mov cx, 59
    mov si, 0
    mov dx, [ball_next_pos]
    
brick_check_loop:
    mov ax, word[bricks_start_loc + si]
    mov bx, word[bricks_end_loc + si]
    add si, 2
    
    cmp dx, ax      
    jb not_this_brick
    cmp dx, bx
    ja not_this_brick
    
    jmp remove_brick 

not_this_brick:
    dec cx
    cmp cx, 0
    je brick_func_end_jump
    jmp brick_check_loop

brick_func_end_jump:
    jmp brick_func_end

remove_brick: 
    sub si, 2 
    
    mov di, word[bricks_start_loc + si]
    mov bx, word[bricks_end_loc + si]
    mov ax, bx
    sub ax, di
    inc ax
    shr ax, 1
    mov cx, ax ; Width
    mov ax, 0x0720
    rep stosw   ; Erase
    
    call sound_brick_break
    dec word[total_bricks]
    
    ; [SCORING]
    cmp si, 20
    jb score_50
    cmp si, 52
    jb score_20
    cmp si, 92
    jb score_10
    jmp score_5

score_50:
    add word[score], 50
    jmp update_score_ui
score_20:
    add word[score], 20
    jmp update_score_ui
score_10:
    add word[score], 10
    jmp update_score_ui
score_5:
    add word[score], 5

update_score_ui:
    mov ax, 1
    push ax
    mov ax, 7
    push ax
    push word[score]
    call print_number
    xor byte[ball_dir_y], 1 
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
    
    mov di, [ball_old_pos]
    mov word[es:di], 0x0720
    
    call calc_next_ball_pos
    mov di, [ball_next_pos]
    mov ax, word[es:di] 
    
    cmp ah, 0x07 ; Empty Space?
    je check_movement_flags
    
    cmp ah, 0x70 ; Paddle Color?
    je hit_paddle
    
    call handle_brick_collision
    jmp calc_final_pos
    
hit_paddle:
    call sound_paddle_hit
    mov word[no_hit_timer], 0 ; Reset no hit timer

    mov ax, word[ball_next_pos]
    sub ax, [paddle_mid_mem]
    cmp ax, 0
    jge abs_dist
    neg ax
abs_dist:
    cmp ax, 4
    jl go_vertical_bounce

    mov byte[ball_is_vertical], 0
    call determine_bounce_dir
    cmp byte[bounce_dir_flag], 1
    jne set_left_bounce
    mov byte[ball_dir_x], 1
    jmp update_paddle_y
set_left_bounce:
    mov byte[ball_dir_x], 0
    jmp update_paddle_y

go_vertical_bounce:
    mov byte[ball_is_vertical], 1
    
update_paddle_y:
    mov byte[ball_dir_y], 0
    jmp calc_final_pos

check_movement_flags:
    cmp byte[ball_is_vertical], 1
    je check_y_w

    cmp word[ball_x], 0     
    jne check_right_w
    mov byte[ball_dir_x], 1
    jmp check_y_w
check_right_w:
    cmp word[ball_x], 79    
    jne check_y_w
    mov byte[ball_dir_x], 0
            
check_y_w:
    cmp word[ball_y], 3     
    jne check_bottom_w
    mov byte[ball_dir_y], 1
    jmp do_ball_print
check_bottom_w:
    cmp byte[powerup_active], 0
    jne powerup_save
    
    cmp word[ball_y], 24    
    jne do_ball_print
    
    call sound_life_lost

    mov byte[is_ball_stuck], 1 
    
    mov ax, word[paddle_mid_mem]
    sub ax, 160 ; Row 22
    mov di, ax
    shr ax, 1
    sub ax, 1760 ; 22 * 80
    mov cx, ax

    mov al, 'O'
    mov ah, 0x07
    mov word[es:di], ax
    mov [ball_stuck_offset], di
    mov word[ball_y], 22
    mov word[ball_x], cx
    mov word[ball_old_pos], di
    
    mov byte[ball_is_vertical], 0

    mov ah, 0x07
    mov al, 'O'
    mov word[es:di], ax
    
    sub byte[player_lives], 1
    
    call draw_lives_ui
    jmp ball_exit
    
powerup_save:
    cmp word[ball_y], 24    
    jne do_ball_print
    mov byte[ball_dir_y], 0 

do_ball_print:
    cmp byte[ball_is_vertical], 1
    je check_y_inc

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
; INTERRUPT HANDLERS
; ==============================================================================

keyboard_handler: 
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds          
    push es
    push cs
    pop ds           
    
    mov word[key_right_pressed], 0
    mov word[key_left_pressed], 0
    mov ax, 0xb800
    mov es, ax 
    in al, 0x60      
    
    cmp al, 0x01 ; ESC
    je set_quit_flag
    
    ; [ADDED] Cheat Key 'L' (0x26)
    cmp al, 0x26
    jne check_menu_input
    mov word[total_bricks], 0 ; Instant Win/Next Level
    jmp kb_exit

check_menu_input:
    cmp byte[is_game_active], 0
    jne game_mode_input
    
    cmp al, 0x1c ; ENTER
    jne kb_exit
    mov byte[is_game_active], 1
    jmp kb_exit

set_quit_flag:
    mov byte[game_quit_flag], 1
    jmp kb_exit

game_mode_input:
    cmp al, 0x4b     
    jne try_right
    mov word[key_left_pressed], 1
    call update_paddle_movement
    jmp kb_exit
try_right: 
    cmp al, 0x4d     
    jne try_space
    mov word[key_right_pressed], 1
    call update_paddle_movement
    jmp kb_exit
try_space:
    cmp al, 0x39     
    jne try_exit
    mov byte[is_ball_stuck], 0
    jmp kb_exit
    
try_exit: 
    cmp al, 0x12     
    jne try_restart
    mov byte[end_of_game_flag], 1
    jmp kb_exit
try_restart:
    cmp al, 0x13     
    jne kb_exit
    mov byte[game_restart_flag], 1
    
kb_exit:
    mov al, 0x20
    out 0x20, al   
    pop es
    pop ds           
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax 
    iret 

timer_handler: 
    push ax
    push ds          
    push cs
    pop ds           
    
    cmp byte[is_game_active], 1
    jne timer_process_logic
    
    inc byte[clock_ticks]
    cmp byte[clock_ticks], 18
    jne timer_process_logic
    add word[clock_seconds], 1
    mov byte[clock_ticks], 0
    
timer_process_logic:
    push ax
    mov ax, 1 
    push ax
    mov ax, 38 
    push ax
    push word[clock_seconds]
    call print_number
    pop ax

    cmp byte[is_ball_stuck], 0
    jne timer_end
    cmp byte[is_game_active], 1
    jne timer_end
    
    inc word[no_hit_timer]
    cmp word[no_hit_timer], 180 ; 10 seconds
    jne skip_powerup_spawn
    call spawn_powerup
    
skip_powerup_spawn:
    ; Update Powerup (Drop) every 2 ticks
    test byte[tick_counter], 1
    jnz skip_powerup_update
    call update_powerup
skip_powerup_update:

    inc byte[tick_counter]
    mov al, [ball_speed_delay]
    cmp byte[tick_counter], al
    jne timer_end
    
    call update_ball_physics
    mov byte[tick_counter], 0
    
timer_end:
    mov al, 0x20
    out 0x20, al 
    pop ds           
    pop ax
    iret 

; ==============================================================================
; MENU SCREEN HELPERS
; ==============================================================================

draw_lives_ui:
    push ax
    push es
    push di
    push cx
    mov ax, 0xb800
    mov es, ax
    
    mov ax, 1
    push ax
    mov ax, 66
    push ax
    call calculate_offset 
    mov cx, 3
    mov ax, 0x0720
    rep stosw
    
    cmp byte[player_lives], 0
    je end_draw_lives
    
    mov ax, 1
    push ax
    mov ax, 66
    push ax
    call calculate_offset
    
    mov cl, byte[player_lives]
    mov ch, 0
    mov al, 0x03        
    mov ah, 0x0C        
    rep stosw
    
end_draw_lives:
    pop cx
    pop di
    pop es
    pop ax
    ret

show_start_menu:
    push ax
    call clear_screen
    
    ; Welcome Title
    mov ax, 4
    push ax
    mov ax, 25
    push ax
    mov ax, str_welcome
    push ax
    mov ax, 24
    push ax
    call print_string_blink
    
    ; Rules Title
    mov ax, 7
    push ax
    mov ax, 25
    push ax
    mov ax, str_rules_title
    push ax
    mov ax, 17
    push ax
    call print_string
    
    ; Rule 1
    mov ax, 9
    push ax
    mov ax, 25
    push ax
    mov ax, str_rule_1
    push ax
    mov ax, 25
    push ax
    call print_string
    
    ; Rule 2
    mov ax, 11
    push ax
    mov ax, 25
    push ax
    mov ax, str_rule_2
    push ax
    mov ax, 24
    push ax
    call print_string
    
    ; Controls
    mov ax, 14
    push ax
    mov ax, 25
    push ax
    mov ax, str_controls_txt
    push ax
    mov ax, 24
    push ax
    call print_string

    ; Cheat
    mov ax, 16
    push ax
    mov ax, 25
    push ax
    mov ax, str_cheat_txt
    push ax
    mov ax, 20
    push ax
    call print_string
    
    ; Start Prompt
    mov ax, 18
    push ax
    mov ax, 25
    push ax
    mov ax, str_start_txt
    push ax
    mov ax, 20
    push ax
    call print_string_blink
    
    pop ax
    ret

show_instructions:
    ret

show_game_over_menu:
    call play_game_over_tune

    push ax
    call clear_screen
    
    cmp byte[player_lives], 1
    jne check_win_condition
    
    ; Lose Text
    mov ax, 10
    push ax
    mov ax, 35
    push ax
    mov ax, str_lose
    push ax
    mov ax, 9
    push ax
    call print_string_blink
    jmp display_results

check_win_condition:
    cmp word[total_bricks], 0
    jne display_results
    
    ; Win Text
    mov ax, 10
    push ax
    mov ax, 35
    push ax
    mov ax, str_win_msg
    push ax
    mov ax, 8
    push ax
    call print_string_blink

display_results:
    mov ax, 12
    push ax
    mov ax, 32
    push ax
    mov ax, str_total_score
    push ax
    mov ax, 12
    push ax
    call print_string
    
    mov ax, 12
    push ax
    mov ax, 45
    push ax
    push word[score]
    call print_number
    
    mov ax, 16
    push ax
    mov ax, 30
    push ax
    mov ax, str_restart
    push ax
    mov ax, 18
    push ax
    call print_string
    
    mov ax, 18
    push ax
    mov ax, 30
    push ax
    mov ax, str_quit_game
    push ax
    mov ax, 17
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
    mov word[total_bricks], 59
    mov byte[player_lives], 3
    mov word[score], 0
    mov byte[end_of_game_flag], 0
    mov word[bonus_score], 0
    mov byte[current_level], 1
    mov byte[ball_speed_delay], 2
    ret

draw_ui_static_text:
    push ax
    mov ax, 0
    push ax
    mov ax, 30
    push ax
    mov ax, str_header_msg
    push ax
    mov ax, 20
    push ax
    call print_string

    mov ax, 1
    push ax
    mov ax, 60
    push ax
    mov ax, str_lives_lbl
    push ax
    mov ax, 5
    push ax
    call print_string_blink
    
    mov ax, 1
    push ax
    mov ax, 1
    push ax
    mov ax, str_score_lbl
    push ax
    mov ax, 5
    push ax
    call print_string_blink
    
    mov ax, 1
    push ax
    mov ax, 32
    push ax
    mov ax, str_time_lbl
    push ax
    mov ax, 4
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
    
    mov ax, [es:9*4]
    mov [old_keyboard_isr], ax
    mov ax, [es:9*4+2]
    mov [old_keyboard_isr+2], ax
    mov ax, [es:8*4]
    mov [old_timer_isr], ax
    mov ax, [es:8*4+2]
    mov [old_timer_isr+2], ax
    
    cli 
    mov word [es:9*4], keyboard_handler
    mov [es:9*4+2], cs 
    mov word [es:8*4], timer_handler
    mov [es:8*4+2], cs
    sti 
    
    call show_start_menu
    
menu_loop:
    cmp byte[game_quit_flag], 1
    je exit_trampoline
    
    cmp byte[is_game_active], 0
    je menu_loop
    
    cmp byte[end_of_game_flag], 1
    je end_game_trampoline
    
    jmp start_game_logic

exit_trampoline:
    jmp exit_to_dos

end_game_trampoline:
    jmp enter_end_game

enter_instruction_screen:
    jmp start_game_logic

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
    
    mov ax, 1
    push ax
    mov ax, 7
    push ax
    push word[score]
    call print_number
    
    call draw_initial_bricks
    mov byte[is_ball_stuck], 1
    
    mov ax, [paddle_center_mem]
    push ax
    call draw_paddle_gfx

game_loop:
    cmp byte[game_quit_flag], 1
    je exit_to_dos
    cmp word[total_bricks], 0
    je check_level_progression 
    cmp byte[end_of_game_flag], 1
    je enter_end_game
    cmp byte[player_lives], 0
    je enter_end_game
    jmp game_loop

check_level_progression:
    cmp byte[current_level], 1
    jne enter_end_game ; If level 2 cleared, win
    
    ; LEVEL 2 INIT
    inc byte[current_level]
    mov byte[ball_speed_delay], 1 ; Double Speed
    mov word[total_bricks], 59
    
    call clear_screen
    mov ax, 10
    push ax
    mov ax, 25
    push ax
    mov ax, str_level2_msg
    push ax
    mov ax, 25
    push ax
    call print_string_blink
    
    call play_level_up_tune
    
    ; Simple delay loop
    mov cx, 0xFFFF
delay_lvl:
    dec cx
    jnz delay_lvl
    
    jmp start_game_logic

enter_end_game:
    mov byte[is_game_active], 0
    call show_game_over_menu
    call clear_screen
    cmp byte[game_restart_flag], 1
    je start_game_logic
    
exit_to_dos:
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