using CSV
using DataFrames
using DataStructures
using Images
using JSON
using Logging
using ProgressBars
# using PyCall


"""A temporary struct to organize bounding boxes on herbarium sheets."""
mutable struct Subject
    subject_id::Int64
    image_file::String
    image_size::Tuple{Int64, Int64}
    boxes::PixelCoords
    deleted::PixelCoords
    merged::PixelCoords
    box_types::Vector{String}
    deleted_types::Vector{String}
    merged_types::Vector{String}

    Subject(subject_id, image_file, image_size) = new(
        subject_id, image_file, image_size,
        pixel_coords(), pixel_coords(), pixel_coords(),
        Array{String}[], Array{String}[], Array{String}[])
end


"""The main function."""
function reconcile(args)
    unreconciled = CSV.File(args["unreconciled"]) |> DataFrame
    if !isnothing(args["limit"])
        unreconciled = first(unreconciled, args["limit"])
    end

    by_subject = groupby(unreconciled, :subject_id)
    subjects = init_subjects(by_subject, args["images"])
    reconcile_subjects(subjects)
    write_reconciled(subjects, args["reconciled"])
end


"""Convert the CSV/JSON input data into an array of Subject records."""
function init_subjects(by_subject, image_dir)::Vector{Subject}
    # PILImage = pyimport("PIL.Image")

    subjects::Vector{Subject} = []

    prefix = "Box(es): box"
    box_headers = [h for h in names(by_subject) if startswith(string(h), prefix)]

    for old_sub in ProgressBar(by_subject)
        subject_id = old_sub.subject_id[1]
        image_file = old_sub.subject_Filename[1]

        image = try
            load("$image_dir/$image_file")
            # PILImage.open("$image_dir/$image_file")
        catch
            @warn "Could not load: $image_file"
            continue
        end

        # image_size = reverse(image.size)
        # image.close()
        image_size = size(image)

        subject = Subject(subject_id, image_file, image_size)
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
                subject.box_types = vcat(subject.box_types, type_)
            end
        end

        subject.boxes = clamp_pixels(boxes, image_size)

        push!(subjects, subject)
    end
    subjects
end


"""Reconcile subject bounding boxes."""
function reconcile_subjects(subjects)
    for subject in ProgressBar(subjects)
        groups = bbox_nms_groups(subject.boxes)

        if length(groups) == 0
            continue
        end

        delete_bad_boxes(subject, groups)
        reconcile_boxes(subject)
    end
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
        box = merge_boxes(boxes)
        subject.merged = vcat(subject.merged, box)

        types = subject.box_types[groups .== g]
        types = unique(t for t in types if t != "")
        types = join(sort(types), "_")
        push!(subject.merged_types, types)
    end
end


"""Output the subject data to a CSV file."""
function write_reconciled(subjects, jsonl_file)
    open(jsonl_file, "w") do f
        for s in subjects
            row = OrderedDict(
                "subject_id" => s.subject_id,
                "image_file" => s.image_file,
                "image_size" => [s.image_size[1], s.image_size[2]],
                "merged" => transpose(s.merged),
                "merged_types" => s.merged_types,
                "boxes" => transpose(s.boxes),
                "box_types" => s.box_types,
                "deleted" => transpose(s.deleted),
                "deleted_types" => s.deleted_types,
            )
            row = JSON.json(row)
            write(f, row, "\n")
        end
    end
end
