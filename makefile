# UVM Makefile
# 支持多种仿真工具：VCS, Xcelium, Questasim
# 支持回归测试、覆盖率收集和波形生成

# ==================== 用户配置区域 ====================
# 选择仿真工具: vcs, xcelium, questa
TOOL ?= vcs

# 测试用例名称（可通过命令行覆盖）
TEST ?= base_test
# 测试种子
SEED ?= 12345
# UVM 版本
UVM_VER ?= 1.2

# 覆盖率选项
COV ?= 0
COV_DIR ?= ./coverage
MERGE_COV ?= 0

# 波形选项
WAVE ?= 0
WAVE_DEPTH ?= all
WAVE_FORMAT ?= fsdb  # fsdb, vpd, shm, vcd

# 编译和仿真选项
COMP_OPTS ?=
RUN_OPTS ?=

# 回归测试配置
REGRESSION ?= 0
REGRESS_LIST ?= testlist.txt
SEED_LIST ?= 1 2 3 4 5
JOBS ?= 4

# 目录结构
RTL_DIR ?= ./rtl
TB_DIR ?= ./tb
WORK_DIR ?= ./work
LOG_DIR ?= ./log
REPORT_DIR ?= ./report

# 源文件列表
RTL_FILES ?= $(wildcard $(RTL_DIR)/*.v $(RTL_DIR)/*.sv)
TB_FILES ?= $(wildcard $(TB_DIR)/*.sv)
TOP_FILE ?= $(TB_DIR)/top.sv

# ==================== 工具相关配置 ====================
ifeq ($(TOOL),vcs)
  COMPILER = vcs
  SIMULATOR = simv
  UVM_HOME = $(shell find /home/tools/synopsys/vcs* -name "uvm-$(UVM_VER)" -type d 2>/dev/null | head -1)
  COMP_FLAGS = -full64 -sverilog +v2k -timescale=1ns/1ps \
               +define+UVM_$(subst .,_,$(UVM_VER)) \
               +incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm.sv \
               +incdir+$(TB_DIR) \
               +vcs+lic+wait \
               -debug_access+all \
               -kdb \
               -lca
  RUN_FLAGS = +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM \
              +UVM_NO_RELNOTES +ntb_random_seed=$(SEED)
  COV_FLAGS = -cm line+cond+fsm+tgl+branch+assert -cm_dir $(COV_DIR)/$(TEST)_$(SEED)
  WAVE_FLAGS = 
  
else ifeq ($(TOOL),xcelium)
  COMPILER = xrun
  SIMULATOR = xmsim
  UVM_HOME = $(shell find /home/tools/cadence/incisiv* -name "uvm-$(UVM_VER)" -type d 2>/dev/null | head -1)
  COMP_FLAGS = -64bit -sv -uvmhome $(UVM_HOME) \
               -uvm $(UVM_VER) \
               -incdir $(TB_DIR) \
               -access +rwc \
               -linedebug
  RUN_FLAGS = -testname $(TEST) \
              -svseed $(SEED) \
              -uvmverbose UVM_MEDIUM
  COV_FLAGS = -coverage all -covtest $(TEST)_$(SEED) -covoverwrite -covdir $(COV_DIR)/$(TEST)_$(SEED)
  WAVE_FLAGS = -input wave.tcl
  
else ifeq ($(TOOL),questa)
  COMPILER = vlog
  SIMULATOR = vsim
  UVM_HOME = $(shell find /home/tools/mentor/questasim* -name "uvm-$(UVM_VER)" -type d 2>/dev/null | head -1)
  COMP_FLAGS = -64 -sv -suppress 2286 \
               +incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm.sv \
               +incdir+$(TB_DIR) \
               -work $(WORK_DIR) \
               -lint -pedanticerrors
  RUN_FLAGS = -c -do "run -all; quit -f" \
              +UVM_TESTNAME=$(TEST) \
              +UVM_VERBOSITY=UVM_MEDIUM \
              -sv_seed $(SEED)
  COV_FLAGS = -coverage -covoverwrite -covdir $(COV_DIR)/$(TEST)_$(SEED) -covercode bstf
  WAVE_FLAGS = -do wave.do -wlf $(TEST)_$(SEED).wlf
  
else
  $(error Unsupported tool: $(TOOL). Please use vcs, xcelium, or questa)
endif

# ==================== 路径创建 ====================
DIRS = $(WORK_DIR) $(LOG_DIR) $(REPORT_DIR) $(COV_DIR)

$(DIRS):
	@mkdir -p $@

# ==================== 主要目标 ====================
.PHONY: all compile run clean clean_all regress cov_merge cov_report wave help

all: compile run

# 编译
compile: $(DIRS)
	@echo "========================================="
	@echo "Compiling with $(TOOL)..."
	@echo "UVM Home: $(UVM_HOME)"
	@echo "========================================="
	
ifeq ($(TOOL),vcs)
	$(COMPILER) $(COMP_FLAGS) $(COMP_OPTS) \
	  $(if $(filter 1,$(COV)),$(COV_FLAGS)) \
	  $(if $(filter 1,$(WAVE)),-debug_access+all) \
	  $(RTL_FILES) $(TB_FILES) $(TOP_FILE) \
	  -o $(SIMULATOR) \
	  -l $(LOG_DIR)/compile.log
	  
else ifeq ($(TOOL),xcelium)
	$(COMPILER) $(COMP_FLAGS) $(COMP_OPTS) \
	  $(if $(filter 1,$(COV)),$(COV_FLAGS)) \
	  $(RTL_FILES) $(TB_FILES) $(TOP_FILE) \
	  -l $(LOG_DIR)/compile.log
	  
else ifeq ($(TOOL),questa)
	vlib $(WORK_DIR)
	$(COMPILER) $(COMP_FLAGS) $(COMP_OPTS) \
	  $(RTL_FILES) $(TB_FILES) $(TOP_FILE) \
	  -l $(LOG_DIR)/compile.log
	vsim $(WORK_DIR).top -c -do "quit -f"  # Check elaboration
endif
	@echo "Compilation completed!"
	@echo "Log file: $(LOG_DIR)/compile.log"

# 运行仿真
run: compile
	@echo "========================================="
	@echo "Running test: $(TEST) with seed: $(SEED)"
	@echo "========================================="
	
	@mkdir -p $(LOG_DIR)/$(TEST)_$(SEED)
	
ifeq ($(TOOL),vcs)
	./$(SIMULATOR) $(RUN_FLAGS) $(RUN_OPTS) \
	  $(if $(filter 1,$(COV)),$(COV_FLAGS)) \
	  $(if $(filter 1,$(WAVE)),+fsdb+autoflush) \
	  -l $(LOG_DIR)/$(TEST)_$(SEED)/run.log
	  
else ifeq ($(TOOL),xcelium)
	$(SIMULATOR) $(RUN_FLAGS) $(RUN_OPTS) \
	  $(if $(filter 1,$(COV)),$(COV_FLAGS)) \
	  $(if $(filter 1,$(WAVE)),$(WAVE_FLAGS)) \
	  -l $(LOG_DIR)/$(TEST)_$(SEED)/run.log
	  
else ifeq ($(TOOL),questa)
	vsim $(WORK_DIR).top $(RUN_FLAGS) $(RUN_OPTS) \
	  $(if $(filter 1,$(COV)),$(COV_FLAGS)) \
	  $(if $(filter 1,$(WAVE)),$(WAVE_FLAGS)) \
	  -l $(LOG_DIR)/$(TEST)_$(SEED)/run.log
endif
	
	@echo "Simulation completed!"
	@echo "Log file: $(LOG_DIR)/$(TEST)_$(SEED)/run.log"
	
	# 检查UVM错误
	@if grep -q "UVM_ERROR" $(LOG_DIR)/$(TEST)_$(SEED)/run.log; then \
	  echo "UVM_ERROR found in simulation!"; \
	  exit 1; \
	fi
	@if grep -q "UVM_FATAL" $(LOG_DIR)/$(TEST)_$(SEED)/run.log; then \
	  echo "UVM_FATAL found in simulation!"; \
	  exit 1; \
	fi

# 回归测试
regress: $(DIRS)
	@echo "========================================="
	@echo "Starting regression with $(JOBS) parallel jobs"
	@echo "========================================="
	
	@if [ -f "$(REGRESS_LIST)" ]; then \
	  tests=$$(cat $(REGRESS_LIST)); \
	else \
	  tests="test1 test2 test3"; \
	  echo "Using default tests: $$tests"; \
	fi; \
	\
	for test in $$tests; do \
	  for seed in $(SEED_LIST); do \
	    echo "make run TEST=$$test SEED=$$seed COV=$(COV) WAVE=$(WAVE) &"; \
	    $(MAKE) run TEST=$$test SEED=$$seed COV=$(COV) WAVE=$(WAVE) -j1 & \
	  done; \
	done; \
	wait; \
	echo "Regression completed!"
	
	# 生成回归报告
	@echo "Generating regression report..."
	@python3 -c "
import os, glob, re
log_files = glob.glob('$(LOG_DIR)/*/*/run.log')
report_file = '$(REPORT_DIR)/regression_report.txt'
with open(report_file, 'w') as rf:
    rf.write('Regression Test Report\n')
    rf.write('='*50 + '\n')
    rf.write('%-30s %-10s %-10s %-15s\n' % ('Test Name', 'Seed', 'Status', 'Sim Time'))
    rf.write('-'*50 + '\n')
    
    for log_file in log_files:
        test_name = log_file.split('/')[-2].split('_')[0]
        seed = log_file.split('/')[-2].split('_')[1]
        status = 'PASS'
        sim_time = 'N/A'
        
        try:
            with open(log_file, 'r') as f:
                content = f.read()
                if 'UVM_ERROR' in content or 'UVM_FATAL' in content:
                    status = 'FAIL'
                time_match = re.search(r'Simulation time:?\s*([\d\.]+)\s*ns', content)
                if time_match:
                    sim_time = time_match.group(1) + ' ns'
        except:
            status = 'ERROR'
        
        rf.write('%-30s %-10s %-10s %-15s\n' % (test_name, seed, status, sim_time))
print('Regression report generated: $(REPORT_DIR)/regression_report.txt')
"

# 合并覆盖率（VCS专用）
cov_merge:
ifeq ($(TOOL),vcs)
	@echo "Merging coverage data..."
	urg -dir $(COV_DIR)/*.vdb \
	    -report $(REPORT_DIR)/coverage_report \
	    -format both \
	    -show tests \
	    -dbname $(COV_DIR)/merged/merged.vdb \
	    -log $(LOG_DIR)/urg.log
	@echo "Coverage merged to $(COV_DIR)/merged/merged.vdb"
else
	@echo "Coverage merge is currently only supported for VCS"
endif

# 生成覆盖率报告
cov_report: cov_merge
ifeq ($(TOOL),vcs)
	firefox $(REPORT_DIR)/coverage_report/html/index.html &
else ifeq ($(TOOL),xcelium)
	imc -execcmd "load -run $(COV_DIR)/*; report -summary -detail -out $(REPORT_DIR)/coverage.rpt; exit" &
else ifeq ($(TOOL),questa)
	vcover merge $(COV_DIR)/merged.ucdb $(COV_DIR)/*.ucdb
	vsim -c -do "coverage load $(COV_DIR)/merged.ucdb; coverage report -details -output $(REPORT_DIR)/coverage.rpt; quit" &
endif

# 生成波形
wave:
	@echo "Generating waveform configuration..."
	@echo 'add wave -r /*' > wave.do
	@echo 'run -all' >> wave.do
	@echo "Waveform configuration created: wave.do"

# 清理
clean:
	rm -rf $(SIMULATOR) $(SIMULATOR).daidir csrc DVEfiles *.vdb *.ucdb *.wlf *.fsdb *.vcd *.vpd transcript *.log
	rm -rf $(WORK_DIR) *.log

clean_all: clean
	rm -rf $(LOG_DIR) $(REPORT_DIR) $(COV_DIR) coverage_html_report
	find . -name "*.log" -delete
	find . -name "*.bak" -delete
	find . -name "*~" -delete

# 帮助信息
help:
	@echo "========================================="
	@echo "UVM Makefile Usage"
	@echo "========================================="
	@echo ""
	@echo "基本命令:"
	@echo "  make compile      - 编译设计"
	@echo "  make run          - 运行仿真 (TEST=test_name SEED=123)"
	@echo "  make all          - 编译并运行"
	@echo "  make regress      - 运行回归测试"
	@echo "  make cov_merge    - 合并覆盖率数据"
	@echo "  make cov_report   - 生成覆盖率报告"
	@echo "  make clean        - 清理临时文件"
	@echo "  make clean_all    - 清理所有生成文件"
	@echo "  make wave         - 生成波形配置"
	@echo ""
	@echo "配置选项:"
	@echo "  TOOL=vcs|xcelium|questa - 选择仿真工具 (默认: vcs)"
	@echo "  TEST=test_name          - 测试用例名称"
	@echo "  SEED=number             - 随机种子"
	@echo "  COV=1                   - 使能覆盖率收集"
	@echo "  WAVE=1                  - 使能波形生成"
	@echo "  JOBS=4                  - 并行任务数"
	@echo ""
	@echo "示例:"
	@echo "  make run TEST=my_test SEED=1 COV=1"
	@echo "  make regress TOOL=questa COV=1"
	@echo "  make all TEST=base_test WAVE=1"
	@echo ""
	@echo "当前配置:"
	@echo "  Tool: $(TOOL)"
	@echo "  UVM Version: $(UVM_VER)"
	@echo "  Coverage: $(COV)"
	@echo "  Waveform: $(WAVE)"
	@echo "========================================="
