using Serialization, ArgParse
using Plots,TensorCast

include("model/model.jl")

#load data from conducted experiment 
function load_data(config)

	include(config)

	# load data
	folder_data = "../data/$folder"

	results = []
	chunk = 0
	#add data to result for all chunks 
	#as long as there is another data file 
	while isfile("$folder_data/data-$(chunk+=1).dat")
		#add results to results list
		append!(results, deserialize("$folder_data/data-$chunk.dat"))
	end

	#print error message if no data found 
	if length(results) == 0
		println("ERROR: No data found in $folder_data")
		exit(1)
	end

	data = Dict()

	#returns the length of the first data set
	plot_it = size(results[1][:model_data],1)

	for (exp_name, props) in experiments
		data[exp_name] = []

		#if more than one data-chunk.dat file
		for i in eachindex(results)
			if results[i][:exp_name] == exp_name
				#add the model data to the data dictionary of the specific experiment
				append!(data[exp_name], [results[i][:model_data][burn_in_months+1:plot_it,:]])
			end
		end
	end

	#return the data dictionary 
	return data
end


function get_data_exp_key(data, exp, key)
	data_exp_key=[]
	#for each run of one experiment get all the data of a specific key, e.g. "carbon_price"

	for i in 1:length(data[exp])
		append!(data_exp_key, [data[exp][i][!,key]])
	end
	return data_exp_key
end

function get_mean_upper_lower(data, conf_level=0.25)
	#transpose data (?)
    @cast data_t[i][j] := data[j][i]

	mean_data = []
	upper =[]
	lower = []

	#take the mean over all rows 
	for i in 1:length(data_t)
		append!(mean_data, mean(data_t[i]))
		if !isnan(mean(data_t[i]))
			#take the upper and lower quantile over all rows 
			append!(upper, quantile(data_t[i], 1-conf_level/2) - mean(data_t[i]))
			append!(lower, mean(data_t[i]) - quantile(data_t[i], conf_level/2))
		else
			append!(upper, NaN)
			append!(lower, NaN)
		end
	end

	return mean_data, upper, lower
end

function add_series_with_ribbon!(pl, series, color, label)
	mean_data, upper, lower = get_mean_upper_lower(series)
	plot!(pl,years, mean_data, color=color, label=label, linewidth=1, ribbon = (lower, upper))
	return pl
end

function add_series_all_runs!(pl, data, exp, var, color, label)
	series = get_data_exp_key(data, exp, var)
	
	c=0
	for d in series
		if (c+=1)==1
			plot!(pl, d, color=color, label=label, linewidth=0.5)
		else
			plot!(pl, d, color=color, label="", linewidth=0.5)
		end
	end

	return pl
end

function plot_comparison(data, exp1, key1, exp2, key2,ribbon, budgets, title, color1, color2, label1, label2, support, yearly)
	series1 = deepcopy(get_data_exp_key(data, exp1, key1))
	series2 = deepcopy(get_data_exp_key(data, exp2, key2))

	if yearly
		series_new1 = []
		series_new2 = []
		for i in eachindex(series1)
			append!(series_new1, [series1[i][960]])
			append!(series_new2, [series2[i][960]])
		end
		series1 = mean(series_new1)
		series2 = mean(series_new2)

		deleteat!(series1,1:84)
		deleteat!(series2,1:84)
	else
		transform_into_yearly(series1)
		transform_into_yearly(series2)
		if support 
			series1[1] = series1[2]
			series2[1] = series2[2]
		end
	end
	
	pl = plot(title=title, fontfamily="Computer Modern")
	if ribbon 
		add_series_with_ribbon!(pl, series1, color1, label1)
		add_series_with_ribbon!(pl, series2, color2, label2)
	else
		plot!(pl,years,series1, color=color1,label=label1)
		plot!(pl,years,series2, color=color2,label=label2)
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
	pl = plot(title=title, fontfamily="Computer Modern")
	if ribbon 
		add_series_with_ribbon!(pl, series, color, label)
	else
		plot!(pl,years,series,color=color,label=label,linewidth=1)
	end

	if budgets == true 
		plot_budgets(pl)
	end

	return pl
end


function plot_comparison_all_runs(data, exp1, var1, exp2, var2, color1, color2, filename)
	data1 = get_data_exp_key(data, exp1, var1)
	data2 = get_data_exp_key(data, exp2, var2)

	pl = plot()
	for d in data1
		plot!(pl, d, color=color1, label="", linewidth=0.5)
	end
	for d in data2
		plot!(pl, d, color=color2, label="", linewidth=0.5)
	end

	return pl
end

function plot_by_quintile(data,exp,keyset,title,labelset,colorpalette,support)
	pl = plot(title=title, fontfamily="Computer Modern")
	
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

		if !support
			plot!(years,mean_series,color=colorpalette[i],label=labelset[i])
		else
			plot!(years,mean_series,color=colorpalette[i],label=labelset[i], ylim=(0,1))
		end

	end
	
	return pl
end


function plot_budgets(pl)
	#plot!(pl, years, emission_path[!, "1.5"], color="darkgreen", label="1.5°", linestyle=:dash)
	plot!(pl, years, emission_path[!, "2"], color="fuchsia", label="2.0°", linestyle=:dash)
	#plot!(pl, years, emission_path[!, "3"], color="darkorange", label="3.0°", linestyle=:dash)
	#plot!(pl, years, emission_path[!, "4"], color="red", label="4.0°", linestyle=:dash)
end

data = load_data("experiments/baseline.jl")
emission_path = CSV.read("../data/EmissionsUSA.csv", DataFrame)

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


name = "baseline"

mkpath("../plots/$name/")






### BASELINE PLOTS ###
baseline_color = "#6C7A89" 
colorpalette = ["mediumblue","cornflowerblue","lightpink","coral","red"]

### Carbon price ###
pl = plot_single(data,"baseline","carbon_price",false,"Carbon Price",baseline_color,"Baseline",false,true)
savefig(pl,"../plots/$name/baseline_carbon_price.png")

### Emissions budgets ###
pl = plot_single(data,"baseline","current_emissions_wrt_budget",true,"CO2 Emissions",baseline_color,"Baseline",false,true)
savefig(pl,"../plots/$name/baseline_emissions_budget.png")

### Policy Support by Quintile ###
keyset1 = ["hh_policy_support_first_quintile","hh_policy_support_second_quintile","hh_policy_support_third_quintile","hh_policy_support_fourth_quintile","hh_policy_support_fifth_quintile"]
labelset = ["First Quintile", "Second Quintile","Third Quintile","Fourth Quintile","Fifth Quintile"]

pl = plot_by_quintile(data,"baseline",reverse(keyset1),"Policy Support by Quintile",reverse(labelset),reverse(colorpalette),true)
savefig(pl,"../plots/$name/baseline_pol_support_by_quintile.png")

### Policy Support ###
pl = plot_single(data,"baseline","hh_policy_support",false,"Policy Support",baseline_color,"Baseline",true,false)
savefig(pl,"../plots/$name/pol_support.png")

### Goods Demand ###
pl = plot_comparison(data,"baseline","demand_dirty","baseline","demand_clean",true,false,"Goods Demand","#652121","darkolivegreen","Dirty Good Demand","Clean Good Demand",false,false)
savefig(pl,"../plots/$name/goods_demand.png")

### Goods Prices ###
pl = plot_comparison(data,"baseline","price_dirty","baseline","price_clean",true,false,"Goods Prices","#652121","darkolivegreen","Dirty Good Price","Clean Good Price",false,false)
savefig(pl,"../plots/$name/goods_prices.png")

### Dirty Goods Demand by Quintile ###
keyset2 = ["demand_dirty_first_quintile","demand_dirty_second_quintile","demand_dirty_third_quintile","demand_dirty_fourth_quintile","demand_dirty_fifth_quintile"]
pl = plot_by_quintile(data,"baseline",reverse(keyset2),"Dirty Good Demand by Quintile",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/dirty_demand_quintile.png")

### Clean Goods Demand by Quintile ###
keyset3 = ["demand_clean_first_quintile","demand_clean_second_quintile","demand_clean_third_quintile","demand_clean_fourth_quintile","demand_clean_fifth_quintile"]
pl = plot_by_quintile(data,"baseline",reverse(keyset3),"Clean Good Demand by Quintile",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/clean_demand_quintile.png")

### Dirty Goods Intensity by Quintile ###
keyset4 = ["demand_intensity_dirty_lc","demand_intensity_dirty_lmc","demand_intensity_dirty_mc","demand_intensity_dirty_umc","demand_intensity_dirty_uc"]
pl = plot_by_quintile(data,"baseline",keyset4,"Dirty Good Consumption Share by Quintile",labelset,colorpalette,false)
savefig(pl,"../plots/$name/dirty_intensity_quintile.png")


### Clean Goods Intensity by Quintile ###
keyset5 = ["demand_intensity_clean_lc","demand_intensity_clean_lmc","demand_intensity_clean_mc","demand_intensity_clean_umc","demand_intensity_clean_uc"]
pl = plot_by_quintile(data,"baseline",reverse(keyset5),"Clean Good Consumption Share by Quintile",reverse(labelset),reverse(colorpalette),false)
savefig(pl,"../plots/$name/clean_intensity_quintile.png")


