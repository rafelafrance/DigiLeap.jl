"""Calculate the intersection over union (IOU) of a pair of boxes."""
function iou(box1, box2)
	# Get interior dimensions of any overlap
	x_min = max(box1[1], box2[1])
	y_min = max(box1[2], box2[2])
	x_max = min(box1[3], box2[3])
	y_max = min(box1[4], box2[4])

	inter = max(0, x_max - x_min + 1) * max(0, y_max - y_min + 1)
	area1 = (box1[3] - box1[1] + 1) * (box1[4] - box1[2] + 1)
	area2 = (box2[3] - box2[1] + 1) * (box2[4] - box2[2] + 1)

	inter / (area1 + area2 - inter)
end


"""Find non-maximum suppression groups of bounding boxes.

This finds and labels all boxes in each non-maximum suppression group
and marks the keepers with a positive group number and all of the ones
normally removed by NMS with negative values. For instance group 3's winner
is labeled with a 3 and losers are marked -3.

We use this function for variants of bounding box non-maximum suppression.

Modified from Matlab code:
https://www.computervisionblog.com/2011/08/blazing-fast-nmsm-from-exemplar-svm.html
"""
function bbox_nms_groups(boxes; threshold=0.3)
	foxes = convert(Matrix{Float64}, boxes)

	# Simplify access to box components
	x_min, y_min, x_max, y_max = foxes[:, 1], foxes[:, 2], foxes[:, 3], foxes[:, 4]

	area = (x_max .- x_min .+ 1.0) .* (y_max .- y_min .+ 1.0)
	idx = sortperm(area)

	overlapping = zeros(Int, length(idx))
	group = 0

	while length(idx) > 0
		# Start another box group
		group += 1
		curr = pop!(idx)
		overlapping[curr] = group

		# Get interior (overlap) coordinates
		left   = max.(x_min[idx], x_min[curr])
		top    = max.(y_min[idx], y_min[curr])
		right  = min.(x_max[idx], x_max[curr])
		bottom = min.(y_max[idx], y_max[curr])

		# Calculate the intersection over union
		inter = max.(0.0, right .- left .+ 1.0) .* max.(0.0, bottom .- top .+ 1.0)
		overlap = inter ./ (area[curr] .+ area[idx] .- inter)

		# Mark all other bounding boxes in the group
		group_mask = overlap .>= threshold
		overlapping[idx[group_mask]] .= -group

		# Remove bounding boxes in the current group from further consideration
		idx = idx[.!group_mask]
	end

	overlapping
end


"""Non-maximum suppression of bounding boxes."""
function bbox_nms(boxes; threshold=0.3)
	groups = bbox_nms_groups(boxes; threshold=threshold)
	boxes[groups .> 0, :]
end


"""Find overlapping groups of bounding boxes."""
function overlapping_bboxes(boxes; threshold=0.3)
	groups = bbox_nms_groups(boxes; threshold=threshold)
	abs.(groups)
end
