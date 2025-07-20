## 🔍 Vista 1 – `vista_ConCubo_2025`

Esta vista fue el **punto de partida** del proyecto Medoro. Se construyó a partir de la tabla mal estructurada `ConCubo`, provista por el sistema original de la empresa.

### 🛠️ Objetivo

Crear una vista limpia y corregida con los siguientes ajustes:

- Corregir el **desfase histórico de 2 días** en los campos de fecha (`Inicio`, `Fin`).
- Generar **formatos legibles** para evitar jerarquía automática en Power BI.
- Calcular las **horas efectivas por tipo de estado**: producción, preparación, parada, mantenimiento.
- Extraer un **ID limpio** (numérico) desde campos alfanuméricos como `FAM 20497`.
- Filtrar únicamente los datos reales del año 2025.
- Incluir la **cantidad de unidades buenas y malas producidas**.

---

### 📄 Código SQL

```sql
CREATE OR ALTER VIEW vista_ConCubo_2025 AS
SELECT
    ID,
    TRY_CAST(SUBSTRING(ID, PATINDEX('%[0-9]%', ID), LEN(ID)) AS INT) AS ID_Limpio,
    Renglon,
    Estado,

    -- Corregimos fechas restando 2 días (desfase histórico)
    DATEADD(DAY, -2, TRY_CAST(Inicio AS DATETIME)) AS Inicio_Corregido,
    DATEADD(DAY, -2, TRY_CAST(Fin AS DATETIME)) AS Fin_Corregido,

    -- Formatos legibles para Power BI sin jerarquía automática
    CONVERT(VARCHAR(16), DATEADD(DAY, -2, TRY_CAST(Inicio AS DATETIME)), 120) AS Inicio_Legible_Texto,
    CONVERT(VARCHAR(16), DATEADD(DAY, -2, TRY_CAST(Fin AS DATETIME)), 120) AS Fin_Legible_Texto,

    -- Fecha base para agrupación
    CONVERT(DATE, DATEADD(DAY, -2, TRY_CAST(Inicio AS DATETIME))) AS Fecha,

    -- Cálculo de duración total
    DATEDIFF(SECOND, TRY_CAST(Inicio AS DATETIME), TRY_CAST(Fin AS DATETIME)) / 3600.0 AS Total_Horas,

    -- Horas separadas por estado
    CASE WHEN Estado = 'Producción' THEN DATEDIFF(SECOND, TRY_CAST(Inicio AS DATETIME), TRY_CAST(Fin AS DATETIME)) / 3600.0 ELSE 0 END AS Horas_Produccion,
    CASE WHEN Estado = 'Preparación' THEN DATEDIFF(SECOND, TRY_CAST(Inicio AS DATETIME), TRY_CAST(Fin AS DATETIME)) / 3600.0 ELSE 0 END AS Horas_Preparacion,
    CASE WHEN Estado = 'Maquina Parada' THEN DATEDIFF(SECOND, TRY_CAST(Inicio AS DATETIME), TRY_CAST(Fin AS DATETIME)) / 3600.0 ELSE 0 END AS Horas_Parada,
    CASE WHEN Estado = 'Mantenimiento' THEN DATEDIFF(SECOND, TRY_CAST(Inicio AS DATETIME), TRY_CAST(Fin AS DATETIME)) / 3600.0 ELSE 0 END AS Horas_Mantenimiento,

    -- Producción buena
    TRY_CAST(CantidadBuenosProducida AS FLOAT) AS CantidadBuenosProducida,
    TRY_CAST(CantidadMalosProducida AS FLOAT) AS CantidadMalosProducida

FROM ConCubo
WHERE 
    TRY_CAST(Inicio AS DATETIME) >= '2025-01-01'
    AND TRY_CAST(Inicio AS DATETIME) < '2026-01-01'
    AND ISNUMERIC(SUBSTRING(ID, PATINDEX('%[0-9]%', ID), LEN(ID))) = 1;
```

---

✅ Logros

Se resolvió el desfase de fechas, validando que el primer día real de trabajo fue el 2 de enero de 2025.

Se evitó el error de conversión por IDs alfanuméricos.

Se estableció la base para todas las vistas posteriores: desde acá se calcula la duración, las horas por estado y las cantidades.

---

## 🔍 Vista 2 – `vista_ConCubo_2025_Eventos`

Esta vista toma como origen la `vista_ConCubo_2025` y representa un refinamiento orientado al análisis de eventos individuales.

### 🛠️ Objetivo

- Consolidar los eventos del año 2025 con fechas corregidas.
- Calcular las horas por estado usando campos corregidos.
- Filtrar exclusivamente por el año 2025.
- Preparar la base para análisis secuencial por orden.

### 📄 Código SQL

```sql
CREATE OR ALTER VIEW vista_ConCubo_2025_Eventos AS
SELECT
    ID,
    ID_Limpio,
    Renglon,
    Estado,
    Inicio_Corregido,
    Fin_Corregido,
    Inicio_Legible_Texto,
    Fin_Legible_Texto,
    CONVERT(DATE, Inicio_Corregido) AS Fecha,
    DATEDIFF(SECOND, Inicio_Corregido, Fin_Corregido) / 3600.0 AS Total_Horas,

    CASE WHEN Estado = 'Producción' THEN DATEDIFF(SECOND, Inicio_Corregido, Fin_Corregido) / 3600.0 ELSE 0 END AS Horas_Produccion,
    CASE WHEN Estado = 'Preparación' THEN DATEDIFF(SECOND, Inicio_Corregido, Fin_Corregido) / 3600.0 ELSE 0 END AS Horas_Preparacion,
    CASE WHEN Estado = 'Maquina Parada' THEN DATEDIFF(SECOND, Inicio_Corregido, Fin_Corregido) / 3600.0 ELSE 0 END AS Horas_Parada,
    CASE WHEN Estado = 'Mantenimiento' THEN DATEDIFF(SECOND, Inicio_Corregido, Fin_Corregido) / 3600.0 ELSE 0 END AS Horas_Mantenimiento,

    CantidadBuenosProducida,
    CantidadMalosProducida

FROM vista_ConCubo_2025
WHERE YEAR(Inicio_Corregido) = 2025;
```

### ✅ Logros

- Se aislaron correctamente los registros de 2025.
- Se calculó la duración por tipo de estado con precisión.
- Se generó una vista ordenada y lista para posteriores agrupamientos o análisis temporales.

---

---

## 📊 Vista 3 – `vista_ConCubo_2025_Eventos_Diario`

Esta vista trabaja sobre `vista_ConCubo_2025_Eventos` y agrega una lógica de secuencia para identificar los distintos bloques de preparación. Es esencial para agrupar eventos y detectar cambios reales dentro de una misma orden.

### 🛠️ Objetivo

- Asignar una secuencia de ingreso por orden (`ID_Limpio`) y máquina (`Renglon`).
- Detectar inicios reales de eventos de **preparación**.
- Generar una secuencia acumulativa por cada bloque de preparación.

### 📄 Código SQL

```sql
CREATE OR ALTER VIEW vista_ConCubo_2025_Eventos_Diario AS

-- Primer CTE: agrega un número de secuencia por ID_Limpio y máquina (Renglon)
WITH Base AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY ID_Limpio, Renglon
            ORDER BY Inicio_Corregido ASC
        ) AS Nro_Secuencia
    FROM vista_ConCubo_2025_Eventos
),

-- Segundo CTE: detecta inicio de bloque de preparación
PrepFlag AS (
    SELECT *,
        CASE 
            WHEN Estado = 'Preparación' AND (
                LAG(Estado) OVER (
                    PARTITION BY ID_Limpio, Renglon 
                    ORDER BY Inicio_Corregido
                ) IS DISTINCT FROM 'Preparación'
            ) THEN 1
            ELSE 0
        END AS FlagPreparacion
    FROM Base
),

-- Tercer CTE: genera la secuencia acumulativa de bloques de preparación
PrepSecuencia AS (
    SELECT *,
        SUM(FlagPreparacion) OVER (
            PARTITION BY ID_Limpio, Renglon
            ORDER BY Inicio_Corregido
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS SecuenciaPreparacion
    FROM PrepFlag
)

-- Resultado final
SELECT *
FROM PrepSecuencia;
```

### ✅ Logros

- Se asignó una numeración por evento dentro de cada orden y máquina.
- Se identificó correctamente el inicio de cada bloque nuevo de preparación.
- Se generó una secuencia robusta para futuras agrupaciones o cálculos de duración acumulada.

---

## ✅ 4 - vista_ConCubo_2025_Resumen_Final

---

```sql
CREATE OR ALTER VIEW vista_ConCubo_2025_Resumen_Final AS
SELECT
    s.ID,
    s.ID_Limpio,
    s.Renglon,
    s.Estado,
    s.Inicio_Corregido,
    s.Fin_Corregido,
    s.Inicio_Legible_Texto,
    s.Fin_Legible_Texto,
    s.Fecha,
    s.Total_Horas,
    s.Horas_Produccion,
    s.Horas_Preparacion,
    s.Horas_Parada,  -- ✅ Ya corregida en vistas anteriores
    s.Horas_Mantenimiento,
    s.CantidadBuenosProducida,
    s.CantidadMalosProducida,
    s.Nro_Secuencia,
    s.FlagPreparacion,
    s.SecuenciaPreparacion,
    VU.saccod1
FROM vista_ConCubo_2025_Eventos_Diario s
LEFT JOIN TablaVinculadaUNION VU
    ON ISNUMERIC(VU.OP) = 1
    AND TRY_CAST(VU.OP AS INT) = s.ID_Limpio;
```

---

✅ **Logros**

- Se combinaron correctamente todos los eventos diarios con los datos de `TablaVinculadaUNION`, conectando por `ID_Limpio`.
- Se agregó `saccod1` como nuevo campo asociado para análisis posterior.
- Se conserva la trazabilidad completa del bloque anterior (`vista_ConCubo_2025_Eventos_Diario`).

---

🧩 Vista Final: vista_ConCubo_2025_Resumen_Final
Esta vista representa la consolidación final de todos los eventos diarios de producción, preparación, parada y mantenimiento para la máquina seleccionada (Renglon = 201) durante el año 2025. Fue diseñada como base estructurada para análisis en Power BI, incorporando todos los atributos corregidos, campos auxiliares legibles y conexiones externas validadas.

✅ Logros alcanzados:

Se combinaron correctamente los eventos de vista_ConCubo_2025_Eventos_Diario con los datos técnicos de TablaVinculadaUNION, utilizando la clave numérica ID_Limpio.

Se agregó el campo saccod1, indispensable para futuras asociaciones con características de diseño, como tipos de troquel (sacabocados) o insumos utilizados.

Se conservan y validan todas las correcciones previas de fecha (Inicio_Corregido, Fin_Corregido), duración por tipo de evento (Total_Horas, Horas_Produccion, Horas_Preparacion, etc.) y trazabilidad (FlagPreparacion, SecuenciaPreparacion).

Se facilita la lectura en Power BI mediante las columnas Inicio_Legible_Texto y Fin_Legible_Texto, evitando errores por jerarquías automáticas de fecha.

Esta vista es el punto de partida para la etapa final de visualización y validación del dashboard "Medoro 7". Permite controlar los tiempos por tipo de evento, cruzarlos con características técnicas del producto, y garantizar que cada análisis parta de una fuente depurada, unificada y robusta.

---


