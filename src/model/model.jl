EPSILON = 10^-6
DAYS_IN_MONTH = 21
MONTHS_IN_YEAR = 12

using Agents, OrderedCollections

include("logging.jl")
include("agents/household.jl")
include("agents/firm.jl")
include("agents/central.jl")

function household_scheduler_randomly(model::ABM)
    return shuffle(abmrng(model), model.households)
end

function households(f, model::ABM)
    for hh in household_scheduler_randomly(model)
        f(hh, model)
    end
end

function firm_scheduler_randomly(model::ABM)
    return shuffle(abmrng(model), model.firms)
end

function firms(f, model::ABM)
    for firm in firm_scheduler_randomly(model)
        f(firm, model)
    end
end

function model_day!(model)
    # Assure Model Consistency 
    assert_model_consistency(model)

    model.day_in_month += 1
    if model.day_in_month == DAYS_IN_MONTH+1
        model.day_in_month = 1
        model.month_in_year+=1

        if model.month_in_year==MONTHS_IN_YEAR+1
            model.month_in_year = 1
            model.year +=1
        end
    end

    if abmtime(model) % 1000 == 0
        println(abmtime(model))
    end

    if model.day_in_month == 1
        productivity_growth(model)

        calculate_inflation(model)

        # Beginning of Month Firm
        firms(model) do firm, model
            production_planning(firm, model)
        end

        # Beginning of Month Household
        households(model) do hh, model
            consumption_planning(hh, model)
            supplier_search(hh, model)
            job_search(hh, model)
        end
    end

    households(model) do hh, model
        consumption(hh, model)
    end

    firms(model) do firm, model
        production(firm, model)
    end

    if model.day_in_month == DAYS_IN_MONTH
        # End of Month Firm
        firms(model) do firm, model
            payments(firm, model)
        end

        distribute_transfers(model)

        calculate_emissions(model)

        determine_consumption_types(model)

        # End of Month Household
        households(model) do hh, model
            adjust_reservation_wage(hh, model)
        end
    end

    if model.day_in_month == DAYS_IN_MONTH && model.month_in_year == MONTHS_IN_YEAR        

        firms(model) do firm, model
            yearly_price(firm)
        end

        # Climate Policy
        households(model) do hh, model
            yearly_utility_level(hh, model)
        end

        if model.year >= model.climate_start_year
            households(model) do hh, model
                adjust_policy_support(hh, model)
            end

        end

        if !model.no_policy_mode set_carbon_price(model) end
    end
end

function assert_model_consistency(model)
    global money1
    money = 0

    for hh in model.households
        if !hh.employed
            @assert hh.employer_id == 0
        else
            @assert hh in model[hh.employer_id].employees
        end

        money+=hh.money
    end

    for firm in model.firms
        for empl in firm.employees
            @assert empl.employed && empl.employer_id == firm.id
        end

        money+=firm.money
    end

    if abmtime(model) == 0
        money1 = money
    else
        if model.day_in_month == 1
            money1 = money1 * (1+model.interest_rate) ^ (1/MONTHS_IN_YEAR)
        end
        
        @assert abs(money1 - money) < EPSILON
    end
end
