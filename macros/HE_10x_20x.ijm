// =====================================================================
// Corrección de imágenes HE a 10x / 20x (tejido ocupa gran parte del campo)
// 1) Detecta el tejido  2) Ajusta el viñeteo circular SOLO con el fondo
// 3) Divide por el fondo  4) Refuerzo uniforme de tinción
// Procesa todas las .tif de una carpeta con los mismos parámetros.
// =====================================================================

K      = 1.8;
BLANCO = 245;
S      = 8;
DEG    = 4;
CX     = 1360;
CY     = 940;

dirIn  = getDirectory("Carpeta con las imagenes ORIGINALES (10x/20x)");
dirOut = getDirectory("Carpeta donde GUARDAR las corregidas");
lista  = getFileList(dirIn);
setBatchMode(true);

for (i = 0; i < lista.length; i++) {
    if (!endsWith(toLowerCase(lista[i]), ".tif")) continue;
    open(dirIn + lista[i]);
    nombre = File.nameWithoutExtension;
    if (bitDepth() != 24) run("RGB Color");
    rename("img");
    W = getWidth(); H = getHeight();
    w = floor(W / S); h = floor(H / S);

    selectWindow("img");
    run("Duplicate...", "title=small");
    run("Size...", "width=" + w + " height=" + h + " depth=1 average interpolation=Bilinear");
    run("Duplicate...", "title=gris");
    run("32-bit");

    selectWindow("gris");
    run("Duplicate...", "title=suave");
    run("Gaussian Blur...", "sigma=3");
    imageCalculator("Subtract create 32-bit", "gris", "suave");
    rename("tex");
    close("suave");
    selectWindow("tex");
    run("Square");
    run("Mean...", "radius=4");
    run("Square Root");

    n = w * h;
    vals = newArray(n);
    k = 0;
    for (y = 0; y < h; y++) for (x = 0; x < w; x++) { vals[k] = getPixel(x, y); k++; }
    orden = Array.copy(vals);
    Array.sort(orden);
    umbralTex = orden[floor(0.55 * n)];

    newImage("mask", "8-bit black", w, h, 1);
    k = 0;
    for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
        if (vals[k] > umbralTex) setPixel(x, y, 255);
        k++;
    }
    run("Options...", "iterations=6 count=1 black");
    run("Close-");
    run("Options...", "iterations=3 count=1 black");
    run("Open");
    run("Fill Holes");
    run("Options...", "iterations=4 count=1 black");
    run("Dilate");
    run("Options...", "iterations=1 count=1 black");

    selectWindow("mask");
    m = newArray(n);
    k = 0;
    for (y = 0; y < h; y++) for (x = 0; x < w; x++) { m[k] = getPixel(x, y); k++; }
    selectWindow("gris");
    g = newArray(n);
    nb = 0;
    k = 0;
    for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
        g[k] = getPixel(x, y);
        if (m[k] == 0) nb++;
        k++;
    }
    fondo = newArray(nb);
    j = 0;
    for (k = 0; k < n; k++) if (m[k] == 0) { fondo[j] = g[k]; j++; }
    Array.sort(fondo);
    umbralOscuro = 0.55 * fondo[floor(0.95 * nb)];

    selectWindow("small");
    run("Split Channels");
    selectWindow("img");
    run("Split Channels");
    chS = newArray("small (red)", "small (green)", "small (blue)");
    chF = newArray("img (red)", "img (green)", "img (blue)");
    sal = newArray("cR", "cG", "cB");
    D = DEG + 1;

    for (c = 0; c < 3; c++) {
        ATA = newArray(D * D);
        ATz = newArray(D);
        selectWindow(chS[c]);
        k = 0;
        for (y = 0; y < h; y++) for (x = 0; x < w; x++) {
            if (m[k] == 0 && g[k] > umbralOscuro) {
                px = x * S + S / 2; py = y * S + S / 2;
                r2 = ((px - CX) * (px - CX) + (py - CY) * (py - CY)) / 2560000;
                z = log(maxOf(getPixel(x, y), 1));
                f = newArray(D);
                f[0] = 1;
                for (q = 1; q < D; q++) f[q] = f[q - 1] * r2;
                for (a = 0; a < D; a++) {
                    ATz[a] = ATz[a] + f[a] * z;
                    for (b = 0; b < D; b++) ATA[a * D + b] = ATA[a * D + b] + f[a] * f[b];
                }
            }
            k++;
        }
        coef = resolver(ATA, ATz, D);

        expr = "" + d2s(coef[0], 12);
        for (q = 1; q < D; q++) {
            pot = "r";
            for (e = 1; e < q; e++) pot = pot + "*r";
            expr = expr + "+(" + d2s(coef[q], 12) + ")*" + pot;
        }
        codigo = "r=((x-" + CX + ")*(x-" + CX + ")+(y-" + CY + ")*(y-" + CY + "))/2560000;"
               + "bg=minOf(exp(" + expr + "),255);"
               + "t=maxOf(0.004,minOf(1,v/bg));"
               + "v=" + BLANCO + "*pow(t," + K + ");";

        selectWindow(chF[c]);
        run("32-bit");
        run("Macro...", "code=[" + codigo + "]");
        setMinAndMax(0, 255);
        run("8-bit");
        rename(sal[c]);
    }

    run("Merge Channels...", "c1=cR c2=cG c3=cB");
    saveAs("Tiff", dirOut + nombre + "_corr.tif");
    close("*");
}

setBatchMode(false);
showMessage("Listo", "Imagenes corregidas guardadas en:\n" + dirOut);

function resolver(A, bvec, nn) {
    for (ii = 0; ii < nn; ii++) {
        p = ii;
        for (rr = ii + 1; rr < nn; rr++)
            if (abs(A[rr * nn + ii]) > abs(A[p * nn + ii])) p = rr;
        if (p != ii) {
            for (cc = 0; cc < nn; cc++) {
                t = A[ii * nn + cc]; A[ii * nn + cc] = A[p * nn + cc]; A[p * nn + cc] = t;
            }
            t = bvec[ii]; bvec[ii] = bvec[p]; bvec[p] = t;
        }
        for (rr = ii + 1; rr < nn; rr++) {
            fac = A[rr * nn + ii] / A[ii * nn + ii];
            for (cc = ii; cc < nn; cc++) A[rr * nn + cc] = A[rr * nn + cc] - fac * A[ii * nn + cc];
            bvec[rr] = bvec[rr] - fac * bvec[ii];
        }
    }
    sol = newArray(nn);
    for (ii = nn - 1; ii >= 0; ii--) {
        s = bvec[ii];
        for (cc = ii + 1; cc < nn; cc++) s = s - A[ii * nn + cc] * sol[cc];
        sol[ii] = s / A[ii * nn + ii];
    }
    return sol;
}
