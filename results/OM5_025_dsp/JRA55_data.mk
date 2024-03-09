# Salt Restoring File
# -------------------
# The JRA55-do dataset provides an annual cycle climatology file to use
# for salt restoring. The climatology spans years 1955 to 2012 and is
# derived from World Ocean Atlas 2013 v2. The salinity is averaged over
# the uppermost 10-m in the water column and is better interpreted as
# salinity at 5-m depth rather than at the surface. (Tsijuno et al. 2018)
# https://doi.org/10.1016/j.ocemod.2018.07.002

# The climatology file used here was downloaded with JRA v1.4. It is
# assumed that this file is unchanged for future versions of JRA.
# This needs to be verified, but the download from ESGF is not working
# as of 13-Oct-2013

INPUT/sos_climatology_WOA13v2_provided_by_JRA55-do_v1_4.nc:
	mkdir -p INPUT
	cp $(GOLD_DIR)/reanalysis/JRA55-do/v1.4.0/original/sos_input4MIPs_atmosphericState_OMIP_MRI-JRA55-do-1-4-0_gr_195501-201212-clim.nc $(@)
	ncap2 -h -O -s 'time(:)={15,45,76,106,136,168,198,228,258,288,320,350}' $(@) $(@)
	ncatted -h -O -a units,time,o,c,'days since 1900-01-01 00:00:00' $(@)
	ncatted -h -O -a long_name,time,o,c,'Day of year' $(@)
	ncatted -h -O -a calendar,time,o,c,'julian' $(@)
	ncatted -h -O -a modulo,time,c,c,' ' $(@)
	ncatted -h -O -a calendar_type,time,c,c,'julian' $(@)

INPUT/salt_restore_JRA.nc: ocean_mosaic INPUT/sos_climatology_WOA13v2_provided_by_JRA55-do_v1_4.nc
	mkdir -p INPUT
	cd INPUT && ln -sf ../ocean_mosaic/ocean*.nc .
	cd INPUT && $(TOOLDIR)/interp_and_fill/interp_and_fill.py \
            ocean_hgrid.nc \
            ocean_mask.nc \
            sos_climatology_WOA13v2_provided_by_JRA55-do_v1_4.nc \
            sos --fms --closest salt_restore_JRA.nc
	cd INPUT && rm -f ocean*.nc

JRA_runoff_files: ocean_mosaic
	mkdir -p $(@)
	cd $(@) && for ver in v1.5.0 v1.5.0.1; do \
          for var in friver licalvf; do \
            for f in ${GOLD_DIR}/reanalysis/JRA55-do/$$ver/padded/$$var*.nc; do \
              $(PYTHON37) $(TOOLDIR)/regrid_runoff/regrid_runoff.py -p --fast_pickle \
                ../ocean_mosaic/ocean_hgrid.nc ../ocean_mosaic/ocean_mask.nc $$f \
                --runoff_var $$var --fms --compress `basename -s '.nc' $$f`.compressed.nc ; \
            done; \
          done; \
       done

JRA_runoff_files_antmask: JRA_runoff_files
	mkdir -p $(@)
	cd $(@) && \
          for var in friver licalvf; do \
            for f in ../JRA_runoff_files/$$var*.nc; do \
              echo $$f ; \
              ncap2 -s "where(j<300) $$var=$$var*0.0;" $$f `basename -s '.nc' $$f`.antmasked.nc ; \
            done; \
          done

