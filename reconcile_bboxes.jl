#!/home/rafe/bin/julia

using ArgParse
using DigiLeap


"""Process command line arguments."""
function parse_arguments()
    settings = ArgParseSettings()

    @add_arg_table! settings begin
        "--unreconciled", "-u"
            help = """Path to the unreconciled input CSV."""
            required = true
            arg_type = String
        "--reconciled", "-r"
            help = """Path to the reconciled output JSONL file."""
            required = true
            arg_type = String
        "--images", "-i"
            help = """Path to the directory containing subject images."""
            required = true
            arg_type = String
        "--limit", "-L"
            help = """Limit the unreconciled input to the first N records."""
            arg_type = Int
    end

    parse_args(settings)
end


if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_arguments()
    reconcile(args)
end

