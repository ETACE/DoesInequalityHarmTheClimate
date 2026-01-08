# Sim properties
folder = "baseline"
simulation_months = 1020 + 80*12
burn_in_months = 1020
no_runs = 100
run_aggregation = []

# Include baseline
include("baseline_init.jl")

# Define experiments
experiments = Dict(
    "baseline" => Dict(),
)

# Data Collection
include("data_collection.jl")