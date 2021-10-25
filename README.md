## Documentation

### parse_harp_binary.jl
There were a couple of attempts at this in some different languages.  In the end, I settled for Julia for the combination of speed and a nice high level language

### Install
Start by installing julia using instructions [here](https://julialang.org/downloads/platform/)

Once `julia` is on your path, call the `dependencies.jl` file as below
```
julia dependencies.jl
```
which will make sure you have all the packages you need (hopefully)

`julia /path/to/parse_harp_binary.jl --help`
```
usage: parse_harp_binary.jl [-n] [-h] dir

positional arguments:
  dir             Positional - Directory or file to parse.  If string
                  ends with .bin then the program will execute the
                  single binary

optional arguments:
  -n, --new_fold  Set to write .csv into a new folder for each file
  -h, --help      show this help message and exit
```

One example of how to use it is given below
`julia parse_harp_binary.jl crash_examples -n`

`dir` -> `crash_examples`
This is the path the program targets.  If the path contains `.bin` then the program will assume you only want to target that single binary.  If the path does not contain `.bin` then the program will assume you have provided a directory and it will search for files ending with `.bin` in that directory, then processing all of those

`--new_fold`, `-n` 
This optional flag indicates whether you want a new directory to be made for each file analysed.  If the flag is provided (as it is here) then a new folder will be created with the same name as the data file and the output files will be placed in that folder.  If the flag is not given the output files will be placed in the same directory as the data file

The program, as run from the command line, results in the creation of a few `.csv` files.  One file each is created for each type of event.  These are saved as `<*event_data_$address.csv>` where `address` is the register address that event is logged with.  All `write` events are saved in `<*write_data.csv>` but the actuall events are not being presented (and are not uniquely recoverable from this file).  Instead, the file describes the state of each of the registers, where `TRUE` indicates high and `FALSE` indicates low.  A value of `NaN` indicates that location has yet to be written to in the session described bu the given datafile.

## To-do
- [ ] Better way to search for existing files to prevent re-analysis
- [ ] Support toggle and other commands *getting there*
- [ ] Remove need to specify the register values
