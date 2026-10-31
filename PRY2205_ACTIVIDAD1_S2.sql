/* ============================================================
   Caso 1: Análisis de Facturas
   ------------------------------------------------------------
   @descripcion  Informe de las facturas emitidas el año anterior
                 al año de ejecución, con montos formateados,
                 clasificación por rango de total y forma de pago.
   @tablas       FACTURA
   @autores      [Sebastian Estrada], [Consuelo Martinez]
   @fecha        [31-10-2026]
   @asignatura   PRY2205 - Consulta de Bases de Datos, Semana 2

   @reglas
     1. Categoría Monto según TOTAL:
          0 a 50000       -> Bajo
          50001 a 100000  -> Medio
          sobre 100000    -> Alto
     2. Forma de pago según CODPAGO:
          1 -> EFECTIVO, 2 -> TARJETA DEBITO,
          3 -> TARJETA CREDITO, otro valor -> CHEQUE
     3. El RUT se muestra con largo 10, rellenando con ceros
        a la izquierda.
     4. Solo facturas del año anterior al de ejecución.
        El año se calcula con SYSDATE (sin fechas fijas).

   @salida       N° Factura, Fecha Emisión, RUT Cliente, Monto Neto,
                 Monto Iva, Total Factura, Categoría Monto,
                 Forma de pago
   @orden        Fecha descendente y, a igual fecha, monto neto
                 descendente.
   @notas        Se ordena por las columnas reales (FECHA, NETO) y no
                 por los alias, porque los alias son texto y se
                 ordenarían alfabéticamente.
   ============================================================ */

SELECT
numfactura AS "Nº factura",
TO_CHAR(fecha, 'DD "de" Month YYYY', 'NLS_DATE_LANGUAGE=SPANISH') AS "Fecha de emisión",
LPAD(rutcliente, 10, '0') AS "Rut de cliente",

TO_CHAR(neto, '$9G999G999') AS "Monto Neto",
TO_CHAR(iva, '$9G999G999') AS "Monto Iva",
TO_CHAR(total, '$9G999G999') AS "Total Factura",

CASE 
WHEN total <= 50000 THEN 'Bajo'
WHEN total <= 100000 THEN 'Medio'
ELSE 'Alto'
END AS "Categoria Monto",

CASE codpago
WHEN 1 THEN 'EFECTIVO'
WHEN 2 THEN 'TARJETA DEBIDO'
WHEN 3 THEN 'TARJETA CREDITO'
ELSE 'CHEQUE'
END AS "Forma de pago"

FROM factura
WHERE EXTRACT(YEAR FROM fecha) = EXTRACT(YEAR FROM SYSDATE) - 1
ORDER BY fecha DESC, neto DESC;


/* ============================================================
   Caso 2: Clasificación de Clientes
   ------------------------------------------------------------
   @descripcion  Reporte de clientes activos con crédito, con datos
                 validados, categorización según el uso de su crédito
                 y mensajes personalizados para datos nulos.
   @tablas       CLIENTE
   
   @reglas
     1. Solo clientes con ESTADO = 'A' y CREDITO mayor a 0.
     2. El RUT se muestra alineado a la derecha, rellenando con
        asteriscos a la izquierda hasta completar 12 caracteres.
     3. Datos nulos: teléfono -> Sin teléfono, comuna -> Sin comuna,
        correo -> Correo no registrado.
     4. Dominio del correo: texto posterior a la arroba, en mayúsculas.
     5. Estado de crédito según la relación SALDO / CREDITO:
          menor a 50%      -> Bueno   (muestra crédito menos saldo)
          entre 50% y 80%  -> Regular (muestra el saldo actual)
          mayor a 80%      -> Crítico

   @salida       RUT, Cliente, TELÉFONO, COMUNA, ESTADO,
                 Estado Crédito, Dominio Correo
   @orden        Nombre del cliente ascendente.
   @notas        La división por CREDITO es segura porque el filtro
                 excluye los créditos iguales a 0.
   ============================================================ */
SELECT 
LPAD(rutcliente, 12, '*') AS "RUT",
nombre AS "Cliente",
NVL(TO_CHAR(telefono), 'Sin telefono') AS "TELÉFONO",
NVL(TO_CHAR(codcomuna), 'Sin comuna') AS "COMUNA",

estado AS "ESTADO",

CASE
WHEN saldo / credito < 0.5
THEN 'Bueno (' || TO_CHAR(credito - saldo, '$9G999G999') || ')'
WHEN saldo / credito <= 0.8
THEN 'Regular(' || TO_CHAR(saldo, '$9G999G999') || ')'
ELSE 'Critico'
END AS "Estado Crédito",

NVL(UPPER(SUBSTR(mail, INSTR(mail, '@') + 1)),
'Correo no registrado') AS "Dominio Correo"


FROM cliente
WHERE estado = 'A'
AND credito > 0
ORDER BY nombre ASC;

/* ============================================================
   Caso 3: Stock de productos
   ------------------------------------------------------------
   @descripcion  Reporte de zapatos importados con su valor de compra
                 en dólares y en pesos, alerta de stock según umbrales
                 ingresados por el usuario y precio de oferta para los
                 productos con alto stock.
   @tablas       PRODUCTO

   @param       TIPOCAMBIO_DOLAR  Valor del dólar en pesos CLP
   @param       UMBRAL_BAJO       Stock bajo el cual la alerta es crítica
   @param       UMBRAL_ALTO       Stock sobre el cual el nivel es normal

   @reglas
     1. Solo productos cuya descripción contenga "zapato" y cuya
        procedencia sea "i" (sin distinguir mayúsculas).
     2. Valor de compra en dólares; si es nulo -> Sin registro.
     3. Conversión a pesos: dólares por tipo de cambio, redondeado
        a entero; si no hay valor en dólares -> Sin registro.
     4. Alerta de stock:
          stock nulo                      -> Sin datos
          menor al umbral bajo            -> ¡ALERTA stock muy bajo!
          entre umbral bajo y alto        -> ¡Reabastecer pronto!
          mayor al umbral alto            -> OK
     5. Precio de oferta: solo si el stock es mayor a 80 unidades,
        equivale al 90% del valor unitario (10% de descuento).
        En los demás casos -> N/A.

   @salida       ID, Descripción de Producto, Compra en USD,
                 USD convertido, Stock, Alerta Stock, Precio Oferta
   @orden        Código de producto descendente.
   @notas        NVL2 se usa en lugar de NVL porque concatenar un
                 nulo con texto no produce nulo en Oracle.
   ============================================================ */
   SELECT codproducto AS "ID",
       descripcion AS "Descripción de Producto",

NVL2(valorcompradolar,
REPLACE(TO_CHAR(valorcompradolar), '.', ',') || ' USD',
'Sin registro') AS "Compra en USD",

NVL2(valorcompradolar,
TO_CHAR(ROUND(valorcompradolar * &TIPOCAMBIO_DOLAR),
'$999G999G999') || ' PESOS',
'Sin registro') AS "USD convertido",

totalstock AS "Stock",

CASE
WHEN totalstock IS NULL            THEN 'Sin datos'
WHEN totalstock < &UMBRAL_BAJO     THEN '¡ALERTA stock muy bajo!'
WHEN totalstock <= &UMBRAL_ALTO    THEN '¡Reabastecer pronto!'
ELSE 'OK'
END AS "Alerta Stock",

CASE
WHEN totalstock > 80
THEN TO_CHAR(ROUND(vunitario * 0.9), '$999G999')
ELSE 'N/A'
END AS "Precio Oferta"

FROM producto
WHERE LOWER(descripcion) LIKE '%zapato%'
AND LOWER(procedencia) = 'i'
ORDER BY codproducto DESC;







