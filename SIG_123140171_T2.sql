SELECT 
    nama_kelurahan, 
    ST_AsText(geom) AS format_wkt, 
    ST_IsValid(geom) AS status_valid 
FROM wilayah;