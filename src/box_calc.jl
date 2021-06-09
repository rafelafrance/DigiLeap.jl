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


"""Find non-maximum suppression groups of bounding boxes.

This finds and labels all boxes in each non-maximum suppression group and marks the
keepers with a positive group number and all of the ones normally removed by NMS with
negative values. For instance group 3's winner is labeled with a 3 and losers are
marked -3.

We use this function for variants of bounding box non-maximum suppression.

Modified from Matlab code:
https://www.computervisionblog.com/2011/08/blazing-fast-nmsm-from-exemplar-svm.html
"""
function bbox_nms_groups(boxes; threshold=0.3)
	foxes = convert(Matrix{Float32}, boxes)

	# Simplify access to box components
	x1, y1, x2, y2 = foxes[:, 1], foxes[:, 2], foxes[:, 3], foxes[:, 4]

	area = (x2 .- x1 .+ 1.0) .* (y2 .- y1 .+ 1.0)
	idx = sortperm(area)

	overlapping = zeros(Int32, length(idx))
	group = 0

	while length(idx) > 0
		# Append another non-overlapping box
		group += 1
		curr = pop!(idx)
		overlapping[curr] = group

		# Get interior (overlap) coordinates
		xx1 = max.(x1[idx], x1[curr])
		yy1 = max.(y1[idx], y1[curr])
		xx2 = min.(x2[idx], x2[curr])
		yy2 = min.(y2[idx], y2[curr])

		# Calculate the intersection over union
		inter = max.(0.0, xx2 .- xx1 .+ 1.0) .* max.(0.0, yy2 .- yy1 .+ 1.0)
		overlap = inter ./ (area[curr] .+ area[idx] .- inter)

		# Mark all other bounding boxes in the group
		in_group = idx[overlap .>= threshold]
		overlapping[in_group] .= -group

		# Remove bounding boxes in the current group from further consideration
		idx = idx[overlap .< threshold]
	end

	overlapping
end


"""Non-maximum suppression of bounding boxes."""
function bbox_nms(boxes; threshold=0.3)
	groups = bbox_nms_groups(boxes; threshold=threshold)
	boxes[groups .> 0, :]
end
