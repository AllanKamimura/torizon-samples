#!/bin/bash
set -e
source build_variables.sh `basename "$0"`

THIS_DIR=$(cd $(dirname $0) && pwd)
FSL_MIRROR='https://www.nxp.com/lgfiles/NMG/MAD/YOCTO'
SRC_URI="${FSL_MIRROR}/${BPN}-${PV}.bin"
IMX_SOC='mx8mp'
IS_MX8='1'
BACKEND="wayland"

LIBVULKAN_VERSION_MAJOR="1"
LIBVULKAN_VERSION="${LIBVULKAN_VERSION_MAJOR}.2.1"

pushd ${WORKDIR} && wget ${SRC_URI} && \
  chmod +x ./${BPN}-${PV}.bin && \
  ./${BPN}-${PV}.bin --force --auto-accept && \
  mv ${BPN}-${PV} ${PN} && \
popd

# do_install () ##
install -d ${D}${libdir}
install -d ${D}${includedir}
install -d ${D}${bindir}

cp -P ${S}/gpu-core/usr/lib/*.so* ${D}${libdir}
cp -r ${S}/gpu-core/usr/include/* ${D}${includedir}
cp -r ${S}/gpu-demos/opt ${D}
cp -r ${S}/gpu-tools/gmem-info/usr/bin/* ${D}${bindir}

# Use vulkan header from vulkan-headers recipe to support vkmark
rm -rf ${D}${includedir}/vulkan/

if [ -d ${S}/gpu-core/usr/lib/${IMX_SOC} ]; then
    cp -r ${S}/gpu-core/usr/lib/${IMX_SOC}/* ${D}${libdir}
fi

install -d ${D}${libdir}/pkgconfig
if ${HAS_GBM}; then
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/gbm.pc ${D}${libdir}/pkgconfig/gbm.pc
fi

if [ "${BACKEND}" = "wayland" ]; then
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/egl_wayland.pc ${D}${libdir}/pkgconfig/egl.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/glesv1_cm.pc ${D}${libdir}/pkgconfig/glesv1_cm.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/glesv2.pc ${D}${libdir}/pkgconfig/glesv2.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/vg.pc ${D}${libdir}/pkgconfig/vg.pc
else
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/glesv1_cm.pc ${D}${libdir}/pkgconfig/glesv1_cm.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/glesv2.pc ${D}${libdir}/pkgconfig/glesv2.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/vg.pc ${D}${libdir}/pkgconfig/vg.pc
    install -m 0644 ${S}/gpu-core/usr/lib/pkgconfig/egl_linuxfb.pc ${D}${libdir}/pkgconfig/egl.pc
fi

# Install Vendor ICDs for OpenCL's installable client driver loader (ICDs Loader)
install -d ${D}${sysconfdir}/OpenCL/vendors/
install -m 0644 ${S}/gpu-core/etc/Vivante.icd ${D}${sysconfdir}/OpenCL/vendors/Vivante.icd

# Handle backend specific drivers
cp -r ${S}/gpu-core/usr/lib/${BACKEND}/* ${D}${libdir}
if [ "${BACKEND}" = "wayland" ] && [ "${IS_MX8}" != "1" ]; then
    # Special case for libVDK on Wayland backend, deliver fb library as well.
    cp ${S}/gpu-core/usr/lib/fb/libVDK.so.1.2.0 ${D}${libdir}/libVDK-fb.so.1.2.0
fi
# if [ "${IS_MX8}" = "1" ]; then
#     # Rename the vulkan implementation library which is wrapped by the vulkan-loader
#     # library of the same name
#     MAJOR=${LIBVULKAN_VERSION_MAJOR}
#     FULL=${LIBVULKAN_VERSION}
#     mv ${D}${libdir}/libvulkan.so.$FULL ${D}${libdir}/libvulkan_VSI.so.$FULL
#     patchelf --set-soname libvulkan_VSI.so.$MAJOR ${D}${libdir}/libvulkan_VSI.so.$FULL
#     rm ${D}${libdir}/libvulkan.so.$MAJOR ${D}${libdir}/libvulkan.so
#     ln -s libvulkan_VSI.so.$FULL ${D}${libdir}/libvulkan_VSI.so.$MAJOR
#     ln -s libvulkan_VSI.so.$FULL ${D}${libdir}/libvulkan_VSI.so
# fi

# FIXME: MX6SL does not have 3D support; hack it for now
if [ "${IS_MX6SL}" = "1" ]; then
    rm -rf ${D}${libdir}/libCLC* ${D}${includedir}/CL \
           \
           ${D}${libdir}/libGL* ${D}${includedir}/GL* ${D}${libdir}/pkgconfig/gl.pc \
           \
           ${D}${libdir}/libGLES* ${D}${libdir}/pkgconfig/gles*.pc \
           \
           ${D}${libdir}/libOpenCL* ${D}${includedir}/CL \
           \
           ${D}${libdir}/libOpenVG.3d.so \
           \
           ${D}${libdir}/libVivanteOpenCL.so \
           \
           ${D}/opt/viv_samples/vdk \
           ${D}/opt/viv_samples/es20 ${D}/opt/viv_samples/cl11

    ln -sf libOpenVG.2d.so ${D}${libdir}/libOpenVG.so
fi

find ${D}${libdir} -type f -exec chmod 644 {} \;
find ${D}${includedir} -type f -exec chmod 644 {} \;

chown -R root:root "${D}"

# Copy installed libraries to rootfs #
cp -r ${D}/* /
# Reload libraries #
ldconfig
# Clean build directory #
rm -rf ${WORKDIR}
