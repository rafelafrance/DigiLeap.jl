#!/home/rafe/bin/julia

using CSV
using DataFrames
using DigiLeap
using JSON

# File locations"""
LABEL_BABEL_2 = "data/label-babel-2"
UNRECONCILED = "$LABEL_BABEL_2/17633_label_babel_2.unreconciled.csv"
RECONCILED = "$LABEL_BABEL_2/17633_label_babel_2.reconciled.csv"

# These structures are used while converting Notes from Nature expedition data that
# identifies labels on a herbarium sheet to reconciled (combined) subject data.
# The data is temporary and is only used here.

"""Holds the coordinates and type of a bounding box."""
struct MergedBox
    box::Array{Int64}
    type_::String
    MergedBox(lb, box) = new(box, lb)
end


"""Used to organize all of the bounding boxes on a herbarium sheet."""
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


"""Convert the CSV/JSON input data into an array of MergedSubject records."""
function init_subject_records(by_subject)
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
    subjects
end



"""Remove bad bounding boxes from the subject."""
function delete_bad_boxes(subject, groups)
    to_delete = delete_multi_labels(subject, groups)
    to_delete .|= delete_unlabeled(subject, groups)
    subject.deleted = subject.boxes[to_delete]
    deleteat!(subject.boxes, to_delete)
end


"""Delete bounding boxes surrounding multiple labels.

Sometimes when labels are next to each other on the herbarium sheet some
people lump them into one large bounding box and others draw boxes around
the individual labels. We'd prefer to have the individual bounding boxes
for each label.
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


"""Delete bounding boxes that are unlabeled singletons.

Some people drew bounding boxes around inappropriate objects or even on blank
areas on the herbarium sheet. This is an attempt to fix this problem. I'm
using two simple heuristics to find and remove these problems.
1) We're assuming that the boxes were not in groups. That is they are single
   boxes on their own.
2) We're also assuming that people didn't label these boxes. This one isn't
   always true but we're accepting some false positives rather than throw out
   too many properly labeled singletons.
"""
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


"""Create a merged box from a group of bounding boxes."""
function merge_boxes(subject)
    if length(subject.boxes) == 0
        return
    end

    boxes = boxes2array(subject.boxes)
    groups = overlapping_bboxes(boxes)
    for g in 1:findmax(groups)[1]
        targets = subject.boxes[groups .== g]
        boxes = boxes2array(targets)
        min_x = minimum(boxes[:, 1])
        min_y = minimum(boxes[:, 2])
        max_x = maximum(boxes[:, 3])
        max_y = maximum(boxes[:, 4])
        types = unique([b.type_ for b in targets])
        types = join(sort(types), "_")
        box = MergedBox(types, [min_x, min_y, max_x, max_y])
        push!(subject.merged, box)
    end
end


function main()
    unreconciled = CSV.File(UNRECONCILED) |> DataFrame  # Read unreconciled data

    by_subject = groupby(unreconciled, :subject_id)  # Group classifications by subject

    subjects = init_subject_records(by_subject)

    for subject in subjects
        boxes = boxes2array(subject.boxes)
        groups = bbox_nms_groups(boxes)

        if length(groups) == 0
            continue
        end

        delete_bad_boxes(subject, groups)
        merge_boxes(subject)
    end

end

main()
