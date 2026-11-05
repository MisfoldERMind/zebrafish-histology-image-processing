// =====================================================================
// Corrección de imágenes de tionina a 100x (tejido llena todo el campo)
// 1) Estima la iluminación a partir de las variaciones de gran escala
// 2) Divide por ella (quita el oscurecimiento de los bordes)
// 3) Balance de blancos usando los espacios claros del tejido
// 4) Refuerzo de tinción en densidad óptica (versión FUERTE)
// Procesa todas las .tif de una carpeta con los mismos parámetros.
// =====================================================================

K      = 1.4;
BLANCO = 245;
S      = 8;
SIGMA  = 40;
PBLANCO = 99.5;

dirIn  = getDirectory("Carpeta con las imagenes ORIGINALES (tionina 100x)");
dirOut = getDirectory("Carpeta donde GUARDAR las corregidas");
lista  = getFileList(dirIn);
setBatchMode(true);
run("Conversions...", "scale");

for (i = 0; i < lista.length; i++) {
    if (!endsWith(toLowerCase(lista[i]), ".tif")) continue;
    open(dirIn + lista[i]);
    nombre = File.nameWithoutExtension;
    if (bitDepth() != 24) run("RGB Color");
    rename("img");
    W = getWidth(); H = getHeight();
    w = floor(W / S); h = floor(H / S);

    selectWindow("img");
    run("Duplicate...", "title=forma");
    run("32-bit");
    run("Size...", "width=" + w + " height=" + h + " depth=1 average interpolation=Bilinear");
    run("Max...", "value=1");
    run("Min...", "value=1");
    run("Log");
    run("Gaussian Blur...", "sigma=" + SIGMA);
    p90 = percentil(90);
    run("Subtract...", "value=" + p90);
    run("Exp");
    run("Size...", "width=" + W + " height=" + H + " depth=1 interpolation=Bilinear");

    selectWindow("img");
    run("Split Channels");
    chF = newArray("img (red)", "img (green)", "img (blue)");
    sal = newArray("cR", "cG", "cB");

    for (c = 0; c < 3; c++) {
        selectWindow(chF[c]);
        run("32-bit");
        imageCalculator("Divide create 32-bit", chF[c], "forma");
        rename(sal[c]);
        close(chF[c]);
        selectWindow(sal[c]);

        wp = percentil(PBLANCO);
        codigo = "t=maxOf(0.004,minOf(1,v/" + wp + "));"
               + "v=" + BLANCO + "*pow(t," + K + ");";
        run("Macro...", "code=[" + codigo + "]");
        setMinAndMax(0, 255);
        run("8-bit");
    }

    close("forma");
    run("Merge Channels...", "c1=cR c2=cG c3=cB");
    saveAs("Tiff", dirOut + nombre + "_corr.tif");
    close("*");
}

setBatchMode(false);
showMessage("Listo", "Imagenes corregidas guardadas en:\n" + dirOut);

function percentil(p) {
    nBins = 10000;
    getStatistics(area, mean, mn, mx);
    getHistogram(valores, cuentas, nBins);
    total = 0;
    for (b = 0; b < nBins; b++) total = total + cuentas[b];
    objetivo = total * p / 100;
    acum = 0;
    for (b = 0; b < nBins; b++) {
        acum = acum + cuentas[b];
        if (acum >= objetivo) return valores[b] + (mx - mn) / nBins / 2;
    }
    return mx;
}
