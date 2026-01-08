# Sim properties
folder = "income_preference_effect"
simulation_months = 1020 + 80*12
burn_in_months = 1020
no_runs = 100
run_aggregation = []

# Include baseline
include("baseline_init.jl")

# Define experiments
experiments = Dict(
    "income_effect" => Dict(:income_effect => true, :Gini => 0.4),
    "preference_effect" => Dict(:preference_effect => true, :Gini => 0.0)
)

# Data Collection
include("data_collection.jl")