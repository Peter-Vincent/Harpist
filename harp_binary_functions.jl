using DataFrames
using CSV
include("harp_reg_addr.jl")

function read_harp_bin(file_name::String)
    harp_file = open(file_name,"r")
    Message   = UInt8[]
    Timestamp = Float64[]
    Addresses = UInt8[]
    Payloads  = []
    Types     = UInt8[]
    while !eof(harp_file)
        try
            message_byte = read(harp_file,UInt8)
            length       = read(harp_file,UInt8)
            address      = read(harp_file,UInt8)
            port         = read(harp_file,UInt8)
            payload_type = read(harp_file,UInt8)
            seconds      = read(harp_file,UInt32)
            micro        = read(harp_file,UInt16)
            time         = seconds + micro * 32e-6
            payload_size = length - 0x0a
            payload_data = read(harp_file,payload_size)
            payload      = read(IOBuffer(payload_data),payloadtypes[payload_type  & ~0x10])
            checksum= read(harp_file,UInt8)
            push!(Message,message_byte)
            push!(Timestamp,time)
            push!(Addresses,address)
            push!(Payloads,payload)
            push!(Types,payload_type * ~0x10)
        catch e

            if isa(e, EOFError)
                mem_file = string(file_name,"memdump.txt")
                # Add code to dump current memory state to this mem-file in hex
                println("EOFError in $file_name - processing continuing.  Manually check.")
                break
            else
                ErrorException("Unhandled error when processing $file_name .  Program terminating")
            end
        end        
    end
    return Message, Timestamp, Addresses,Payloads, Types
end

function read_message(x::UInt16)
    N = count_ones(x)
    inds = Vector{Int}(undef, N)
    if N == 0
        return inds
    end
    k = trailing_zeros(x)
    x >>= k + 1
    i = N - 1
    inds[N] = n = 16 - k
    while i >= 1
        (x, r) = divrem(x, 0x2)
        n -= 1
        if r == 1
            inds[i] = n
            i -= 1
        end
    end
    return sort(16 .- inds)
end

function common_elements(ind_array::Vector{Int},sub_array::Vector{Int})
    common_ind = Array{Union{Nothing,Int}}(nothing,length(sub_array))
    for (ind,element) in enumerate(sub_array)
        common_ind[ind] = findfirst(element .== ind_array)
    end
    return common_ind
end

function track_state(Message,Timestamp,Addresses,Payloads,Types)
    num_states = length(registerbits_A)
    state_bits = sort(collect(keys(registerbits_A)))
    state_names= Vector{String}()
    for ind in state_bits
        push!(state_names,registerbits_A[ind])
    end
    reads  = Message .=== 0x01
    writes = Message .=== 0x02
    events = Message .=== 0x03
    num_writes = count(writes)
    # Construct events
    event_types = unique(Types[events])
    event_dictionary = Dict{UInt8,DataFrame}()
    for cur_type in event_types
        type_index = (Types .=== cur_type) .& events
        event_address = unique(Addresses[type_index])
        for cur_address in event_address
            event_index = (Addresses .=== cur_address) .& type_index
            merge!(event_dictionary,Dict([(cur_address,DataFrame(Timestamp = Timestamp[event_index], Payload = Payloads[event_index]))]))
        end
    end
    write_events        = Array{Union{Nothing,Bool,Float64,String},2}(nothing,num_writes,num_states+1)
    write_sets          = writes .& (Addresses .=== 0x22)
    write_set_events    = Array{Union{Nothing,Bool},2}(nothing,count(write_sets),num_states)
    write_clears        = writes .& (Addresses .=== 0x23)
    write_clear_events  = Array{Union{Nothing,Bool},2}(nothing,count(write_clears),num_states)
    write_toggles       = writes .& (Addresses .=== 0x24)
    write_toggle_events = Array{Union{Nothing,String},2}(nothing,count(write_toggles),num_states)
    set_inds    = findall(Addresses[writes] .=== 0x22)
    clear_inds  = findall(Addresses[writes] .=== 0x23)
    toggle_inds = findall(Addresses[writes] .=== 0x24)
    for (ind,write_ind) in enumerate(findall(write_sets))
        cur_payload = read_message(Payloads[write_ind])
        set_registers = common_elements(state_bits,cur_payload)
        write_set_events[ind,set_registers] .= true
    end
    for (ind,write_ind) in enumerate(findall(write_clears))
        cur_payload = read_message(Payloads[write_ind])
        clear_registers = common_elements(state_bits,cur_payload)
        write_clear_events[ind,clear_registers] .= false
    end
    for (ind,write_ind) in enumerate(findall(write_toggles))
        cur_payload = read_message(Payloads[write_ind])
        toggle_registers = common_elements(state_bits,cur_payload)
        write_toggle_events[ind,toggle_registers] .= "TOGG"
    end
    write_events[set_inds,2:end]   = write_set_events
    write_events[clear_inds,2:end] = write_clear_events
    write_events[toggle_inds,2:end]= write_toggle_events
    
    write_events[:,1] = Timestamp[writes]

    # Now delete superflous columnns
    col_with_data  = dropdims(sum(write_events .=== nothing,dims=1) .!= size(write_events)[1],dims=1)
    write_events   = write_events[:,col_with_data]
    write_headings = vcat("Times",state_names)
    write_headings = write_headings[col_with_data]
    # Fill in the extra state
    for row_ind = 2:size(write_events)[1]
        propagate_state = (write_events[row_ind,:] .=== nothing) .& (write_events[row_ind-1,:] .!== "TOGG")
        write_events[row_ind,propagate_state] = write_events[row_ind-1,propagate_state]
    end
    write_data = DataFrame(write_events,write_headings)
    return event_dictionary, write_data
end

function sink_data(event_dictionary::Dict{UInt8, DataFrame},write_data::DataFrame,file_name::String)
    for col in eachcol(write_data)
        replace!(col,nothing=>NaN)
    end
    base_title = replace(file_name,".bin"=>"")
    for (key, value) in event_dictionary
        title = string(base_title,"_event_data_",key,".csv")
        CSV.write(title,value)
    end
    title = string(base_title,"_write_data.csv")
    CSV.write(title,write_data)
end

function sink_folder(event_dictionary::Dict{UInt8,DataFrame},write_data::DataFrame,file_name::String)
    for col in eachcol(write_data)
        replace!(col,nothing=>NaN)
    end
    
    base_title = replace(file_name,".bin"=>"")
    mkdir(base_title)
    for (key, value) in event_dictionary
        title = joinpath(base_title,string("event_data_",key,".csv"))
        CSV.write(title,value)
    end
    title = joinpath(base_title,"write_data.csv")
    CSV.write(title,write_data)
end