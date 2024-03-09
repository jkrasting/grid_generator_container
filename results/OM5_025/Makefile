# OM5 Horizontal Grid, Topography, and Preprocessing Datasets
# GFDL Ocean Division - March 2024
#
# Makefile for OM5 (Standard South Pole)
# -------------------------------
#
# This Makefile is broken into the following sections
#
#     Part 1: Horizontal grid
#
#     Part 2: Topography Generation
#        2a: Remap source GEBCO and BedMachine topography 
#        2b: Generate topgraphy Edits
#        2c: Apply topog edits and assemble GEBCO+BedMachine
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
	mkdir -p tile_grids
	mv -vf ocean_hgrid.ncMerc.nc tile_grids/.
	mv -vf ocean_hgrid.ncBP.nc tile_grids/.
	mv -vf ocean_hgrid.ncSO.nc tile_grids/.


# Part 2a: Regrid BedMachine and GEBCO topography
# -----------------------------------------------

# Supergrid index corresponding to j-row 280
J60S := 562

interpolated_BedMachine/bedmachine_remapped_bed.nc: ocean_hgrid.nc
	mkdir -p interpolated_BedMachine
	$(PYTHON3) $(TOOLDIR)/auxillary/remap_bedmachine.py \
          ocean_hgrid.nc $(J60S) bed \
          $(GOLD_DIR)/topography/BedMachineAntarctica_2020-07-15_v02.nc \
          $(@)

interpolated_BedMachine/bedmachine_remapped_surface.nc: ocean_hgrid.nc
	mkdir -p interpolated_BedMachine
	$(PYTHON3) $(TOOLDIR)/auxillary/remap_bedmachine.py \
          ocean_hgrid.nc $(J60S) surface \
          $(GOLD_DIR)/topography/BedMachineAntarctica_2020-07-15_v02.nc \
          $(@)

interpolated_BedMachine/bedmachine_remapped_surface_with_bed.nc: interpolated_BedMachine/bedmachine_remapped_surface.nc interpolated_BedMachine/bedmachine_remapped_bed.nc
	$(PYTHON3) $(TOOLDIR)/auxillary/combine_bedmachine_surface_bed.py $^ $(@)

interpolated_GEBCO/interpolated_GEBCO_topog.nc: ocean_hgrid.nc
	mkdir -p interpolated_GEBCO
	ln -sf ocean_hgrid.nc interpolated_GEBCO/ocean_hgrid.nc
	# Use sub_ice topog for generating h2 in the ice shelf cavities
	ln -sf $(GOLD_DIR)/topography/GEBCO_2023/GEBCO_2023.nc interpolated_GEBCO/source_topog.nc
	# ln -sf $(GOLD_DIR)/topography/GEBCO_2023/GEBCO_2023_sub_ice_topo.nc interpolated_GEBCO/source_topog.nc
	cp -vf $(TOOLDIR)/auxillary/Generate-OM5-topo.ipynb interpolated_GEBCO/.
	cp -vf $(TOOLDIR)/thin-wall-topography/python/GMesh.py interpolated_GEBCO/.
	# execute topog generation notebook; cp line is used for quick testing
	cd interpolated_GEBCO && export PYDEVD_DISABLE_FILE_VALIDATION=1 && \
            jupyter nbconvert --to notebook --execute Generate-OM5-topo.ipynb --output Generate-OM5-topo.ipynb
	# cd interpolated_GEBCO && cp -vf ../../OM5_025_BedMach/new_topo_bak/new_topo_OM5_grid_r8_24x387.nc . && cd ../
	#
	cp -vf interpolated_GEBCO/new_topo_OM5_grid_r8_24x387.nc $(@)
	ncatted -O -a units,depth,a,c,"meters" $(@)
	ncatted -O -a description,depth,a,c,"Non-negative nominal thickness of the ocean at cell centers" $(@)
	ncatted -O -a units,h2,a,c,"meters^2" $(@)
	ncatted -O -a standard_name,h2,a,c,"Variance of sub-grid scale topography" $(@)


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

om5_topo_edits/om5_topo_edits.nc: om5_topo_edits interpolated_GEBCO/interpolated_GEBCO_topog.nc
	cd om5_topo_edits && ln -sf ../interpolated_GEBCO/interpolated_GEBCO_topog.nc regridded_source_topog.nc
	cd om5_topo_edits && ln -sf ../ocean_hgrid.nc .
	cd om5_topo_edits && export PYDEVD_DISABLE_FILE_VALIDATION=1 && ./run_batch.sh 2>&1 | tee batch_output.txt
	cd om5_topo_edits && ./combine_nc_edits.py -o om5_topo_edits.nc om5_topo_edits_region_*.nc
	# line below is used for quick testing
	# cp -vf ../OM5_025/om5_topo_edits.nc $(@)


# Part 2c:  Apply topog edits and assemble GEBCO+BedMachine
# ---------------------------------------------------------

assembled_topog/edited_GEBCO.nc: om5_topo_edits/om5_topo_edits.nc interpolated_GEBCO/interpolated_GEBCO_topog.nc
	mkdir -p assembled_topog
	# Apply the topography edits using the legacy OM4 tool
	cp interpolated_GEBCO/interpolated_GEBCO_topog.nc tmp.nc 
	$(PYTHON2) $(MOM6_EXAMPLES_PREPROC)/apply_edits.py om5_topo_edits/om5_topo_edits.nc tmp.nc
	cp tmp.nc $(@)
	# Remove temporary file
	rm -f tmp.nc

assembled_topog/edited_GEBCO_ice9ed.nc: assembled_topog/edited_GEBCO.nc
	# Flip the sign
	ncap2 -hs "depth=depth*(-1)" $< tmp.nc
	ice9.py tmp.nc --variable 'depth' \
         --iseed 10 --jseed 200 --output $(@)
	# Remove temporary file
	rm -f tmp.nc

NROWS := 280

assembled_topog/edited_GEBCO_ice9ed_bedmachine_surface.nc: assembled_topog/edited_GEBCO_ice9ed.nc interpolated_BedMachine/bedmachine_remapped_surface_with_bed.nc
	$(PYTHON3) $(TOOLDIR)/auxillary/replace_depth_values.py $< depth $(word 2, $^) surface $(NROWS) $(@)

assembled_topog/edited_GEBCO_ice9ed_bedmachine_bed.nc: assembled_topog/edited_GEBCO_ice9ed.nc interpolated_BedMachine/bedmachine_remapped_bed.nc
	$(PYTHON3) $(TOOLDIR)/auxillary/replace_depth_values.py $< depth $(word 2, $^) bed $(NROWS) $(@)

assembled_topog/edited_GEBCO_ice9ed_bedmachine_surface_zeroed.nc: assembled_topog/edited_GEBCO_ice9ed_bedmachine_surface.nc
	ncap2 -s 'where(depth<0) depth=0;' $< $(@)

ocean_topog.nc: assembled_topog/edited_GEBCO_ice9ed_bedmachine_surface_zeroed.nc
	# Flip the sign
	ncap2 -hs "depth=depth*(-1)" $< tmp.nc
	ice9.py tmp.nc --variable 'depth' --iseed 10 --jseed 200 --output $(@)
	# Remove temporary file
	rm -f tmp.nc
	ncatted -h -a creation_date,global,c,c,"`date`" $(@)
	ncatted -h -a source,global,c,c,"GEBCO 2023 remapped via GMesh.py (Jan 2024 version)" $(@)
	ncatted -h -a topo_edits,global,c,c,"True" $(@)

ocean_topog_w_AIS.nc: ocean_topog.nc assembled_topog/edited_GEBCO_ice9ed_bedmachine_surface.nc assembled_topog/edited_GEBCO_ice9ed_bedmachine_bed.nc
	$(PYTHON3) $(TOOLDIR)/auxillary/mask_AIS.py $^ $(@)
	$(PYTHON2) $(MOM6_EXAMPLES_PREPROC)/addDimension.py $(@) ntiles 1


# Part 3: FMS Grid Spec, Mosaic Files, and Mask Tables
# ----------------------------------------------------

ocean_mosaic: ocean_hgrid.nc ocean_topog.nc ocean_topog_w_AIS.nc
	mkdir -p ocean_mosaic
	cp -vf ocean_hgrid.nc $(@)/.
	cp -vf ocean_topog.nc $(@)/.
	cp -vf ocean_topog.nc $(@)/topog.nc
	cp -vf ocean_topog_w_AIS.nc $(@)/.
	#
	cd $(@) && $(FRE_NCTOOLS)/make_solo_mosaic \
            --num_tiles 1 \
            --dir . \
            --mosaic_name ocean_mosaic \
            --tile_file ocean_hgrid.nc \
            --periodx 360.
	#
	cd $(@) && $(FRE_NCTOOLS)/make_quick_mosaic \
            --reproduce_siena \
            --input_mosaic ocean_mosaic.nc \
            --mosaic_name grid_spec \
            --ocean_topog ocean_topog.nc 
	#
	cd $(@) && $(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 20,10
	cd $(@) && $(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 20,20
	cd $(@) && $(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 36,18
	cd $(@) && $(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 36,6
	cd $(@) && $(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 26,4
	cd $(@) && $(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 90,45
	cd $(@) && $(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 90,72
	cd $(@) && $(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 32,72
	cd $(@) && $(FRE_NCTOOLS)/check_mask --grid_file ocean_mosaic.nc --ocean_topog ocean_topog.nc --layout 45,72
	#
	touch $(@)

coupled_mosaic: ocean_mosaic
	mkdir -p $(@)
	cp -v /archive/cm6/datasets/CM4/common/c96_grid/c96_OM4_025_grid_No_mg_drag_v20160808.unpacked/C96_mosaic.nc $(@)/.
	cp -v /archive/cm6/datasets/CM4/common/c96_grid/c96_OM4_025_grid_No_mg_drag_v20160808.unpacked/C96_grid.tile*.nc $(@)/.
	cp -v ocean_mosaic/ocean_hgrid.nc $(@)/.
	cp -v ocean_mosaic/ocean_mask.nc $(@)/.
	cp -v ocean_mosaic/ocean_mosaic.nc $(@)/.
	cp -v ocean_mosaic/ocean_topog.nc $(@)/.
	#
	cd $(@) && $(FRE_NCTOOLS)/make_coupler_mosaic \
            --atmos_mosaic C96_mosaic.nc \
            --ocean_mosaic ocean_mosaic.nc \
            --mosaic_name mosaic \
            --ocean_topog ocean_topog.nc


# Include additional makefile(s) defining input datasets
include *.mk

JRA: INPUT/salt_restore_JRA.nc JRA_runoff_files JRA_runoff_files_antmask

all: coupled_mosaic INPUT JRA

distclean:
	rm -f *.nc
	rm -fR interpolated_GEBCO
	rm -fR interpolated_BedMachine
	rm -fR tile_grids
	rm -fR assembled_topog
	rm -fR om5_topo_edits
	rm -fR INPUT
	rm -fR coupled_mosaic
	rm -fR JRA_runoff_files
	rm -fR JRA_runoff_files_antmask
	rm -fR ocean_mosaic
