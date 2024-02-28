#!/usr/bin/env python

import sys
import xarray as xr


def replace_values(
    source_file,
    variable_to_replace,
    replacement_file,
    replacement_variable,
    nrows,
    output_file,
):
    with xr.open_dataset(source_file) as ds_source:
        with xr.open_dataset(replacement_file) as ds_replacement:
            # Assuming the variables are 2D, replace the specified rows
            # BedMachine referenced to the surface, hence the -1
            ds_source[variable_to_replace][0:nrows, :] = (
                ds_replacement[replacement_variable].values * -1.0
            )

        # Save the modified dataset to the new file
        ds_source.to_netcdf(output_file)


if __name__ == "__main__":
    if len(sys.argv) != 7:
        print(
            "Usage: python replace_depth_values.py <source_file> <variable_to_replace> <replacement_file> <replacement_variable> <nrows> <output_file>"
        )
        sys.exit(1)

    (
        source_file,
        variable_to_replace,
        replacement_file,
        replacement_variable,
        nrows,
        output_file,
    ) = sys.argv[1:]
    nrows = int(nrows)  # Convert nrows to integer

    replace_values(
        source_file,
        variable_to_replace,
        replacement_file,
        replacement_variable,
        nrows,
        output_file,
    )
