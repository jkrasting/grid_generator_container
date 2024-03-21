#!/usr/bin/env python

import sys
import xarray as xr
import numpy as np

def main(topog_file, mask_file, output_file):
    dsmask = xr.open_dataset(mask_file)
    ds_GEBCO_edited = xr.open_dataset(topog_file)
    depth_ais_masked = (ds_GEBCO_edited.depth * dsmask.wet.values)
    depth_ais_masked.attrs = ds_GEBCO_edited.depth.attrs
    ds_GEBCO_edited["depth"] = depth_ais_masked
    ds_GEBCO_edited.to_netcdf(output_file)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: apply_AIS_mask.py <topog_file> <mask_file> <output_file>")
        sys.exit(1)

    topog_file = sys.argv[1]
    mask_file = sys.argv[2]
    output_file = sys.argv[3]

    main(topog_file, mask_file, output_file)
