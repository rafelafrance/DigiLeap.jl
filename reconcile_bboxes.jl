#!/home/rafe/bin/julia

using CSV
using DataFrames
using DigiLeap
using JSON

# File locations"""
LABEL_BABEL_2 = "data/label-babel-2"
SHEETS_2 = "$LABEL_BABEL_2/herbarium-sheets-small"
UNRECONCILED = "$LABEL_BABEL_2/17633_label_babel_2.unreconciled.csv"
RECONCILED = "$LABEL_BABEL_2/17633_label_babel_2.reconciled.csv"

# Read unreconciled data
unreconciled = CSV.File(UNRECONCILED) |> DataFrame

# These structures are used while converting Notes from Nature expedition data that
# identifies labels on a herbarium sheet to reconciled (combined) subject data.
# The data is temporary and has a singular use.
mutable struct MergedBox
	type_::String
	group::Int64
	box::Array{Int64}
	MergedBox(lb, box) = new(lb, 0, box)
end

mutable struct MergedSubject
	subject_id::Int64
	file_name::String
	boxes::Array{MergedBox}
	deleted::Array{MergedBox}
	merged::Array{MergedBox}
	MergedSubject(sid::Int64, fn::String) = new(sid, fn, [], [], [])
end

"""Convert JSON bounding box to an array"""
function bbox_from_json(json_box::String)
    box = JSON.parse(json_box)
    [box["left"] box["top"] box["right"] box["bottom"]]
end

"""Convert all boxes in a subject into matrix form"""
function boxes2array(recon_boxes::Array{MergedBox})
	boxes = Array{Int64}(undef, 0, 4)
	for box in recon_boxes
		boxes = vcat(boxes, box.box)
	end
	boxes
end

# Group classifications by subject
by_subject = groupby(unreconciled, :subject_id)

# Initialize an array of subject records.
subjects = []
for old_sub in by_subject
	sid::Int64 = old_sub.subject_id[1]
	fn::String = old_sub.subject_Filename[1]
	sub = MergedSubject(sid, fn)

	for row in eachrow(old_sub)
		row = Dict(pairs(skipmissing(row)))

		prefix = "Box(es): box"
		boxes = [v for (k, v) in pairs(row) if startswith(string(k), prefix)]

		prefix = "Box(es): select"
		types = [v for (k, v) in pairs(row) if startswith(string(k), prefix)]

		for (box, type_) in zip(boxes, types)
			box = bbox_from_json(box)
			push!(sub.boxes, MergedBox(type_, box))
		end

	end

	push!(subjects, sub)
end

"""Merge bounding boxes

Merge all boxes in each group of boxes into a single "best" bound box.

There is a slight wrinkle here in that when labels are next to each
other on the herbarium sheet some people lump them into one large
bounding box and others draw boxes around the individual labels.
We'd prefer to have the individual bounding boxes for each label
so we're going to do some extra processing to see if we can get them.
"""
function delete_multi_labels(subject, groups)
	to_delete = zeros(Bool, length(groups))
	for g in 1:findmax(groups)[1]
		sub_boxes = boxes2array(subject.boxes[groups .== -g])
		subgroups = bbox_nms_groups(sub_boxes)
		if length(subgroups) > 0 && findmax(subgroups)[1] > 1
			idx = findfirst(groups .== g)
			push!(subject.deleted, subject.boxes[idx])
			to_delete[idx] = 1
		end
	end
	to_delete
end

function delete_unlabeled(subject, groups)
	to_delete = zeros(Bool, length(groups))
	for g in 1:findmax(groups)[1]
		sub_boxes = boxes2array(subject.boxes[groups .== -g])
		if length(sub_boxes) == 0
			idx = findfirst(groups .== g)
			push!(subject.deleted, subject.boxes[idx])
			to_delete[idx] = 1
		end
	end
	to_delete
end

for subject in subjects
	boxes = boxes2array(subject.boxes)
	groups = bbox_nms_groups(boxes)
	for (box, group) in zip(subject.boxes, groups)
		box.group = group
	end

	if length(groups) == 0
		continue
	end

	to_delete = delete_multi_labels(subject, groups)
	to_delete .|= delete_unlabeled(subject, groups)
	deleteat!(subject.boxes, to_delete)

	boxes = boxes2array(subject.boxes)
	groups = overlapping_bboxes(boxes)
	for g in 1:findmax(groups)[1]
		boxes = boxes2array(subject.boxes[groups .== g])
		min_x = minimum(boxes[:, 1])
		min_y = minimum(boxes[:, 2])
		max_x = maximum(boxes[:, 3])
		max_y = maximum(boxes[:, 4])
		types = [b.type_ for b in subject.boxes]
		type_ = join(types, "_")
		box = MergedBox(type_, [min_x, min_y, max_x, max_y])
		push!(subject.merged, box)
	end
end
