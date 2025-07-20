SELECT TOP 10 * FROM ConCubo
WHERE Estado = 'Maquina Parada';

SELECT TOP 1 * FROM TablaVinculadaUNION;

--

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


---

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

    -- Horas separadas por estado (con corrección de Maquina Parada)
    CASE WHEN Estado = 'Producción' THEN DATEDIFF(SECOND, Inicio_Corregido, Fin_Corregido) / 3600.0 ELSE 0 END AS Horas_Produccion,
    CASE WHEN Estado = 'Preparación' THEN DATEDIFF(SECOND, Inicio_Corregido, Fin_Corregido) / 3600.0 ELSE 0 END AS Horas_Preparacion,
    CASE WHEN Estado = 'Maquina Parada' THEN DATEDIFF(SECOND, Inicio_Corregido, Fin_Corregido) / 3600.0 ELSE 0 END AS Horas_Parada,
    CASE WHEN Estado = 'Mantenimiento' THEN DATEDIFF(SECOND, Inicio_Corregido, Fin_Corregido) / 3600.0 ELSE 0 END AS Horas_Mantenimiento,

    CantidadBuenosProducida,
    CantidadMalosProducida

FROM vista_ConCubo_2025
WHERE YEAR(Inicio_Corregido) = 2025;

--Si querés mostrar otros años además de 2025 (por ejemplo, 2015 a 2025), el cambio debe hacerse en la vista base, 
--es decir:

--🔄 Debés modificar vista_ConCubo_2025 (la primera vista) para que no tenga filtro por año 
--o tenga un rango más amplio.

---

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

---

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

---
--TEST VALIDAR

SELECT
    ID_Limpio,
    SUM(Horas_Produccion) AS Total_Horas_Produccion,
    SUM(Horas_Preparacion) AS Total_Horas_Preparacion,
    SUM(Horas_Parada) AS Total_Horas_Parada,
    SUM(Horas_Mantenimiento) AS Total_Horas_Mantenimiento
FROM vista_ConCubo_2025_Resumen_Final
WHERE
    Renglon = 201
    AND ID_Limpio IN (14782, 14800, 14805, 14828, 14832)
GROUP BY ID_Limpio
ORDER BY ID_Limpio;

---
