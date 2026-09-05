#include <cups/raster.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int sample_is_dark(const unsigned char *p, unsigned bpp, cups_cspace_t cs)
{
    if (bpp == 1) {
        return *p ? 1 : 0;
    }

    if (bpp == 8 || cs == CUPS_CSPACE_W || cs == CUPS_CSPACE_SW ||
        cs == CUPS_CSPACE_K || cs == CUPS_CSPACE_GRAYE) {
        return *p < 160;
    }

    if (bpp >= 24) {
        unsigned r = p[0], g = p[1], b = p[2];
        unsigned y = (299 * r + 587 * g + 114 * b) / 1000;
        return y < 160;
    }

    return *p < 160;
}

int main(int argc, char **argv)
{
    int fd = 0;
    if (argc > 1 && strcmp(argv[1], "-") != 0) {
        fd = open(argv[1], O_RDONLY);
        if (fd < 0) {
            fprintf(stderr, "m1005-raster2pbm: open %s: %s\n", argv[1], strerror(errno));
            return 1;
        }
    }

    cups_raster_t *ras = cupsRasterOpen(fd, CUPS_RASTER_READ);
    if (!ras) {
        fprintf(stderr, "m1005-raster2pbm: cupsRasterOpen failed\n");
        return 1;
    }

    cups_page_header2_t h;
    unsigned page = 0;
    while (cupsRasterReadHeader2(ras, &h)) {
        page++;
        unsigned width = h.cupsWidth;
        unsigned height = h.cupsHeight;
        unsigned in_bytes = h.cupsBytesPerLine;
        unsigned out_bytes = (width + 7) / 8;
        unsigned bpp = h.cupsBitsPerPixel;
        unsigned bytes_per_pixel = bpp >= 8 ? (bpp + 7) / 8 : 1;

        fprintf(stderr,
                "PAGE: %u %u width=%u height=%u bpp=%u cs=%d xdpi=%u ydpi=%u\n",
                page, page, width, height, bpp, h.cupsColorSpace,
                h.HWResolution[0], h.HWResolution[1]);

        unsigned char *in = calloc(1, in_bytes);
        unsigned char *out = calloc(1, out_bytes);
        if (!in || !out) {
            fprintf(stderr, "m1005-raster2pbm: out of memory\n");
            return 1;
        }

        printf("P4\n%u %u\n", width, height);
        for (unsigned y = 0; y < height; y++) {
            if (cupsRasterReadPixels(ras, in, in_bytes) != in_bytes) {
                fprintf(stderr, "m1005-raster2pbm: short raster row\n");
                return 1;
            }

            memset(out, 0, out_bytes);
            for (unsigned x = 0; x < width; x++) {
                int dark = 0;
                if (bpp == 1) {
                    dark = (in[x / 8] & (0x80 >> (x & 7))) != 0;
                } else {
                    const unsigned char *p = in + x * bytes_per_pixel;
                    if ((unsigned)(p - in) < in_bytes) {
                        dark = sample_is_dark(p, bpp, h.cupsColorSpace);
                    }
                }
                if (dark) {
                    out[x / 8] |= (0x80 >> (x & 7));
                }
            }

            if (fwrite(out, 1, out_bytes, stdout) != out_bytes) {
                fprintf(stderr, "m1005-raster2pbm: write failed\n");
                return 1;
            }
        }
        free(in);
        free(out);
    }

    cupsRasterClose(ras);
    if (fd != 0) close(fd);
    return page ? 0 : 1;
}
