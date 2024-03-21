#!/usr/bin/env python

import sys
import xarray as xr
import numpy as np

def main(topog_file, topog_file_AIS, output_file):
    ds_topog = xr.open_dataset(topog_file)
    ds_topog_AIS = xr.open_dataset(topog_file_AIS)
    
    diff = (ds_topog.depth - ds_topog_AIS.depth)
    aismask = xr.where(diff==0,-1,0)
    
    dsout = xr.Dataset({"aismask":aismask})
    dsout["aismask"].attrs["units"] = "1"
    dsout.to_netcdf(output_file)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: isolate_AIS_mask.py <topog_file> <topog_file_AIS> <output_file>")
        sys.exit(1)

    topog_file = sys.argv[1]
    topog_file_AIS = sys.argv[2]
    output_file = sys.argv[3]

    main(topog_file, topog_file_AIS, output_file)
