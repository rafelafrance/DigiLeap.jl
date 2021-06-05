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

# ╔═╡ bf2b8bf6-c281-11eb-1830-57b105bc4b13
begin
	using CSV
	using DataFrames
	using ImageDraw
	using Images
	using JSON
	using PlutoUI
end

# ╔═╡ 39280d20-cf59-4819-b656-00de8de6ca5a
md"""# Display Reconciled Bounding Boxes"""

# ╔═╡ 46e1eb9d-19fc-4176-86fe-f57a4e37579d
md"""## File locations"""

# ╔═╡ be57fa62-073c-4d68-ba7a-f030409b1fab
begin
	LABEL_BABEL_2 = "data/label-babel-2"
	SHEETS_2 = "$LABEL_BABEL_2/herbarium-sheets-small"
	RECONCILED = "$LABEL_BABEL_2/17633_label_babel_2.reconciled.csv"
end

# ╔═╡ 62f76c0a-236b-4aa9-ab27-e0ae67108de1
md"""## Read reconciled data"""

# ╔═╡ c52ab234-83fc-48d5-a3a8-3b8f23031b55
df = CSV.File(RECONCILED) |> DataFrame

# ╔═╡ e8ef035a-4e4d-4a22-9a09-b78d2e127abf
md"""## Display bounding box given JSON coordinates"""

# ╔═╡ ba6b0ce3-d1f3-4498-872f-1d8b6cd456ae
function draw_rectangle(image, coords; color=RGB(0, 0, 0), thickness=1)
	ll, tt, rr, bb = coords

	max_h, max_w = size(image)

	ll, rr = clamp(ll, 1, max_w), clamp(rr, 1, max_w)
	tt, bb = clamp(tt, 1, max_h), clamp(bb, 1, max_h)

	image[tt:clamp(tt+thickness, 1, max_h), ll:rr] .= color
	image[clamp(bb-thickness, 1, max_h):bb, ll:rr] .= color
	image[tt:bb, ll:clamp(ll+thickness, 1, max_w)] .= color
	image[tt:bb, clamp(rr-thickness, 1, max_w):rr] .= color
end

# ╔═╡ 70cacb63-709a-42ee-bc84-b14266510adc
function draw_box(image, box, color; thickness=1)
	box = JSON.parse(box)
	ll, tt, rr, bb = box["left"], box["top"], box["right"], box["bottom"]
	draw_rectangle(image, (ll, tt, rr, bb), color=color, thickness=thickness)
end

# ╔═╡ 4f19d1e2-1469-4594-8476-5d0f7008e191
# function draw_box_new(image, box, color; width=1)
# 	box = JSON.parse(box)
# 	ll, tt, rr, bb = box["left"], box["top"], box["right"], box["bottom"]
# 	draw!(image, Polygon(RectanglePoints(ll, tt, rr, bb)), color)
# end

# ╔═╡ 3c70dabb-a4c9-4a10-8832-01440d5ada83
md"""## Show all bounding boxes for a subject"""

# ╔═╡ 29d7ff04-4cc2-474d-9c81-8d4462812d5a
function show_boxes(idx)
	row = df[idx, :]
	row = Dict(pairs(skipmissing(row)))

	path = "$SHEETS_2/$(row[:subject_file_name])"

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
# ╠═bf2b8bf6-c281-11eb-1830-57b105bc4b13
# ╟─46e1eb9d-19fc-4176-86fe-f57a4e37579d
# ╠═be57fa62-073c-4d68-ba7a-f030409b1fab
# ╟─62f76c0a-236b-4aa9-ab27-e0ae67108de1
# ╠═c52ab234-83fc-48d5-a3a8-3b8f23031b55
# ╟─e8ef035a-4e4d-4a22-9a09-b78d2e127abf
# ╠═ba6b0ce3-d1f3-4498-872f-1d8b6cd456ae
# ╠═70cacb63-709a-42ee-bc84-b14266510adc
# ╠═4f19d1e2-1469-4594-8476-5d0f7008e191
# ╟─3c70dabb-a4c9-4a10-8832-01440d5ada83
# ╠═29d7ff04-4cc2-474d-9c81-8d4462812d5a
# ╟─7b9ee6de-f3a4-42ba-ab6b-7efc2e2e6236
# ╟─db853124-c950-4951-a9d3-19f208fac09a
# ╠═04d5ee1f-dd31-4f9c-967b-b0535d76392d
# ╠═50f35ce4-4d2c-47e1-9c6f-7079993e00a6
