#=
Code to process the binaries from the harp board.
=#

using ArgParse
using Glob

include("harp_binary_functions.jl")
    

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--head_values"
            help = "positional - Bitshifts to search for in the write data"
        "--head_names"
            help = "positional - Bitshift titles"
        "--new_fold", "-n"
            help = "Set to write .csv into a new folder for each file"
            action = :store_true
        "dir"
            help = "Positional - Directory or file to parse.  If string ends with .bin then the program will execute the single binary"
            required = true
    end

    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()
    spec_flag = 0
    ## Now turn string arguments into what they actually should be
    if typeof(parsed_args["head_values"]) == String
        parsed_args["head_values"] = parse.(Int64,string.(split(parsed_args["head_values"],",")))
        
        if typeof(parsed_args["head_names"]) != String
            ErrorException("You must provide BOTH head_values and head_names, or neither")
        end
        spec_flag += 1
    end
    if typeof(parsed_args["head_names"]) == String
        parsed_args["head_names"]  = string.(split(parsed_args["head_names"],","))
        
        if typeof(parsed_args["head_values"]) != String
            ErrorException("You must provide BOTH head_values and head_names, or neither")
        end
        spec_flag += 1
    end
    dir = parsed_args["dir"]
    # Now start parsing the data
    to_analyse = Vector{String}()
    if occursin(".bin",dir)
        push!(to_analyse,dir)
    elseif isdir(dir)
        dir_files = readdir(dir)
        for cur_file in dir_files
            if occursin(".bin",cur_file)
                push!(to_analyse,joinpath(dir,cur_file))
            end
        end
    else
        ArgumentError("Invalid path provided")
    end
    for cur_path in to_analyse
        if check_exist(cur_path,parsed_args["new_fold"])
            println("Processing $cur_path")
        else
            println("Output files for $cur_path already exist - moving on")
            continue
        end
        Message, Timestamp, Addresses,Payloads, Types = read_harp_bin(cur_path)
        if spec_flag == 2
            events,writes = track_state(Message, Timestamp, Addresses,Payloads, Types,parsed_args["head_values"],parsed_args["head_names"])
        else
            events,writes = track_state(Message, Timestamp, Addresses,Payloads, Types)
        end
        if parsed_args["new_fold"]
            sink_folder(events,writes,cur_path)
        else
            sink_data(events,writes,cur_path)
        end
    end
end

function check_exist(dir,new_fold)
    base_title = replace(dir,".bin"=>"")
    if new_fold
        file_names = glob(joinpath(base_title,"*.csv"))
    else
        file_names = glob(string(base_title,"*.csv"))
    end
    return isempty(file_names)
end

main()

    