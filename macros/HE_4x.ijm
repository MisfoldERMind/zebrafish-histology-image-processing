// =====================================================================

// Corrección de imágenes de campo claro (HE): iluminación desigual,

// balance de blancos y refuerzo uniforme de la tinción.

// Procesa todas las .tif de una carpeta con LOS MISMOS parámetros.

// =====================================================================



K      = 1.8;   // refuerzo de la tinción (densidad óptica). Igual para todas.

BLANCO = 245;   // valor que tendrá el fondo después de corregir

F      = 8;     // factor de reducción para estimar el fondo

R      = 12;    // radio de filtro (en píxeles de la imagen reducida)



dirIn  = getDirectory("Elige la carpeta con las imagenes ORIGINALES");

dirOut = getDirectory("Elige la carpeta donde GUARDAR las corregidas");

lista  = getFileList(dirIn);

setBatchMode(true);



for (i = 0; i < lista.length; i++) {

    if (!endsWith(toLowerCase(lista[i]), ".tif")) continue;



    open(dirIn + lista[i]);

    nombre = File.nameWithoutExtension;

    if (bitDepth() != 24) run("RGB Color");

    rename("img");

    w = getWidth();

    h = getHeight();



    run("Split Channels");               // crea "img (red)", "img (green)", "img (blue)"

    canales = newArray("img (red)", "img (green)", "img (blue)");

    salida  = newArray("cR", "cG", "cB");



    for (c = 0; c < 3; c++) {

        selectWindow(canales[c]);

        run("32-bit");



        // --- 1. Estimar el fondo (imagen reducida, filtros, ampliar) ---

        run("Scale...", "x=" + (1/F) + " y=" + (1/F) + " interpolation=Bilinear average create title=fondo");

        selectWindow("fondo");

        run("Maximum...", "radius=" + R);   // rellena el tejido con el fondo vecino

        run("Minimum...", "radius=" + R);

        run("Gaussian Blur...", "sigma=" + R);

        run("Size...", "width=" + w + " height=" + h + " depth=1 interpolation=Bilinear");



        // --- 2. Dividir por el fondo: quita viñeteo y neutraliza el color ---

        imageCalculator("Divide create 32-bit", canales[c], "fondo");

        rename(salida[c]);

        run("Min...", "value=0.004");

        run("Max...", "value=1");            // fondo = 1, tejido < 1



        // --- 3. Refuerzo uniforme de la tinción: v = BLANCO * v^K ---

        run("Macro...", "code=v=" + BLANCO + "*pow(v," + K + ")");



        setMinAndMax(0, 255);

        run("8-bit");



        close(canales[c]);

        close("fondo");

    }



    run("Merge Channels...", "c1=cR c2=cG c3=cB");   // vuelve a RGB

    saveAs("Tiff", dirOut + nombre + "_corr.tif");

    close("*");

}



setBatchMode(false);

showMessage("Listo", "Imagenes corregidas guardadas en:\n" + dirOut);
