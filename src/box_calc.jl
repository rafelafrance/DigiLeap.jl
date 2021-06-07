"""Calculate the intersection over union (IOU) of a pair of boxes."""
function iou(box1, box2)
	# Get interior dimensions of any overlap
	x1 = max(box1[1], box2[1])
	y1 = max(box1[2], box2[2])
	x2 = min(box1[3], box2[3])
	y2 = min(box1[4], box2[4])

	inter = max(0, x2 - x1 + 1) * max(0, y2 - y1 + 1)
	area1 = (box1[3] - box1[1] + 1) * (box1[4] - box1[2] + 1)
	area2 = (box2[3] - box2[1] + 1) * (box2[4] - box2[2] + 1)

	inter / (area1 + area2 - inter)
end


"""Non-maximum suppression of bounding boxes.

This finds the largest bounding boxes and remove all other smaller boxes that
overlap with them by having an intersection over union (IOU) that is greater
than or equal to the given threshold. The output boxes are sorted by area descending.
"""
function nms(boxes; threshold=0.3)
	foxes = convert(Matrix{Float32}, boxes)

	# Simplify access to box components
	x1, y1, x2, y2 = foxes[:, 1], foxes[:, 2], foxes[:, 3], foxes[:, 4]

	area = (x2 .- x1 .+ 1.0) .* (y2 .- y1 .+ 1.0)
	idx = sortperm(area)

	non_overlapping = []
	while length(idx) > 0
		# Append another non-overlapping box
		curr = pop!(idx)
		push!(non_overlapping, curr)

		# Get interior (overlap) coordinates
		xx1 = max.(x1[idx], x1[curr])
		yy1 = max.(y1[idx], y1[curr])
		xx2 = min.(x2[idx], x2[curr])
		yy2 = min.(y2[idx], y2[curr])

		# Calculate the intersection over union
		inter = max.(0.0, xx2 .- xx1 .+ 1.0) .* max.(0.0, yy2 .- yy1 .+ 1.0)
		overlap = inter ./ (area[curr] .+ area[idx] .- inter)

		# Find all IOUs smaller than threshold and keep them
		idx = idx[overlap .< threshold]
	end

	reverse!(non_overlapping)
	boxes[non_overlapping, :]
end
