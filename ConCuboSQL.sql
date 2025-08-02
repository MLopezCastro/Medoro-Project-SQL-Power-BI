SELECT Renglon, SUM(CantidadBuenosProducida), Estado, Inicio, Fin FROM ConCubo
WHERE Renglon = '201' AND ID = '14620' AND AnoInicio = '2025'
GROUP BY Renglon, Estado, Inicio, Fin;


SELECT * FROM ConCubo;


SELECT *
FROM ConCubo
WHERE ID = '14620' AND Renglon = '201' AND AnoInicio = 2025;

SELECT 
    Estado,
    CantidadBuenosProducida
FROM ConCubo
WHERE 
    ID = '14620' AND 
    Renglon = '201' AND 
    AnoInicio = 2025;


SELECT 
    Estado,
    SUM(COALESCE(CantidadBuenosProducida, 0)) AS TotalBuenos
FROM ConCubo
WHERE 
    ID = '14620' AND 
    Renglon = '201' AND 
    AnoInicio = 2025 AND
    Estado = 'Producción'
GROUP BY Estado;



SELECT 
    ID,
    Renglon,
    MIN(Inicio) AS FechaInicio,
    MAX(Fin) AS FechaFin,
    Estado,
    SUM(COALESCE(CantidadBuenosProducida, 0)) AS TotalBuenos
FROM ConCubo
WHERE 
    ID = '14620' AND 
    Renglon = '201' AND 
    AnoInicio = 2025 AND
    Estado = 'Producción'
GROUP BY 
    ID, Renglon, Estado;

