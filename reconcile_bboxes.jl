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


"""A temporary struct to organize all of the bounding boxes on a herbarium sheet."""
mutable struct MergedSubject
    subject_id::Int64
    image_file::String
    image_size::Tuple{Int64, Int64}
    boxes::PixelCoords
    deleted::PixelCoords
    merged::PixelCoords
    box_types::Vector{String}
    deleted_types::Vector{String}
    merged_types::Vector{String}

    MergedSubject(subject_id, image_file, image_size) = new(
        subject_id, image_file, image_size,
        pixel_coords(), pixel_coords(), pixel_coords(),
        Array{String}[], Array{String}[], Array{String}[])
end


"""Convert the CSV/JSON input data into an array of MergedSubject records."""
function init_subject_records(by_subject, image_dir)
    subjects = []

    prefix = "Box(es): box"
    box_headers = [h for h in names(by_subject) if startswith(string(h), prefix)]

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
        boxes = pixel_coords()

        for row in eachrow(old_sub)

            for (i, box_header) in enumerate(box_headers)
                box = row[box_header]
                if ismissing(box)
                    break
                end
                boxes = vcat(boxes, json2coords(box))
                type_ = row["Box(es): select #$i"]
                type_ = ismissing(type_) ? "" : type_
                sub.box_types = vcat(sub.box_types, type_)
            end
        end

        sub.boxes = clamp_pixels(boxes, image_size)

        push!(subjects, sub)
    end
    subjects
end


"""Remove bad bounding boxes from the subject."""
function delete_bad_boxes(subject, groups)
    to_delete = delete_multi_labels(subject, groups)
    to_delete .|= delete_unlabeled(subject, groups)

    subject.deleted = subject.boxes[to_delete, :]
    subject.deleted_types = subject.box_types[to_delete]
    subject.boxes = subject.boxes[.!to_delete, :]
    subject.box_types = subject.box_types[.!to_delete]
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
        sub_boxes = subject.boxes[groups .== -g, :]
        subgroups = bbox_nms_groups(sub_boxes)
        if length(subgroups) > 0 && findmax(subgroups)[1] > 1
            idx = findfirst(groups .== g)
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
        sub_boxes = subject.boxes[groups .== -g, :]
        if length(sub_boxes) == 1
            idx = findfirst(groups .== g)
            if subject.type_ == ""
                to_delete[idx] = 1
            end
        end
    end
    to_delete
end


"""Create merged boxes from groups of bounding boxes."""
function reconcile_boxes(subject)
    if length(subject.boxes) == 0
        return
    end

    subject.merged = pixel_coords()
    groups = overlapping_bboxes(subject.boxes)
    for g in 1:findmax(groups)[1]
        boxes = subject.boxes[groups .== g, :]
        min_x = minimum(boxes[:, 1])
        min_y = minimum(boxes[:, 2])
        max_x = maximum(boxes[:, 3])
        max_y = maximum(boxes[:, 4])
        box = [min_x min_y max_x max_y]
        subject.merged = vcat(subject.merged, box)

        types = subject.box_types[groups .== g]
        types = unique(t for t in types if t != "")
        types = join(sort(types), "_")
        push!(subject.merged_types, types)
    end
end


"""Output the subject data to a CSV file."""
function write_reconciled_csv(subjects, out_csv)
    # Get column counts
    box_len = maximum(s -> size(s.boxes, 1), subjects)
    del_len = maximum(s -> size(s.deleted, 1), subjects)
    merge_len = maximum(s -> size(s.merged, 1), subjects)

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
    for s in subjects
        row = OrderedDict(
            "subject_id" => s.subject_id,
            "image_file" => s.image_file,
            "image_size" => JSON.json(Dict(
                :height => s.image_size[1],
                :width => s.image_size[2],
            )),
        )

        count = size(s.merged, 1)
        for i in 1:merge_len
            key1 = "merged_box_$i"
            key2 = "merged_type_$i"
            row[key1] = i <= count ? bbox2json(s.merged[i, :]) : ""
            row[key2] = i <= count ? s.merged_types[i] : ""
        end

        count = size(s.deleted, 1)
        for i in 1:del_len
            key1 = "removed_box_$i"
            key2 = "removed_type_$i"
            row[key1] = i <= count ? bbox2json(s.deleted[i, :]) : ""
            row[key2] = i <= count ? s.deleted_types[i] : ""
        end

        count = size(s.boxes, 1)
        for i in 1:box_len
            row["box_$i"] = i <= count ? bbox2json(s.boxes[i, :]) : ""
            row["type_$i"] = i <= count ? s.box_types[i] : ""
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
    # unreconciled = first(unreconciled, 100)

    by_subject = groupby(unreconciled, :subject_id)

    subjects = init_subject_records(by_subject, args["images"])

    for subject in ProgressBar(subjects)
        groups = bbox_nms_groups(subject.boxes)

        if length(groups) == 0
            continue
        end

        delete_bad_boxes(subject, groups)
        reconcile_boxes(subject)
    end

    write_reconciled_csv(subjects, args["reconciled"])
end


main()
