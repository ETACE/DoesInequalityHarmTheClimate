using Serialization, ArgParse, StatsPlots
using Plots,TensorCast

include("model/model.jl")

include("experiments/baseline.jl")
include("experiments/inequality.jl")
include("experiments/preferences.jl")
include("experiments/voter_turnout.jl")


# Load Data from Conducted Experiment
function load_dataset(folder)
	folder_data = "../data/$folder"

	results = []
	chunk = 0
	while isfile("$folder_data/data-$(chunk+=1).dat")
		append!(results, deserialize("$folder_data/data-$chunk.dat"))
	end

	if length(results) == 0
		println("ERROR: No data found in $folder_data")
		exit(1)
	end

	return results
end

function merge_data(results, experiments; burn_in_months = 1020)
    data = Dict{String, Vector{DataFrame}}()

    for (exp_name, _) in experiments
        data[exp_name] = Vector{DataFrame}()

        for r in results
            if r[:exp_name] == exp_name
                plot_it = size(r[:model_data], 1)
                df = r[:model_data][burn_in_months + 1:plot_it, :]
                push!(data[exp_name], df)
            end
        end
    end

    return data
end

function get_data_exp_key(data, exp, key)
	data_exp_key = []
	for i in 1:length(data[exp])
		append!(data_exp_key, [data[exp][i][!,key]])
	end
	return data_exp_key
end

function get_mean_upper_lower(data, conf_level)
    @cast data_t[i][j] := data[j][i]

	mean_data = []
	upper =[]
	lower = []

	for i in 1:length(data_t)
		append!(mean_data, mean(data_t[i]))
		if !isnan(mean(data_t[i]))
			append!(upper, quantile(data_t[i], 1-conf_level/2) - mean(data_t[i]))
			append!(lower, mean(data_t[i]) - quantile(data_t[i], conf_level/2))
		else
			append!(upper, NaN)
			append!(lower, NaN)
		end
	end

	return mean_data, upper, lower
end

confidence_level = 0.25

function add_series_with_ribbon!(pl, series, color, label)
	mean_data, upper, lower = get_mean_upper_lower(series, confidence_level)
	plot!(pl,years, mean_data, color=color, label=label, linewidth=1.5, ribbon = (lower, upper))
	return pl
end

function plot_three(data, exp1, key1, exp2, key2,exp3,key3,ribbon, budgets, title, color1, color2,color3, label1, label2,label3, support)
	series1 = deepcopy(get_data_exp_key(data, exp1, key1))
	series2 = deepcopy(get_data_exp_key(data, exp2, key2))
	series3 = deepcopy(get_data_exp_key(data, exp3, key3))


	transform_into_yearly(series1)
	transform_into_yearly(series2)
	transform_into_yearly(series3)

	if support 
		for j in eachindex(series1)
			series1[j][1] = series1[j][2]
			series2[j][1] = series2[j][2]
			series3[j][1] = series3[j][2]
		end
	end
	
	pl = plot( fontfamily="Computer Modern")
	if ribbon 
		add_series_with_ribbon!(pl, series1, color1, label1)
		add_series_with_ribbon!(pl, series2, color2, label2)
		add_series_with_ribbon!(pl, series3, color3, label3)

	else
		plot!(pl,years,mean(series1), color=color1,label=label1)
		plot!(pl,years,mean(series2), color=color2,label=label2)
		plot!(pl,years,mean(series3), color=color3,label=label3)

	end

	if budgets == true 
		plot_budgets(pl)
	end

	return pl
end

function plot_comparison(data, exp1, key1, exp2, key2,ribbon, budgets, title, color1, color2, label1, label2, support,yearly)
	series1 = deepcopy(get_data_exp_key(data, exp1, key1))
	series2 = deepcopy(get_data_exp_key(data, exp2, key2))

	if yearly
		for j in eachindex(series1)
			series1[j] = series1[j][960]
			series2[j] = series2[j][960]
			deleteat!(series1[j],1:84)
			deleteat!(series2[j],1:84)
		end
		
	else
		transform_into_yearly(series1)
		transform_into_yearly(series2)
		if support 
			for j in eachindex(series1)
				series1[j][1] = series1[j][2]
				series2[j][1] = series2[j][2]
			end
		end
	end
	
	pl = plot(fontfamily="Computer Modern")
	if ribbon 
		add_series_with_ribbon!(pl, series1, color1, label1)
		add_series_with_ribbon!(pl, series2, color2, label2)
	else
		plot!(pl,years,mean(series1), color=color1,label=label1,linewidth=1.75)
		plot!(pl,years,mean(series2), color=color2,label=label2,linewidth=1.75)
	end

	if budgets == true 
		plot_budgets(pl)
	end

	return pl
end

function plot_single(data,exp,key,budgets,title,color,label,support,ribbon)
	series = deepcopy(get_data_exp_key(data, exp, key))
	transform_into_yearly(series)
	if support 
		series[1] = series[2]
	end
	pl = plot(fontfamily="Computer Modern")
	if ribbon 
		add_series_with_ribbon!(pl, series, color, label)
	else
		plot!(pl,years,series,color=color,label=label,linewidth=1.75)
	end

	if budgets == true 
		plot_budgets(pl)
	end

	return pl
end


function plot_by_income_class(data,exp,keyset,title,labelset,colorpalette,lim)
	if lim 
		pl = plot( fontfamily="Computer Modern", ylimit=(0,1))
	else
		pl = plot(fontfamily="Computer Modern")
	end 

	for i in 1:5
		series = deepcopy(get_data_exp_key(data,exp,keyset[i]))
		transform_into_yearly(series)
		mean_series = []
		for j in 1:length(series[1])
			list = []
			for k in eachindex(series)
				append!(list,[series[k][j]])
			end
			push!(mean_series,mean(list))
		end
		
		plot!(years,mean_series,color=colorpalette[i],label=labelset[i],linewidth=1.75)
		
	end
	
	return pl
end

function plot_budgets(pl)
	#plot!(pl, years, emission_path[!, "1.5"], color="darkgreen", label="1.5°", linestyle=:dash)
	plot!(pl, years, emission_path[!, "2"], color="black", label="2°C Emission Budget", linestyle=:dash)
	#plot!(pl, years, emission_path[!, "3"], color="darkorange", label="3.0°", linestyle=:dash)
	#plot!(pl, years, emission_path[!, "4"], color="red", label="4.0°", linestyle=:dash)
end


function transform_into_yearly(series)
	k = []
	last = []
	d = length(series[1])-(simulation_months-burn_in_months)
	for j in eachindex(series)
		deleteat!(series[j],1:d)
		append!(last,series[j][length(series[1])]) 
	end
	for i in 1:Int.((length(series[1]))/12)
		append!(k,[i*12])
	end
	for j in eachindex(series)
		keepat!(series[j],k)
		append!(series[j],last[j])
	end
	
	return series
end


years = []
for i in 1:((simulation_months-burn_in_months)/12+1)
	push!(years,-1+i)
end

# Load experiment data
results_base = load_dataset("baseline")
results_ineq = load_dataset("inequality")
results_pref = load_dataset("preferences")
results_vote = load_dataset("voter_turnout")
results_income_preference = load_dataset("income_preference_effect")

experiments_base = Dict("baseline" => Dict())
experiments_ineq = Dict(
    "gini_0.0" => Dict(:Gini => 0.0),
    "gini_0.1" => Dict(:Gini => 0.1),
    "gini_0.2" => Dict(:Gini => 0.2),
    "gini_0.3" => Dict(:Gini => 0.3),
    "gini_0.5" => Dict(:Gini => 0.5),
    "gini_0.6" => Dict(:Gini => 0.6)
)
experiments_pref = Dict(
    "constant"  => Dict(:preferences => "constant"),
    "decreasing"  => Dict(:preferences => "decreasing")
)
experiments_vote = Dict("power_weighted_voting" => Dict(:voting_rule => POWER_WEIGHTED_VOTING))

experiments_income_preference = Dict(
	"income_effect" => Dict(:income_effect => true, :Gini => 0.4),
    "preference_effect" => Dict(:preference_effect => true, :Gini => 0.0)
)

data_base = merge_data(results_base, experiments_base)
data_ineq = merge_data(results_ineq, experiments_ineq)
data_pref = merge_data(results_pref, experiments_pref)
data_vote = merge_data(results_vote, experiments_vote)
data_income_preference = merge_data(results_income_preference, experiments_income_preference)

data = mergewith(vcat, data_base, data_ineq, data_pref, data_vote, data_income_preference)

emission_path = CSV.read("../data/EmissionsUSA.csv", DataFrame)

name = "all_final"

mkpath("../plots/$name/baseline/")
mkpath("../plots/$name/baselinevsinequality/")
mkpath("../plots/$name/preferences/")
mkpath("../plots/$name/baselinevsturnout/")
mkpath("../plots/$name/income_preference_effect/")


### BASELINE PLOTS ###
baseline_color = "#6C7A89" 
comparison_color1 = "darkorange"
comparison_color2 = "darkmagenta"

### Carbon price ###
pl = plot_single(data,"baseline","carbon_price",false,"Carbon Price",baseline_color,"Baseline",false,true)
savefig(pl,"../plots/$name/baseline/baseline_carbon_price.pdf")

### Emissions budgets ###
pl = plot_single(data,"baseline","current_emissions_wrt_budget",true,"CO2 Emissions",baseline_color,"Baseline",false,true)
savefig(pl,"../plots/$name/baseline/baseline_emissions.pdf")

### Gini ###
pl = plot_single(data,"baseline","gini_income",false,"Gini Coefficient Income",baseline_color,"Baseline",false,true)
savefig(pl,"../plots/$name/baseline/gini_income.pdf")
pl = plot_single(data,"baseline","gini_wealth",false,"Gini Coefficient Wealth",baseline_color,"Baseline",false,true)
savefig(pl,"../plots/$name/baseline/gini_wealth.pdf")

### Policy Support ###
pl = plot_single(data,"baseline","hh_policy_support",false,"Policy Support",baseline_color,"Baseline",true,false)
savefig(pl,"../plots/$name/baseline/pol_support.pdf")

### Policy Support by Income Class ###
colorpalette = ["mediumblue","cornflowerblue","lightpink","coral","red"]
keyset1 = ["hh_policy_support_first_quintile","hh_policy_support_second_quintile","hh_policy_support_third_quintile","hh_policy_support_fourth_quintile","hh_policy_support_fifth_quintile"]
labelset = ["First Quintile", "Second Quintile","Third Quintile","Fourth Quintile","Fifth Quintile"]

pl = plot_by_income_class(data,"baseline",reverse(keyset1),"Policy Support by Quintile",reverse(labelset),reverse(colorpalette),true)
savefig(pl,"../plots/$name/baseline/baseline_pol_support_by_income_class.pdf")


### Goods Demand ###
pl = plot_comparison(data,"baseline","demand_dirty","baseline","demand_clean",true,false,"Goods Demand","#652121","darkolivegreen","Dirty Good Demand","Clean Good Demand",false,false)
savefig(pl,"../plots/$name/baseline/baseline_goods_demand.pdf")


### Goods Prices ###
pl = plot_comparison(data,"baseline","price_dirty","baseline","price_clean",true,false,"Goods Prices","saddlebrown","darkgreen","Dirty Good Price","Clean Good Price",false,false)
savefig(pl,"../plots/$name/baseline/goods_prices.pdf")

### Relative Prices ###
clean_price = deepcopy(get_data_exp_key(data, "baseline", "price_clean"))
dirty_price = deepcopy(get_data_exp_key(data, "baseline", "price_dirty"))
rel_price = clean_price
for j in eachindex(clean_price)
	for i in 1:length(clean_price[j])
		clean_price[j][i] = clean_price[j][i]
		dirty_price[j][i] = dirty_price[j][i]
		rel_price[j][i] = dirty_price[j][i]/clean_price[j][i]
	end
end
transform_into_yearly(rel_price)

pl = plot(fontfamily="Computer Modern",linewidth=1.75)
add_series_with_ribbon!(pl, rel_price, baseline_color, "Baseline")
savefig(pl,"../plots/$name/baseline/baseline_rel_price.pdf")

### Dirty Goods Demand by Income Class ###
keyset2 = ["demand_dirty_first_quintile","demand_dirty_second_quintile","demand_dirty_third_quintile","demand_dirty_fourth_quintile","demand_dirty_fifth_quintile"]
pl = plot_by_income_class(data,"baseline",reverse(keyset2),"Dirty Good Demand by Income Class",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/baseline/baseline_abs_consumption.pdf")

### Clean Goods Demand by Income Class ###
keyset3 = ["demand_clean_first_quintile","demand_clean_second_quintile","demand_clean_third_quintile","demand_clean_fourth_quintile","demand_clean_fifth_quintile"]
pl = plot_by_income_class(data,"baseline",reverse(keyset3),"Clean Good Demand by Income Class",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/baseline/clean_demand_income_class.pdf")

### Dirty Goods Intensity by Income Class ###
keyset4 = ["demand_intensity_dirty_lc","demand_intensity_dirty_lmc","demand_intensity_dirty_mc","demand_intensity_dirty_umc","demand_intensity_dirty_uc"]
pl = plot_by_income_class(data,"baseline",keyset4,"Dirty Good Consumption Share by Income Class",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baseline/baseline_rel_consumption.pdf")

### Clean Goods Intensity by Income Class ###
keyset5 = ["demand_intensity_clean_lc","demand_intensity_clean_lmc","demand_intensity_clean_mc","demand_intensity_clean_umc","demand_intensity_clean_uc"]
pl = plot_by_income_class(data,"baseline",reverse(keyset5),"Clean Good Consumption Share by Income Class",reverse(labelset),reverse(colorpalette),true)
savefig(pl,"../plots/$name/baseline/clean_intensity_income_class.pdf")


### INCOME EFFECT ###

### Carbon price ###
pl = plot_single(data,"income_effect","carbon_price",false,"Carbon Price","navyblue","income_effect",false,true)
savefig(pl,"../plots/$name/income_preference_effect/income_effect_carbon_price.pdf")

### Emissions budgets ###
pl = plot_single(data,"income_effect","current_emissions_wrt_budget",true,"CO2 Emissions","navyblue","income_effect",false,true)
savefig(pl,"../plots/$name/income_preference_effect/income_effect_emissions_budget.pdf")

### Dirty Goods Demand by Income Class ###
keyset2 = ["demand_dirty_first_quintile","demand_dirty_second_quintile","demand_dirty_third_quintile","demand_dirty_fourth_quintile","demand_dirty_fifth_quintile"]
pl = plot_by_income_class(data,"income_effect",reverse(keyset2),"Dirty Good Demand by Income Class",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/income_preference_effect/dirty_demand_income_class_income_effect.pdf")

### Clean Goods Demand by Income Class ###
keyset3 = ["demand_clean_first_quintile","demand_clean_second_quintile","demand_clean_third_quintile","demand_clean_fourth_quintile","demand_clean_fifth_quintile"]
pl = plot_by_income_class(data,"income_effect",reverse(keyset3),"Clean Good Demand by Income Class",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/income_preference_effect/clean_demand_income_class_income_effect.pdf")

### Dirty Goods Intensity by Income Class ###
keyset4 = ["demand_intensity_dirty_lc","demand_intensity_dirty_lmc","demand_intensity_dirty_mc","demand_intensity_dirty_umc","demand_intensity_dirty_uc"]
pl = plot_by_income_class(data,"income_effect",keyset4,"Dirty Good Consumption Share by Income Class",labelset,colorpalette,false)
savefig(pl,"../plots/$name/income_preference_effect/dirty_intensity_income_class_income_effect.pdf")

### Clean Goods Intensity by Income Class ###
keyset5 = ["demand_intensity_clean_lc","demand_intensity_clean_lmc","demand_intensity_clean_mc","demand_intensity_clean_umc","demand_intensity_clean_uc"]
pl = plot_by_income_class(data,"income_effect",reverse(keyset5),"Clean Good Consumption Share by Income Class",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/income_preference_effect/clean_intensity_income_class_income_effect.pdf")

### Policy Support by Income Class ###
keyset1 = ["hh_policy_support_first_quintile","hh_policy_support_second_quintile","hh_policy_support_third_quintile","hh_policy_support_fourth_quintile","hh_policy_support_fifth_quintile"]
labelset = ["First Quintile", "Second Quintile","Third Quintile","Fourth Quintile","Fifth Quintile"]

pl = plot_by_income_class(data,"income_effect",reverse(keyset1),"Policy Support by Quintile",reverse(labelset),reverse(colorpalette),true)
savefig(pl,"../plots/$name/income_preference_effect/income_effect_pol_support_by_income_class.pdf")

### Upper and Lower Class Policy Support ###
pl = plot_comparison(data,"baseline","hh_policy_support_first_quintile","income_effect","hh_policy_support_first_quintile",false,false,"Policy Support First Quintile",comparison_color1,comparison_color1,"Baseline","Income Effect",true,false)
savefig(pl,"../plots/$name/income_preference_effect/lower_class_policy_support_income_effect.pdf")

pl = plot_comparison(data,"baseline","hh_policy_support_fifth_quintile","income_effect","hh_policy_support_fifth_quintile",false,false,"Policy Support Fifth Quintile",comparison_color1,comparison_color1,"Baseline","Income Effect",true,false)
savefig(pl,"../plots/$name/income_preference_effect/upper_class_policy_support_income_effect.pdf")

### PREFERENCE EFFECT ###
### Carbon price ###
pl = plot_single(data,"preference_effect","carbon_price",false,"Carbon Price","navyblue","preference_effect",false,true)
savefig(pl,"../plots/$name/income_preference_effect/preference_effect_carbon_price.pdf")

### Emissions budgets ###
pl = plot_single(data,"preference_effect","current_emissions_wrt_budget",true,"CO2 Emissions","navyblue","preference_effect",false,true)
savefig(pl,"../plots/$name/income_preference_effect/preference_effect_emissions_budget.pdf")

### Dirty Goods Demand by Income Class ###
keyset2 = ["demand_dirty_first_quintile","demand_dirty_second_quintile","demand_dirty_third_quintile","demand_dirty_fourth_quintile","demand_dirty_fifth_quintile"]
pl = plot_by_income_class(data,"preference_effect",reverse(keyset2),"Dirty Good Demand by Income Class",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/income_preference_effect/dirty_demand_income_class_preference_effect.pdf")

### Clean Goods Demand by Income Class ###
keyset3 = ["demand_clean_first_quintile","demand_clean_second_quintile","demand_clean_third_quintile","demand_clean_fourth_quintile","demand_clean_fifth_quintile"]
pl = plot_by_income_class(data,"preference_effect",reverse(keyset3),"Clean Good Demand by Income Class",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/income_preference_effect/clean_demand_income_class_preference_effect.pdf")

### Dirty Goods Intensity by Income Class ###
keyset4 = ["demand_intensity_dirty_lc","demand_intensity_dirty_lmc","demand_intensity_dirty_mc","demand_intensity_dirty_umc","demand_intensity_dirty_uc"]
pl = plot_by_income_class(data,"preference_effect",keyset4,"Dirty Good Consumption Share by Income Class",labelset,colorpalette,false)
savefig(pl,"../plots/$name/income_preference_effect/dirty_intensity_income_class_preference_effect.pdf")

### Clean Goods Intensity by Income Class ###
keyset5 = ["demand_intensity_clean_lc","demand_intensity_clean_lmc","demand_intensity_clean_mc","demand_intensity_clean_umc","demand_intensity_clean_uc"]
pl = plot_by_income_class(data,"preference_effect",reverse(keyset5),"Clean Good Consumption Share by Income Class",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/income_preference_effect/clean_intensity_income_class_preference_effect.pdf")

### Policy Support by Income Class ###
keyset1 = ["hh_policy_support_first_quintile","hh_policy_support_second_quintile","hh_policy_support_third_quintile","hh_policy_support_fourth_quintile","hh_policy_support_fifth_quintile"]
labelset = ["First Quintile", "Second Quintile","Third Quintile","Fourth Quintile","Fifth Quintile"]

pl = plot_by_income_class(data,"preference_effect",reverse(keyset1),"Policy Support by Quintile",reverse(labelset),reverse(colorpalette),true)
savefig(pl,"../plots/$name/income_preference_effect/preference_effect_pol_support_by_income_class.pdf")

### Upper and Lower Class Policy Support ###
pl = plot_comparison(data,"baseline","hh_policy_support_first_quintile","preference_effect","hh_policy_support_first_quintile",false,false,"Policy Support First Quintile",comparison_color1,comparison_color1,"Baseline","Income Effect",true,false)
savefig(pl,"../plots/$name/income_preference_effect/lower_class_policy_support_preference_effect.pdf")

pl = plot_comparison(data,"baseline","hh_policy_support_fifth_quintile","preference_effect","hh_policy_support_fifth_quintile",false,false,"Policy Support Fifth Quintile",comparison_color1,comparison_color1,"Baseline","Income Effect",true,false)
savefig(pl,"../plots/$name/income_preference_effect/upper_class_policy_support_preference_effect.pdf")

### Support Comparison for all three ###
pl = plot_three(data, "baseline", "hh_policy_support_first_quintile", "income_effect", "hh_policy_support_first_quintile", "preference_effect", "hh_policy_support_first_quintile", false, false, "Policy Support First Quintile", comparison_color1, comparison_color1, "tomato", "Baseline", "Income Effect", "Preference Effect", true)
savefig(pl,"../plots/$name/income_preference_effect/lower_class_policy_support_all_three.pdf")

pl = plot_three(data, "baseline", "hh_policy_support_fifth_quintile", "income_effect", "hh_policy_support_fifth_quintile", "preference_effect", "hh_policy_support_fifth_quintile", false, false, "Policy Support Fifth Quintile", comparison_color1, comparison_color1, "tomato", "Baseline", "Income Effect", "Preference Effect", true)
savefig(pl,"../plots/$name/income_preference_effect/upper_class_policy_support_all_three.pdf")




### INEQUALITY EXPERIMENTS ###

### Emissions ###
pl = plot_three(data,"baseline","current_emissions_wrt_budget","gini_0.3","current_emissions_wrt_budget","gini_0.5","current_emissions_wrt_budget",true,true,"CO2 Emissions","navyblue",comparison_color1,comparison_color1,"Baseline","Gini 0.3","Gini 0.5",false)
savefig(pl,"../plots/$name/baselinevsinequality/emissions.pdf")

pl = plot_three(data,"gini_0.2","current_emissions_wrt_budget","baseline","current_emissions_wrt_budget","gini_0.6","current_emissions_wrt_budget",true,true,"CO2 Emissions",comparison_color2,baseline_color,comparison_color1,"Gini 0.2","Baseline","Gini 0.6",false)
savefig(pl,"../plots/$name/baselinevsinequality/emissions_middle.pdf")

### All emissions ###
series0 = deepcopy(get_data_exp_key(data, "gini_0.0", "current_emissions_wrt_budget"))
series1 = deepcopy(get_data_exp_key(data, "gini_0.1", "current_emissions_wrt_budget"))
series2 = deepcopy(get_data_exp_key(data, "gini_0.2", "current_emissions_wrt_budget"))
series3 = deepcopy(get_data_exp_key(data, "gini_0.3", "current_emissions_wrt_budget"))
series4 = deepcopy(get_data_exp_key(data, "baseline", "current_emissions_wrt_budget"))
series5 = deepcopy(get_data_exp_key(data, "gini_0.5", "current_emissions_wrt_budget"))
series6 = deepcopy(get_data_exp_key(data, "gini_0.6", "current_emissions_wrt_budget"))

transform_into_yearly(series0)
transform_into_yearly(series1)
transform_into_yearly(series2)
transform_into_yearly(series3)
transform_into_yearly(series4)
transform_into_yearly(series5)
transform_into_yearly(series6)

pl = plot(fontfamily="Computer Modern")

plot!(pl,years,mean(series0), color="dodgerblue",label="Gini 0.0")
plot!(pl,years,mean(series1), color="aqua",label="Gini 0.1")
plot!(pl,years,mean(series2), color="limegreen",label="Gini 0.2")
plot!(pl,years,mean(series3), color="darkorange",label="Gini 0.3")
plot!(pl,years,mean(series4), color=baseline_color,label="Baseline (Gini 0.4)")
plot!(pl,years,mean(series5), color="hotpink",label="Gini 0.5")
plot!(pl,years,mean(series6), color="firebrick",label="Gini 0.6")

plot_budgets(pl)

savefig(pl,"../plots/$name/baselinevsinequality/emissions_all.pdf")

### All prices ###
series0 = deepcopy(get_data_exp_key(data, "gini_0.0", "carbon_price"))
series1 = deepcopy(get_data_exp_key(data, "gini_0.1", "carbon_price"))
series2 = deepcopy(get_data_exp_key(data, "gini_0.2", "carbon_price"))
series3 = deepcopy(get_data_exp_key(data, "gini_0.3", "carbon_price"))
series4 = deepcopy(get_data_exp_key(data, "baseline", "carbon_price"))
series5 = deepcopy(get_data_exp_key(data, "gini_0.5", "carbon_price"))
series6 = deepcopy(get_data_exp_key(data, "gini_0.6", "carbon_price"))

transform_into_yearly(series0)
transform_into_yearly(series1)
transform_into_yearly(series2)
transform_into_yearly(series3)
transform_into_yearly(series4)
transform_into_yearly(series5)
transform_into_yearly(series6)

pl = plot( fontfamily="Computer Modern")

plot!(pl,years,mean(series0), color="dodgerblue",label="Gini 0.0")
plot!(pl,years,mean(series1), color="aqua",label="Gini 0.1")
plot!(pl,years,mean(series2), color="limegreen",label="Gini 0.2")
plot!(pl,years,mean(series3), color="darkorange",label="Gini 0.3")
plot!(pl,years,mean(series4), color=baseline_color,label="Baseline (Gini 0.4)")
plot!(pl,years,mean(series5), color="hotpink",label="Gini 0.5")
plot!(pl,years,mean(series6), color="firebrick",label="Gini 0.6")

savefig(pl,"../plots/$name/baselinevsinequality/carbon_price_all.pdf")

### Carbon Price ###
pl = plot_three(data,"baseline","carbon_price","gini_0.3","carbon_price","gini_0.5","carbon_price",true,false,"Carbon Price",baseline_color,comparison_color1,comparison_color1,"Baseline","Gini 0.3","Gini 0.5",false)
savefig(pl,"../plots/$name/baselinevsinequality/carbon_price_sm.pdf")

pl = plot_three(data,"gini_0.2","carbon_price","baseline","carbon_price","gini_0.6","carbon_price",true,false,"Carbon Price",comparison_color2,baseline_color,comparison_color1,"Gini 0.2","Baseline","Gini 0.6",false)
savefig(pl,"../plots/$name/baselinevsinequality/carbon_price_la.pdf")

### Goods Demand ###
pl = plot_three(data,"baseline","demand_dirty","gini_0.3","demand_dirty","gini_0.5","demand_dirty",true,false,"Demand Dirty",comparison_color1,"green","tomato","Baseline","Gini 0.3","Gini 0.5",false)
savefig(pl,"../plots/$name/baselinevsinequality/demand_dirty_sm.pdf")

pl = plot_three(data,"baseline","demand_clean","gini_0.3","demand_clean","gini_0.5","demand_clean",true,false,"Demand Clean",comparison_color1,"green","tomato","Baseline","Gini 0.3","Gini 0.5",false)
savefig(pl,"../plots/$name/baselinevsinequality/demand_clean_sm.pdf")

pl = plot_three(data,"baseline","demand_dirty","gini_0.2","demand_dirty","gini_0.6","demand_dirty",true,false,"Demand Dirty",comparison_color1,"green","tomato","Baseline","Gini 0.2","Gini 0.6",false)
savefig(pl,"../plots/$name/baselinevsinequality/demand_dirty_la.pdf")

pl = plot_three(data,"baseline","demand_clean","gini_0.2","demand_clean","gini_0.6","demand_clean",true,false,"Demand Clean",comparison_color1,"green","tomato","Baseline","Gini 0.2","Gini 0.6",false)
savefig(pl,"../plots/$name/baselinevsinequality/demand_clean_la.pdf")

### Policy Support ###
pl = plot_three(data,"baseline","hh_policy_support","gini_0.3","hh_policy_support","gini_0.5","hh_policy_support",true,false,"Policy Support Voting Households",comparison_color1,"green","tomato","Baseline","Gini 0.3","Gini 0.5",true)
savefig(pl,"../plots/$name/baselinevsinequality/hh_policy_support_sm.pdf")
pl = plot_three(data,"baseline","hh_policy_support","gini_0.2","hh_policy_support","gini_0.6","hh_policy_support",true,false,"Policy Support Voting Households",comparison_color1,"green","tomato","Baseline","Gini 0.2","Gini 0.6",true)
savefig(pl,"../plots/$name/baselinevsinequality/hh_policy_support_la.pdf")


### Prices ###
pl = plot_three(data,"baseline","price_dirty","gini_0.2","price_dirty","gini_0.6","price_dirty",true,false,"Price Dirty",comparison_color1,"green","tomato","Baseline","Gini 0.2","Gini 0.6",false)
savefig(pl,"../plots/$name/baselinevsinequality/price_dirty.pdf")

pl = plot_three(data,"baseline","price_clean","gini_0.2","price_clean","gini_0.6","price_clean",true,false,"Price Clean",comparison_color1,"green","tomato","Baseline","Gini 0.2","Gini 0.6",false)
savefig(pl,"../plots/$name/baselinevsinequality/price_clean.pdf")

### Demand Share by Quintile ###
keyset1 = ["demand_intensity_dirty_lc","demand_intensity_dirty_lmc","demand_intensity_dirty_mc","demand_intensity_dirty_umc","demand_intensity_dirty_uc"]
labelset = ["First Quintile", "Second Quintile","Third Quintile","Fourth Quintile","Fifth Quintile"]

pl = plot_by_income_class(data,"baseline",keyset1,"Dirty Good Consumption Share by Quintile",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_share_baseline.pdf")
pl = plot_by_income_class(data,"gini_0.3",keyset1,"Dirty Good Consumption Share by Quintile",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_share_0.3.pdf")
pl = plot_by_income_class(data,"gini_0.5",keyset1,"Dirty Good Consumption Share by Quintile",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_share_0.5.pdf")
pl = plot_by_income_class(data,"gini_0.1",keyset1,"Dirty Good Consumption Share by Quintile",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_share_0.1.pdf")
pl = plot_by_income_class(data,"gini_0.2",keyset1,"Dirty Good Consumption Share by Quintile",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_share_0.2.pdf")
pl = plot_by_income_class(data,"gini_0.6",keyset1,"Dirty Good Consumption Share by Quintile",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_share_0.6.pdf")
pl = plot_by_income_class(data,"gini_0.0",keyset1,"Dirty Good Consumption Share by Quintile",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_share_0.0.pdf")


### Quintile Per Capita Demand ###
keyset3 = ["demand_dirty_first_quintile","demand_dirty_second_quintile","demand_dirty_third_quintile","demand_dirty_fourth_quintile","demand_dirty_fifth_quintile"]
pl = plot_by_income_class(data,"baseline",keyset3,"Dirty Good Consumption by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_demand_baseline.pdf")
pl = plot_by_income_class(data,"gini_0.3",keyset3,"Dirty Good Consumption by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_demand_0.3.pdf")
pl = plot_by_income_class(data,"gini_0.5",keyset3,"Dirty Good Consumption by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_demand_0.5.pdf")
pl = plot_by_income_class(data,"gini_0.1",keyset3,"Dirty Good Consumption by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_demand_0.1.pdf")
pl = plot_by_income_class(data,"gini_0.2",reverse(keyset3),"Dirty Good Consumption by Quintile",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_demand_0.2.pdf")
pl = plot_by_income_class(data,"gini_0.6",reverse(keyset3),"Dirty Good Consumption by Quintile",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_demand_0.6.pdf")
pl = plot_by_income_class(data,"gini_0.0",keyset3,"Dirty Good Consumption by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsinequality/dirty_demand_0.0.pdf")


keyset4 = ["demand_clean_first_quintile","demand_clean_second_quintile","demand_clean_third_quintile","demand_clean_fourth_quintile","demand_clean_fifth_quintile"]
pl = plot_by_income_class(data,"baseline",keyset4,"Clean Good Consumption by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsinequality/clean_demand_baseline.pdf")
pl = plot_by_income_class(data,"gini_0.3",keyset4,"Clean Good Consumption by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsinequality/clean_demand_0.3.pdf")
pl = plot_by_income_class(data,"gini_0.5",keyset4,"Clean Good Consumption by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsinequality/clean_demand_0.5.pdf")
pl = plot_by_income_class(data,"gini_0.1",keyset4,"Clean Good Consumption by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsinequality/clean_demand_0.1.pdf")
pl = plot_by_income_class(data,"gini_0.2",keyset4,"Clean Good Consumption by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsinequality/clean_demand_0.2.pdf")
pl = plot_by_income_class(data,"gini_0.6",keyset4,"Clean Good Consumption by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsinequality/clean_demand_0.6.pdf")
pl = plot_by_income_class(data,"gini_0.0",keyset4,"Clean Good Consumption by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsinequality/clean_demand_0.0.pdf")

### Quintile Policy Support ###
keyset2 = ["hh_policy_support_first_quintile","hh_policy_support_second_quintile","hh_policy_support_third_quintile","hh_policy_support_fourth_quintile","hh_policy_support_fifth_quintile"]
pl = plot_by_income_class(data,"baseline",keyset2,"Policy Support by Quintile, Gini = 0.4",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baselinevsinequality/pol_sup_classes_baseline.pdf")
pl = plot_by_income_class(data,"gini_0.1",keyset2,"Policy Support by Quintile, Gini = 0.1",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baselinevsinequality/pol_sup_classes_0.1.pdf")
pl = plot_by_income_class(data,"gini_0.2",reverse(keyset2),"Policy Support by Quintile, Gini = 0.2",reverse(labelset),reverse(colorpalette),true)
savefig(pl,"../plots/$name/baselinevsinequality/pol_sup_classes_0.2.pdf")
pl = plot_by_income_class(data,"gini_0.3",keyset2,"Policy Support by Quintile, Gini = 0.3",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baselinevsinequality/pol_sup_classes_0.3.pdf")
pl = plot_by_income_class(data,"gini_0.5",keyset2,"Policy Support by Quintile, Gini = 0.5",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baselinevsinequality/pol_sup_classes_0.5.pdf")
pl = plot_by_income_class(data,"gini_0.6",reverse(keyset2),"Policy Support by Quintile, Gini = 0.6",reverse(labelset),reverse(colorpalette),true)
savefig(pl,"../plots/$name/baselinevsinequality/pol_sup_classes_0.6.pdf")
pl = plot_by_income_class(data,"gini_0.0",keyset2,"Policy Support by Quintile, Gini = 0.0",labelset,colorpalette,true)
savefig(pl,"../plots/$name/baselinevsinequality/pol_sup_classes_0.0.pdf")

### Baseline vs More Equal ###
pl = plot_comparison(data,"baseline","current_emissions_wrt_budget","gini_0.1","current_emissions_wrt_budget",true,true,"CO2 Emissions","navyblue","deepskyblue","Baseline (Gini 0.4)","Gini 0.1",false,false)
savefig(pl,"../plots/$name/baselinevsinequality/emissions_baseline_0.1.pdf")

### Baseline vs More Unequal ###
pl = plot_comparison(data,"baseline","current_emissions_wrt_budget","gini_0.6","current_emissions_wrt_budget",true,true,"CO2 Emissions",comparison_color1,comparison_color1,"Baseline (Gini 0.4)","Gini 0.6",false,false)
savefig(pl,"../plots/$name/baselinevsinequality/emissions_baseline_0.6.pdf")

### Equal vs Unequal ###
pl = plot_comparison(data,"gini_0.6","current_emissions_wrt_budget","gini_0.1","current_emissions_wrt_budget",true,true,"CO2 Emissions",comparison_color1,comparison_color1,"Gini 0.6","Gini 0.1",false,false)
savefig(pl,"../plots/$name/baselinevsinequality/emissions_0.1_0.6.pdf")


### VOTER TURNOUT EXPERIMENTS ###

### Emissions ###
pl = plot_comparison(data,"baseline","current_emissions_wrt_budget","power_weighted_voting","current_emissions_wrt_budget",true,true,"CO2 Emissions",baseline_color,comparison_color1,"SMR","PWR",false,false)
savefig(pl,"../plots/$name/baselinevsturnout/emissions_baseline_vs_voting.pdf")

### Carbon Price ###
pl = plot_comparison(data,"baseline","carbon_price","power_weighted_voting","carbon_price",true,false,"Carbon Price",baseline_color,comparison_color1,"SMR","PWR",false,false)
savefig(pl,"../plots/$name/baselinevsturnout/carbon_price_baseline_vs_voting.pdf")

### Demand ###
pl = plot_comparison(data,"baseline","demand_dirty","power_weighted_voting","demand_dirty",true,false,"Dirty Good Demand",baseline_color,comparison_color1,"SMR","PWR",false,false)
savefig(pl,"../plots/$name/baselinevsturnout/dirty_demand_voting.pdf")

pl = plot_comparison(data,"baseline","demand_clean","power_weighted_voting","demand_clean",true,false,"Clean Good Demand",baseline_color,comparison_color1,"SMR","PWR",false,false)
savefig(pl,"../plots/$name/baselinevsturnout/clean_demand_voting.pdf")

### Policy Support ###
pl = plot_comparison(data, "baseline", "hh_policy_support", "power_weighted_voting", "hh_policy_support_weighted", true, false, "Policy Support", baseline_color, comparison_color1, "SMR", "PWR", true, false)
savefig(pl,"../plots/$name/baselinevsturnout/pol_support_baseline_vs_voting.pdf")

### Policy Support by Income Class ###
keyset1 = ["hh_policy_support_first_quintile","hh_policy_support_second_quintile","hh_policy_support_third_quintile","hh_policy_support_fourth_quintile","hh_policy_support_fifth_quintile"]
labelset = ["First Quintile", "Second Quintile","Third Quintile","Fourth Quintile","Fifth Quintile"]

pl = plot_by_income_class(data,"power_weighted_voting",reverse(keyset1),"Policy Support by Quintile",reverse(labelset),reverse(colorpalette),true)
savefig(pl,"../plots/$name/baselinevsturnout/power_weighted_voting_pol_support_by_income_class.pdf")

### Goods Demand ###
pl = plot_comparison(data,"power_weighted_voting","demand_dirty","power_weighted_voting","demand_clean",true,false,"Goods Demand","saddlebrown","darkgreen","Dirty Good Demand","Clean Good Demand",false,false)
savefig(pl,"../plots/$name/baselinevsturnout/power_weighted_voting_goods_demand.pdf")

### Goods Prices ###
pl = plot_comparison(data,"power_weighted_voting","price_dirty","power_weighted_voting","price_clean",true,false,"Goods Prices","saddlebrown","darkgreen","Dirty Good Price","Clean Good Price",false,false)
savefig(pl,"../plots/$name/baselinevsturnout/goods_prices.pdf")

### Relative Prices ###
clean_price = deepcopy(get_data_exp_key(data, "power_weighted_voting", "price_clean"))
dirty_price = deepcopy(get_data_exp_key(data, "power_weighted_voting", "price_dirty"))
rel_price = clean_price
for j in eachindex(clean_price)
	for i in 1:length(clean_price[j])
		clean_price[j][i] = clean_price[j][i]
		dirty_price[j][i] = dirty_price[j][i]
		rel_price[j][i] = dirty_price[j][i]/clean_price[j][i]
	end
end
transform_into_yearly(rel_price)

pl = plot(fontfamily="Computer Modern")
add_series_with_ribbon!(pl, rel_price, baseline_color, "Dirty/Clean Price Ratio")
savefig(pl,"../plots/$name/baselinevsturnout/power_weighted_voting_rel_price.pdf")

### Dirty Goods Demand by Income Class ###
keyset2 = ["demand_dirty_first_quintile","demand_dirty_second_quintile","demand_dirty_third_quintile","demand_dirty_fourth_quintile","demand_dirty_fifth_quintile"]
pl = plot_by_income_class(data,"power_weighted_voting",reverse(keyset2),"Dirty Good Demand by Income Class",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/baselinevsturnout/power_weighted_voting_abs_consumption.pdf")

### Clean Goods Demand by Income Class ###
keyset3 = ["demand_clean_first_quintile","demand_clean_second_quintile","demand_clean_third_quintile","demand_clean_fourth_quintile","demand_clean_fifth_quintile"]
pl = plot_by_income_class(data,"power_weighted_voting",reverse(keyset3),"Clean Good Demand by Income Class",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/baselinevsturnout/power_weighted_voting_clean_demand_income_class.pdf")

### Dirty Goods Intensity by Income Class ###
keyset4 = ["demand_intensity_dirty_lc","demand_intensity_dirty_lmc","demand_intensity_dirty_mc","demand_intensity_dirty_umc","demand_intensity_dirty_uc"]
pl = plot_by_income_class(data,"power_weighted_voting",keyset4,"Dirty Good Consumption Share by Income Class",labelset,colorpalette,false)
savefig(pl,"../plots/$name/baselinevsturnout/power_weighted_voting_rel_consumption.pdf")

### Clean Goods Intensity by Income Class ###
keyset5 = ["demand_intensity_clean_lc","demand_intensity_clean_lmc","demand_intensity_clean_mc","demand_intensity_clean_umc","demand_intensity_clean_uc"]
pl = plot_by_income_class(data,"power_weighted_voting",reverse(keyset5),"Clean Good Consumption Share by Income Class",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/baselinevsturnout/power_weighted_voting_clean_intensity_income_class.pdf")


### PREFERENCES EXPERIMENTS ###

keyset1 = ["hh_policy_support_first_quintile","hh_policy_support_second_quintile","hh_policy_support_third_quintile","hh_policy_support_fourth_quintile","hh_policy_support_fifth_quintile"]
keyset2 = ["demand_dirty_first_quintile","demand_dirty_second_quintile","demand_dirty_third_quintile","demand_dirty_fourth_quintile","demand_dirty_fifth_quintile"]
keyset3 = ["demand_clean_first_quintile","demand_clean_second_quintile","demand_clean_third_quintile","demand_clean_fourth_quintile","demand_clean_fifth_quintile"]
keyset4 = ["demand_intensity_dirty_lc","demand_intensity_dirty_lmc","demand_intensity_dirty_mc","demand_intensity_dirty_umc","demand_intensity_dirty_uc"]
keyset5 = ["demand_intensity_clean_lc","demand_intensity_clean_lmc","demand_intensity_clean_mc","demand_intensity_clean_umc","demand_intensity_clean_uc"]
keyset6 = ["dirty_lc_employees","dirty_lmc_employees","dirty_mc_employees","dirty_umc_employees","dirty_uc_employees"]

### Constant Preferences ###

### Emissions ###
pl = plot_comparison(data,"baseline","current_emissions_wrt_budget","constant","current_emissions_wrt_budget",true,true,"CO2 Emissions",baseline_color,comparison_color1,"Increasing Preferences","Constant Preferences",false,false)
savefig(pl,"../plots/$name/preferences/emissions_baseline_vs_constant_preferences.pdf")

### Carbon Price ###
pl = plot_comparison(data,"baseline","carbon_price","constant","carbon_price",true,false,"Carbon Price",baseline_color,comparison_color1,"Increasing Preferences","Constant Preferences",false,false)
savefig(pl,"../plots/$name/preferences/carbon_price_baseline_vs_constant_preferences.pdf")

### Goods Demand ###
pl = plot_comparison(data,"baseline","demand_dirty","constant","demand_dirty",true,false,"Dirty Good Demand",baseline_color,comparison_color1,"Increasing Preferences","Constant Preferences",false,false)
savefig(pl,"../plots/$name/preferences/dirty_demand_constant_preferences.pdf")

pl = plot_comparison(data,"baseline","demand_clean","constant","demand_clean",true,false,"Clean Good Demand",baseline_color,comparison_color1,"Increasing Preferences","Constant Preferences",false,false)
savefig(pl,"../plots/$name/preferences/clean_demand_constant_preferences.pdf")

### Policy Support ###
pl = plot_comparison(data, "baseline", "hh_policy_support", "constant", "hh_policy_support", true, false, "Policy Support", baseline_color, comparison_color1, "Increasing Preferences", "Constant Preferences", true, false)
savefig(pl,"../plots/$name/preferences/pol_support_comparison_base_constant.pdf")

pl = plot_by_income_class(data,"constant",reverse(keyset1),"Policy Support by Quintile, Constant Preferences",reverse(labelset),reverse(colorpalette),true)
savefig(pl,"../plots/$name/preferences/constant_preferences_pol_support_by_income_class.pdf")

### Demand Intensity ###
pl = plot_by_income_class(data,"constant",keyset4,"Dirty Good Consumption Share by Quintile, Constant Preferences",labelset,colorpalette,true)
savefig(pl,"../plots/$name/preferences/dirty_intensity_income_class_constant_preferences.pdf")




### Decreasing Preferences ###

### Emissions ###
pl = plot_comparison(data,"baseline","current_emissions_wrt_budget","decreasing","current_emissions_wrt_budget",true,true,"CO2 Emissions",baseline_color,comparison_color1,"Increasing Preferences","Decreasing Preferences",false,false)
savefig(pl,"../plots/$name/preferences/emissions_baseline_vs_decreasing_preferences.pdf")

### Carbon Price ###
pl = plot_comparison(data,"baseline","carbon_price","decreasing","carbon_price",true,false,"Carbon Price",baseline_color,comparison_color1,"Increasing Preferences","Decreasing Preferences",false,false)
savefig(pl,"../plots/$name/preferences/carbon_price_baseline_vs_decreasing_preferences.pdf")

### Goods Demand ###
pl = plot_comparison(data,"baseline","demand_dirty","decreasing","demand_dirty",true,false,"Dirty Good Demand",baseline_color,comparison_color1,"Increasing Preferences","Decreasing Preferences",false,false)
savefig(pl,"../plots/$name/preferences/dirty_demand_decreasing_preferences.pdf")

pl = plot_comparison(data,"baseline","demand_clean","decreasing","demand_clean",true,false,"Clean Good Demand",baseline_color,comparison_color1,"Increasing Preferences","Decreasing Preferences",false,false)
savefig(pl,"../plots/$name/preferences/clean_demand_decreasing_preferences.pdf")

### Policy Support ###
pl = plot_comparison(data, "baseline", "hh_policy_support", "decreasing", "hh_policy_support", true, false, "Policy Support", baseline_color, comparison_color1, "Increasing Preferences", "Decreasing Preferences", true, false)
savefig(pl,"../plots/$name/preferences/pol_support_comparison_base_decreasing.pdf")

pl = plot_comparison(data, "baseline", "hh_policy_support_first_quintile", "decreasing", "hh_policy_support_first_quintile", true, false, "Policy Support", baseline_color, comparison_color1, "Increasing Preferences", "Decreasing Preferences", true, false)
savefig(pl,"../plots/$name/preferences/pol_support_first_quintile_base_decreasing.pdf")

pl = plot_comparison(data, "baseline", "hh_policy_support_second_quintile", "decreasing", "hh_policy_support_second_quintile", true, false, "Policy Support", baseline_color, comparison_color1, "Increasing Preferences", "Decreasing Preferences", true, false)
savefig(pl,"../plots/$name/preferences/pol_support_second_quintile_base_decreasing.pdf")

pl = plot_comparison(data, "baseline", "hh_policy_support_third_quintile", "decreasing", "hh_policy_support_third_quintile", true, false, "Policy Support", baseline_color, comparison_color1, "Increasing Preferences", "Decreasing Preferences", true, false)
savefig(pl,"../plots/$name/preferences/pol_support_third_quintile_base_decreasing.pdf")

pl = plot_comparison(data, "baseline", "hh_policy_support_fourth_quintile", "decreasing", "hh_policy_support_fourth_quintile", true, false, "Policy Support", baseline_color, comparison_color1, "Increasing Preferences", "Decreasing Preferences", true, false)
savefig(pl,"../plots/$name/preferences/pol_support_fourth_quintile_base_decreasing.pdf")


pl = plot_comparison(data, "baseline", "hh_policy_support_fifth_quintile", "decreasing", "hh_policy_support_fifth_quintile", true, false, "Policy Support", baseline_color, comparison_color1, "Increasing Preferences", "Decreasing Preferences", true, false)
savefig(pl,"../plots/$name/preferences/pol_support_fifth_quintile_base_decreasing.pdf")


pl = plot_by_income_class(data,"decreasing",reverse(keyset1),"Policy Support by Quintile",reverse(labelset),reverse(colorpalette),true)
savefig(pl,"../plots/$name/preferences/decreasing_preferences_pol_support_by_income_class.pdf")

### Demand Intensity ###
pl = plot_by_income_class(data,"decreasing",reverse(keyset4),"Dirty Good Consumption Share by Quintile",reverse(labelset),reverse(colorpalette),true)
savefig(pl,"../plots/$name/preferences/dirty_intensity_income_class_decreasing_preferences.pdf")

