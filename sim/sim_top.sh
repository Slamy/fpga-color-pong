set -e

verilator --top-module top_color_pong \
    --trace --cc --assert --exe --build sim_top.cpp \
    ../fpga-composite-video/rtl/*.svh ../fpga-composite-video/rtl/*.sv  ../fpga-composite-video/rtl/filter/*.sv  ../fpga-composite-video/rtl/*.v \
    ../rtl/*.sv \
    -I../rtl  -I../fpga-composite-video/rtl/ ../fpga-composite-video/sim/*.sv \
    /usr/lib/x86_64-linux-gnu/libpng.so

./obj_dir/Vtop_color_pong

# gtkwave waveform.vcd
