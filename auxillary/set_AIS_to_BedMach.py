#!/usr/bin/env python

import sys
import xarray as xr
import numpy as np

def main(topog_file, bedmach_file, mask_file, output_file):
    dstopog = xr.open_dataset(topog_file)
    dsbedmach = xr.open_dataset(bedmach_file)
    dsmask = xr.open_dataset(mask_file)
    modified_depth = xr.where(dsmask.wet==0,dsbedmach.depth.values,dstopog.depth.values)
    modified_depth.attrs = dstopog.depth.attrs
    modified_wet = xr.where(dsmask.wet==0,1.,dstopog.wet)
    modified_wet.attrs = dstopog.wet.attrs
    dstopog["depth"] = modified_depth
    dstopog["wet"] = modified_wet
    dstopog.to_netcdf(output_file)


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: set_AIS_to_bedmach.py <topog_file> <bedmach_file> <mask_file> <output_file>")
        sys.exit(1)

    topog_file = sys.argv[1]
    bedmach_file = sys.argv[2]
    mask_file = sys.argv[3]
    output_file = sys.argv[4]

    main(topog_file, bedmach_file, mask_file, output_file)
