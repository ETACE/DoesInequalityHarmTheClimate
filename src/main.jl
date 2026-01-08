include("model/model.jl")
include("experiments/baseline_init.jl")

# Initialization
model = initialize(baseline_properties)

include("experiments/data_collection.jl")

model_log_file = open("model_log.txt", "w")
model_logging(false)
model_logger_target(model_log_file)
model_log_agent(Household)
model_log_agent(Firm)
model_log_category("consumption_planning")
model_log_category("supplier_search")
model_log_category("job_search")
model_log_category("consumption")
model_log_category("adjust_reservation_wage")
model_log_category("wage_prob")

n_iterations = 10000

# Running
@time agent_data, model_data = run!(model, n_iterations; mdata = mdata, when=when_collect, showprogress=false)