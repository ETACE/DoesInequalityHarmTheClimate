using Random, StatsBase, Distributions, DelimitedFiles

const MAJORITY_VOTING = 1
const POWER_WEIGHTED_VOTING = 2

baseline_properties = Dict(
    # Economic Module
    :n_households => 2000,
    :n_dirty_firms => 100,
    :n_clean_firms => 100,
    :alpha => 0.9,
    :n => 7,
    :psi_price => 0.25,
    :psi_quant => 0.25,
    :gamma => 24,
    :delta => 0.019,
    :phi_inv_upper => 1.0,
    :phi_inv_lower => 0.25,
    :phi_price_upper => 1.15,
    :phi_price_lower => 1.025,
    :upsilon => 0.02,
    :theta => 0.75,
    :xi => 1.0,
    :fire_share_of_productivity => 0.05,
    :firing_intensity => 8,
    :init_price_dirty => 1.0,
    :init_price_clean => 1.0 + 0.5,
    :price_dirty_energy => 0.0,
    :price_clean_energy => 0.5,
    :sigma => 5,
    :yearly_growth_start_month => 0,
    :yearly_growth_start_year => 1,
    :yearly_growth_mean => 0.01,
    :yearly_growth_std => 0.01,
    :interest_rate => 0.01,
    :decouple_energy_from_growth_year => 85,
    :bailout_firms => true,
    :shape1beta => [10000,6,5,1.75,1.25,0.75,0.46],
    :shape2beta => [10,2,10,2.75,4.5,4,3],
    :mean_productivity => 0.35,

    # Consumption Preferences
    :preferences => "increasing",
    :beta_1 => 333.674,
    :beta_2 => -0.538,
    :mean_income_survey => 54,
    :lambda_fix_year => 60,
    :preference_effect => false,
    :income_effect => false,

    # Climate Module
    :exogenous_emissions_scaling_param => 0.04120963199641906,
    :climate_start_year => 85,
    :emission_path => nothing,
    :risk_aversion => 0.88,
    :loss_aversion => 2.25,
    :redistribution => "neutral",

    # Policy Module
    :a => 10,
    :internal_weight => 0.75,
    :policy_start_month => 85*12, # year 85, so 2020
    :policy_start_year => 85,
    :policy_increase => 0.05,
    :dictator_mode => false,
    :no_policy_mode => false,
    :voting_rule => MAJORITY_VOTING,

    # Global
    :Gini => 0.4,
	:day_in_month => 0,
    :month_in_year => 1,
    :year => 1,
    :households => Array{Household},
    :firms => Array{Firm},
    :dirty_firms => Array{Firm},
    :clean_firms => Array{Firm},
    :central => CentralAgency,
)

function initialize(properties)
    model = StandardABM(Union{Household, Firm}, model_step! = model_day!, properties = properties, warn = false)

    model.emission_path = CSV.read("../data/EmissionsUSA.csv", DataFrame)

    beta_dist = Beta(model.shape1beta[Int(model.Gini*10)+1], model.shape2beta[Int.(model.Gini*10)+1])
    samples = rand(abmrng(model), beta_dist, model.n_households)
    samples = samples * model.mean_productivity/mean(samples)
    samples = sort(samples)

    n_firms = model.n_dirty_firms + model.n_clean_firms

	init_tech = 0.4364

    mean_price = (model.init_price_dirty +  model.init_price_clean) / 2
    mean_price_energy = (model.price_dirty_energy + model.price_clean_energy) / 2

    hh_per_firms =  model.n_households / n_firms
    
    prod_per_worker = init_tech * model.mean_productivity * 21

    init_wage = (mean_price / 1.0725 - mean_price_energy) * prod_per_worker / model.mean_productivity

    model.central = CentralAgency()

    # Firms
    model.firms = Array{Firm, 1}()
    model.dirty_firms = Array{Firm, 1}()
    model.clean_firms = Array{Firm, 1}()

    for _ in 1:model.n_dirty_firms
        firm = add_agent!(Firm, model)

        firm.type = DIRTY
        firm.inventory = 0.5 * prod_per_worker * hh_per_firms
        firm.recent_demand = prod_per_worker * hh_per_firms
        firm.production = prod_per_worker * hh_per_firms
        firm.price = model.init_price_dirty
        firm.wage = init_wage
        firm.marginal_costs = (firm.wage * model.mean_productivity) / prod_per_worker + model.price_dirty_energy
        firm.money =  model.xi * (firm.wage * model.mean_productivity * hh_per_firms + firm.production * model.price_dirty_energy)

        push!(model.firms, firm)
        push!(model.dirty_firms, firm)
    end

    for _ in 1:model.n_clean_firms
        firm = add_agent!(Firm, model)

        firm.type = CLEAN
		firm.inventory = 0.5 * prod_per_worker * hh_per_firms
        firm.recent_demand = prod_per_worker * hh_per_firms
        firm.production = prod_per_worker * hh_per_firms
        firm.price = model.init_price_clean
        firm.wage = init_wage
        firm.marginal_costs = (firm.wage * model.mean_productivity) / prod_per_worker + model.price_clean_energy
        firm.money =  model.xi * (firm.wage * model.mean_productivity * hh_per_firms + firm.production * model.price_clean_energy)

        push!(model.firms, firm)
        push!(model.clean_firms, firm)
    end

    # Households 
    model.households = Array{Household, 1}()
    
    total_hh_money = (prod_per_worker*mean_price)^(1/model.alpha) * model.n_households
    total_hh_productivity = 0

    for i in 1:model.n_households
        hh = add_agent!(Household, model)

        hh.productivity = samples[i]
        total_hh_productivity += hh.productivity

        # Assign Quintile
        if i <= model.n_households/5
            hh.quintile = 1
            push!(model.central.first_quintile, hh)
        elseif i <= 2*model.n_households/5
            hh.quintile = 2
            push!(model.central.second_quintile, hh)
        elseif i <= 3*model.n_households/5
            hh.quintile = 3
            push!(model.central.third_quintile, hh)
        elseif i <= 4*model.n_households/5
            hh.quintile = 4
            push!(model.central.fourth_quintile, hh)
        else
            hh.quintile = 5
            push!(model.central.fifth_quintile, hh)
        end
      
        hh.employed = true

        employer = sample(abmrng(model), model.firms)
        hh.employer_id = employer.id
        if employer.type == DIRTY
            hh.dirty_employer = true
        else
            hh.clean_employer = true
        end
        push!(employer.employees, hh)

        for s in sample(abmrng(model), model.dirty_firms, model.n, replace=false)
            push!(hh.dirty_supplier_ids, s.id)
        end

        for s in sample(abmrng(model), model.clean_firms, model.n, replace=false)
            push!(hh.clean_supplier_ids, s.id)
        end

        hh.reservation_wage = init_wage
        hh.consumption_type = 0.5
        

       push!(model.households, hh)
    end

    for hh in model.households
        hh.money = hh.productivity / total_hh_productivity * total_hh_money
    end
    @assert abs(total_hh_money - sum(map(hh->hh.money, model.households))) < EPSILON

    model.central.tech_productivity = init_tech

    # Climate Policy
    model.central.carbon_price = 0.0

    return model
end
