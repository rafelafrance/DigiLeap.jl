#!/home/rafe/bin/julia

using ArgParse
using CSV
using DataFrames
using DataStructures
using DigiLeap
using Images
using JSON
using Logging
using ProgressBars


"""A temporary struct to hold the coordinates and type of a bounding box."""
struct BBox
    box::Array{Int64}
    type_::String
    BBox(t, b) = new(b, t)
end


"""Convert a bounding box to JSON."""
bbox2json(bbox::BBox) = JSON.json(Dict(
    :left => bbox.box[1],
    :top => bbox.box[2],
    :right => bbox.box[3],
    :bottom => bbox.box[4],
))


"""A temporary struct to organize all of the bounding boxes on a herbarium sheet."""
mutable struct MergedSubject
    subject_id::Int64
    image_file::String
    image_size::Tuple{Int64, Int64}
    boxes::Array{BBox}
    deleted::Array{BBox}
    merged::Array{BBox}
end
function MergedSubject(subject_id, image_file, image_size)
    MergedSubject(subject_id, image_file, image_size, [], [], [])
end


"""Convert JSON bounding box to an array."""
function json2bbox(json_box::String)
    box = JSON.parse(json_box)
    [box["left"] box["top"] box["right"] box["bottom"]]
end


"""Convert all boxes in a subject into a matrix."""
function boxes2array(old_boxes::Array{BBox})
    boxes = Array{Int64}(undef, 0, 4)
    for box in old_boxes
        boxes = vcat(boxes, box.box)
    end
    boxes
end


"""Convert the CSV/JSON input data into an array of MergedSubject records."""
function init_subject_records(by_subject, image_dir)
    subjects = []

    for old_sub in ProgressBar(by_subject)
        subject_id = old_sub.subject_id[1]
        image_file = old_sub.subject_Filename[1]

        image = try
            load("$image_dir/$image_file")
        catch
            @warn "Could not load: $image_file"
            continue
        end

        image_size = size(image)
        sub = MergedSubject(subject_id, image_file, image_size)

        for row in eachrow(old_sub)
            row = Dict(pairs(skipmissing(row)))

            prefix = "Box(es): box"
            boxes = [v for (k, v) in pairs(row) if startswith(string(k), prefix)]

            prefix = "Box(es): select"
            types = [v for (k, v) in pairs(row) if startswith(string(k), prefix)]

            for (box, type_) in zip(boxes, types)
                bbox = json2bbox(box)
                bbox = fix_bbox(bbox, image_size)
                push!(sub.boxes, BBox(type_, bbox))
            end

        end

        push!(subjects, sub)
    end
    subjects
end


"""Clamp the coordinates of the bounding box to the image coordinates.

We're given bounding boxes with coordinates outside of the image size.
We'll get negative coordinates and all sorts of nonsense.
"""
function fix_bbox(bbox, image_size)
    ll, tt, rr, bb = bbox
    max_h, max_w = image_size
    ll, rr = clamp(ll, 1, max_w), clamp(rr, 1, max_w)
	tt, bb = clamp(tt, 1, max_h), clamp(bb, 1, max_h)
    [ll tt rr bb]
end


"""Remove bad bounding boxes from the subject."""
function delete_bad_boxes(subject, groups)
    to_delete = delete_multi_labels(subject, groups)
    to_delete .|= delete_unlabeled(subject, groups)
    subject.deleted = subject.boxes[to_delete]
    deleteat!(subject.boxes, to_delete)
end


"""Delete bounding boxes surrounding multiple labels.

Sometimes when labels are next to each other on the herbarium sheet &some
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
   too many properly properly labeled singletons.
"""
function delete_unlabeled(subject, groups)
    to_delete = zeros(Bool, length(groups))
    for g in 1:findmax(groups)[1]
        sub_boxes = boxes2array(subject.boxes[groups .== -g])
        if length(sub_boxes) == 1
            idx = findfirst(groups .== g)
            if subject.type_ == ""
                push!(subject.deleted, subject.boxes[idx])
                to_delete[idx] = 1
            end
        end
    end
    to_delete
end


"""Create merged boxes from groups of bounding boxes."""
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
        box = BBox(types, [min_x, min_y, max_x, max_y])
        push!(subject.merged, box)
    end
end


"""Output the subject data to a CSV file."""
function write_reconciled_csv(subjects, out_csv)
    # Get column counts
    box_len = maximum(s -> length(s.boxes), subjects)
    del_len = maximum(s -> length(s.deleted), subjects)
    merge_len = maximum(s -> length(s.merged), subjects)

    # Create a data frame
    columns = OrderedDict(
        "subject_id" => Int64[],
        "image_file" => String[],
        "image_size" => String[],
    )
    for i in 1:merge_len
        columns["merged_box_$i"] = String[]
        columns["merged_type_$i"] = String[]
    end
    for i in 1:del_len
        columns["removed_box_$i"] = String[]
        columns["removed_type_$i"] = String[]
    end
    for i in 1:box_len
        columns["box_$i"] = String[]
        columns["type_$i"] = String[]
    end
    df = DataFrame(columns)

    # Fill the data frame
    for sub in subjects
        row = OrderedDict(
            "subject_id" => sub.subject_id,
            "image_file" => sub.image_file,
            "image_size" => JSON.json(Dict(
                :height => sub.image_size[1],
                :width => sub.image_size[2],
            )),
        )
        for i in 1:merge_len
            key1 = "merged_box_$i"
            key2 = "merged_type_$i"
            row[key1] = i <= length(sub.merged) ? bbox2json(sub.merged[i]) : ""
            row[key2] = i <= length(sub.merged) ? sub.merged[i].type_ : ""
        end
        for i in 1:del_len
            key1 = "removed_box_$i"
            key2 = "removed_type_$i"
            row[key1] = i <= length(sub.deleted) ? bbox2json(sub.deleted[i]) : ""
            row[key2] = i <= length(sub.deleted) ? sub.deleted[i].type_ : ""
       end
       for i in 1:box_len
            row["box_$i"] = i <= length(sub.boxes) ? bbox2json(sub.boxes[i]) : ""
            row["type_$i"] = i <= length(sub.boxes) ? sub.boxes[i].type_ : ""
        end

        push!(df, row)
    end

   CSV.write(out_csv, df)
end


"""Process command line arguments."""
function parse_arguments()
    settings = ArgParseSettings()

    @add_arg_table! settings begin
        "--unreconciled", "-u"
            help = """Path to the unreconciled input CSV."""
            required = true
            arg_type = String
        "--reconciled", "-r"
            help = """Path to the reconciled output CSV."""
            required = true
            arg_type = String
        "--images", "-i"
            help = """Path to the directory containing the images."""
            required = true
            arg_type = String
    end

    parse_args(settings)
end


"""Process the script."""
function main()
    args = parse_arguments()

    unreconciled = CSV.File(args["unreconciled"]) |> DataFrame

    by_subject = groupby(unreconciled, :subject_id)

    subjects = init_subject_records(by_subject, args["images"])

    for subject in ProgressBar(subjects)
        boxes = boxes2array(subject.boxes)
        groups = bbox_nms_groups(boxes)

        if length(groups) == 0
            continue
        end

        delete_bad_boxes(subject, groups)
        merge_boxes(subject)
    end

    write_reconciled_csv(subjects, args["reconciled"])
end


main()
