# OM5 Horizontal Grid, Topography, and Preprocessing Datasets
# GFDL Ocean Division - October 2023
#
# Makefile for OM5 (Standard South Pole)
# -------------------------------
#
# This Makefile is broken into the following sections
#
#     Part 1: Horizontal Grid
#
#     Part 2: Topography Generation
#        2a: Interpolared Topography with Subgrid Tiles
#        2b: Topgraphy Edits
#        2c: Flood-filling & Connectivity (ICE-9)
#
#     Part 3: FMS Grid Spec, Mosaic Files, and Mask Tables
#
# Example Usage:
#    make -f Makefile_OM5_rp grid_spec.nc
#    make -f Makefile_OM5_rp mask_tables
#
# ---------------------------------------

# COMMON PATHS & SETTINGS
# -----------------------

# This Makefile relies on two different versions of Python. The updated
# new tools rely on Python 3 while the legacy OM4 tools rely on Python 2.
PYTHON2 := /pad/griduser/.conda/envs/py27/bin/python
PYTHON3 := /pad/griduser/.conda/envs/py311/bin/python
PYTHON37 := /pad/griduser/.conda/envs/py37/bin/python

# GFDL O-division has a central repository for common datasets
GOLD_DIR := /archive/gold/datasets

# Directories inside the container with tools
TOOLDIR := /opt/tools
FRE_NCTOOLS := /opt/fre-nctools/bin


# Part 1: Horizontal Grid
# ------------------------

# Use N. Zadeh's `ocean_grid_gnerator.py` tool to create the horizontal grid.
# The resolution is specificed as an "inverse resolution" specified with the
# `-r` flag. The 0.25-degree (1/4) is specified as `-r 4`.

ocean_hgrid.nc:
	ocean_grid_generator.py \
            --write_subgrid_files \
            -f $(@F) \
            -r 4 \
            --south_ocean_lower_lat -88.57 \
            --no_south_cap \
            --match_dy so


# BedMachine Topography
# ---------------------

# Supergrid index corresponding to j-row 280
J60S := 562

bedmachine_remapped_bed.nc: ocean_hgrid.nc
	$(PYTHON3) $(TOOLDIR)/auxillary/remap_bedmachine.py \
          ocean_hgrid.nc $(J60S) bed \
          $(GOLD_DIR)/topography/BedMachineAntarctica_2020-07-15_v02.nc \
          $(@F)

bedmachine_remapped_surface.nc: ocean_hgrid.nc bedmachine_remapped_bed.nc
	$(PYTHON3) $(TOOLDIR)/auxillary/remap_bedmachine.py \
          ocean_hgrid.nc $(J60S) surface \
          $(GOLD_DIR)/topography/BedMachineAntarctica_2020-07-15_v02.nc \
          $(@F)

bedmachine_remapped_surface_with_bed.nc: bedmachine_remapped_surface.nc bedmachine_remapped_bed.nc
	$(PYTHON3) $(TOOLDIR)/auxillary/combine_bedmachine_surface_bed.py \
          bedmachine_remapped_surface.nc bedmachine_remapped_bed.nc $(@F)


# Part 2a: Interpolated Topography
# --------------------------------

# The source topography for OM5 is GEBCO 2023, which incorporates IBCAO and
# BEDMACHINE updates that were processed separately in OM4. This command
# below specifies the source location for the GEBCO 2023 data and the variable
# names contained within the file.

source_topog.nc:
	ln -s $(GOLD_DIR)/topography/GEBCO_2023/GEBCO_2023.nc source_topog.nc

new_topo_OM5_grid_r8_24x387.nc: source_topog.nc
	cp -v $(TOOLDIR)/auxillary/Generate-OM5-topo.ipynb .
	cp -v $(TOOLDIR)/thin-wall-topography/python/GMesh.py .
	jupyter nbconvert --to notebook --execute Generate-OM5-topo.ipynb --output Generate-OM5-topo.ipynb

ocean_topog_merged.nc: new_topo_OM5_grid_r8_24x387.nc
	cp new_topo_OM5_grid_r8_24x387.nc ocean_topog_merged.nc
	ncatted -O -a units,depth,a,c,"meters" ocean_topog_merged.nc
	ncatted -O -a description,depth,a,c,"Non-negative nominal thickness of the ocean at cell centers" ocean_topog_merged.nc
	ncatted -O -a units,h2,a,c,"meters^2" ocean_topog_merged.nc
	ncatted -O -a standard_name,h2,a,c,"Variance of sub-grid scale topography" ocean_topog_merged.nc


# Part 2b: Topgraphy Edits
# ------------------------

# Topography edits are applied both in the preprocessing workflow and
# also at model runtime. The preprocessing edits are necessary in order
# to create connectivity that is required for the flood-filling
# alogrightm (ICE-9) used in the next step.  The topo edits are contained
# within the Jupyter notebooks in `om5_topo_edits`. The notebooks are
# executed in batch to create NetCDF files of edits for each region. The
# regions are combined together to make a single topo edits file that is 
# applied to interpolated topography.

# Path of legacy OM4 preprocessing code
MOM6_EXAMPLES_PREPROC = /opt/tools/MOM6-examples/ice_ocean_SIS2/OM4_025/preprocessing

om5_topo_edits:
	cp -rp /opt/tools/om5_topo_edits .

om5_topo_edits.nc: om5_topo_edits ocean_topog_merged.nc
	cp -v ocean_topog_merged.nc om5_topo_edits/.
	cd om5_topo_edits && ln -s ocean_topog_merged.nc regridded_source_topog.nc
	cd om5_topo_edits && ln -s ../ocean_hgrid.nc .
	cd om5_topo_edits && export PYDEVD_DISABLE_FILE_VALIDATION=1 && ./run_batch.sh 2>&1 | tee batch_output.txt
	cd om5_topo_edits && ./combine_nc_edits.py -o ../om5_topo_edits.nc om5_topo_edits_region_*.nc

ocean_topog_edited.nc: ocean_topog_merged.nc om5_topo_edits.nc
	# Apply the topography edits using the legacy OM4 tool
	cp ocean_topog_merged.nc tmp.nc 
	$(PYTHON2) $(MOM6_EXAMPLES_PREPROC)/apply_edits.py om5_topo_edits.nc tmp.nc
	cp tmp.nc $(@F)
	
	# Remove temporary file
	rm -f tmp.nc


# Part 2c: Flood-filling & Connectivity (ICE-9)
# ---------------------------------------------

# This step uses the ICE-9 algorighm to determine the basin conenctivity and
# arrive at a wet mask for the grid. (NOTE: this wet mask may be adjusted by
# any runtime topography edits that are used by the model, so this step should
# not be considered the models' final wet mask; refer to the `ocean_static.nc`
# file written by the model at runtime.)

ocean_topog_ice9ed.nc: ocean_topog_edited.nc
	# Flip the sign
	ncap2 -hs "depth=depth*(-1)" $< tmp.nc
	
	ice9.py tmp.nc --variable 'depth' \
        --iseed 10 --jseed 200 --output $(@F)
	
	# Remove temporary file
	rm -f tmp.nc

ocean_topog_GEBCO.nc: ocean_topog_ice9ed.nc
	cp $< topog.nc
	ncatted -h -a creation_date,global,c,c,"`date`" topog.nc
	ncatted -h -a source,global,c,c,"GEBCO 2023 remapped via GMesh.py (Jan 2024 version)" topog.nc
	ncatted -h -a topo_edits,global,c,c,"True" topog.nc
	#$(PYTHON2) $(MOM6_EXAMPLES_PREPROC)/addDimension.py topog.nc ntiles 1
	cp topog.nc $(@F)

ocean_topog_GEBCO_bedmachine_surface.nc: ocean_topog_GEBCO.nc bedmachine_remapped_surface_with_bed.nc
	$(PYTHON3) $(TOOLDIR)/auxillary/replace_depth_values.py \
          ocean_topog_GEBCO.nc depth bedmachine_remapped_surface_with_bed.nc surface 280 $(@F)

ocean_topog_GEBCO_bedmachine_bed.nc: ocean_topog_GEBCO.nc bedmachine_remapped_bed.nc
	$(PYTHON3) $(TOOLDIR)/auxillary/replace_depth_values.py \
          ocean_topog_GEBCO.nc depth bedmachine_remapped_bed.nc bed 280 $(@F)

ocean_topog.nc: ocean_topog_GEBCO_bedmachine_surface.nc
	ncap2 -s 'where(depth<0) depth=0;' ocean_topog_GEBCO_bedmachine_surface.nc $(@F)
	cp -v ocean_topog.nc topog.nc

# Part 3: FMS Grid Spec, Mosaic Files, and Mask Tables
# ----------------------------------------------------

ocean_mosaic.nc: ocean_hgrid.nc ocean_topog.nc
	$(FRE_NCTOOLS)/make_solo_mosaic \
        --num_tiles 1 \
        --dir . \
        --mosaic_name ocean_mosaic \
        --tile_file ocean_hgrid.nc \
        --periodx 360.

grid_spec.nc: ocean_mosaic.nc
	$(FRE_NCTOOLS)/make_quick_mosaic \
        --reproduce_siena \
        --input_mosaic ocean_mosaic.nc \
        --mosaic_name grid_spec \
        --ocean_topog ocean_topog.nc 

mask_tables: $(FRE_NCTOOLS)/check_mask ocean_mosaic.nc ocean_topog.nc
	$(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 20,10
	$(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 20,20
	$(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 36,18
	$(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 36,6
	$(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 26,4
	$(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 90,45
	$(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 90,72
	$(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 32,72
	$(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 45,72
	touch $@


# Include additional makefile(s) defining input datasets
include *.mk

grid_spec_bundle.tar: grid_spec.nc mask_tables
	tar -cvf grid_spec_bundle.tar ocean_topog.nc ocean_mosaic.nc ocean_mask.nc land_mask.nc *_tile1X* grid_spec.nc ocean_hgrid.nc* mask_table*

INPUT.tar: INPUT INPUT/salt_restore_JRA.nc
	tar -cvf INPUT.tar INPUT

JRA_data.tar: JRA_runoff_data JRA_output
	tar -cvf JRA_data.tar JRA_output

all: grid_spec_bundle.tar INPUT.tar JRA_data.tar
