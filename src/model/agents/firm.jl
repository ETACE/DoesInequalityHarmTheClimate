const DIRTY = 1
const CLEAN = 2

@agent struct Firm(NoSpaceAgent)
    type::Int64 = DIRTY
    money::Float64 = 0
    inventory::Float64 = 0
    production::Float64 = 0
    marginal_costs::Float64 = 0
    price::Float64 = 0
    price_list_monthly::Array{Float64, 1} = []
    price_list_yearly::Array{Float64, 1} = []
    wage::Float64 = 0
    employees::OrderedSet{Household} = OrderedSet{Household}()
    hiring::Bool = false
    recent_demand::Float64 = 0
    positions_filled_months::Int64 = 0
    bankrupt::Bool = false
    energy_used::Float64 = 0
    units_sold = 0
end

function production_planning(firm::Firm, model::ABM)
    @model_log firm "wage_prob" "wage1" firm.wage

    # Collect Interest
    firm.money = firm.money * (1+model.interest_rate)^(1/MONTHS_IN_YEAR)

    # Adjust Wage
    if firm.hiring
        firm.positions_filled_months = 0
        firm.wage = firm.wage * (1+rand(abmrng(model))*model.delta)
    else
        firm.positions_filled_months += 1

        if firm.positions_filled_months > model.gamma
            firm.wage = firm.wage * (1-rand(abmrng(model))*model.delta)
        end
    end

    @model_log firm "wage_prob" "wage2" firm.wage
    @assert firm.wage > -EPSILON

    # Reset
    firm.hiring = false

    inventory_upper = model.phi_inv_upper * firm.recent_demand
    inventory_lower = model.phi_inv_lower * firm.recent_demand

    price_upper = model.phi_price_upper * firm.marginal_costs
    price_lower = model.phi_price_lower * firm.marginal_costs

    if firm.inventory < inventory_lower
        # Hire Worker
        firm.hiring = true

        # Consider Price Increase
        if firm.price < price_upper && rand(abmrng(model)) < model.theta
            firm.price = firm.price * (1+rand(abmrng(model))*model.upsilon)
        end
    end

    if firm.inventory > inventory_upper && length(firm.employees) > 0
        # Fire Some Employees
        sum_prod = sum(map(e -> e.productivity, collect(firm.employees)))
        sum_fired = 0

        while sum_fired < model.fire_share_of_productivity * sum_prod
            
            unlucky = rand_worker_by_prod(model.firing_intensity, collect(firm.employees), model)
            
            unlucky.employed = false
            unlucky.employer_id = 0
            delete!(firm.employees, unlucky)
            sum_fired += unlucky.productivity
        end

        # Consider Price Decrease
        if firm.price > price_lower && rand(abmrng(model)) < model.theta
            firm.price = firm.price * (1-rand(abmrng(model))*model.upsilon)
        end
    end

    # Make sure Price is above Marginal Costs
    firm.price = max(price_lower, firm.price)

    # Add Price to Price List
    append!(firm.price_list_monthly, [firm.price])

    # Reset
    firm.production = 0
    firm.recent_demand = 0
    firm.units_sold = 0
end

function rand_worker_by_prod(intensity, employees, model)
    denom = sum(map(e -> intensity*e.productivity, employees))
    weights = map(e -> intensity*e.productivity / denom, employees)

    return sample(abmrng(model), employees, Weights(weights))
end

function production(firm::Firm, model::ABM)
    daily_production = model.central.tech_productivity * sum(map(e -> e.productivity, collect(firm.employees)))
    
    firm.production += daily_production
    firm.inventory += daily_production
end

function payments(firm::Firm, model::ABM)
    # Wages
    sum_labor_productivities = sum(map(e -> e.productivity, collect(firm.employees)))
    labor_costs = sum_labor_productivities * firm.wage

    @assert !isnan(sum_labor_productivities)

    # Energy Costs and Costs for Emitting CO2
    if model.year >= model.decouple_energy_from_growth_year
        firm.energy_used = sum_labor_productivities * DAYS_IN_MONTH
    else
        firm.energy_used = model.central.tech_productivity * sum_labor_productivities * DAYS_IN_MONTH
    end

    if firm.type == DIRTY
        energy_costs = firm.energy_used * model.price_dirty_energy
        carbon_costs = firm.energy_used * model.central.carbon_price
    end

    if firm.type == CLEAN
        energy_costs = firm.energy_used * model.price_clean_energy
        carbon_costs = 0.0
    end

    # Calculate Marginal Costs
    if labor_costs > EPSILON && firm.production > EPSILON
        firm.marginal_costs = (labor_costs + carbon_costs + energy_costs) / firm.production
    end

    # Pay Carbon Price
    if carbon_costs < firm.money
        firm.money -= carbon_costs
        model.central.money_carbon_price += carbon_costs
        firm.bankrupt = false
    else
        model.central.money_carbon_price += firm.money
        firm.money = 0
        firm.bankrupt = true
    end

    # Pay Energy Costs
    if energy_costs < firm.money
        firm.money -= energy_costs
        model.central.money_energy += energy_costs
        firm.bankrupt = false
    else
        model.central.money_energy += firm.money
        firm.money = 0
        firm.bankrupt = true
    end

    # If Illiquid Pay Employees Less
    if labor_costs > firm.money && length(firm.employees) > 0
        factor = firm.money / labor_costs
        firm.bankrupt = true
    else
        factor = 1
        firm.bankrupt = false
    end

    # Do not Cut Wage Payments if Firm Will Be Bailed Out
    if firm.bankrupt && model.bailout_firms
        factor = 1
    end

    @assert factor > -EPSILON

    # Pay Wages
    for hh in firm.employees
        eff_wage = hh.productivity * firm.wage * factor

        firm.money -= eff_wage
        hh.money += eff_wage
        hh.labor_income = eff_wage

        @assert hh.money > -EPSILON
    end

    buffer = model.xi * (labor_costs + energy_costs + carbon_costs)

    # Dividends
    dividends = firm.money - buffer
    if dividends > 0
        firm.money -= dividends
        model.central.money_dividends += dividends
    end

    # Bailout / Bankruptcy Resolution Procedure
    if firm.bankrupt && model.bailout_firms
        # Bailout Firm
        bailout = buffer - firm.money

        firm.money += bailout
        model.central.money_bailouts -= bailout

        sum_prod = sum(map(e -> e.productivity, collect(firm.employees)))
        sum_fired = 0

        # Fire Some Workers
        while sum_fired < model.fire_share_of_productivity * sum_prod
            unlucky = rand(abmrng(model), firm.employees)
            unlucky.employed = false
            unlucky.employer_id = 0
            delete!(firm.employees, unlucky)
            sum_fired += unlucky.productivity
        end

        # Reset 
        if firm.type == DIRTY
            firm.wage = median(map(f -> f.wage, model.dirty_firms))
            firm.price = median(map(f -> f.price, model.dirty_firms))
        end

        if firm.type == CLEAN
            firm.wage = median(map(f -> f.wage, model.clean_firms))
            firm.price = median(map(f -> f.price, model.clean_firms))
        end
    end

    @assert firm.money > -EPSILON
    @assert firm.wage > -EPSILON
end

function yearly_price(firm::Firm)
    # Calculate Average Price
    append!(firm.price_list_yearly, mean(firm.price_list_monthly[1:MONTHS_IN_YEAR]))

    # Reset 
    firm.price_list_monthly = []
end