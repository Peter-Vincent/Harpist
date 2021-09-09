using DataFrames
using CSV


payloadtypes = Dict([
    (1 , UInt8),
    (2 , UInt16),
    (4 , UInt32),
    (8 , UInt64),
    (129 , Int8),
    (130 , Int16),
    (132 , Int32),
    (136 , Int64),
    (68  , Float32)
])

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
                println("EOFError in $file_name - processing continuing.  Manually check")
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

function track_state(Message,Timestamp,Addresses,Payloads,Types,write_bitshifts::Vector{Int},write_headings::Vector{String})
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
    
    write_events = Array{Union{Nothing,Bool,Float64},2}(undef,num_writes,length(write_bitshifts)+1)
    write_sets   = writes .& (Addresses .=== 0x22)
    write_set_events = Array{Union{Nothing,Bool},2}(undef,count(write_sets),length(write_bitshifts))
    write_clears = writes .& (Addresses .=== 0x23)
    write_clear_events = Array{Union{Nothing,Bool},2}(undef,count(write_clears),length(write_bitshifts))
    set_inds = findall(Addresses[writes] .=== 0x22)
    clear_inds = findall(Addresses[writes] .=== 0x23)
    for (ind,write_ind) in enumerate(findall(write_sets))
        cur_payload = read_message(Payloads[write_ind])
        set_registers = common_elements(write_bitshifts,cur_payload)
        write_set_events[ind,set_registers] .= true
    end
    for (ind,write_ind) in enumerate(findall(write_clears))
        cur_payload = read_message(Payloads[write_ind])
        clear_registers = common_elements(write_bitshifts,cur_payload)
        write_clear_events[ind,clear_registers] .= false
    end
    write_events[set_inds,2:end]   = write_set_events
    write_events[clear_inds,2:end] = write_clear_events
    write_events[:,1] = Timestamp[writes]
    for row_ind = 2:size(write_events)[1]
        write_events[row_ind,write_events[row_ind,:] .== nothing] = write_events[row_ind-1,write_events[row_ind,:] .== nothing]
    end
    write_data = DataFrame(write_events,vcat("Times",write_headings))
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