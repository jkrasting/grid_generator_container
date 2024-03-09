#!/usr/bin/env python

import sys
import xarray as xr
import numpy as np

def main(topog_file, surface_file, bed_file, output_file):
    dst = xr.open_dataset(topog_file)
    dss = xr.open_dataset(surface_file)
    dsb = xr.open_dataset(bed_file)

    depth = dst.depth.values
    surface = dss.depth.values
    bed = dsb.depth.values

    #bed = dsb.bed.values
    #surface = dss.surface.values
    #nrows = bed.shape[0]

    #expanded = np.zeros(depth.shape)
    #expanded[0:nrows] = bed
    #bed = expanded

    #expanded = np.zeros(depth.shape)
    #expanded[0:nrows] = surface
    #surface = expanded

    mask = np.abs(bed-surface)
    depth = np.where(mask > 0, bed, depth)
    dst["depth"].values = depth

    dst.to_netcdf(output_file)


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: mask_AIS.py <topog_file> <surface_file> <bed_file> <output_file>")
        sys.exit(1)

    topog_file = sys.argv[1]
    surface_file = sys.argv[2]
    bed_file = sys.argv[3]
    output_file = sys.argv[4]

    main(topog_file, surface_file, bed_file, output_file)
