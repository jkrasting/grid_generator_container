#!/usr/bin/env python

import sys
import xarray as xr


def main(surface_file, bed_file, output_file):
    dss = xr.open_dataset(surface_file)
    dsb = xr.open_dataset(bed_file)
    dss["surface"] = xr.where(dss.surface == 0.0, dsb.bed, dss.surface)
    dss.to_netcdf(output_file)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: script.py <surface_file> <bed_file> <output_file>")
        sys.exit(1)

    surface_file = sys.argv[1]
    bed_file = sys.argv[2]
    output_file = sys.argv[3]

    main(surface_file, bed_file, output_file)
