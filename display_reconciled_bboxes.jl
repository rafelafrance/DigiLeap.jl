### A Pluto.jl notebook ###
# v0.15.1

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
	using Pkg
	Pkg.activate(".")

	using Revise
	using DataFrames
	using Images
	using ImageDraw
	using JSON
	using PlutoUI

	using DigiLeap
end

# ╔═╡ 39280d20-cf59-4819-b656-00de8de6ca5a
md"""# Display Reconciled Bounding Boxes"""

# ╔═╡ 39b004ba-295b-4e56-8023-de2a1d36b5ea
md"""# Setup"""

# ╔═╡ 46e1eb9d-19fc-4176-86fe-f57a4e37579d
md"""## File locations"""

# ╔═╡ be57fa62-073c-4d68-ba7a-f030409b1fab
begin
	LABEL_BABEL_2 = "data/label-babel-2"
	SHEETS_2 = "$LABEL_BABEL_2/herbarium-sheets-small"
	RECONCILED = "output/17633_label_babel_2.reconciled.jsonl"
end

# ╔═╡ 62f76c0a-236b-4aa9-ab27-e0ae67108de1
md"""## Read reconciled data"""

# ╔═╡ c52ab234-83fc-48d5-a3a8-3b8f23031b55
df = CSV.File(RECONCILED) |> DataFrame

# ╔═╡ e8ef035a-4e4d-4a22-9a09-b78d2e127abf
md"""## Display bounding box given JSON coordinates"""

# ╔═╡ b309306e-b3f0-43b4-b1b9-b40498b72879
function json_box(image, box, color; thickness=1)
	bx = JSON.parse(box)
	ll, tt, rr, bb = bx["left"], bx["top"], bx["right"], bx["bottom"]

	h, w = size(image)

	for i in 1:thickness
		draw!(image, Polygon(RectanglePoints(Point(ll, tt), Point(rr, bb))), color)
	end
end

# ╔═╡ 3c70dabb-a4c9-4a10-8832-01440d5ada83
md"""## Show all bounding boxes for a subject"""

# ╔═╡ 29d7ff04-4cc2-474d-9c81-8d4462812d5a
function show_boxes(idx)
	row = df[idx, :]
	row = Dict(pairs(skipmissing(row)))

	path = "$SHEETS_2/$(row[:image_file])"

	image = load(path)

	for b in [v for (k, v) in pairs(row) if startswith(string(k), "merged_box_")]
		json_box(image, b, RGB{N0f8}(0.75, 0, 0), thickness=4)
	end

	for b in [v for (k, v) in pairs(row) if startswith(string(k), "removed_box_")]
		json_box(image, b, RGB{N0f8}(0, 0.75, 0), thickness=4)
	end

	for b in [v for (k, v) in pairs(row) if startswith(string(k), "box_")]
		json_box(image, b, RGB{N0f8}(0.25, 0.25, 0.75))
	end

	image
end

# ╔═╡ d63abc39-7628-4429-a191-422ed3605e08
@bind idx Slider(1:size(df, 1); show_value=true)

# ╔═╡ 7b9ee6de-f3a4-42ba-ab6b-7efc2e2e6236
md"""## Choose a subject"""

# ╔═╡ 04d5ee1f-dd31-4f9c-967b-b0535d76392d
show_boxes(idx)

# ╔═╡ ff2ce5ae-b9d8-4395-ac04-bb3ced50cfb8


# ╔═╡ Cell order:
# ╟─39280d20-cf59-4819-b656-00de8de6ca5a
# ╟─39b004ba-295b-4e56-8023-de2a1d36b5ea
# ╠═bf2b8bf6-c281-11eb-1830-57b105bc4b13
# ╟─46e1eb9d-19fc-4176-86fe-f57a4e37579d
# ╠═be57fa62-073c-4d68-ba7a-f030409b1fab
# ╟─62f76c0a-236b-4aa9-ab27-e0ae67108de1
# ╠═c52ab234-83fc-48d5-a3a8-3b8f23031b55
# ╟─e8ef035a-4e4d-4a22-9a09-b78d2e127abf
# ╠═b309306e-b3f0-43b4-b1b9-b40498b72879
# ╟─3c70dabb-a4c9-4a10-8832-01440d5ada83
# ╠═29d7ff04-4cc2-474d-9c81-8d4462812d5a
# ╠═d63abc39-7628-4429-a191-422ed3605e08
# ╟─7b9ee6de-f3a4-42ba-ab6b-7efc2e2e6236
# ╠═04d5ee1f-dd31-4f9c-967b-b0535d76392d
# ╠═ff2ce5ae-b9d8-4395-ac04-bb3ced50cfb8
