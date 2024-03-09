# Ocean color / chlorophyll file
# ------------------------------
INPUT/seawifs-clim-1997-2010.nc: ocean_mosaic
	mkdir -p INPUT
	cd INPUT && ln -sf ../ocean_mosaic/ocean*.nc .
	cd INPUT && $(TOOLDIR)/interp_and_fill/interp_and_fill.py \
            ocean_hgrid.nc \
            ocean_mask.nc \
            $(GOLD_DIR)/obs/SeaWiFS/fill_ocean_color/seawifs-clim-1997-2010.nc  \
            chlor_a --fms $(@F)
	cd INPUT && rm -f ocean*.nc


# Geothermal Flux
# ---------------
# Geothermal flux is a time-invariant field. The source data are a CSV
# CSV file that is contained in the supplemental material of 
# Davies et al. 2013 (https://doi.org/10.1002/ggge.20271). The CSV file
# was converted to a NetCDF file using the `convert_Davies_2013.py` script.
# A copy of the NetCDF file is stored in $(GOLD_DIR) and is regridded to
# the model horizontal grid using `regrid_geothermal.py`

INPUT/geothermal_davies2013_v1.nc: ocean_mosaic
	mkdir -p INPUT
	cd INPUT && rm -f convert_Davies_2013
	cd INPUT && ln -s /archive/gold/datasets/obs/convert_Davies_2013 .
	cd INPUT && ln -sf ../ocean_mosaic/ocean*.nc .
	cd INPUT && $(PYTHON3) $(TOOLDIR)/OM4_05_preprocessing_geothermal/regrid_geothermal.py
	cd INPUT && rm -f convert_Davies_2013 ocean*.nc


# Tidal amplitude file
# --------------------
# Script writted by Raf Dussin
INPUT/tidal_amplitude.nc: ocean_mosaic
	mkdir -p INPUT
	cd INPUT && ln -sf ../ocean_mosaic/ocean*.nc .
	cd INPUT && $(PYTHON3) \
            $(TOOLDIR)/auxillary/remap_Tidal_forcing_TPXO9.py \
            ocean_hgrid.nc \
            ocean_topog.nc \
            $(GOLD_DIR)/obs
	cd INPUT && rm -f ocean*.nc


INPUT: INPUT/seawifs-clim-1997-2010.nc INPUT/geothermal_davies2013_v1.nc INPUT/tidal_amplitude.nc
