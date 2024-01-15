module pong_game (
    input clk,
    input reset,
    input [8:0] video_y,
    input [12:0] video_x,
    input [8:0] v_active,
    input newline,
    input newframe,
    input visible_window,
    input newpixel,
    input [7:0] paddle0,
    input [7:0] paddle1,
    input paddle0_button,
    input paddle1_button,
    output ycbcr_t ycbcr_out
);
    wire signed [9:0] last_row = v_active - 1;

    bit signed  [9:0] pixel_x = 0;
    bit signed  [9:0] pixel_y = 0;

    always_ff @(posedge clk) begin
        if (newline) pixel_x <= 0;
        if (visible_window && newpixel) pixel_x <= pixel_x + 1;

        pixel_y <= video_y - 38;
    end

    bit signed [9:0] paddle0_frame_latched_val;
    bit signed [9:0] paddle1_frame_latched_val;

    bit [7:0] R_d;
    bit [7:0] G_d;
    bit [7:0] B_d;

    always_ff @(posedge clk) begin
        rgb_conv_in.r <= R_d;
        rgb_conv_in.g <= G_d;
        rgb_conv_in.b <= B_d;

        if (video_y == 7) begin
            paddle0_frame_latched_val <= 10'(paddle0);
            paddle1_frame_latched_val <= 10'(paddle1);
        end
    end

    ycbcr_t rgb_conv_out;
    rgb_t   rgb_conv_in;
    RGB2YCbCr rgb_conv (
        .clk,
        .in (rgb_conv_in),
        .out(rgb_conv_out)
    );

    // Game logic
    typedef struct {
        bit signed [9:0] x;
        bit signed [9:0] y;
    } position_t;

    position_t ball;
    position_t ball_delay1;
    position_t ball_delay2;

    initial begin
        ball.x = 100;
        ball.y = 100;
    end
    delayfifo32e #(20) d1 (
        .clk,
        .enable(newframe),
        .in({ball.x, ball.y}),
        .latency(5),
        .out({ball_delay1.x, ball_delay1.y})
    );

    delayfifo32e #(20) d2 (
        .clk,
        .enable(newframe),
        .in({ball_delay1.x, ball_delay1.y}),
        .latency(5),
        .out({ball_delay2.x, ball_delay2.y})
    );

    bit signed [9:0] ball_speed_x = 1;
    bit signed [9:0] ball_speed_y = 0;
    bit signed [9:0] next_ball_speed_x;
    bit signed [9:0] next_ball_speed_y;
    //bit signed [9:0] nextball_speed_y = 1;
    localparam bit signed [9:0] ShadowX = 3;
    localparam bit signed [9:0] ShadowY = 4;

    localparam bit signed [9:0] BallHalfWidth = 3;
    localparam bit signed [9:0] BallHalfHeight = 5;

    localparam bit signed [9:0] PaddleHalfHeight = 30;

    bit signed [9:0] paddle_collider_top;
    bit signed [9:0] paddle_collider_bottom;
    bit signed [9:0] paddle_collision_force_d;
    bit signed [9:0] paddle_collision_force_q;

    always_ff @(posedge clk) paddle_collision_force_q <= paddle_collision_force_d;

    bit left_player_scored = 0;
    bit left_player_scored_q = 0;
    bit right_player_scored = 0;
    bit restart_game = 0;

    bit [3:0] left_player_score = 0;
    bit [3:0] right_player_score = 0;
    bit [7:0] charline;
    bit [7:0] charline_shadow;
    bit [7:0] ball_hit_cnt = 0;

    wire signed [9:0] pixel_x_shifted8 = pixel_x + 8;
    wire signed [9:0] pixel_x_shifted6 = pixel_x + 6;  // for shadow
    wire signed [9:0] pixel_y_shiftedM5 = pixel_y - 5;
    wire signed [9:0] pixel_y_shiftedM8 = pixel_y - 8;  // for shadow

    character_rom crom (
        .number(pixel_x > 128 ? right_player_score : left_player_score),
        .line  (pixel_y_shiftedM5[4:2]),
        .charline
    );

    character_rom crom_shadow (
        .number(pixel_x > 128 ? right_player_score : left_player_score),
        .line(pixel_y_shiftedM8[4:2]),
        .charline(charline_shadow)
    );


    always_comb begin
        if (ball.x > 128) begin
            paddle_collider_top = paddle1_frame_latched_val - PaddleHalfHeight;
            paddle_collider_bottom = paddle1_frame_latched_val + PaddleHalfHeight;
            // as >>>4 divides by 16, I'm adding 8 here for proper rounding
            paddle_collision_force_d = (ball.y - paddle1_frame_latched_val);
        end else begin
            paddle_collider_top = paddle0_frame_latched_val - PaddleHalfHeight;
            paddle_collider_bottom = paddle0_frame_latched_val + PaddleHalfHeight;
            // as >>>4 divides by 16, I'm adding 8 here for proper rounding
            paddle_collision_force_d = (ball.y - paddle0_frame_latched_val);
        end

    end

    always_comb begin
        next_ball_speed_x = 2;
        if (ball_hit_cnt > 0) next_ball_speed_x = 3;
        if (ball_hit_cnt > 1) next_ball_speed_x = 4;
        if (ball_hit_cnt > 2) next_ball_speed_x = 5;
        if (ball_hit_cnt > 3) next_ball_speed_x = 6;
        if (ball_hit_cnt > 10) next_ball_speed_x = 7;

        next_ball_speed_y = ((paddle_collision_force_q * next_ball_speed_x) + (1 << 3)) >>> 4;

        // limit ball to 45 degree angle
        if (next_ball_speed_y > next_ball_speed_x) next_ball_speed_y = next_ball_speed_x;
        else if (next_ball_speed_y < -next_ball_speed_x) next_ball_speed_y = -next_ball_speed_x;

        if (ball_speed_x > 0) next_ball_speed_x = -next_ball_speed_x;

    end

    always_ff @(posedge clk) begin
        // We need to sync the game logic to the frames. At first I didn't want to do this
        // to be independent of 60 and 50 Hz. But it simply doesn't work as screen tearing or jitter will occur.
        if (newframe) begin
            ball.x <= ball.x + ball_speed_x;
            ball.y <= ball.y + ball_speed_y;

            // paddle collision
            if (ball.y >= paddle_collider_top && ball.y <= paddle_collider_bottom) begin
                if (ball.x > (255 - 20) && ball.x < (255 - 12) && ball_speed_x > 0) begin
                    ball_speed_x <= next_ball_speed_x;
                    ball_speed_y <= next_ball_speed_y;
                    if (ball_hit_cnt != 255) ball_hit_cnt <= ball_hit_cnt + 1;
                end
                if (ball.x < 20 && ball.x > 12 && ball_speed_x < 0) begin
                    ball_speed_x <= next_ball_speed_x;
                    ball_speed_y <= next_ball_speed_y;
                    if (ball_hit_cnt != 255) ball_hit_cnt <= ball_hit_cnt + 1;
                end
            end

            // vertical collision
            if (ball.y < BallHalfHeight && ball_speed_y < 0) ball_speed_y <= -ball_speed_y;
            if (ball.y > last_row - BallHalfHeight && ball_speed_y > 0)
                ball_speed_y <= -ball_speed_y;

            // ball out of bounds
            if (ball.x > 255 + 5) left_player_scored <= 1;
            if (ball.x < -5) right_player_scored <= 1;

        end

        if (left_player_scored || right_player_scored) begin
            left_player_scored <= 0;
            right_player_scored <= 0;
            left_player_scored_q <= left_player_scored;
            restart_game <= 1;

            if (left_player_scored) left_player_score <= left_player_score + 1;
            else right_player_score <= right_player_score + 1;
        end

        if (restart_game) begin
            restart_game <= 0;
            ball.x <= 128;
            ball.y <= 128;
            ball_hit_cnt <= 0;
            ball_speed_y <= 0;

            if (left_player_score == 10 || right_player_score == 10) begin
                ball_speed_x <= 0;
            end else begin
                ball_speed_x <= left_player_scored_q ? -1 : 1;
            end
        end

        if (reset) begin
            left_player_score <= 0;
            right_player_score <= 0;
            restart_game <= 1;
        end
    end

    bit left_paddle_shadow;
    bit right_paddle_shadow;
    bit ball_shadow;
    bit score_board;
    bit ball_blur1;
    bit ball_blur2;
    bit ball_white;
    bit left_paddle_white;
    bit right_paddle_white;
    bit center_line;
    bit left_paddle_color;
    bit right_paddle_color;
    bit borders;
    bit score_board_shadow;
    bit ball_red;

    // calculate as much in parallel as possible
    always_ff @(posedge clk) begin
        left_paddle_shadow <= (pixel_x >= 8 + ShadowX && pixel_x <= 17 + ShadowX &&
                  pixel_y < paddle0_frame_latched_val+PaddleHalfHeight+4 &&
                  pixel_y > paddle0_frame_latched_val-PaddleHalfHeight+4);

        right_paddle_shadow <= (pixel_x >= 255-17 + ShadowX && pixel_x <= 255-8 + ShadowX &&
                  pixel_y < paddle1_frame_latched_val+PaddleHalfHeight + ShadowY &&
                  pixel_y > paddle1_frame_latched_val-PaddleHalfHeight + ShadowY);

        ball_shadow <= (pixel_y > ball.y - BallHalfHeight + 3 && pixel_y < ball.y + BallHalfHeight + 3 &&
                    pixel_x >= ball.x - BallHalfWidth + 2 && pixel_x <= ball.x + BallHalfWidth + 2);

        score_board <= charline[pixel_x_shifted8[3:1]] &&
                        (pixel_x_shifted8[9:4] == 9 || pixel_x_shifted8[9:4] == 7) &&
                        pixel_y_shiftedM5[9:5]==0;
        score_board_shadow <= charline_shadow[pixel_x_shifted6[3:1]] &&
                                (pixel_x_shifted6[9:4] == 9 || pixel_x_shifted6[9:4] == 7) &&
                                pixel_y_shiftedM8[9:5]==0;

        ball_blur1 <= (pixel_y > ball_delay1.y - BallHalfHeight && pixel_y < ball_delay1.y + BallHalfHeight &&
                    pixel_x >= ball_delay1.x - BallHalfWidth && pixel_x <= ball_delay1.x + BallHalfWidth );
        ball_blur2 <= (pixel_y > ball_delay2.y - BallHalfHeight && pixel_y < ball_delay2.y + BallHalfHeight &&
                    pixel_x >= ball_delay2.x - BallHalfWidth && pixel_x <= ball_delay2.x + BallHalfWidth );
        ball_white <= (pixel_y > ball.y - BallHalfHeight && pixel_y < ball.y + BallHalfHeight &&
                pixel_x >= ball.x - BallHalfWidth && pixel_x <= ball.x + BallHalfWidth );

        ball_red <= ball_white && (ball_hit_cnt > 10);
        left_paddle_white <= (pixel_x >= 8 && pixel_x <= 17 &&
              pixel_y < paddle0_frame_latched_val + PaddleHalfHeight &&
              pixel_y > paddle0_frame_latched_val - PaddleHalfHeight );

        right_paddle_white <= (pixel_x >= 255 - 17 && pixel_x <= 255 - 8 &&
              pixel_y < paddle1_frame_latched_val + PaddleHalfHeight &&
              pixel_y > paddle1_frame_latched_val - PaddleHalfHeight );

        center_line <= (pixel_x >= 128 - 2 && pixel_x <= 128 + 2 && video_y[3]);

        left_paddle_color <= (pixel_x >= 10 && pixel_x <= 15 &&
              pixel_y < paddle0_frame_latched_val + (PaddleHalfHeight-2) &&
              pixel_y > paddle0_frame_latched_val - (PaddleHalfHeight-2));

        right_paddle_color <= (pixel_x >= 255 - 15 && pixel_x <= 255 - 10 &&
              pixel_y < paddle1_frame_latched_val + (PaddleHalfHeight-2) &&
              pixel_y > paddle1_frame_latched_val - (PaddleHalfHeight-2));

        borders <= (pixel_x == 0 || pixel_x == 255 || pixel_y == 0 || pixel_y == last_row);
    end

    always_comb begin
        ycbcr_out.y  = 0;
        ycbcr_out.cb = 0;
        ycbcr_out.cr = 0;

        if (visible_window) begin
            ycbcr_out = rgb_conv_out;
        end
    end

    // Visuals in order of overlap
    always_comb begin
        static bit [7:0] R;
        static bit [7:0] G;
        static bit [7:0] B;

        // Background colors
        if (pixel_x >= 128) begin
            R = 100 >> 1;
            G = 200 >> 1;
            B = 100 >> 1;
        end else begin
            R = 100 >> 1;
            G = 200 >> 1;
            B = 200 >> 1;
        end

        // Center line
        if (center_line) begin
            R = 230;
            G = 150;
            B = 0;
        end

        // Left paddle shadow
        if (left_paddle_shadow || right_paddle_shadow || ball_shadow || score_board_shadow) begin
            // mix 50% of background with 50% of black
            R = (R >> 1);
            G = (G >> 1);
            B = (B >> 1);
        end

        // Ball Blur Shadows
        if (ball_blur1) begin
            // mix 50% of background with 50% of white
            R = (R >> 1) + 128;
            G = (G >> 1) + 128;
            B = (B >> 1) + 128;
        end

        if (ball_blur2) begin
            // mix 75% of background with 25% of white
            R = (R >> 2) + (R >> 1) + 64;
            G = (G >> 2) + (G >> 1) + 64;
            B = (B >> 2) + (B >> 1) + 64;
        end

        // Ball, Borders, Scoreboard and paddle white
        if (ball_white || left_paddle_white || right_paddle_white || borders || score_board) begin
            R = 255;
            G = 255;
            B = 255;
        end

        // Left paddle inside
        if (left_paddle_color) begin
            R = 0;
            G = 255;
            B = 0;
        end

        // Right paddle inside
        if (right_paddle_color) begin
            R = 0;
            G = 255;
            B = 255;
        end

        // Right paddle inside
        if (ball_red) begin
            R = 255;
            G = 0;
            B = 0;
        end

        R_d = R;
        G_d = G;
        B_d = B;
    end
endmodule
