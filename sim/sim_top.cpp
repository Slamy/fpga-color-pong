// Include common routines
#include <verilated.h>
#include <verilated_vcd_c.h>

// Include model header, generated from Verilating "top.v"
#include "Vtop_color_pong.h"
#include "Vtop_color_pong___024root.h"

#include <cstdlib>
#include <cstdio>
#include <png.h>

const int width = 0x0c00U;
const int lines = 630 * 2;
const int stretch = 1;
const int height = lines * stretch;
vluint64_t sim_time = 0;

int main(int argc, char **argv)
{
  // Initialize Verilators variables
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);

  VerilatedVcdC m_trace;
  Vtop_color_pong dut;

  dut.trace(&m_trace, 5);
  m_trace.open("waveform.vcd");

  dut.switch1 = 1;

  for (int i = 0; i < 500000; i++)
  {
    dut.rootp->top_color_pong__DOT__clk = 0;
    dut.eval();
    m_trace.dump(sim_time);
    sim_time++;
    dut.rootp->top_color_pong__DOT__clk = 1;
    dut.eval();
    m_trace.dump(sim_time);
    sim_time++;
  }

  return 0;
}
