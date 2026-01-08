using StatsBase

@agent struct Household(NoSpaceAgent)
    productivity::Float64 = 0
    money::Float64 = 0
    utility_cumulative::Float64 = 0
    utility_yearly_history::Array{Float64, 1} = []
    utility_hypothetical::Array{Float64, 1} = []
    employed::Bool = false
    employer_id::Int64 = -1
    dirty_employer::Bool = false
    clean_employer::Bool = false
    dirty_supplier_ids::OrderedSet{Int64} = OrderedSet{Int64}()
    clean_supplier_ids::OrderedSet{Int64} = OrderedSet{Int64}()
    bad_dirty_suppliers::OrderedDict{Int64, Float64} = OrderedDict{Int64, Float64}()
    bad_clean_suppliers::OrderedDict{Int64, Float64} = OrderedDict{Int64, Float64}()
    reservation_wage::Float64 = 0
    planned_daily_dirty_consumption::Float64 = 0
    planned_daily_clean_consumption::Float64 = 0
    dirty_consumption::Float64 = 0
    clean_consumption::Float64 = 0
    labor_income::Float64 = 0
    dividend_income::Float64 = 0
    energy_income::Float64 = 0
    transfer_income::Float64 = 0
    interest_income::Float64 = 0
    total_income_yearly::Float64 = 0
    income_yearly_history::Array{Float64, 1} = []
    quintile::Int64 = 0
    top_income_dist::Bool = false
    savings_rate::Float64 = 0
    policy_support::Float64 = 0
    voting_power::Float64 = 0
    consumption_type::Float64 = 0
    consumption_type_list::Array{Float64, 1} = fill(0.5,12)
    budget_list::Array{Float64, 1} = []
end

function consumption_planning(hh::Household, model::ABM)
    if hh.money < 0
        @model_log hh "consumption_planning" "money_set_to_zero" hh.money
        hh.money = 0
    end

    # Collect Interest
    hh.interest_income = hh.money * ((1+model.interest_rate)^(1/MONTHS_IN_YEAR)-1)
    hh.money += hh.interest_income

    # Calculate Mean Prices of Suppliers in Network
    mean_price_dirty = mean(map(id -> model[id].price, collect(hh.dirty_supplier_ids)))
    mean_price_clean = mean(map(id -> model[id].price, collect(hh.clean_supplier_ids)))

    # Calculate Price Level as Weighted Mean of Prices
    if hh.dirty_consumption + hh.clean_consumption > 0
        price_level = (hh.dirty_consumption * mean_price_dirty + hh.clean_consumption * mean_price_clean) / (hh.dirty_consumption + hh.clean_consumption)
    else
        price_level = (mean_price_dirty + mean_price_clean) / 2
    end

    # Calculate Monthly Budget
    budget = min(hh.money, (hh.money / price_level)^model.alpha * price_level)
    append!(hh.budget_list, budget)

    # Determine Planned Daily Consumption Levels
    hh.planned_daily_clean_consumption = ((hh.consumption_type/mean_price_clean)^model.sigma*budget/(hh.consumption_type^model.sigma*mean_price_clean^(1-model.sigma)+(1-hh.consumption_type)^model.sigma*mean_price_dirty^(1-model.sigma))) / DAYS_IN_MONTH
    hh.planned_daily_dirty_consumption = (((1-hh.consumption_type)/mean_price_dirty)^model.sigma*budget/(hh.consumption_type^model.sigma*mean_price_clean^(1-model.sigma)+(1-hh.consumption_type)^model.sigma*mean_price_dirty^(1-model.sigma))) / DAYS_IN_MONTH
    
    if hh.planned_daily_dirty_consumption < 0
        hh.planned_daily_dirty_consumption = 0
    end

    hh.total_income_yearly += hh.labor_income + hh.dividend_income + hh.transfer_income + hh.energy_income

    if hh.money > 0
        hh.savings_rate = 1 - budget / (hh.labor_income + hh.dividend_income + hh.transfer_income + hh.energy_income)
    end

    @assert hh.planned_daily_dirty_consumption > -EPSILON
    @assert hh.planned_daily_clean_consumption > -EPSILON

    @model_log hh "consumption_planning" "money" hh.money
    @model_log hh "consumption_planning" "mean_price_dirty" mean_price_dirty
    @model_log hh "consumption_planning" "mean_price_clean" mean_price_clean
    @model_log hh "consumption_planning" "planned_daily_dirty_consumption" hh.planned_daily_dirty_consumption
    @model_log hh "consumption_planning" "planned_daily_clean_consumption" hh.planned_daily_clean_consumption

    # Reset
    hh.dirty_consumption = 0
    hh.clean_consumption = 0
    hh.labor_income = 0
    hh.dividend_income = 0
    hh.transfer_income = 0
    hh.energy_income = 0
end

function supplier_search(hh::Household, model::ABM)
    supplier_search(hh, model, model.dirty_firms, hh.dirty_supplier_ids, hh.bad_dirty_suppliers)
    supplier_search(hh, model, model.clean_firms, hh.clean_supplier_ids, hh.bad_clean_suppliers)

    # Reset
    hh.bad_dirty_suppliers = OrderedDict{Int64, Float64}()
    hh.bad_clean_suppliers = OrderedDict{Int64, Float64}()

    @assert length(hh.dirty_supplier_ids) == model.n
    @assert length(hh.clean_supplier_ids) == model.n
end

function supplier_search(hh::Household, model::ABM, firms, supplier_ids, bad_suppliers)
    # Price Search
    if rand(abmrng(model)) < model.psi_price
        @model_log hh "supplier_search" "price_search"

        current_supplier_id = sample(abmrng(model), collect(supplier_ids))
        current_supplier = model[current_supplier_id]

        # Pick Other Supplier
        other_supplier_ids = Array{Int64, 1}()
        sizes = Array{Float64, 1}()

        sum = 0
        for supplier in firms
            if !(supplier.id in supplier_ids)
                push!(other_supplier_ids, supplier.id)
                push!(sizes, length(supplier.employees))
                sum += length(supplier.employees)
            end
        end

        if sum > 0
            probs = map((x)->x/sum, sizes)

            other_supplier_id = sample(abmrng(model), other_supplier_ids, Weights(probs))
            other_supplier = model[other_supplier_id]

            # Replace if Cheaper
            if other_supplier.price < 0.99 * current_supplier.price
                delete!(supplier_ids, current_supplier_id)
                delete!(bad_suppliers, current_supplier_id)
                push!(supplier_ids, other_supplier_id)
            end
        end
    end

    # Quantity Search
    if rand(abmrng(model)) < model.psi_quant && length(bad_suppliers) > 0
        @model_log hh "supplier_search" "quantity_search"

        bad_supplier_ids = Array{Int64, 1}()
        weights = Array{Float64, 1}()

        sum = 0
        for (supplier_id, weight) in bad_suppliers
            push!(bad_supplier_ids, supplier_id)
            push!(weights, weight)
            sum += weight
        end

        probs = map((x)->x/sum, weights)

        bad_supplier_id = sample(abmrng(model), bad_supplier_ids, Weights(probs))

        # Pick Random Other Supplier
        other_supplier = sample(abmrng(model), firms)
        while other_supplier.id in supplier_ids
            other_supplier = sample(abmrng(model), firms)
        end

        # Replace
        delete!(supplier_ids, bad_supplier_id)
        push!(supplier_ids, other_supplier.id)
    end
end

function job_search(hh::Household, model::ABM)
    @model_log hh "job_search" "employed" hh.employed

    if !hh.employed
        for _ in 1:5
            
            firm = rand(abmrng(model), model.firms)
            
            
            if firm.hiring && firm.wage > hh.reservation_wage
                firm.hiring = false
                push!(firm.employees, hh)

                hh.employed = true
                hh.employer_id = firm.id
                if firm.type == DIRTY
                    hh.dirty_employer = true
                    hh.clean_employer = false
                else
                    hh.clean_employer = true
                    hh.dirty_employer = false
                end
                hh.reservation_wage = firm.wage

                break
            end
        end
    else
        @model_log hh "job_search" "employer_id" hh.employer_id
        @model_log hh "job_search" "reservation_wage" hh.reservation_wage
        @model_log hh "job_search" "wage" model[hh.employer_id].wage

        employer = model[hh.employer_id]

        # Consider on-the-job-search
        search = false
        if employer.wage < hh.reservation_wage
            search  = true
        else
            if rand(abmrng(model)) < 0.1
                search = true
            end
        end

        @model_log hh "job_search" "search" search

        if search
            firm = rand(abmrng(model), model.firms)
            

            if firm.hiring && firm.wage > employer.wage
                # Quit
                delete!(employer.employees, hh)
                employer.hiring = true

                # Accept New Position
                firm.hiring = false
                push!(firm.employees, hh)

                hh.employer_id = firm.id
                if firm.type == DIRTY
                    hh.dirty_employer = true
                    hh.clean_employer = false
                else
                    hh.clean_employer = true
                    hh.dirty_employer = false
                end
                hh.reservation_wage = firm.wage
            end
        end
    end
end

function consumption(hh::Household, model::ABM)
    # Randomize Between Consuming Dirty First / Clean First
    if rand(abmrng(model)) < 0.5
        hh.dirty_consumption += consumption(hh, model, hh.dirty_supplier_ids, hh.planned_daily_dirty_consumption, hh.bad_dirty_suppliers)
        hh.clean_consumption += consumption(hh, model, hh.clean_supplier_ids, hh.planned_daily_clean_consumption, hh.bad_clean_suppliers)
    else
        hh.clean_consumption += consumption(hh, model, hh.clean_supplier_ids, hh.planned_daily_clean_consumption, hh.bad_clean_suppliers)
        hh.dirty_consumption += consumption(hh, model, hh.dirty_supplier_ids, hh.planned_daily_dirty_consumption, hh.bad_dirty_suppliers)
    end

    @assert hh.clean_consumption > -EPSILON
    @assert hh.dirty_consumption > -EPSILON

    if hh.dirty_consumption < 0
        hh.dirty_consumption = 0
    end
    if hh.clean_consumption < 0
        hh.clean_consumption = 0
    end

    hh.utility_cumulative += (hh.consumption_type*hh.clean_consumption^((model.sigma-1)/(model.sigma))+(1-hh.consumption_type)*hh.dirty_consumption^((model.sigma-1)/(model.sigma)))^(model.sigma/(model.sigma-1))
end

function consumption(hh::Household, model::ABM, supplier_ids, planned_daily_consumption, bad_suppliers)
    @model_log hh "consumption" "planned_daily_consumption" planned_daily_consumption
    @model_log hh "consumption" "money" hh.money

    remaining_demand = planned_daily_consumption
    consumption = 0.0
    
    n = 0
    for supplier_id in shuffle(abmrng(model), collect(supplier_ids))
        n+=1
        supplier = model[supplier_id]

        demand = min(remaining_demand, hh.money/supplier.price)

        supplier.recent_demand += demand

        # Adjust Demand if Inventory is Low
        if demand > supplier.inventory
            if supplier_id in keys(bad_suppliers)
                bad_suppliers[supplier_id] += (demand - supplier.inventory)
            else
                bad_suppliers[supplier_id] = (demand - supplier.inventory)
            end
            demand = supplier.inventory
        end

        # Transact
        revenue = demand * supplier.price
        hh.money -= revenue
        supplier.money += revenue
        supplier.inventory -= demand
        supplier.units_sold += demand
        consumption += demand
        remaining_demand -= demand

        @assert hh.money > -EPSILON
        @model_log hh "consumption" "units_bought" demand
        @model_log hh "consumption" "money" hh.money
        @model_log hh "consumption" "remaining_demand" remaining_demand     
        
        if remaining_demand < 0.05 * planned_daily_consumption || n == 7
            break
        end
    end

    return consumption
end

function yearly_utility_level(hh::Household, model::ABM)
    current_year = model.year
    last_year = current_year - 1

    append!(hh.utility_yearly_history, [hh.utility_cumulative])
    append!(hh.income_yearly_history, [hh.total_income_yearly])

    if current_year < model.policy_start_year
        append!(hh.utility_hypothetical, [hh.utility_yearly_history[current_year]])
    else
        append!(hh.utility_hypothetical, [hh.utility_yearly_history[current_year - 10]*(1+model.interest_rate)^10])
    end

    # Reset
    hh.utility_cumulative = 0
    hh.total_income_yearly = 0
end

function adjust_reservation_wage(hh::Household, model::ABM)
    if !hh.employed
        hh.reservation_wage = 0.9 * hh.reservation_wage
    else
        employer = model[hh.employer_id]
        hh.reservation_wage = max(hh.reservation_wage, employer.wage)
    end

    @model_log hh "adjust_reservation_wage" "new_reservation_wage" hh.reservation_wage
end

function adjust_policy_support(hh::Household, model::ABM)
    current_year = model.year

    # Material Wellbeing
    # Internal Comparison
    utility_new = hh.utility_yearly_history[current_year]

    if hh.utility_hypothetical[current_year] > 0.0
        utility_change = (utility_new - hh.utility_hypothetical[current_year])/min(hh.utility_hypothetical[current_year], utility_new) 
    else
        utility_change = 0
    end

    if utility_change >= 0
        internal_comparison = utility_change^model.risk_aversion
    else
        internal_comparison = (-model.loss_aversion) * (-utility_change)^model.risk_aversion
    end

    # External Comparison
    median_utility = median(map(hh -> hh.utility_yearly_history[current_year], model.households))

    utility_distance = (utility_new - median_utility)/min(utility_new, median_utility)

    if utility_distance >= 0
        external_comparison = utility_distance^model.risk_aversion
    else
        external_comparison = (-model.loss_aversion) * (-utility_distance)^model.risk_aversion
    end


    wellbeing_comparison = model.internal_weight * internal_comparison + (1-model.internal_weight) * external_comparison

    wellbeing = 1/(1+exp(-model.a * wellbeing_comparison))

    # Policy Effectiveness
    emissions_target = model.emission_path[current_year-model.climate_start_year+1,4]
    climate_change = (model.central.current_emissions_wrt_budget - emissions_target)/min(model.central.current_emissions_wrt_budget,emissions_target)

    effectiveness = 1/(1+exp(-model.a * climate_change))
    
    # Final Policy Support
    hh.policy_support = (effectiveness + wellbeing)/2
    
    hh.voting_power = hh.income_yearly_history[current_year] / sum(map(hh -> hh.income_yearly_history[current_year], model.households))

    @assert hh.policy_support >= 0.0
    @assert hh.policy_support <= 1.0
end


