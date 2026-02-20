#pragma once

template <class CModule> class CTestBench {
    protected:
    CModule * m_top;
    VerilatedVcdC * m_tfp;
    vluint64_t m_main_time;
    public:
    CTestBench(void) {
        m_main_time = 0;
        m_top = new CModule;
        #if VM_TRACE
        // Enable Trace
        Verilated::traceEverOn(true); // Verilator must compute traced signals
        #endif
    }
    virtual ~CTestBench(void) {
		delete m_top;
		m_main_time = NULL;
	}
    virtual void reset (void) {
      for (int i = 0; i < 10; i++) {
        m_top->rst_ni = 0;
        m_top->clk_i = 0;
        m_top->eval();
      #if VM_TRACE
        m_tfp->dump(static_cast<vluint64_t>(main_time * 2));
      #endif
        m_top->clk_i = 1;
        m_top->eval();
      #if VM_TRACE
        m_tfp->dump(static_cast<vluint64_t>(main_time * 2 + 1));
      #endif
        m_main_time++;
      }
      m_top->rst_ni = 1; 
    }
    /**
     * @brief Function to tick the DUT.
     * @param N number of clock ticks to increment.
     * @returns void.
     */
    virtual void tick(int N){
      for (int i = 0; i < N; i++) {
        m_top->clk_i = 1;
        m_top->eval();
      #if VM_TRACE
        m_tfp->dump(static_cast<vluint64_t>(main_time * 2));
      #endif
        m_top->clk_i = 0;
        m_top->eval();
      #if VM_TRACE
        m_tfp->dump(static_cast<vluint64_t>(main_time * 2 + 1));
      #endif
        m_main_time++;
      }
    }
    virtual bool done(void) { return (Verilated::gotFinish()); }
    // Open/create a trace file
	virtual	void open_trace(const char *dumpfile) {
        #if VM_TRACE
		if (!m_tfp) {
			m_tfp = new VerilatedVcdC;
			m_top->trace(m_tfp, 99);
			m_tfp->open(dumpfile);
		}
        #else
        m_tfp = nullptr;
        #endif

	}

	// Close a trace file
	virtual void close_trace(void) {
		if (!m_tfp) {
			m_tfp->close();
			m_tfp = NULL;
		}
	}
}