# Sim properties
folder = "inequality"
simulation_months = 1020 + 80*12
burn_in_months = 1020
no_runs = 100
run_aggregation = []

# Include baseline
include("baseline_init.jl")

# Define experiments
experiments = Dict(
    "gini_0.0" => Dict(:Gini => 0.0),
    "gini_0.1" => Dict(:Gini => 0.1),
    "gini_0.2" => Dict(:Gini => 0.2),
    "gini_0.3" => Dict(:Gini => 0.3),
    "gini_0.5" => Dict(:Gini => 0.5),
    "gini_0.6" => Dict(:Gini => 0.6)
)

# Data Collection
include("data_collection.jl")