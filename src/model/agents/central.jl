using CSV
using DataFrames
using Statistics

mutable struct CentralAgency
    tech_productivity::Float64
    money_energy::Float64
    money_dividends::Float64
    money_carbon_price::Float64
    money_bailouts::Float64
    carbon_price::Float64
    energy_consumption_cumulative::Float64
    current_emissions_wrt_budget::Float64
    cumulative_emissions_wrt_budget::Float64
    first_quintile::OrderedSet{Household}
    second_quintile::OrderedSet{Household}
    third_quintile::OrderedSet{Household}
    fourth_quintile::OrderedSet{Household}
    fifth_quintile::OrderedSet{Household}
    price_level::Float64
    inflation::Float64
    emissions_scaling::Float64
    unit_emissions_actual::Float64
end

function CentralAgency()
    return CentralAgency(1,0,0,0,0,0,0,0,0,OrderedSet{Household}(),OrderedSet{Household}(),OrderedSet{Household}(),OrderedSet{Household}(),OrderedSet{Household}(),0,0,0,0)
end

function calculate_inflation(model::ABM)
    total_units_sold = sum(map(f -> f.units_sold, model.firms))

    if total_units_sold > EPSILON
        new_price_level = sum(map(f -> f.units_sold / total_units_sold * f.price, model.firms))

        if model.central.price_level > EPSILON
            model.central.inflation = new_price_level / model.central.price_level - 1
        end

        model.central.price_level = new_price_level
    end
end

function productivity_growth(model::ABM)
    if model.year >= model.yearly_growth_start_year

        if model.yearly_growth_std > EPSILON
            growth_rate = (1 + rand(abmrng(model), Normal(model.yearly_growth_mean, model.yearly_growth_std))) ^ (1/MONTHS_IN_YEAR)
        else
            growth_rate = (1+model.yearly_growth_mean) ^(1/MONTHS_IN_YEAR)
        end

        model.central.tech_productivity = model.central.tech_productivity * growth_rate
    end

    calculate_unit_emissions(model)
end

function calculate_unit_emissions(model::ABM)
    if model.year >= model.decouple_energy_from_growth_year
        energy_per_unit = 1 / model.central.tech_productivity
    else
        energy_per_unit = 1
    end

    model.central.unit_emissions_actual = model.central.emissions_scaling * energy_per_unit
end

function set_carbon_price(model::ABM)
    if model.year < model.policy_start_year
        model.central.carbon_price = 0.0
    else
        model.central.carbon_price = model.central.carbon_price * (1+model.central.inflation)
        model.policy_increase = model.policy_increase * (1+model.central.inflation)

        model.price_dirty_energy = model.price_dirty_energy * (1+model.central.inflation)
        model.price_clean_energy = model.price_clean_energy * (1+model.central.inflation)

        if model.voting_rule == MAJORITY_VOTING
            median_policy_support = median(map(hh -> hh.policy_support, model.households))
        end

        if model.voting_rule == POWER_WEIGHTED_VOTING
            median_policy_support = weighted_median(map(hh -> (hh.policy_support, hh.voting_power), model.households))
        end

        if model.dictator_mode || median_policy_support >= 2/3
            model.central.carbon_price += model.policy_increase
        end

        if !model.dictator_mode
            if median_policy_support <= 1/3
                model.central.carbon_price -= model.policy_increase
            end
        end

    end

    model.central.carbon_price = max(0.0, model.central.carbon_price)

    @assert model.central.carbon_price > -EPSILON
end

function weighted_median(values_and_weights)
    combined = sort(collect(values_and_weights), by = x -> x[1])
    
    sorted_values = [x[1] for x in combined]
    sorted_weights = [x[2] for x in combined]
    cumulative_weights = cumsum(sorted_weights)
    total_weight = sum(sorted_weights)
    
    median_index = findfirst(cumulative_weights .>= total_weight / 2)
    
    return sorted_values[median_index]
end

function distribute_transfers(model::ABM)
    total_dividends = model.central.money_dividends
    total_energy_dividends = model.central.money_energy
    total_earnings_carbon = model.central.money_carbon_price
    total_bailouts = model.central.money_bailouts 
    total_wealth = sum(map(hh -> hh.money, model.households))
    total_labor_income = sum(map(hh -> hh.labor_income, model.households))
    if model.preferences == "increasing"
        weighted_total_labor_income = sum(map(hh -> hh.labor_income^0.92, model.households))
    elseif model.preferences == "decreasing"
        weighted_total_labor_income = sum(map(hh -> 207.851/ (1 + exp(-2.0068 * (log(hh.labor_income + 1) - 5.5515))) , model.households))
    end
    total_dirty_consumption = sum(map(hh -> hh.dirty_consumption, model.households))

    @assert total_dividends > -EPSILON
    @assert total_energy_dividends > -EPSILON
    @assert total_earnings_carbon > -EPSILON
    @assert total_wealth > -EPSILON

    if total_dividends > 0 || total_energy_dividends > 0 || total_earnings_carbon > 0 || total_bailouts > 0
        for hh in model.households
            # Dividends
            div = hh.money / total_wealth * total_dividends
            div_energy = hh.money / total_wealth * total_energy_dividends

            # Bailouts
            share_bailouts = hh.money / total_wealth * total_bailouts

            # Carbon Price Earnings
            if model.redistribution == "progressive"
                lumpsum = total_earnings_carbon / length(model.households)
                model.central.money_carbon_price -= lumpsum
                hh.money += div + lumpsum + div_energy + share_bailouts
                hh.transfer_income = lumpsum
            elseif model.redistribution == "regressive"
                income_tax = total_earnings_carbon / total_labor_income - 1
                model.central.money_carbon_price -= (1+income_tax)*hh.labor_income
                hh.money += div + (1+income_tax)*hh.labor_income + div_energy + share_bailouts
                hh.transfer_income = (1+income_tax)*hh.labor_income
            elseif model.redistribution == "neutral"

                if model.preferences == "increasing"
                    transfer = (hh.labor_income^0.92)/weighted_total_labor_income * total_earnings_carbon
                elseif model.preferences == "constant"
                    transfer = hh.labor_income/total_labor_income * total_earnings_carbon
                elseif model.preferences == "decreasing"
                    transfer = (207.851/ (1 + exp(-2.0068 * (log(hh.labor_income + 1) - 5.5515)))) / weighted_total_labor_income * total_earnings_carbon
                end
                model.central.money_carbon_price -= transfer
                hh.money += div + transfer + div_energy + share_bailouts
                hh.transfer_income = transfer
            end
            
            # Transfer Money to Households
            model.central.money_dividends -= div
            model.central.money_energy -= div_energy
            model.central.money_bailouts -= share_bailouts
            
            hh.dividend_income = div
            hh.energy_income = div_energy

            @assert hh.money > -EPSILON
        end
    end

    @assert model.central.money_energy > -EPSILON
    @assert model.central.money_energy < EPSILON
    @assert model.central.money_dividends > -EPSILON
    @assert model.central.money_dividends < EPSILON
    @assert model.central.money_carbon_price > -EPSILON
    @assert model.central.money_carbon_price < EPSILON
    @assert model.central.money_bailouts > -EPSILON
    @assert model.central.money_bailouts < EPSILON
end

function calculate_emissions(model::ABM)
    # Sum Energy Consumption Over Year
    model.central.energy_consumption_cumulative += sum(map(f -> f.energy_used, model.dirty_firms))

    @assert !isnan(model.central.energy_consumption_cumulative)

    
    model.central.emissions_scaling = model.exogenous_emissions_scaling_param
   

    @assert !isnan(model.central.emissions_scaling)

    calculate_unit_emissions(model)

    # Reset at End of the Year, Calculate Emissions with Respect to Budget
    if model.month_in_year == MONTHS_IN_YEAR
        model.central.current_emissions_wrt_budget = model.central.emissions_scaling * model.central.energy_consumption_cumulative

        if model.year >= model.climate_start_year
            model.central.cumulative_emissions_wrt_budget += model.central.current_emissions_wrt_budget
        end

        model.central.energy_consumption_cumulative = 0
    end
end

function determine_consumption_types(model::ABM)
    if model.year == model.lambda_fix_year && (model.month_in_year == MONTHS_IN_YEAR)
        
        if model.preferences == "increasing"
        lambdas = CSV.read("../data/increasing_preferences.csv", DataFrame)
        elseif model.preferences == "constant"
            lambdas = CSV.read("../data/constant_preferences.csv", DataFrame)
        elseif model.preferences == "decreasing"
            lambdas = CSV.read("../data/decreasing_preferences.csv", DataFrame)
        end

        if !model.preference_effect && !model.income_effect
            for hh in model.households
                hh.consumption_type = lambdas[argmin(abs.(lambdas[:, 1] .- hh.productivity)), 2]
            end
        elseif model.preference_effect
            for hh in model.households
                sort!(lambdas, [2])
                part = floor(length(lambdas[:,2])/5)
                rand_number = Int(rand((hh.quintile-1)*part+1:hh.quintile*part))
                hh.consumption_type = lambdas[rand_number, 2]
            end
        elseif model.income_effect
            for hh in model.households
                hh.consumption_type = mean(lambdas[:, 2])
            end
        end
        
    end
end