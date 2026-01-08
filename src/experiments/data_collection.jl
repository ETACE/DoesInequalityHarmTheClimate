using Statistics

when_collect(model, s) = model.day_in_month == DAYS_IN_MONTH

### Economic Module ###

# Supply Side #
production(m) = sum(map(f -> f.production, m.firms))
energy_dirty(m) = sum(map(f -> f.energy_used, m.dirty_firms))
energy_clean(m) = sum(map(f -> f.energy_used, m.clean_firms))
production_dirty(m) = sum(map(f -> f.production, m.dirty_firms))
production_dirty_std(m) = std(map(f -> f.production, m.dirty_firms))
production_dirty_min(m) = minimum(map(f -> f.production, m.dirty_firms))
production_dirty_max(m) = maximum(map(f -> f.production, m.dirty_firms))
production_clean(m) = sum(map(f -> f.production, m.clean_firms))
production_clean_std(m) = std(map(f -> f.production, m.clean_firms))
production_clean_min(m) = minimum(map(f -> f.production, m.clean_firms))
production_clean_max(m) = maximum(map(f -> f.production, m.clean_firms))
inventories(m) = sum(map(f -> f.inventory, m.firms))
price_dirty(m) = mean(map(f -> f.price, m.dirty_firms))
price_clean(m) = mean(map(f -> f.price, m.clean_firms))
price_dirty_std(m) = std(map(f -> f.price, m.dirty_firms))
price_clean_std(m) = std(map(f -> f.price, m.clean_firms))
price_dirty_min(m) = minimum(map(f -> f.price, m.clean_firms))
price_clean_min(m) = minimum(map(f -> f.price, m.dirty_firms))
price_dirty_max(m) = maximum(map(f -> f.price, m.dirty_firms))
price_clean_max(m) = maximum(map(f -> f.price, m.clean_firms))
wage(m) = mean(map(f -> f.wage, m.firms))
wage_std(m) = std(map(f -> f.wage, m.firms))
wage_min(m) = minimum(map(f -> f.wage, m.firms))
wage_max(m) = maximum(map(f -> f.wage, m.firms))
wage_dirty(m) = mean(map(f -> f.wage, m.dirty_firms))
wage_clean(m) = mean(map(f -> f.wage, m.clean_firms))
marginal_costs_dirty(m) = mean(map(f -> f.marginal_costs, m.dirty_firms))
marginal_costs_clean(m) = mean(map(f -> f.marginal_costs, m.clean_firms))
money_firms(m) = sum(map(f -> f.money, m.firms))

firm_bankrupt(m) = mean(map(f -> f.bankrupt, m.firms))
firm_bankrupt_clean(m) = mean(map(f -> f.bankrupt, m.clean_firms))
firm_bankrupt_dirty(m) = mean(map(f -> f.bankrupt, m.dirty_firms))
firm_active(m) = sum(map(f -> length(f.employees) > 0 ? 1 : 0, m.firms))
firm_active_clean(m) = sum(map(f -> length(f.employees) > 0 ? 1 : 0, m.clean_firms))
firm_active_dirty(m) = sum(map(f -> length(f.employees) > 0 ? 1 : 0, m.dirty_firms))

# Demand Side #
demand_intensity_dirty_lc(m) = mean(map(h -> h.planned_daily_dirty_consumption,collect(m.central.first_quintile)))/mean(map(h -> h.planned_daily_dirty_consumption+h.planned_daily_clean_consumption,collect(m.central.first_quintile)))
demand_intensity_dirty_lmc(m) = mean(map(h -> h.planned_daily_dirty_consumption,collect(m.central.second_quintile)))/mean(map(h -> h.planned_daily_dirty_consumption+h.planned_daily_clean_consumption,collect(m.central.second_quintile)))
demand_intensity_dirty_mc(m) = mean(map(h -> h.planned_daily_dirty_consumption,collect(m.central.third_quintile)))/mean(map(h -> h.planned_daily_dirty_consumption+h.planned_daily_clean_consumption,collect(m.central.third_quintile)))
demand_intensity_dirty_umc(m) = mean(map(h -> h.planned_daily_dirty_consumption,collect(m.central.fourth_quintile)))/mean(map(h -> h.planned_daily_dirty_consumption+h.planned_daily_clean_consumption,collect(m.central.fourth_quintile)))
demand_intensity_dirty_uc(m) = mean(map(h -> h.planned_daily_dirty_consumption,collect(m.central.fifth_quintile)))/mean(map(h -> h.planned_daily_dirty_consumption+h.planned_daily_clean_consumption,collect(m.central.fifth_quintile)))
demand_intensity_clean_lc(m) = mean(map(h -> h.planned_daily_clean_consumption,collect(m.central.first_quintile)))/mean(map(h -> h.planned_daily_dirty_consumption+h.planned_daily_clean_consumption,collect(m.central.first_quintile)))
demand_intensity_clean_lmc(m) = mean(map(h -> h.planned_daily_clean_consumption,collect(m.central.second_quintile)))/mean(map(h -> h.planned_daily_dirty_consumption+h.planned_daily_clean_consumption,collect(m.central.second_quintile)))
demand_intensity_clean_mc(m) = mean(map(h -> h.planned_daily_clean_consumption,collect(m.central.third_quintile)))/mean(map(h -> h.planned_daily_dirty_consumption+h.planned_daily_clean_consumption,collect(m.central.third_quintile)))
demand_intensity_clean_umc(m) = mean(map(h -> h.planned_daily_clean_consumption,collect(m.central.fourth_quintile)))/mean(map(h -> h.planned_daily_dirty_consumption+h.planned_daily_clean_consumption,collect(m.central.fourth_quintile)))
demand_intensity_clean_uc(m) = mean(map(h -> h.planned_daily_clean_consumption,collect(m.central.fifth_quintile)))/mean(map(h -> h.planned_daily_dirty_consumption+h.planned_daily_clean_consumption,collect(m.central.fifth_quintile)))

demand_dirty(m) = 21*sum(map(h -> h.planned_daily_dirty_consumption,m.households))
demand_dirty_first_quintile(m) = 21*mean(map(h -> h.planned_daily_dirty_consumption,collect(m.central.first_quintile)))
demand_dirty_second_quintile(m) = 21*mean(map(h -> h.planned_daily_dirty_consumption,collect(m.central.second_quintile)))
demand_dirty_third_quintile(m) = (21*mean(map(h -> h.planned_daily_dirty_consumption,collect(m.central.third_quintile))))
demand_dirty_fourth_quintile(m) = 21*mean(map(h -> h.planned_daily_dirty_consumption,collect(m.central.fourth_quintile)))
demand_dirty_fifth_quintile(m) = (21*mean(map(h -> h.planned_daily_dirty_consumption,collect(m.central.fifth_quintile))))

demand_clean(m) = 21*sum(map(h -> h.planned_daily_clean_consumption, m.households))
demand_clean_first_quintile(m) = 21*mean(map(h -> h.planned_daily_clean_consumption,collect(m.central.first_quintile)))
demand_clean_second_quintile(m) = 21*mean(map(h -> h.planned_daily_clean_consumption,collect(m.central.second_quintile)))
demand_clean_third_quintile(m) = 21*mean(map(h -> h.planned_daily_clean_consumption,collect(m.central.third_quintile)))
demand_clean_fourth_quintile(m) = 21*mean(map(h -> h.planned_daily_clean_consumption,collect(m.central.fourth_quintile)))
demand_clean_fifth_quintile(m) =  (21*mean(map(h -> h.planned_daily_clean_consumption,collect(m.central.fifth_quintile))))

consumption_dirty(m) = sum(map(h -> h.dirty_consumption, m.households))
consumption_clean(m) = sum(map(h -> h.clean_consumption, m.households))

hh_income_total(m) = sum(map(h -> h.labor_income + h.dividend_income + h.energy_income + h.transfer_income, m.households))
hh_income_labor(m) = sum(map(h -> h.labor_income, m.households))
hh_income_energy(m) = sum(map(h -> h.energy_income, m.households))
hh_income_dividends(m) = sum(map(h -> h.dividend_income, m.households))
hh_income_transfers(m) = sum(map(h -> h.transfer_income, m.households))
hh_income_interest(m) = sum(map(h -> h.interest_income, m.households))
money_hhs(m) = sum(map(h -> h.money, m.households))

hh_savings_rate(m) = mean((map(h -> h.savings_rate, m.households)))
hh_rel_expenditure(m) = (mean(map(f -> f.price, m.dirty_firms))*mean(map(h -> h.dirty_consumption, m.households)))/(mean(map(f -> f.price, m.clean_firms))*mean(map(h -> h.clean_consumption, m.households)))

income_share_labor(m) = hh_income_labor(m) / hh_income_total(m)
income_share_dividends(m) = hh_income_dividends(m) / hh_income_total(m)
income_share_interest(m) = hh_income_interest(m) / hh_income_total(m)
income_share_energy(m) = hh_income_energy(m) / hh_income_total(m)
income_share_transfers(m) = hh_income_transfers(m) / hh_income_total(m)

income_share_first_quintile(m) = sum(map(h -> h.labor_income + h.dividend_income + h.energy_income + h.transfer_income, collect(m.central.first_quintile)))/hh_income_total(m)
income_share_second_quintile(m) = sum(map(h -> h.labor_income + h.dividend_income + h.energy_income + h.transfer_income, collect(m.central.second_quintile)))/hh_income_total(m)
income_share_third_quintile(m) = sum(map(h -> h.labor_income + h.dividend_income + h.energy_income + h.transfer_income, collect(m.central.third_quintile)))/hh_income_total(m)
income_share_fourth_quintile(m) = sum(map(h -> h.labor_income + h.dividend_income + h.energy_income + h.transfer_income, collect(m.central.fourth_quintile)))/hh_income_total(m)
income_share_fifth_quintile(m) = sum(map(h -> h.labor_income + h.dividend_income + h.energy_income + h.transfer_income, collect(m.central.fifth_quintile)))/hh_income_total(m)

# Global #
price_clean_energy(m) = m.price_clean_energy
unemployment_rate(m) = 1-mean(map(hh -> hh.employed, m.households))
gini(v::AbstractVector{<:Real})::Float64 = (2 * sum([x*i for (i,x) in enumerate(sort(v))]) / sum(sort(v)) - (length(v)+1))/(length(v))
gini_income(m) = gini(collect(map(h -> h.labor_income + h.dividend_income + h.energy_income + h.transfer_income, m.households)))
gini_wealth(m) = gini(collect(map(h -> h.money, m.households)))
technology(m) = m.central.tech_productivity
gdp(m) = production_dirty(m) * price_dirty(m) + production_clean(m) * price_clean(m)


### Policy Module ###
hh_policy_support(m) = median(map(hh -> hh.policy_support, m.households))
hh_policy_support_weighted(m) = weighted_median(map(hh -> (hh.policy_support, hh.voting_power), m.households))

hh_policy_support_first_quintile(m) = (median(map(hh -> hh.policy_support, collect(m.central.first_quintile)))) 
hh_policy_support_second_quintile(m) = median(map(hh -> hh.policy_support, collect(m.central.second_quintile)))
hh_policy_support_third_quintile(m) = (median(map(hh -> hh.policy_support, collect(m.central.third_quintile))))
hh_policy_support_fourth_quintile(m) = median(map(hh -> hh.policy_support, collect(m.central.fourth_quintile)))
hh_policy_support_fifth_quintile(m) = median(map(hh -> hh.policy_support, collect(m.central.fifth_quintile)))

### Climate Module ###
carbon_price(m) = m.central.carbon_price
current_emissions_wrt_budget(m) = m.central.current_emissions_wrt_budget
emissions_scaling(m) = m.central.emissions_scaling
unit_emissions_actual(m) = m.central.unit_emissions_actual

data_collect(m) = println("DATACOLLECT", " ", abmtime(m))

mdata = [
    # Economic module
        # Supply
    production, energy_dirty, energy_clean, production_dirty, production_dirty_std, production_dirty_min, 
    production_dirty_max, production_clean, production_clean_std, production_clean_min, production_clean_max, 
    inventories, price_dirty, price_clean, price_dirty_std, price_clean_std, price_dirty_min, price_clean_min, 
    price_dirty_max, price_clean_max, wage, wage_std, wage_min, wage_max, wage_dirty, wage_clean, 
    marginal_costs_dirty, marginal_costs_clean, money_firms, firm_bankrupt, firm_bankrupt_clean, 
    firm_bankrupt_dirty, firm_active, firm_active_clean, firm_active_dirty, 
        # Demand
    demand_intensity_dirty_lc, demand_intensity_dirty_lmc, demand_intensity_dirty_mc, demand_intensity_dirty_umc, 
    demand_intensity_dirty_uc, demand_intensity_clean_lc, demand_intensity_clean_lmc, demand_intensity_clean_mc, 
    demand_intensity_clean_umc, demand_intensity_clean_uc, demand_dirty, demand_dirty_first_quintile, 
    demand_dirty_second_quintile, demand_dirty_third_quintile, demand_dirty_fourth_quintile, 
    demand_dirty_fifth_quintile, demand_clean, demand_clean_first_quintile, demand_clean_second_quintile, 
    demand_clean_third_quintile, demand_clean_fourth_quintile, demand_clean_fifth_quintile, consumption_dirty, 
    consumption_clean, hh_income_total, hh_income_labor, hh_income_energy, hh_income_dividends, hh_income_transfers, 
    hh_income_interest, money_hhs, hh_savings_rate, hh_rel_expenditure, income_share_labor, income_share_dividends, 
    income_share_interest, income_share_energy, income_share_transfers, income_share_first_quintile, 
    income_share_second_quintile, income_share_third_quintile, income_share_fourth_quintile, 
    income_share_fifth_quintile,
        # Global
    price_clean_energy, unemployment_rate, gini_income, gini_wealth, technology, gdp,

    # Policy module
    hh_policy_support, hh_policy_support_weighted,
    hh_policy_support_first_quintile, hh_policy_support_second_quintile, hh_policy_support_third_quintile,
    hh_policy_support_fourth_quintile, hh_policy_support_fifth_quintile,

    # Climate module
    carbon_price, current_emissions_wrt_budget, emissions_scaling, unit_emissions_actual
]

adata = nothing
