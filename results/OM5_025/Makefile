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
#        2d: Reset the wet mask to match OM4
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
 

# Part 2a: Interpolared Topography with Subgrid Tiles
# ---------------------------------------------------

OCEAN_TOPOG_TOOL = create_topog_refinedSampling.py

# The source topography for OM5 is GEBCO 2023, which incorporates IBCAO and
# BEDMACHINE updates that were processed separately in OM4. This command
# below specifies the source location for the GEBCO 2023 data and the variable
# names contained within the file.

OCEAN_TOPOG_SRC = --source_file $(GOLD_DIR)/topography/GEBCO_2023/GEBCO_2023.nc \
                  --source_lon lon \
                  --source_lat lat \
                  --source_elv elevation 

# Bipolar Cap
ocean_topog_BP.nc: 
	$(OCEAN_TOPOG_TOOL) --hgridfilename ./ocean_hgrid.ncBP.nc \
        --max_refine=5 --nxblocks=4 \
        --outputfilename $(@F) $(OCEAN_TOPOG_SRC)

# Mercator Region
ocean_topog_MERC.nc: 
	$(OCEAN_TOPOG_TOOL) --hgridfilename ./ocean_hgrid.ncMerc.nc \
        --max_refine=5 --nxblocks=4 \
        --outputfilename $(@F) $(OCEAN_TOPOG_SRC)

# Southern Ocean Spherical Grid
ocean_topog_SO.nc: 
	$(OCEAN_TOPOG_TOOL) --hgridfilename ./ocean_hgrid.ncSO.nc \
        --max_refine=5 --nxblocks=4 \
        --outputfilename $(@F) $(OCEAN_TOPOG_SRC)

# Merge all tiles together
ocean_topog_merged.nc: ocean_topog_MERC.nc ocean_topog_SO.nc ocean_topog_BP.nc
	merge_topog_tiles.py \
        --tilefiles ocean_topog_SO.nc,ocean_topog_MERC.nc,ocean_topog_BP.nc \
        --outputfilename $(@F)


# Part 2b: Topgraphy Edits
# ------------------------

# Topography edits are applied both in the preprocessing workflow and
# also at model runtime. The preprocessing edits are necessary in order
# to create connectivity that is required for the flood-filling
# alogiright (ICE-9) used in the next step.

# Path of legacy OM4 preprocessing code
MOM6_EXAMPLES_PREPROC = /opt/tools/MOM6-examples/ice_ocean_SIS2/OM4_025/preprocessing

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

ocean_topog.nc: ocean_topog_ice9ed.nc
	cp $< topog.nc
	ncatted -h -a creation_date,global,c,c,"`date`" topog.nc
	ncatted -h -a source,global,c,c,"GEBCO 2023 remapped via RSC" topog.nc
	ncatted -h -a topo_edits,global,c,c,"True" topog.nc
	#$(PYTHON2) $(MOM6_EXAMPLES_PREPROC)/addDimension.py topog.nc ntiles 1
	cp topog.nc ocean_topog.nc


# Part 3: FMS Grid Spec, Mosaic Files, and Mask Tables
# --------------------------------------

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

all: grid_spec.nc INPUT INPUT/salt_restore_JRA.nc JRA_runoff_data
