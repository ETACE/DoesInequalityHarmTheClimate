# Sim properties
folder = "economic_channel"
simulation_months = 1020 + 80*12
burn_in_months = 1020
no_runs = 100
run_aggregation = []

# Include baseline
include("baseline_init.jl")

# Define experiments
experiments = Dict(
    "constant" => Dict(:preferences => "constant"),
    "decreasing" => Dict(:preferences => "decreasing"),
)

# Data Collection
include("data_collection.jl")