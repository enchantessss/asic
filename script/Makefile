UVM_VER           = uvm-1.2
UVM_HOME          = /home/patrick/uvm/$(UVM_VER)
UVM_VERBOSITY     = UVM_MEDIUM
DESIGN_PATH       = /home/patrick/asic
RTL_PATH          = $(DESIGN_PATH)/rtl
ENV_PATH          = $(DESIGN_PATH)/sv
FILE_LIST_PATH    = $(DESIGN_PATH)/filelist
TEST              = fifo_test
#EXTRA_VCS_RUNOPTS = -cm line+cond+fsm+branch+tgl -cm_dir ./coverage.vdb

VCS               = vcs -full64
VCS_OPTS          = -sverilog -debug_access +vpi -timescale=1ns/1ns

build:
	$(VCS) $(VCS_OPTS) -ntb_opts uvm \
	+define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR \
	+incdir+$(UVM_HOME)/src \
	$(UVM_HOME)/src/uvm.sv \
	$(EXTRA_VCS_RUNOPTS) \
	+vcsd \
	+incdir+$(RTL_PATH) \
	+incdir+$(ENV_PATH) \
	-f $(FILE_LIST_PATH)/fifo_filelist.f

sim:
	./simv +UVM_VERBOSITY=$(UVM_VERBOSITY) \
	+UVM_TESTNAME=$(TEST) +UVM_TR_RECORD +UVM_LOG_RECORD \
	+verbose=1 +ntb_random_seed=244 -l vcs.log

all: build sim

clean:
	@echo cleaning old simulation files and libraries...
	@ -$(RM) -rf csrc* DVEfiles simv* ucli* work *.bak *.log *.vpd transcript \
	waves.shm *.wlf mylib lib *.vstf .restart* \
	urgReport *.so vc_hdrs.h

# EOF

