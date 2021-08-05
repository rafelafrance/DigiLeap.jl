#!/home/rafe/bin/julia

using ArgParse
using DigiLeap


"""Process command line arguments."""
function parse_arguments()
    settings = ArgParseSettings(
        """Reconcile data from a Label Babel expedition.\n\n\n\n
            This script merges bounding boxes and label types from unreconciled
            Label Babel classifications. We have to figure out which bounding
            boxes refer to which labels on the herbarium sheet and then merge
            them to find a single "best" bounding box.
        """,
        )

    @add_arg_table! settings begin
        "--limit", "-L"
            help = """Limit the unreconciled input to the first N records."""
            arg_type = Int
    end

    add_arg_group!(settings, "required arguments")

    @add_arg_table! settings begin
        "--unreconciled-csv", "-u"
            help = """Path to the unreconciled input CSV file."""
            required = true
            arg_type = String
        "--reconciled-jsonl", "-r"
            help = """Path to the reconciled output JSONL file."""
            required = true
            arg_type = String
        "--image-dir", "-i"
            help = """Path to the directory containing subject images."""
            required = true
            arg_type = String
    end

    parse_args(settings)
end


ARGS = parse_arguments()

reconcile(
    ARGS["unreconciled-csv"],
    ARGS["reconciled-jsonl"],
    ARGS["image-dir"],
    limit=ARGS["limit"],
)
