### A Pluto.jl notebook ###
# v0.14.7

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 5cbedf9e-3bfb-4862-b7b0-4f53715bbbc7
using Revise

# ╔═╡ bf2b8bf6-c281-11eb-1830-57b105bc4b13
begin
	using CSV
	using DataFrames
	using DigiLeap
	using Images
	using JSON
	using PlutoUI
end

# ╔═╡ 39b004ba-295b-4e56-8023-de2a1d36b5ea
md"""# Setup"""

# ╔═╡ 46e1eb9d-19fc-4176-86fe-f57a4e37579d
md"""## File locations"""

# ╔═╡ be57fa62-073c-4d68-ba7a-f030409b1fab
begin
	LABEL_BABEL_2 = "data/label-babel-2"
	SHEETS_2 = "$LABEL_BABEL_2/herbarium-sheets-small"
	UNRECONCILED = "$LABEL_BABEL_2/17633_label_babel_2.unreconciled.csv"
	RECONCILED = "$LABEL_BABEL_2/17633_label_babel_2.reconciled.csv"
end

# ╔═╡ 39280d20-cf59-4819-b656-00de8de6ca5a
md"""# Display Reconciled Bounding Boxes"""

# ╔═╡ 62f76c0a-236b-4aa9-ab27-e0ae67108de1
md"""## Read reconciled data"""

# ╔═╡ c52ab234-83fc-48d5-a3a8-3b8f23031b55
df = CSV.File(RECONCILED) |> DataFrame

# ╔═╡ e8ef035a-4e4d-4a22-9a09-b78d2e127abf
md"""## Display bounding box given JSON coordinates"""

# ╔═╡ 70cacb63-709a-42ee-bc84-b14266510adc
function draw_box(image, box, color; thickness=1)
	box = JSON.parse(box)
	ll, tt, rr, bb = box["left"], box["top"], box["right"], box["bottom"]
	simple_box(image, (ll, tt, rr, bb), color=color, thickness=thickness)
end

# ╔═╡ 3c70dabb-a4c9-4a10-8832-01440d5ada83
md"""## Show all bounding boxes for a subject"""

# ╔═╡ 29d7ff04-4cc2-474d-9c81-8d4462812d5a
function show_boxes(idx)
	row = df[idx, :]
	row = Dict(pairs(skipmissing(row)))

	path = "$SHEETS_2/$(row[:image_file])"

	image = load(path)

	for box in [v for (k, v) in pairs(row) if startswith(string(k), "merged_box_")]
		draw_box(image, box, RGB(0.75, 0, 0); thickness=4)
	end

	for box in [v for (k, v) in pairs(row) if startswith(string(k), "box_")]
		draw_box(image, box, RGB(0.25, 0.25, 0.75))
	end

	for box in [v for (k, v) in pairs(row) if startswith(string(k), "removed_box_")]
		draw_box(image, box, RGB(0, 0.75, 0); thickness=4)
	end

	image
end

# ╔═╡ 7b9ee6de-f3a4-42ba-ab6b-7efc2e2e6236
md"""## Choose a subject"""

# ╔═╡ db853124-c950-4951-a9d3-19f208fac09a
@bind idx Slider(1:size(df, 1); show_value=true)

# ╔═╡ 04d5ee1f-dd31-4f9c-967b-b0535d76392d
show_boxes(idx)

# ╔═╡ 50f35ce4-4d2c-47e1-9c6f-7079993e00a6


# ╔═╡ Cell order:
# ╟─39280d20-cf59-4819-b656-00de8de6ca5a
# ╟─39b004ba-295b-4e56-8023-de2a1d36b5ea
# ╠═5cbedf9e-3bfb-4862-b7b0-4f53715bbbc7
# ╠═bf2b8bf6-c281-11eb-1830-57b105bc4b13
# ╟─46e1eb9d-19fc-4176-86fe-f57a4e37579d
# ╠═be57fa62-073c-4d68-ba7a-f030409b1fab
# ╟─62f76c0a-236b-4aa9-ab27-e0ae67108de1
# ╠═c52ab234-83fc-48d5-a3a8-3b8f23031b55
# ╟─e8ef035a-4e4d-4a22-9a09-b78d2e127abf
# ╠═70cacb63-709a-42ee-bc84-b14266510adc
# ╟─3c70dabb-a4c9-4a10-8832-01440d5ada83
# ╠═29d7ff04-4cc2-474d-9c81-8d4462812d5a
# ╟─7b9ee6de-f3a4-42ba-ab6b-7efc2e2e6236
# ╟─db853124-c950-4951-a9d3-19f208fac09a
# ╠═04d5ee1f-dd31-4f9c-967b-b0535d76392d
# ╠═50f35ce4-4d2c-47e1-9c6f-7079993e00a6
