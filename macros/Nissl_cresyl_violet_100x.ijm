// =====================================================================
// Corrección de imágenes de CRESIL VIOLETA a 100x
// Paso 1: patrón de iluminación COMÚN a todas las fotos (+ línea vertical fija)
// Paso 2: relación de absorción azul/verde del cresil (fotos no saturadas)
// Paso 3: corrección, balance de blancos, reconstrucción del azul saturado
//         (si la foto lo necesita) y refuerzo FUERTE de tinción
// Todas las fotos deben ser del MISMO objetivo y cámara (2560x1920).
// =====================================================================

K       = 1.4;
BLANCO  = 245;
PBLANCO = 99.5;
SATLIM  = 0.05;
LX0 = 745; LX1 = 815; LY0 = 200; LY1 = 740;
MARG = 12; MEDLEN = 30;

dirIn  = getDirectory("Carpeta con las imagenes ORIGINALES (cresil 100x)");
dirOut = getDirectory("Carpeta donde GUARDAR las corregidas");
todos  = getFileList(dirIn);
lista  = newArray(0);
for (i = 0; i < todos.length; i++)
    if (endsWith(toLowerCase(todos[i]), ".tif")) lista = Array.concat(lista, todos[i]);

setBatchMode(true);
run("Conversions...", "scale");

// ===================== PASO 1: patrón común =====================
for (i = 0; i < lista.length; i++) {
    open(dirIn + lista[i]);
    if (bitDepth() != 24) run("RGB Color");
    rename("img");
    W = getWidth(); H = getHeight();
    run("Split Channels");
    close("img (red)");
    close("img (blue)");
    selectWindow("img (green)");
    run("32-bit");
    run("Size...", "width=" + (W/2) + " height=" + (H/2) + " depth=1 average interpolation=Bilinear");
    run("Min...", "value=1");
    run("Log");
    p = percentil(90);
    run("Subtract...", "value=" + d2s(p, 6));
    rename("g_" + i);
}

run("Images to Stack", "name=pila title=g_ use");
run("Z Project...", "projection=Median");
rename("med");
close("pila");
w2 = getWidth(); h2 = getHeight();

selectWindow("med"); run("Duplicate...", "title=illum");
run("Gaussian Blur...", "sigma=80");

selectWindow("med"); run("Duplicate...", "title=suave");
run("Gaussian Blur...", "sigma=25");
imageCalculator("Subtract create 32-bit", "med", "suave");
rename("res");
close("suave");

ya = maxOf(0, LY0 - MARG - MEDLEN); yb = minOf(h2 - 1, LY1 + MARG + MEDLEN);
xa = LX0 - MARG; xb = LX1 + MARG;
nx = xb - xa + 1; ny = yb - ya + 1;
selectWindow("res");
R = newArray(nx * ny);
for (y = ya; y <= yb; y++) for (x = xa; x <= xb; x++) R[(y - ya) * nx + (x - xa)] = getPixel(x, y);

newImage("vert", "32-bit black", w2, h2, 1);
selectWindow("vert");
ventana = newArray(2 * MEDLEN + 1);
for (y = LY0 - MARG; y < LY1 + MARG; y++) {
    for (x = xa; x <= xb; x++) {
        cnt = 0;
        for (d = -MEDLEN; d <= MEDLEN; d++) {
            yy = y + d;
            if (yy < ya) yy = ya;
            if (yy > yb) yy = yb;
            ventana[cnt] = R[(yy - ya) * nx + (x - xa)];
            cnt++;
        }
        ord = Array.sort(Array.copy(ventana));
        val = ord[MEDLEN];
        if (val > 0) val = 0;
        setPixel(x, y, val);
    }
}

newImage("banda", "32-bit black", w2, h2, 1);
makeRectangle(LX0, LY0, LX1 - LX0, LY1 - LY0);
run("Set...", "value=1");
run("Select None");
run("Gaussian Blur...", "sigma=4");
imageCalculator("Multiply create 32-bit", "vert", "banda");
rename("defecto");

imageCalculator("Add create 32-bit", "illum", "defecto");
rename("forma");
p = percentil(90);
run("Subtract...", "value=" + d2s(p, 6));
run("Exp");
run("Size...", "width=" + (2 * w2) + " height=" + (2 * h2) + " depth=1 interpolation=Bilinear");
cerrar(newArray("med", "illum", "res", "vert", "banda", "defecto"));

// ===================== PASO 2: relación azul/verde del cresil =====================
ratios = newArray(0);
for (i = 0; i < lista.length; i++) {
    sat = cargar(dirIn + lista[i]);
    if (sat < 0.01) {
        selectWindow("fG"); wpG = percentil(PBLANCO);
        selectWindow("fB"); wpB = percentil(PBLANCO);
        odImg("fG", wpG, "odG");
        odImg("fB", wpB, "odB");
        selectWindow("odG"); run("Duplicate...", "title=condG");
        run("Macro...", "code=[if (v>0.3) v=1; else v=NaN;]");
        imageCalculator("Divide create 32-bit", "odB", "odG");
        rename("rat");
        imageCalculator("Multiply", "rat", "condG");
        selectWindow("rat");
        ratios = Array.concat(ratios, percentil(50));
    }
    cerrar(newArray("fR", "fG", "fB", "aB", "odG", "odB", "condG", "rat"));
}

if (ratios.length > 0) {
    Array.sort(ratios);
    rBG = ratios[floor(ratios.length / 2)];
} else {
    rBG = 0.61;
}

print("Relacion de absorcion azul/verde del cresil: " + d2s(rBG, 3));

// ===================== PASO 3: corrección final =====================
for (i = 0; i < lista.length; i++) {
    nombre = File.getNameWithoutExtension(lista[i]);
    sat = cargar(dirIn + lista[i]);

    selectWindow("fR"); wpR = percentil(PBLANCO);
    selectWindow("fG"); wpG = percentil(PBLANCO);
    odImg("fR", wpR, "odR");
    odImg("fG", wpG, "odG");

    if (sat < SATLIM) {
        selectWindow("fB"); wpB = percentil(PBLANCO);
        odImg("fB", wpB, "odB");
    } else {
        print(nombre + ": azul saturado (" + d2s(100 * sat, 1) + "%), se reconstruye");

        selectWindow("fB"); run("Duplicate...", "title=lb");
        run("Macro...", "code=[v=log(maxOf(v,0.000001));]");
        selectWindow("odG"); run("Duplicate...", "title=t2");
        run("Multiply...", "value=" + d2s(rBG, 6));
        imageCalculator("Add create 32-bit", "lb", "t2");
        rename("suma");

        selectWindow("aB"); run("Duplicate...", "title=condB"); run("32-bit");
        run("Macro...", "code=[if (v<250) v=1; else v=NaN;]");
        selectWindow("odG"); run("Duplicate...", "title=condG");
        run("Macro...", "code=[if (v>0.3) v=1; else v=NaN;]");
        imageCalculator("Multiply", "suma", "condB");
        imageCalculator("Multiply", "suma", "condG");
        selectWindow("suma");
        wpB = exp(percentil(50));

        selectWindow("fB"); run("Duplicate...", "title=odB");
        run("Macro...", "code=[v=-log(maxOf(0.004,v/" + d2s(wpB, 6) + ")); v=maxOf(v,0);]");

        selectWindow("aB"); run("Duplicate...", "title=S"); run("32-bit");
        run("Macro...", "code=[if (v>=250) v=1; else v=0;]");
        selectWindow("S"); run("Duplicate...", "title=NS");
        run("Macro...", "code=[v=1-v;]");
        imageCalculator("Multiply", "odB", "NS");
        imageCalculator("Multiply", "t2", "S");
        imageCalculator("Add", "odB", "t2");

        cerrar(newArray("lb", "t2", "suma", "condB", "condG", "S", "NS"));
    }

    od  = newArray("odR", "odG", "odB");
    sal = newArray("cR", "cG", "cB");
    for (c = 0; c < 3; c++) {
        selectWindow(od[c]);
        run("Macro...", "code=[v=" + BLANCO + "*exp(-" + K + "*v);]");
        setMinAndMax(0, 255);
        run("8-bit");
        rename(sal[c]);
    }

    run("Merge Channels...", "c1=cR c2=cG c3=cB");
    saveAs("Tiff", dirOut + nombre + "_cresil_corr.tif");
    close();
    cerrar(newArray("fR", "fG", "fB", "aB"));
}

close("forma");
setBatchMode(false);
showMessage("Listo", "Imagenes corregidas guardadas en:\n" + dirOut);

// ===================== Funciones =====================
function cargar(ruta) {
    open(ruta);
    if (bitDepth() != 24) run("RGB Color");
    rename("img");
    run("Split Channels");

    selectWindow("img (blue)");
    getHistogram(vv, cc, 256);
    tot = 0; s = 0;
    for (b = 0; b < 256; b++) { tot += cc[b]; if (b >= 250) s += cc[b]; }
    run("Duplicate...", "title=aB");

    ch = newArray("img (red)", "img (green)", "img (blue)");
    nm = newArray("fR", "fG", "fB");
    for (c = 0; c < 3; c++) {
        selectWindow(ch[c]);
        run("32-bit");
        imageCalculator("Divide create 32-bit", ch[c], "forma");
        rename(nm[c]);
        close(ch[c]);
    }
    return s / tot;
}

function odImg(src, wp, dst) {
    selectWindow(src);
    run("Duplicate...", "title=" + dst);
    run("Macro...", "code=[v=-log(maxOf(0.004,minOf(1,v/" + d2s(wp, 6) + ")));]");
}

function percentil(p) {
    nBins = 10000;
    getStatistics(area, mean, mn, mx);
    getHistogram(valores, cuentas, nBins);
    total = 0;
    for (b = 0; b < nBins; b++) total += cuentas[b];
    objetivo = total * p / 100;
    acum = 0;
    for (b = 0; b < nBins; b++) {
        acum += cuentas[b];
        if (acum >= objetivo) return valores[b] + (mx - mn) / nBins / 2;
    }
    return mx;
}

function cerrar(nombres) {
    for (q = 0; q < nombres.length; q++) if (isOpen(nombres[q])) close(nombres[q]);
}
