# Create work library
vlib work
vmap work work

# Compile RTL files
echo ">>> Compiling RTL..."
vlog -work work ob_params.v
vlog -work work obi_calculator.v
vlog -work work vol_calculator.v
vlog -work work ob_processor.v

# Compile testbench
echo ">>> Compiling Testbench..."
vlog -work work tb_ob_processor.v

# Run simulation
echo ">>> Starting Simulation..."
vsim -c work.tb_ob_processor -do "run -all; quit"
