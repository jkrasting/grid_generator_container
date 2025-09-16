# Dockerfile for container used to generate OM5 grids and datasets
# J. Krasting NOAA/GFDL
# Last updated: 18 October 2023


# Stage 00: Establish the base container
#----------------------------------------------
# Use Miniconda3 AS base image
#FROM continuumio/miniconda3:23.3.1-0 AS base
FROM condaforge/miniforge3 AS base

# Turn off prompts
ARG DEBIAN_FRONTEND=noninteractive

# Set the name for the non-privilged user
ARG UNPRIV_USER=griduser

# Install Fortran Libraries & make
RUN apt-get update && apt-get install -y \
    git \
    libnetcdf-dev \
    libnetcdff-dev \
    make \
    nco \
    wget \
    libc-bin \
    less \
    ucommon-utils \
    patch \
    tcsh \
    emacs \
    vim

# Create the non-privilged user
RUN groupadd $UNPRIV_USER && useradd -ms /bin/bash -g $UNPRIV_USER $UNPRIV_USER
RUN mkdir -p /pad/$UNPRIV_USER
RUN chown $UNPRIV_USER:$UNPRIV_USER /pad/$UNPRIV_USER
RUN usermod -d /pad/$UNPRIV_USER $UNPRIV_USER

# Stage 0: Compiler Tools
#----------------------------------------------
FROM base AS compiler

# Install git, C-compiler, Fortran-compiler and autoreconf
RUN apt-get update && apt-get install -y \
    autoconf \
    gcc-10 \
    gfortran-10

RUN ln -s /usr/bin/gcc-10 /usr/bin/gcc
RUN ln -s /usr/bin/gfortran-10 /usr/bin/gfortran


# Stage 1: Build the Python environment with tools
#----------------------------------------------
FROM compiler AS python

# Update system level conda and add conda-forge as a channel
RUN conda install mamba

# Switch to non-privileged user
ARG UNPRIV_USER=griduser
USER $UNPRIV_USER

# Create a new conda environment with Python 3.11 and the necessary packages
RUN mamba create -y --prefix /pad/griduser/.conda/envs/py311 \
    python=3.11.8=hab00c5b_0_cpython \
    numpy=1.26.4=py311h64a7726_0 \
    scipy=1.13.0=py311h64a7726_0 \
    matplotlib=3.8.4=py311h38be061_0 \
    cartopy=0.22.0=py311h320fe9a_1 \
    netcdf4=1.6.5=nompi_py311he8ad708_100 \
    pytest=8.1.1=pyhd8ed1ab_0 \
    xarray=2024.3.0=pyhd8ed1ab_0 \
    dask=2024.4.1=pyhd8ed1ab_0 \
    numba=0.59.1=py311h96b013e_0 \
    tqdm=4.66.2=pyhd8ed1ab_0 \
    xesmf=0.8.4=pyhd8ed1ab_1 \
    xgcm=0.8.1=pyhd8ed1ab_0 \
    seawater=3.3.4=py_1 \
    jupyter=1.0.0=pyhd8ed1ab_10 \
    cmocean=4.0.3=pyhd8ed1ab_0 

# Create a Python 2.7 environment for the legacy tools
RUN mamba create -y --prefix /pad/griduser/.conda/envs/py27 \
    python=2.7.15=h5a48372_1011_cpython \
    numpy=1.16.5=py27h95a1406_0 \
    basemap=1.2.1=py27hd1be537_2 \
    blas=2.20=mkl \
    cftime=1.1.1=py27h588f082_0 \
    geos=3.8.0=he1b5a44_1 \
    glib=2.66.3=h58526e2_0 \
    gstreamer=1.14.5=h36ae1b5_2 \
    gsw=3.0.6=py27_0 \
    hdf4=4.2.15=h9772cbc_5 \
    hdf5=1.10.5=nompi_h7c3c948_1111 \
    matplotlib=2.2.5=ha770c72_3 \
    netcdf4=1.5.3=nompi_py27hd35fb8e_102 \
    proj4=5.2.0=he1b5a44_1006 \
    pyproj=1.9.6=py27h516909a_1002 \
    scipy=1.2.1=py27h921218d_2

# Create a Python 3.7 environment for the river runoff regridding
RUN mamba create -y --prefix /pad/griduser/.conda/envs/py37 \
    python=3.7.12=hf930737_100_cpython \
    numpy=1.17.3=py37h95a1406_0 \
    scipy=1.3.1=py37h921218d_2 \
    netcdf4=1.4.2=py37had69b76_1001 \
    numba=0.50.1=py37h0da4684_1 


# Stage 2: Build the FRE NCtools
#----------------------------------------------
FROM compiler AS fretools

# FRE-NCtools version
ARG FRENC_COMMIT=dcbfc10

# Clone and install FRE-NCtools
RUN git clone https://github.com/NOAA-GFDL/FRE-NCtools.git
RUN cd FRE-NCtools && git checkout $FRENC_COMMIT

RUN cd FRE-NCtools && autoreconf -i && ./configure --prefix=/opt/fre-nctools && make install
RUN apt list --installed > /opt/fre-nctools/version_record.txt



# Stage 3: Assemble Python Toolsets
#---------------------------------------------
FROM base AS tools

ARG UNPRIV_USER=griduser

# Specify tool directory
ARG TOOLDIR=/opt
RUN mkdir -p $TOOLDIR
RUN chown $UNPRIV_USER $TOOLDIR
RUN chgrp $UNPRIV_USER $TOOLDIR

# Switch to non-privileged user
USER $UNPRIV_USER

RUN cd $TOOLDIR && git clone --recursive https://github.com/jkrasting/grid_generator_container.git tools && cd tools && git submodule update --recursive


# Stage 4: Install Python packages in developer mode
#---------------------------------------------
FROM python AS python-installed

# Specify tool directory
ARG TOOLDIR=/opt/tools
COPY --from=tools $TOOLDIR $TOOLDIR

# Switch to non-privileged user
ARG UNPRIV_USER=griduser
USER $UNPRIV_USER

SHELL ["conda", "run", "-n", "py311", "/bin/bash", "-c"]
RUN cd $TOOLDIR/numpypi && pip install -e .
RUN cd $TOOLDIR/ocean_model_grid_generator && pip install -e .
RUN cd $TOOLDIR/ocean_model_topog_generator && pip install -e .
RUN cd $TOOLDIR/sloppy && pip install -e .


# Stage 5: Build OM4 Preprocessing Tools
#---------------------------------------------
FROM python-installed AS om4preprocess

#ARG UNPRIV_USER=griduser
#
## Open up permissions
#USER root
#RUN mkdir -p $TOOLDIR
#RUN chown $UNPRIV_USER $TOOLDIR
#RUN chgrp $UNPRIV_USER $TOOLDIR

ARG TOOLDIR=/opt/tools

USER $UNPRIV_USER

SHELL ["conda", "run", "-n", "py27", "/bin/bash", "-c"]

RUN cd $TOOLDIR/MOM6-examples \
    && cd ice_ocean_SIS2/OM4_025/preprocessing \
    && make MIDAS \
    && make local


# Stage 6: Assemble the container
#---------------------------------------------
FROM om4preprocess

SHELL ["/bin/bash", "-c"]

ARG UNPRIV_USER=griduser
USER root

COPY --from=fretools /opt/fre-nctools /opt/fre-nctools

# Activate conda environment in .bashrc
RUN echo "export TERM=xterm" > /pad/$UNPRIV_USER/.bashrc
RUN echo "source activate py311" >> /pad/$UNPRIV_USER/.bashrc
RUN echo "echo 'OM5 Preprocessing Container'" >> /pad/$UNPRIV_USER/.bashrc

# Make mount points for GFDL-specific dataset locations
RUN mkdir -p /archive/gold \
    && mkdir -p /archive/cm6 \
    && mkdir -p /archive/pcm \
    && mkdir -p /archive/kap

# Make results directory
RUN cp -r /opt/tools/results /results
RUN chown -R $UNPRIV_USER /results
RUN chgrp -R $UNPRIV_USER /results

USER $UNPRIV_USER

CMD ["/bin/bash"]
