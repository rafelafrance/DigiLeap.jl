#!/home/rafe/bin/julia

using ArgParse


function transform()
    args = parse_arguments()
    mkpath(args["transformed"])
end


"""Process command line arguments."""
function parse_arguments()
    settings = ArgParseSettings()

    piplelines = Dict(
        "deskew" => "Deskew",
        "binarize" => "Binarize",
    )

    pipe_names = join(keys(piplelines), ", ", " and ")

    @add_arg_table! settings begin
        "--labels", "-l"
            help = """The directory containing input labels."""
            required = true
            arg_type = String
        "--transformed", "-t"
            help = """Output transformed labels to this directory."""
            required = true
            arg_type = String
        "--pipeline", "-p"
            help = """The pipeline to use for transformations.
                Options: $(pipe_names)"""
            required = true
            arg_type = String
        "--limit", "-L"
            help = """Limit the input labels to the first N files."""
            arg_type = Int
        "--filter", "-f"
            help = """Filter files in the --labels with this."""
            arg_type = String
            default = "*.jpg"
    end

    args = parse_args(settings)

    if args["pipeline"] ∉ keys(piplelines)
        error("""Unknown pipeline '$(args["pipeline"])'.
            Available options: $(pipe_names)""")
    end

    args
end


transform()
