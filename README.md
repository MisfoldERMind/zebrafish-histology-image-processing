# Reproducible ImageJ macros for zebrafish brain histology

ImageJ/Fiji macros used for reproducible and standardised visual processing of bright-field histological images from adult zebrafish brain sections stained with haematoxylin-eosin (H&E) or Nissl stains.

The repository was created to make the image-processing workflow transparent, inspectable and reproducible. Original microscopy files are retained unchanged; processed files are generated as separate derivatives.

## Repository contents

- `macros/HE_4x.ijm` — 4× H&E images: background/illumination correction, channel-wise normalisation and uniform stain enhancement.
- `macros/HE_10x_20x.ijm` — 10×/20× H&E images: tissue masking, radial illumination modelling, background correction and uniform stain enhancement.
- `macros/Nissl_thionin_100x.ijm` — 100× thionin images: large-scale illumination correction, white balancing and uniform stain enhancement.
- `macros/Nissl_cresyl_violet_100x.ijm` — 100× cresyl-violet images: common illumination correction, white balancing and conditional model-based reconstruction of saturated blue-channel optical density.

## Image-integrity principles

The macros apply predefined processing rules programmatically to all images acquired under the same condition. The workflows do not perform local manual retouching or selective region-specific enhancement.

The main operations are:

1. estimation of large-scale illumination/background variation;
2. correction by division by the estimated illumination field;
3. channel-wise white-balance normalisation;
4. fixed global intensity or optical-density transformations;
5. batch application of identical parameters within each acquisition condition.

All processing parameters are explicitly declared in the source code.

## Important limitation: cresyl-violet 100× images

The `Nissl_cresyl_violet_100x.ijm` workflow includes a conditional model-based reconstruction when saturation in the blue channel exceeds the predefined threshold. Reconstructed blue-channel values are inferred from green-channel optical density and an empirically estimated blue/green absorption relationship.

Accordingly:

- reconstructed images are intended for visual standardisation and figure preparation;
- reconstructed pixel values should not be used for pixel-level quantitative measurements;
- reconstructed images should not be the sole basis for detecting subtle morphological differences;
- original, unsaturated source images should be used whenever quantitative or diagnostic interpretation is required.

## Recommended data-integrity workflow

For each microscopy dataset, retain:

1. original acquisition files unchanged;
2. processed derivatives in a separate directory;
3. the exact macro version used;
4. acquisition metadata and microscope/camera settings;
5. the parameters used for each acquisition condition.

Original microscopy files should never be overwritten.

## Software

The scripts use the ImageJ/Fiji macro language. Histological images used for figure preparation were subsequently assembled in Inkscape.

## Reproducibility

Each macro prompts the user to select an input folder containing original TIFF images and a separate output folder. Images from a given acquisition condition are processed in batch using the same parameter set.

Because some parameters are acquisition-specific (for example optical centre coordinates or the fixed vertical artefact region), users applying these scripts to another microscope/camera configuration should inspect and adapt those parameters before use.

## Citation

For posters, manuscripts or supplementary methods, cite this GitHub repository together with the ImageJ/Fiji version used.

For archival publication, a tagged release can subsequently be deposited in Zenodo to obtain a permanent DOI.

## Licence

Code is distributed under the repository licence. Please retain attribution when reusing or adapting the macros.
